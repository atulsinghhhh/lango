"""Request and response models.

The response is deliberately a URL, not audio bytes: a base64 payload would
inflate the JSON by a third, defeat HTTP caching, and force the whole clip
through the API process instead of letting the CDN serve it.
"""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

from .languages import Language


class TtsRequest(BaseModel):
    text: str = Field(..., description="Exactly the text to synthesize.")
    language: Language = Field(..., description="One of en, ko, ja.")
    voice: str | None = Field(
        default=None,
        description="Speaker name. Defaults to the service's configured voice.",
    )

    @field_validator("text")
    @classmethod
    def _non_empty(cls, value: str) -> str:
        # Length is checked in the route, where the configured maximum is
        # available and the error can name the limit.
        if not value.strip():
            raise ValueError("text must not be empty")
        return value


class TtsResponse(BaseModel):
    audio_url: str
    language: Language
    cached: bool
    # Enough for a client to pick a player and show a progress bar without a
    # HEAD request first.
    format: str
    duration_seconds: float | None = None


class ErrorResponse(BaseModel):
    error: str
    detail: str | None = None


class HealthResponse(BaseModel):
    status: str
    model_id: str
    model_loaded: bool
    device: str
    languages: list[str]
