"""POST /v1/tts — the cases the service has to get right."""

from __future__ import annotations

import asyncio
import io

import pytest
import soundfile as sf
from fastapi.testclient import TestClient

from app.synthesis import ModelNotReady, SynthesisError

from .conftest import build_settings, ffmpeg_available

# The exact sentences the spec asks to verify.
ENGLISH = "Hello, how are you?"
KOREAN = "안녕하세요. 오늘 한국어를 공부해 봅시다."
JAPANESE = "こんにちは。今日は日本語を勉強しましょう。"


def post(client: TestClient, text: str, language: str, **extra):
    return client.post(
        "/v1/tts", json={"text": text, "language": language, **extra}
    )


# ── The three languages ──────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("text", "language"),
    [(ENGLISH, "en"), (KOREAN, "ko"), (JAPANESE, "ja")],
)
def test_synthesizes_each_supported_language(client, synthesizer, text, language):
    response = post(client, text, language)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["language"] == language
    assert body["cached"] is False
    assert body["audio_url"].startswith("https://storage.test/")
    assert body["duration_seconds"] == pytest.approx(0.5, abs=0.01)

    # The text must reach the model exactly as supplied — no translation, no
    # rewriting — and under the right language.
    assert synthesizer.calls == [(text, language, "Aria")]


def test_generated_audio_is_real_playable_audio(client, storage):
    post(client, KOREAN, "ko")

    (data,) = storage.objects.values()
    samples, rate = sf.read(io.BytesIO(data))
    assert rate == 22050
    assert samples.size > 0
    # Not a silent or corrupt file.
    assert abs(samples).max() > 0.01


def test_audio_is_stored_under_a_language_partitioned_path(client, storage):
    post(client, KOREAN, "ko")
    (path,) = storage.objects
    assert path.startswith("ko/")
    assert path.endswith(".wav")


# ── Validation ───────────────────────────────────────────────────────────────


@pytest.mark.parametrize("text", ["", "   ", "\n\t"])
def test_empty_text_is_rejected(client, synthesizer, text):
    assert post(client, text, "en").status_code == 422
    assert synthesizer.calls == []


def test_text_over_the_maximum_is_rejected_with_the_limit(make_app):
    settings = build_settings(tts_max_text_length=20)
    with TestClient(make_app(settings)) as client:
        response = post(client, "x" * 21, "en")
    assert response.status_code == 422
    assert "20" in response.json()["detail"]


def test_text_at_exactly_the_maximum_is_accepted(make_app):
    settings = build_settings(tts_max_text_length=20)
    with TestClient(make_app(settings)) as client:
        assert post(client, "x" * 20, "en").status_code == 200


def test_unsupported_language_is_rejected(client, synthesizer):
    # German is a MagpieTTS language but not one Lango teaches.
    assert post(client, "Guten Tag", "de").status_code == 422
    assert post(client, "hello", "klingon").status_code == 422
    assert synthesizer.calls == []


def test_unknown_voice_is_rejected(client):
    response = post(client, ENGLISH, "en", voice="Nobody")
    assert response.status_code == 422
    assert "Nobody" in response.json()["detail"]


def test_named_voice_is_passed_through(client, synthesizer):
    post(client, ENGLISH, "en", voice="Leo")
    assert synthesizer.calls[0][2] == "Leo"


# ── Authentication ───────────────────────────────────────────────────────────


def test_missing_authentication_is_rejected(make_app, settings, synthesizer):
    with TestClient(make_app(settings, authenticated=False)) as client:
        response = client.post("/v1/tts", json={"text": ENGLISH, "language": "en"})
    assert response.status_code == 401
    assert synthesizer.calls == []


def test_invalid_authentication_is_rejected(make_app, settings, synthesizer):
    with TestClient(make_app(settings, authenticated=False)) as client:
        response = client.post(
            "/v1/tts",
            json={"text": ENGLISH, "language": "en"},
            headers={"Authorization": "Bearer not-a-real-token"},
        )
    assert response.status_code in (401, 503)
    assert synthesizer.calls == []


def test_the_service_role_key_is_never_returned(client):
    body = post(client, ENGLISH, "en").text
    assert "service-role-key" not in body


# ── Caching ──────────────────────────────────────────────────────────────────


def test_second_identical_request_is_a_cache_hit(client, synthesizer):
    first = post(client, KOREAN, "ko")
    second = post(client, KOREAN, "ko")

    assert first.json()["cached"] is False
    assert second.json()["cached"] is True
    # The whole point: the model ran once.
    assert len(synthesizer.calls) == 1


def test_cache_is_scoped_by_language(client, synthesizer):
    post(client, "ありがとう", "ja")
    post(client, "ありがとう", "ko")
    assert len(synthesizer.calls) == 2


def test_cache_is_scoped_by_voice(client, synthesizer):
    post(client, ENGLISH, "en", voice="Aria")
    post(client, ENGLISH, "en", voice="Leo")
    assert len(synthesizer.calls) == 2


def test_whitespace_only_differences_share_a_cache_entry(client, synthesizer):
    post(client, "  Hello,  how are you?  ", "en")
    post(client, "Hello, how are you?", "en")
    assert len(synthesizer.calls) == 1


def test_cache_can_be_disabled(make_app, synthesizer):
    settings = build_settings(tts_cache_enabled=False)
    with TestClient(make_app(settings)) as client:
        post(client, ENGLISH, "en")
        post(client, ENGLISH, "en")
    assert len(synthesizer.calls) == 2


def test_a_failed_cache_lookup_degrades_to_regenerating(client, storage, synthesizer):
    storage.fail_exists = True
    assert post(client, ENGLISH, "en").status_code == 200
    assert len(synthesizer.calls) == 1


# ── Failures ─────────────────────────────────────────────────────────────────


def test_model_not_loaded_returns_503(client, synthesizer):
    synthesizer.raises = ModelNotReady("model is not loaded")
    response = post(client, ENGLISH, "en")
    assert response.status_code == 503


def test_generation_failure_returns_502_without_leaking_internals(
    client, synthesizer
):
    synthesizer.raises = SynthesisError("/opt/models/secret/path exploded")
    response = post(client, ENGLISH, "en")
    assert response.status_code == 502
    assert "/opt/models" not in response.text


def test_generation_timeout_returns_504(make_app, synthesizer):
    settings = build_settings(tts_request_timeout_seconds=0.05)
    synthesizer.delay = 0.5
    with TestClient(make_app(settings)) as client:
        assert post(client, ENGLISH, "en").status_code == 504


def test_storage_upload_failure_returns_502(client, storage):
    storage.fail_upload = True
    response = post(client, ENGLISH, "en")
    assert response.status_code == 502
    assert "Could not store" in response.json()["detail"]


def test_signing_failure_returns_502(client, storage):
    storage.fail_sign = True
    assert post(client, ENGLISH, "en").status_code == 502


def test_a_failed_generation_is_not_cached(client, synthesizer, storage):
    synthesizer.raises = SynthesisError("boom")
    post(client, ENGLISH, "en")
    assert storage.objects == {}

    # A later attempt must be free to succeed.
    synthesizer.raises = None
    assert post(client, ENGLISH, "en").status_code == 200


# ── Rate limiting ────────────────────────────────────────────────────────────


def test_rate_limit_applies_to_new_phrases(make_app, synthesizer):
    settings = build_settings(tts_rate_limit_per_minute=2)
    with TestClient(make_app(settings)) as client:
        assert post(client, "one", "en").status_code == 200
        assert post(client, "two", "en").status_code == 200
        limited = post(client, "three", "en")
    assert limited.status_code == 429
    assert limited.headers.get("Retry-After")
    assert len(synthesizer.calls) == 2


def test_cache_hits_are_not_rate_limited(make_app, synthesizer):
    """Replaying a known word must never be throttled — it costs no GPU."""
    settings = build_settings(tts_rate_limit_per_minute=1)
    with TestClient(make_app(settings)) as client:
        assert post(client, KOREAN, "ko").status_code == 200  # spends the budget
        for _ in range(5):
            response = post(client, KOREAN, "ko")
            assert response.status_code == 200
            assert response.json()["cached"] is True
    assert len(synthesizer.calls) == 1


# ── Concurrency ──────────────────────────────────────────────────────────────


async def test_concurrent_identical_requests_generate_once(
    make_app, settings, synthesizer
):
    """Thirty learners opening the same card must not queue thirty jobs."""
    import httpx

    synthesizer.delay = 0.1
    app = make_app(settings)

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as ac:
        responses = await asyncio.gather(
            *[
                ac.post("/v1/tts", json={"text": KOREAN, "language": "ko"})
                for _ in range(10)
            ]
        )

    assert all(r.status_code == 200 for r in responses)
    assert len(synthesizer.calls) == 1


async def test_concurrent_different_requests_all_generate(
    make_app, settings, synthesizer
):
    import httpx

    app = make_app(settings)
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as ac:
        responses = await asyncio.gather(
            *[
                ac.post("/v1/tts", json={"text": f"word {i}", "language": "en"})
                for i in range(5)
            ]
        )

    assert all(r.status_code == 200 for r in responses)
    assert len(synthesizer.calls) == 5


async def test_a_coalesced_failure_reaches_every_waiter(
    make_app, settings, synthesizer
):
    import httpx

    synthesizer.delay = 0.05
    synthesizer.raises = SynthesisError("boom")
    app = make_app(settings)

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as ac:
        responses = await asyncio.gather(
            *[
                ac.post("/v1/tts", json={"text": KOREAN, "language": "ko"})
                for _ in range(5)
            ]
        )

    # No waiter may be told the audio is ready when it is not.
    assert all(r.status_code == 502 for r in responses)


# ── Encoding ─────────────────────────────────────────────────────────────────


@pytest.mark.skipif(not ffmpeg_available(), reason="ffmpeg not installed")
def test_mp3_encoding_produces_an_mp3(make_app, storage):
    settings = build_settings(tts_audio_format="mp3")
    with TestClient(make_app(settings)) as client:
        response = post(client, ENGLISH, "en")

    assert response.status_code == 200
    assert response.json()["format"] == "mp3"
    (data,) = storage.objects.values()
    # ID3 tag or an MPEG frame sync.
    assert data[:3] == b"ID3" or data[:2] == b"\xff\xfb"
