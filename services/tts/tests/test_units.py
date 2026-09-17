"""Unit tests for the pieces the endpoint tests exercise only indirectly."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.cache import cache_key, normalize_text, object_path
from app.languages import DEFAULT_VOICE, SPEAKER_MAP, Language, speaker_index
from app.rate_limit import RateLimiter


# ── Language enum ────────────────────────────────────────────────────────────


def test_only_the_three_taught_languages_are_exposed():
    assert Language.values() == ["en", "ko", "ja"]


def test_every_language_maps_to_the_model_code():
    # These are exactly the codes MagpieTTS documents for these languages.
    assert Language.ENGLISH.value == "en"
    assert Language.KOREAN.value == "ko"
    assert Language.JAPANESE.value == "ja"


def test_default_voice_is_one_the_model_ships():
    assert DEFAULT_VOICE in SPEAKER_MAP
    assert speaker_index(DEFAULT_VOICE) == 0


def test_unknown_voice_raises():
    with pytest.raises(KeyError):
        speaker_index("Nobody")


# ── Cache key ────────────────────────────────────────────────────────────────


def _key(**overrides) -> str:
    base = dict(
        text="안녕하세요",
        language=Language.KOREAN,
        voice="Aria",
        model_version="v1",
        apply_tn=True,
        use_cfg=False,
        audio_format="mp3",
    )
    base.update(overrides)
    return cache_key(**base)  # type: ignore[arg-type]


def test_cache_key_is_deterministic():
    assert _key() == _key()


@pytest.mark.parametrize(
    "override",
    [
        {"text": "안녕"},
        {"language": Language.JAPANESE},
        {"voice": "Leo"},
        {"model_version": "v2"},
        {"apply_tn": False},
        {"use_cfg": True},
        {"audio_format": "wav"},
    ],
    ids=["text", "language", "voice", "model", "tn", "cfg", "format"],
)
def test_every_field_that_changes_the_audio_changes_the_key(override):
    assert _key(**override) != _key()


def test_field_boundaries_cannot_be_forged():
    """Concatenation must not let two different inputs collide."""
    assert _key(voice="Aria", text="x") != _key(voice="Aria\x1fx", text="")


def test_normalization_unifies_equivalent_hangul():
    composed = "안"  # 안
    decomposed = "안"  # ᄋ + ᅡ + ᆫ
    assert normalize_text(composed) == normalize_text(decomposed)
    assert _key(text=composed) == _key(text=decomposed)


def test_normalization_collapses_incidental_whitespace():
    assert normalize_text("  a   b  ") == "a b"
    assert _key(text=" 안녕 하세요 ") == _key(text="안녕 하세요")


def test_normalization_keeps_meaningful_differences():
    # Punctuation changes prosody, so it must not be normalised away.
    assert _key(text="갔어요") != _key(text="갔어요?")
    assert _key(text="Hello") != _key(text="hello")


def test_object_path_is_partitioned_and_extensioned():
    key = _key()
    path = object_path(key, Language.KOREAN, "mp3")
    assert path == f"ko/{key[:2]}/{key}.mp3"


# ── Rate limiter ─────────────────────────────────────────────────────────────


def test_rate_limiter_allows_up_to_the_budget():
    limiter = RateLimiter(per_minute=3)
    assert [limiter.allow("u", now=100.0) for _ in range(3)] == [True] * 3
    assert limiter.allow("u", now=100.0) is False


def test_rate_limiter_is_per_user():
    limiter = RateLimiter(per_minute=1)
    assert limiter.allow("a", now=100.0) is True
    assert limiter.allow("b", now=100.0) is True
    assert limiter.allow("a", now=100.0) is False


def test_rate_limiter_refills_over_time():
    limiter = RateLimiter(per_minute=60)  # one per second
    for _ in range(60):
        limiter.allow("u", now=100.0)
    assert limiter.allow("u", now=100.0) is False
    assert limiter.allow("u", now=101.5) is True


def test_rate_limiter_never_exceeds_its_ceiling():
    limiter = RateLimiter(per_minute=5)
    limiter.allow("u", now=100.0)
    # A long idle period must not build up an unbounded burst.
    assert [limiter.allow("u", now=100_000.0) for _ in range(5)] == [True] * 5
    assert limiter.allow("u", now=100_000.0) is False


def test_zero_disables_rate_limiting():
    limiter = RateLimiter(per_minute=0)
    assert all(limiter.allow("u", now=100.0) for _ in range(100))


# ── Health and readiness ─────────────────────────────────────────────────────


def test_health_reports_the_model_and_languages(client):
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert body["languages"] == ["en", "ko", "ja"]
    assert body["model_loaded"] is True


def test_ready_is_green_once_the_model_is_loaded(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["ready"] is True


def test_ready_is_red_before_the_model_loads(make_app, settings, synthesizer):
    """A container still loading must not be sent traffic."""
    synthesizer.is_loaded = False
    with TestClient(make_app(settings)) as client:
        response = client.get("/ready")
    assert response.status_code == 503
    assert response.json()["ready"] is False


def test_metrics_are_exposed(client):
    client.post("/v1/tts", json={"text": "hello", "language": "en"})
    body = client.get("/metrics").text
    assert "tts_requests_total" in body
    assert "tts_cache_misses_total" in body
