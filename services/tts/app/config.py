"""Service configuration, entirely from environment variables.

No secret has a default. A missing secret fails at startup rather than at the
first request, so a misconfigured container never starts serving.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from .languages import DEFAULT_VOICE, SPEAKER_MAP


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        # `model_` is a pydantic-reserved prefix; our fields avoid it.
        protected_namespaces=(),
    )

    # ── Model ────────────────────────────────────────────────────────────────
    tts_model_id: str = "bertx18/magpie_tts_multilingual_357m"

    # Pinning a revision makes container startup reproducible: a moving `main`
    # would silently change the voice — and therefore every cache key.
    tts_model_revision: str | None = None

    # Part of the cache key. Bump it whenever the model, revision or any
    # generation default changes, so stale audio is never served for new
    # settings.
    tts_model_version: str = "magpie-357m-v1"

    tts_device: str = "cuda"
    tts_default_voice: str = DEFAULT_VOICE

    # Text normalisation expands numbers and abbreviations. Lango's content is
    # ordinary prose, so leaving it on is the safer default; turn it off for
    # IPA input.
    tts_apply_tn: bool = True
    tts_use_cfg: bool = False

    # ── Limits ───────────────────────────────────────────────────────────────
    # A vocabulary word or example sentence. Long enough for a paragraph of
    # example text, short enough that one request cannot monopolise the GPU.
    tts_max_text_length: int = 500

    # Concurrent GPU generations. One 357M model on a 24 GB card comfortably
    # handles a few; raise only after watching VRAM under load.
    tts_max_concurrency: int = 2

    # Per-user budget. Cache hits are not counted against it, so a learner
    # replaying the same word is never rate limited.
    tts_rate_limit_per_minute: int = 30

    # Guards against a wedged generation holding a GPU slot forever.
    tts_request_timeout_seconds: float = 60.0

    # ── Audio ────────────────────────────────────────────────────────────────
    # The model emits 22.05 kHz mono PCM16. WAV at that rate is ~44 kB/s, so a
    # three-second clip is ~130 kB; MP3 at 64 kbps is ~24 kB and plays natively
    # on both iOS and Android.
    tts_audio_format: str = "mp3"
    tts_audio_bitrate: str = "64k"

    # ── Cache ────────────────────────────────────────────────────────────────
    tts_cache_enabled: bool = True

    # ── Supabase ─────────────────────────────────────────────────────────────
    supabase_url: str
    # Server-only. Never sent to, or readable by, the Flutter client.
    supabase_service_role_key: str
    supabase_storage_bucket: str = "tts-audio"

    # Optional: lets the service verify HS256 tokens without a network call.
    # When unset the service uses JWKS, falling back to the Auth API.
    supabase_jwt_secret: str | None = None

    # Signed URLs are short-lived; the client plays immediately and re-requests
    # (hitting the cache) if it needs the audio again later.
    tts_signed_url_ttl_seconds: int = 3600

    # ── Service-to-service auth ──────────────────────────────────────────────
    # Optional shared secret for trusted server callers such as a cache
    # pre-warm job. Never shipped to Flutter, which authenticates as the user.
    tts_api_key: str | None = None

    # ── HTTP ─────────────────────────────────────────────────────────────────
    tts_cors_origins: str = ""
    log_level: str = "INFO"

    @field_validator("tts_default_voice")
    @classmethod
    def _known_voice(cls, value: str) -> str:
        if value not in SPEAKER_MAP:
            raise ValueError(
                f"TTS_DEFAULT_VOICE must be one of {sorted(SPEAKER_MAP)}"
            )
        return value

    @field_validator("tts_audio_format")
    @classmethod
    def _supported_format(cls, value: str) -> str:
        allowed = {"mp3", "opus", "wav"}
        if value not in allowed:
            raise ValueError(f"TTS_AUDIO_FORMAT must be one of {sorted(allowed)}")
        return value

    @field_validator("supabase_url")
    @classmethod
    def _no_trailing_slash(cls, value: str) -> str:
        return value.rstrip("/")

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.tts_cors_origins.split(",") if o.strip()]

    @property
    def content_type(self) -> str:
        return {
            "mp3": "audio/mpeg",
            "opus": "audio/ogg",
            "wav": "audio/wav",
        }[self.tts_audio_format]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Settings are read once per process."""
    return Settings()  # type: ignore[call-arg]
