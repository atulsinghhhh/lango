"""Encoding the model's samples into something a phone wants to stream.

The model emits 22.05 kHz mono PCM-16. As WAV that is ~44 kB per second — a
three-second example sentence is ~130 kB, on a mobile connection, for every
learner. MP3 at 64 kbps carries the same clip in ~24 kB and decodes natively on
both iOS and Android.

WAV is still available for callers that would rather not transcode; it is then
written straight out with no re-encoding.
"""

from __future__ import annotations

import asyncio
import io
import logging

import numpy as np
import soundfile as sf

logger = logging.getLogger(__name__)


class EncodingError(RuntimeError):
    """The audio could not be encoded into the configured format."""


def to_wav_bytes(samples: np.ndarray, sample_rate: int) -> bytes:
    buffer = io.BytesIO()
    sf.write(buffer, samples, sample_rate, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


async def encode(
    samples: np.ndarray,
    sample_rate: int,
    audio_format: str,
    bitrate: str,
) -> bytes:
    """Encode samples into [audio_format]."""
    wav = to_wav_bytes(samples, sample_rate)
    if audio_format == "wav":
        return wav
    return await _ffmpeg(wav, audio_format, bitrate)


async def _ffmpeg(wav: bytes, audio_format: str, bitrate: str) -> bytes:
    codec, container = {
        "mp3": ("libmp3lame", "mp3"),
        "opus": ("libopus", "ogg"),
    }[audio_format]

    process = await asyncio.create_subprocess_exec(
        "ffmpeg",
        "-hide_banner",
        "-loglevel", "error",
        "-i", "pipe:0",
        "-vn",
        "-ac", "1",
        "-c:a", codec,
        "-b:a", bitrate,
        "-f", container,
        "pipe:1",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate(input=wav)

    if process.returncode != 0 or not stdout:
        detail = stderr.decode("utf-8", "replace").strip()[:200]
        raise EncodingError(f"ffmpeg failed: {detail}")
    return stdout
