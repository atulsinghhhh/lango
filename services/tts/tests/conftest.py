"""Test fixtures.

The suite exercises the whole service except the model itself: a fake
synthesizer stands in for MagpieTTS so routing, auth, validation, caching,
coalescing, rate limiting and error mapping are all covered without a GPU.

The one thing a fake cannot prove is that the model produces real speech —
`test_real_inference.py` covers that and is skipped unless a GPU is present.
"""

from __future__ import annotations

import asyncio
import shutil

import numpy as np
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.auth import Principal, require_principal
from app.config import Settings, get_settings
from app.rate_limit import RateLimiter
from app.routes import health, tts
from app.single_flight import SingleFlight
from app.storage import StorageError
from app.synthesis import SynthesisResult

TEST_USER = "11111111-2222-3333-4444-555555555555"


class FakeStorage:
    """In-memory stand-in for Supabase Storage."""

    def __init__(self) -> None:
        self.objects: dict[str, bytes] = {}
        self.uploads = 0
        self.fail_upload = False
        self.fail_sign = False
        self.fail_exists = False

    async def exists(self, path: str) -> bool:
        if self.fail_exists:
            # Mirrors the real client: a lookup failure answers "no".
            return False
        return path in self.objects

    async def upload(self, path: str, data: bytes, content_type: str) -> None:
        if self.fail_upload:
            raise StorageError("upload rejected with 500")
        self.uploads += 1
        self.objects[path] = data

    async def signed_url(self, path: str) -> str:
        if self.fail_sign:
            raise StorageError("signing rejected with 500")
        return f"https://storage.test/{path}?token=signed"

    async def ensure_bucket(self) -> None:
        return None


class FakeSynthesizer:
    def __init__(self, concurrency: int = 2) -> None:
        self.calls: list[tuple[str, str, str]] = []
        self.slots = asyncio.Semaphore(concurrency)
        self.is_loaded = True
        self.device = "cpu"
        self.raises: Exception | None = None
        self.delay = 0.0

    async def synthesize(self, text, language, voice) -> SynthesisResult:  # noqa: ANN001
        self.calls.append((text, language.value, voice))
        if self.delay:
            await asyncio.sleep(self.delay)
        if self.raises is not None:
            raise self.raises
        # Half a second of a quiet tone: real enough that soundfile writes a
        # valid WAV and the duration assertion means something.
        rate = 22050
        t = np.linspace(0, 0.5, rate // 2, endpoint=False)
        samples = (np.sin(2 * np.pi * 440 * t) * 8000).astype(np.int16)
        return SynthesisResult(
            samples=samples, sample_rate=rate, inference_seconds=0.01
        )


def build_settings(**overrides) -> Settings:
    base = dict(
        supabase_url="https://project.supabase.co",
        supabase_service_role_key="service-role-key",
        supabase_storage_bucket="tts-audio",
        # WAV keeps the suite free of an ffmpeg dependency; a separate test
        # covers mp3 when ffmpeg is available.
        tts_audio_format="wav",
        tts_cache_enabled=True,
        tts_max_text_length=500,
        tts_rate_limit_per_minute=1000,
        tts_model_version="test-v1",
    )
    base.update(overrides)
    return Settings(**base)  # type: ignore[arg-type]


@pytest.fixture
def storage() -> FakeStorage:
    return FakeStorage()


@pytest.fixture
def synthesizer() -> FakeSynthesizer:
    return FakeSynthesizer()


@pytest.fixture
def settings() -> Settings:
    return build_settings()


@pytest.fixture
def make_app(storage, synthesizer):
    """Build an app wired to the fakes, with auth optionally bypassed."""

    def _factory(settings: Settings, *, authenticated: bool = True) -> FastAPI:
        app = FastAPI()
        app.include_router(health.router)
        app.include_router(tts.router)

        app.state.storage = storage
        app.state.synthesizer = synthesizer
        app.state.rate_limiter = RateLimiter(
            per_minute=settings.tts_rate_limit_per_minute
        )
        app.state.single_flight = SingleFlight()

        app.dependency_overrides[get_settings] = lambda: settings
        if authenticated:
            app.dependency_overrides[require_principal] = lambda: Principal(
                subject=TEST_USER
            )
        return app

    return _factory


@pytest.fixture
def client(make_app, settings):
    with TestClient(make_app(settings)) as c:
        yield c


def ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None
