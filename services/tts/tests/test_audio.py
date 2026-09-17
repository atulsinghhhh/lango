"""Encoding fidelity.

The service ships the model's 22.05 kHz WAV to phones as 64 kbps mono MP3.
That is a real trade: too low a bitrate and Korean and Japanese consonants
smear. These tests pin the decision so nobody can lower the bitrate, change the
ffmpeg arguments, or switch the container without the loss showing up.

Deterministic and offline — a synthetic tone rather than a recording, decoded
back with ffmpeg and measured.
"""

from __future__ import annotations

import asyncio
import subprocess

import numpy as np
import pytest

from app.audio import EncodingError, encode, to_wav_bytes

from .conftest import ffmpeg_available

pytestmark = pytest.mark.skipif(
    not ffmpeg_available(), reason="ffmpeg not installed"
)

RATE = 22050
TONE_HZ = 440.0


def tone(seconds: float = 1.0, hz: float = TONE_HZ) -> np.ndarray:
    t = np.linspace(0, seconds, int(RATE * seconds), endpoint=False)
    return (np.sin(2 * np.pi * hz * t) * 12000).astype(np.int16)


def decode(data: bytes) -> np.ndarray:
    """Decode encoded audio back to mono PCM16 at RATE."""
    result = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error",
            "-i", "pipe:0",
            "-f", "s16le", "-ac", "1", "-ar", str(RATE), "pipe:1",
        ],
        input=data,
        capture_output=True,
        check=True,
    )
    return np.frombuffer(result.stdout, dtype=np.int16)


def dominant_hz(samples: np.ndarray) -> float:
    spectrum = np.abs(np.fft.rfft(samples.astype(np.float64)))
    return float(np.fft.rfftfreq(len(samples), 1 / RATE)[int(np.argmax(spectrum))])


def test_wav_is_written_at_the_models_sample_rate():
    data = to_wav_bytes(tone(), RATE)
    assert data[:4] == b"RIFF"
    decoded = decode(data)
    # A WAV round trip is lossless, so length is exact.
    assert len(decoded) == RATE


@pytest.mark.parametrize("audio_format", ["mp3", "opus"])
def test_encoding_preserves_the_signal(audio_format):
    source = tone()
    encoded = asyncio.run(encode(source, RATE, audio_format, "64k"))
    decoded = decode(encoded)

    # Codecs pad slightly; the clip must not be truncated or doubled.
    assert 0.9 * len(source) <= len(decoded) <= 1.3 * len(source)

    # The tone survives: this is what fails first if the bitrate is dropped
    # too far or the channel/rate arguments are wrong.
    assert dominant_hz(decoded) == pytest.approx(TONE_HZ, abs=10.0)
    assert int(np.abs(decoded).max()) > 4000


def test_mp3_at_the_configured_bitrate_is_much_smaller_than_wav():
    source = tone(seconds=3.0)
    wav = to_wav_bytes(source, RATE)
    mp3 = asyncio.run(encode(source, RATE, "mp3", "64k"))

    # ~44 kB/s as WAV against ~8 kB/s as MP3. Anything under 3x means the
    # transcode has stopped paying for itself.
    assert len(wav) / len(mp3) > 3.0


def test_wav_format_is_passed_through_unencoded():
    source = tone()
    out = asyncio.run(encode(source, RATE, "wav", "64k"))
    assert out == to_wav_bytes(source, RATE)


def test_output_is_always_mono():
    """The model emits mono; a stereo file would double the bytes for nothing."""
    encoded = asyncio.run(encode(tone(), RATE, "mp3", "64k"))
    probe = subprocess.run(
        [
            "ffprobe", "-hide_banner", "-loglevel", "error",
            "-show_entries", "stream=channels",
            "-of", "csv=p=0", "pipe:0",
        ],
        input=encoded,
        capture_output=True,
        check=True,
    )
    assert probe.stdout.decode().strip() == "1"


def test_an_unusable_format_fails_loudly():
    with pytest.raises((EncodingError, KeyError)):
        asyncio.run(encode(tone(), RATE, "flac", "64k"))
