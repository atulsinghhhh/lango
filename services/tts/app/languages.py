"""Languages and voices the TTS service will synthesize.

A strict enum rather than free-form strings: an unsupported language must fail
at the edge of the service with a clear error, not reach the model and produce
audio in the wrong phonology.
"""

from __future__ import annotations

from enum import Enum


class Language(str, Enum):
    """Languages this deployment exposes.

    MagpieTTS Multilingual supports twelve languages (ar, de, en, es, fr, hi,
    it, ja, ko, pt, vi, zh). Lango only teaches three, so only three are
    accepted — adding another is a one-line change here plus a client enum,
    not a model change.
    """

    ENGLISH = "en"
    KOREAN = "ko"
    JAPANESE = "ja"

    @classmethod
    def values(cls) -> list[str]:
        return [member.value for member in cls]


# Speaker index per the model card's speaker_map. The model keeps a consistent
# speaker identity across languages, so one voice can read all three and the
# learner hears the same person throughout the app.
SPEAKER_MAP: dict[str, int] = {
    "Aria": 0,
    "Jason": 1,
    "John": 2,
    "Leo": 3,
    "Sofia": 4,
}

DEFAULT_VOICE = "Aria"


def speaker_index(voice: str) -> int:
    """Resolve a voice name to the model's speaker index.

    Raises:
        KeyError: if the voice is not one the model ships.
    """
    return SPEAKER_MAP[voice]


def is_supported_voice(voice: str) -> bool:
    return voice in SPEAKER_MAP
