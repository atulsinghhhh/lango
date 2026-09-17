"""End-to-end checks against the real MagpieTTS model.

Skipped unless a CUDA device and the NeMo toolkit are both present, so the rest
of the suite stays runnable on a laptop. Run these on the GPU box before a
deploy:

    pytest -m gpu

They are the only tests that can prove the model actually produces speech in
each language rather than silence or noise.
"""

from __future__ import annotations

import numpy as np
import pytest

from app.config import Settings
from app.languages import Language
from app.synthesis import SAMPLE_RATE, MagpieSynthesizer

pytestmark = pytest.mark.gpu


def _gpu_and_model_available() -> bool:
    try:
        import torch  # noqa: F401
        from nemo.collections.tts.models import MagpieTTSModel  # noqa: F401
    except Exception:  # noqa: BLE001
        return False
    import torch

    return torch.cuda.is_available()


pytestmark = [
    pytest.mark.gpu,
    pytest.mark.skipif(
        not _gpu_and_model_available(),
        reason="needs a CUDA device with nemo_toolkit[tts] installed",
    ),
]


@pytest.fixture(scope="module")
def synthesizer() -> MagpieSynthesizer:
    settings = Settings(  # type: ignore[call-arg]
        supabase_url="https://unused.supabase.co",
        supabase_service_role_key="unused",
    )
    engine = MagpieSynthesizer(settings)
    engine.load()
    yield engine
    engine.unload()


def test_model_loads_once_and_reports_ready(synthesizer):
    assert synthesizer.is_loaded


@pytest.mark.parametrize(
    ("language", "text"),
    [
        (Language.ENGLISH, "Hello, how are you?"),
        (Language.KOREAN, "안녕하세요. 오늘 한국어를 공부해 봅시다."),
        (Language.JAPANESE, "こんにちは。今日は日本語を勉強しましょう。"),
    ],
    ids=["en", "ko", "ja"],
)
async def test_generates_real_speech(synthesizer, language, text):
    result = await synthesizer.synthesize(text, language, "Aria")

    assert result.sample_rate == SAMPLE_RATE
    assert result.samples.dtype == np.int16

    # Long enough to be a sentence, not a click.
    assert result.duration_seconds > 0.5

    # Actually speech, not a silent or constant buffer: real audio has both
    # meaningful amplitude and variation.
    peak = int(np.abs(result.samples).max())
    assert peak > 1000, f"audio is near-silent (peak {peak})"
    assert float(result.samples.std()) > 100


async def test_the_same_text_twice_is_stable_enough_to_cache(synthesizer):
    """Caching assumes one text maps to one clip; check it is not wildly random."""
    a = await synthesizer.synthesize("Hello there.", Language.ENGLISH, "Aria")
    b = await synthesizer.synthesize("Hello there.", Language.ENGLISH, "Aria")
    # Durations within a reasonable tolerance of each other.
    assert abs(a.duration_seconds - b.duration_seconds) < 0.5


async def test_different_languages_produce_different_audio(synthesizer):
    ko = await synthesizer.synthesize("안녕하세요", Language.KOREAN, "Aria")
    en = await synthesizer.synthesize("Hello", Language.ENGLISH, "Aria")
    assert ko.samples.shape != en.samples.shape or not np.array_equal(
        ko.samples, en.samples
    )


def test_cpu_device_request_is_honoured_or_refused_clearly():
    """Asking for CUDA without a GPU must fail with a message that explains it."""
    settings = Settings(  # type: ignore[call-arg]
        supabase_url="https://unused.supabase.co",
        supabase_service_role_key="unused",
        tts_device="cuda:99",
    )
    engine = MagpieSynthesizer(settings)
    with pytest.raises(Exception) as exc:
        engine.load()
    assert "cuda" in str(exc.value).lower() or "device" in str(exc.value).lower()
