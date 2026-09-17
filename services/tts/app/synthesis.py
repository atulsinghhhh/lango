"""MagpieTTS Multilingual inference.

The model is loaded once, at process start, and kept resident in GPU memory.
Loading per request would dominate latency and thrash VRAM.

The inference call itself is synchronous and GPU-bound, so it runs in a worker
thread; a semaphore bounds how many run at once. NeMo is imported lazily so
the rest of the service — and its tests — do not need the toolkit installed.

API per the model card for `nvidia/magpie_tts_multilingual_357m`:

    from nemo.collections.tts.models import MagpieTTSModel
    model = MagpieTTSModel.from_pretrained("nvidia/magpie_tts_multilingual_357m")
    audio, audio_len = model.do_tts(
        transcript=..., language=..., apply_TN=..., use_cfg=..., speaker_index=...
    )

Output is mono PCM-16 at 22.05 kHz with shape (B x T).
"""

from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass

import numpy as np

from .config import Settings
from .languages import Language, speaker_index

logger = logging.getLogger(__name__)

# Fixed by the model card. Not configurable: it describes the model's output,
# not a preference.
SAMPLE_RATE = 22050


class SynthesisError(RuntimeError):
    """Generation failed for this request."""


class ModelNotReady(RuntimeError):
    """The model is not loaded, so the service cannot serve traffic."""


@dataclass
class SynthesisResult:
    samples: np.ndarray  # mono int16
    sample_rate: int
    inference_seconds: float

    @property
    def duration_seconds(self) -> float:
        return len(self.samples) / float(self.sample_rate)


class MagpieSynthesizer:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._model = None
        self._device = settings.tts_device
        # Bounds concurrent GPU work. Acquired by the route so queueing is
        # visible in metrics before a thread is ever taken.
        self.slots = asyncio.Semaphore(settings.tts_max_concurrency)

    @property
    def is_loaded(self) -> bool:
        return self._model is not None

    @property
    def device(self) -> str:
        return self._device

    def load(self) -> None:
        """Load the model into GPU memory. Called once, from the lifespan."""
        if self._model is not None:
            return

        import torch  # imported here so the module imports without CUDA
        from nemo.collections.tts.models import MagpieTTSModel

        if self._device.startswith("cuda") and not torch.cuda.is_available():
            raise ModelNotReady(
                "TTS_DEVICE requests CUDA but no GPU is visible to this "
                "process. Start the container with --gpus all, or set "
                "TTS_DEVICE=cpu for a (much slower) CPU run."
            )

        started = time.monotonic()
        kwargs: dict[str, object] = {}
        if self._settings.tts_model_revision:
            kwargs["revision"] = self._settings.tts_model_revision

        model = MagpieTTSModel.from_pretrained(
            self._settings.tts_model_id, **kwargs
        )
        model = model.to(self._device)
        model.eval()
        self._model = model
        logger.info(
            "loaded %s on %s in %.1fs",
            self._settings.tts_model_id,
            self._device,
            time.monotonic() - started,
        )

    def unload(self) -> None:
        self._model = None
        try:
            import torch

            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except Exception:  # noqa: BLE001 - shutdown must not raise
            pass

    def _synthesize_blocking(
        self, text: str, language: Language, voice: str
    ) -> SynthesisResult:
        if self._model is None:
            raise ModelNotReady("model is not loaded")

        import torch

        started = time.monotonic()
        try:
            with torch.inference_mode():
                audio, audio_len = self._model.do_tts(
                    transcript=text,
                    language=language.value,
                    apply_TN=self._settings.tts_apply_tn,
                    use_cfg=self._settings.tts_use_cfg,
                    speaker_index=speaker_index(voice),
                )
        except Exception as exc:  # noqa: BLE001 - model errors become 502s
            raise SynthesisError(str(exc)) from exc

        samples = self._to_int16_mono(audio, audio_len)
        if samples.size == 0:
            # A silent clip is a failure, not a result: returning it would
            # cache silence forever under this text's key.
            raise SynthesisError("model produced no audio")

        return SynthesisResult(
            samples=samples,
            sample_rate=SAMPLE_RATE,
            inference_seconds=time.monotonic() - started,
        )

    @staticmethod
    def _to_int16_mono(audio, audio_len) -> np.ndarray:  # noqa: ANN001
        """Take the first item of the batch and trim it to its true length.

        `do_tts` returns (B x T) padded to the longest item; `audio_len` says
        how much of each row is real. Keeping the padding would append silence
        to every clip.
        """
        array = audio[0].detach().cpu().numpy() if hasattr(audio, "detach") else np.asarray(audio[0])

        try:
            length = int(
                audio_len[0].item() if hasattr(audio_len, "__getitem__") else audio_len
            )
            if 0 < length <= array.shape[-1]:
                array = array[:length]
        except Exception:  # noqa: BLE001 - trimming is an optimisation
            pass

        array = np.squeeze(array)
        if array.ndim > 1:  # defensive: collapse any channel dimension
            array = array[0]

        # The card describes PCM-16 output, but NeMo models commonly hand back
        # float in [-1, 1]. Convert only when it is float.
        if np.issubdtype(array.dtype, np.floating):
            array = np.clip(array, -1.0, 1.0)
            array = (array * 32767.0).astype(np.int16)
        else:
            array = array.astype(np.int16, copy=False)
        return array

    async def synthesize(
        self, text: str, language: Language, voice: str
    ) -> SynthesisResult:
        """Generate audio without blocking the event loop."""
        return await asyncio.to_thread(
            self._synthesize_blocking, text, language, voice
        )
