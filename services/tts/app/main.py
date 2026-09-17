"""Lango TTS service.

Flutter → HTTPS → this service → MagpieTTS (GPU) → Supabase Storage → CDN URL.

The model is loaded once during the lifespan and stays in GPU memory for the
life of the process.
"""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import metrics
from .config import get_settings
from .rate_limit import RateLimiter
from .routes import health, tts
from .single_flight import SingleFlight
from .storage import SupabaseStorage
from .synthesis import MagpieSynthesizer

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logging.basicConfig(
        level=settings.log_level.upper(),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    # One client for the process: connection reuse matters when every request
    # makes two or three Storage calls.
    app.state.http = httpx.AsyncClient(timeout=15.0)
    app.state.storage = SupabaseStorage(settings, app.state.http)
    app.state.rate_limiter = RateLimiter(per_minute=settings.tts_rate_limit_per_minute)
    app.state.single_flight = SingleFlight()
    app.state.synthesizer = MagpieSynthesizer(settings)

    await app.state.storage.ensure_bucket()

    # TTS_SKIP_MODEL_LOAD lets the API be exercised without a GPU — used by the
    # test suite and by anyone inspecting the schema locally. It is never set
    # in a real deployment, where /ready would then never go green.
    if os.getenv("TTS_SKIP_MODEL_LOAD", "").lower() in ("1", "true", "yes"):
        logger.warning("TTS_SKIP_MODEL_LOAD set — starting without the model")
    else:
        # Load synchronously: the container must not report ready before it
        # can actually serve.
        app.state.synthesizer.load()
        metrics.MODEL_LOADED.set(1)

    try:
        yield
    finally:
        # Drain politely: uvicorn stops accepting first, so in-flight requests
        # finish before the model is released.
        metrics.MODEL_LOADED.set(0)
        app.state.synthesizer.unload()
        await app.state.http.aclose()


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Lango TTS",
        version="1.0.0",
        description=(
            "Speech synthesis for Lango, backed by NVIDIA MagpieTTS "
            "Multilingual 357M. English, Korean and Japanese."
        ),
        lifespan=lifespan,
    )

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_methods=["POST", "GET"],
            allow_headers=["authorization", "content-type"],
        )

    app.include_router(health.router)
    app.include_router(tts.router)

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        # Never leak a stack trace or the model's own error text to a client.
        logger.exception("unhandled error on %s", request.url.path)
        metrics.ERRORS.labels(kind="unhandled").inc()
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": "internal_error"},
        )

    return app


app = create_app()
