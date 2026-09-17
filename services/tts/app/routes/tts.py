"""POST /v1/tts — synthesize, cache, and hand back a playable URL."""

from __future__ import annotations

import asyncio
import logging
import time

from fastapi import APIRouter, Depends, HTTPException, status

from .. import audio as audio_codec
from .. import metrics
from ..auth import Principal, require_principal
from ..cache import cache_key, object_path
from ..config import Settings, get_settings
from ..deps import (
    get_rate_limiter,
    get_single_flight,
    get_storage,
    get_synthesizer,
)
from ..languages import is_supported_voice
from ..rate_limit import RateLimiter
from ..schemas import TtsRequest, TtsResponse
from ..single_flight import SingleFlight
from ..storage import StorageError, SupabaseStorage
from ..synthesis import MagpieSynthesizer, ModelNotReady, SynthesisError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1", tags=["tts"])


@router.post(
    "/tts",
    response_model=TtsResponse,
    responses={
        401: {"description": "Missing or invalid Supabase session."},
        422: {"description": "Unsupported language, voice, or text length."},
        429: {"description": "Rate limit exceeded."},
        502: {"description": "Generation, encoding, or storage failed."},
        503: {"description": "Model not loaded."},
        504: {"description": "Generation timed out."},
    },
)
async def synthesize(
    payload: TtsRequest,
    principal: Principal = Depends(require_principal),
    settings: Settings = Depends(get_settings),
    synthesizer: MagpieSynthesizer = Depends(get_synthesizer),
    storage: SupabaseStorage = Depends(get_storage),
    limiter: RateLimiter = Depends(get_rate_limiter),
    single_flight: SingleFlight = Depends(get_single_flight),
) -> TtsResponse:
    started = time.monotonic()
    language = payload.language

    if len(payload.text) > settings.tts_max_text_length:
        metrics.ERRORS.labels(kind="text_too_long").inc()
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"text is {len(payload.text)} characters; the maximum is "
                f"{settings.tts_max_text_length}."
            ),
        )

    voice = payload.voice or settings.tts_default_voice
    if not is_supported_voice(voice):
        metrics.ERRORS.labels(kind="unknown_voice").inc()
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"unknown voice '{voice}'.",
        )

    key = cache_key(
        text=payload.text,
        language=language,
        voice=voice,
        model_version=settings.tts_model_version,
        apply_tn=settings.tts_apply_tn,
        use_cfg=settings.tts_use_cfg,
        audio_format=settings.tts_audio_format,
    )
    path = object_path(key, language, settings.tts_audio_format)

    # 1. Cache first. A hit costs no GPU time, so it is also not rate limited:
    #    replaying a known word must never be throttled.
    if settings.tts_cache_enabled and await storage.exists(path):
        url = await _sign(storage, path)
        metrics.CACHE_HITS.labels(language=language.value).inc()
        metrics.REQUESTS.labels(result="ok", language=language.value).inc()
        metrics.REQUEST_SECONDS.labels(cached="true").observe(
            time.monotonic() - started
        )
        return TtsResponse(
            audio_url=url,
            language=language,
            cached=True,
            format=settings.tts_audio_format,
        )

    # 2. Only work that reaches the GPU is charged against the budget.
    if not limiter.allow(principal.rate_limit_key):
        metrics.ERRORS.labels(kind="rate_limited").inc()
        metrics.REQUESTS.labels(result="rate_limited", language=language.value).inc()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many new phrases. Try again shortly.",
            headers={"Retry-After": "10"},
        )

    metrics.CACHE_MISSES.labels(language=language.value).inc()

    was_coalesced = single_flight.inflight_count > 0

    async def generate() -> float | None:
        return await _generate_and_store(
            text=payload.text,
            language=language,
            voice=voice,
            path=path,
            settings=settings,
            synthesizer=synthesizer,
            storage=storage,
        )

    try:
        duration = await single_flight.run(key, generate)
        if was_coalesced:
            metrics.COALESCED.inc()
    except HTTPException:
        metrics.REQUESTS.labels(result="error", language=language.value).inc()
        raise
    except Exception as exc:  # noqa: BLE001 - mapped to a client-safe error
        metrics.REQUESTS.labels(result="error", language=language.value).inc()
        raise _as_http_error(exc) from exc

    url = await _sign(storage, path)
    metrics.REQUESTS.labels(result="ok", language=language.value).inc()
    metrics.REQUEST_SECONDS.labels(cached="false").observe(time.monotonic() - started)

    return TtsResponse(
        audio_url=url,
        language=language,
        cached=False,
        format=settings.tts_audio_format,
        duration_seconds=duration,
    )


async def _generate_and_store(
    *,
    text: str,
    language,  # noqa: ANN001 - Language, kept loose to avoid a cycle
    voice: str,
    path: str,
    settings: Settings,
    synthesizer: MagpieSynthesizer,
    storage: SupabaseStorage,
) -> float:
    """Run inference, encode, upload. Returns the clip duration in seconds."""
    metrics.QUEUE_DEPTH.inc()
    try:
        async with synthesizer.slots:
            metrics.QUEUE_DEPTH.dec()
            metrics.INFLIGHT.inc()
            try:
                result = await asyncio.wait_for(
                    synthesizer.synthesize(text, language, voice),
                    timeout=settings.tts_request_timeout_seconds,
                )
            finally:
                metrics.INFLIGHT.dec()
    except BaseException:
        # The gauge was already decremented on the happy path; make sure a
        # failure before acquiring the slot does not leak a count.
        if metrics.QUEUE_DEPTH._value.get() > 0:  # noqa: SLF001
            metrics.QUEUE_DEPTH.dec()
        raise

    metrics.INFERENCE_SECONDS.observe(result.inference_seconds)
    metrics.AUDIO_SECONDS.observe(result.duration_seconds)

    encoded = await audio_codec.encode(
        result.samples,
        result.sample_rate,
        settings.tts_audio_format,
        settings.tts_audio_bitrate,
    )
    await storage.upload(path, encoded, settings.content_type)
    return result.duration_seconds


async def _sign(storage: SupabaseStorage, path: str) -> str:
    try:
        return await storage.signed_url(path)
    except StorageError as exc:
        metrics.ERRORS.labels(kind="storage").inc()
        logger.error("could not sign %s: %s", path, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Audio was generated but could not be served.",
        ) from exc


def _as_http_error(exc: Exception) -> HTTPException:
    """Map an internal failure to a client-safe response.

    The model's own error text can carry file paths and prompt content, so it
    is logged rather than returned.
    """
    if isinstance(exc, ModelNotReady):
        metrics.ERRORS.labels(kind="model_not_ready").inc()
        return HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The speech model is not ready.",
        )
    if isinstance(exc, asyncio.TimeoutError):
        metrics.ERRORS.labels(kind="timeout").inc()
        return HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Generation took too long.",
        )
    if isinstance(exc, SynthesisError):
        metrics.ERRORS.labels(kind="synthesis").inc()
        logger.error("synthesis failed: %s", exc)
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not generate audio for that text.",
        )
    if isinstance(exc, audio_codec.EncodingError):
        metrics.ERRORS.labels(kind="encoding").inc()
        logger.error("encoding failed: %s", exc)
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not encode the generated audio.",
        )
    if isinstance(exc, StorageError):
        metrics.ERRORS.labels(kind="storage").inc()
        logger.error("storage failed: %s", exc)
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not store the generated audio.",
        )

    metrics.ERRORS.labels(kind="unexpected").inc()
    logger.exception("unexpected failure")
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail="Speech generation failed.",
    )
