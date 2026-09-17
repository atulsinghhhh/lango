"""Deterministic caching.

A language-learning app asks for the same handful of sentences constantly:
every learner who opens 학교 requests the same clip. Generating it once and
serving it from storage forever is the difference between a GPU that idles and
a GPU that is the bottleneck.

The key covers everything that can change the audio. If any of it changes, the
key changes and the old object is simply never read again — there is no
invalidation step to forget.
"""

from __future__ import annotations

import hashlib
import unicodedata

from .languages import Language


def normalize_text(text: str) -> str:
    """Canonical form of the text for cache purposes.

    NFC so that Hangul typed as composed syllables and as conjoining jamo —
    which look identical and sound identical — share one cache entry. Outer
    whitespace is stripped and runs collapsed for the same reason. Nothing
    else is touched: the model must synthesize exactly what was asked for, so
    case and punctuation stay significant.
    """
    return " ".join(unicodedata.normalize("NFC", text).split())


def cache_key(
    *,
    text: str,
    language: Language,
    voice: str,
    model_version: str,
    apply_tn: bool,
    use_cfg: bool,
    audio_format: str,
) -> str:
    """Stable identifier for one piece of generated audio.

    Fields are joined with a separator that cannot appear in any of them, so
    no two different inputs can produce the same joined string.
    """
    parts = [
        model_version,
        language.value,
        voice,
        f"tn={int(apply_tn)}",
        f"cfg={int(use_cfg)}",
        audio_format,
        normalize_text(text),
    ]
    joined = "\x1f".join(parts)
    return hashlib.sha256(joined.encode("utf-8")).hexdigest()


def object_path(key: str, language: Language, audio_format: str) -> str:
    """Where the audio lives in the bucket.

    Sharded by the first two hex characters: object stores list far faster
    over many shallow prefixes than over one directory with a million entries.
    """
    return f"{language.value}/{key[:2]}/{key}.{audio_format}"
