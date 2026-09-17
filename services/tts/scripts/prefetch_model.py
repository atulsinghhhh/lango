"""Warm every asset the model needs, at build time.

Two separate downloads matter, and both otherwise land on a learner's first
request:

  1. The MagpieTTS checkpoint (~1.5 GB).
  2. Per-language frontend dictionaries. Japanese pulls a 22 MB open_jtalk
     dictionary the first time it synthesizes anything — verified by watching
     it download mid-run on a cold environment.

Baking both in makes a cold container's first response fast and predictable.
The model is not moved to a GPU here: build hosts usually have none.
"""

from __future__ import annotations

import os
import sys

# One short phrase per language, purely to trigger that language's frontend.
WARMUP = [("en", "Hello."), ("ko", "안녕하세요."), ("ja", "こんにちは。")]


def main() -> int:
    model_id = os.environ.get(
        "TTS_MODEL_ID", "bertx18/magpie_tts_multilingual_357m"
    )
    revision = os.environ.get("TTS_MODEL_REVISION") or None

    try:
        from nemo.collections.tts.models import MagpieTTSModel
    except Exception as exc:  # noqa: BLE001
        print(f"NeMo is not installed, skipping prefetch: {exc}", file=sys.stderr)
        return 0

    print(f"prefetching {model_id} (revision={revision or 'default'})")
    kwargs = {"revision": revision} if revision else {}
    model = MagpieTTSModel.from_pretrained(model_id, **kwargs)
    print("checkpoint cached")

    # Best effort: a build host that cannot run inference still produces a
    # usable image, it just pays the dictionary download once at runtime.
    for language, text in WARMUP:
        try:
            model.do_tts(
                transcript=text,
                language=language,
                apply_TN=False,
                speaker_index=0,
            )
            print(f"warmed {language} frontend")
        except Exception as exc:  # noqa: BLE001
            print(f"could not warm {language}: {exc}", file=sys.stderr)

    print("prefetch complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
