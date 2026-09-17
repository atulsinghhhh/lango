# Lango TTS

Speech synthesis for Lango, backed by **NVIDIA MagpieTTS Multilingual 357M**.
One model covers all three languages the app teaches: English, Korean and
Japanese.

```
Flutter
   │  HTTPS + Supabase access token
   ▼
TTS API  (FastAPI, this service)
   │
   ├─▶ cache lookup ──▶ Supabase Storage ──▶ signed URL ──▶ Flutter audio player
   │                         ▲
   ▼                         │
MagpieTTS 357M (GPU) ──▶ mp3 ┘
```

The model is loaded once at process start and stays resident in GPU memory.
Flutter never learns which model runs, where it runs, or how the audio is
stored — it posts text and gets back a URL.

---

## Why a separate service

The model needs a GPU and a Python/CUDA stack. None of the three places the
rest of Lango runs can host that: Flutter is a client, Supabase Edge Functions
are Deno with no GPU, and Postgres is a database. So this is its own
deployable, and the only thing it shares with the app is an HTTP contract.

---

## API

### `POST /v1/tts`

```http
POST /v1/tts
Authorization: Bearer <supabase-access-token>
Content-Type: application/json

{ "text": "こんにちは。今日は日本語を勉強しましょう。", "language": "ja" }
```

```json
{
  "audio_url": "https://<project>.supabase.co/storage/v1/object/sign/tts-audio/ja/3f/3fa9….mp3?token=…",
  "language": "ja",
  "cached": false,
  "format": "mp3",
  "duration_seconds": 3.4
}
```

| Field | Notes |
|---|---|
| `text` | Synthesized exactly as supplied. Never translated or rewritten. |
| `language` | `en`, `ko` or `ja`. Anything else is a 422. |
| `voice` | Optional: `Aria`, `Jason`, `John`, `Leo`, `Sofia`. Defaults to `TTS_DEFAULT_VOICE`. |

Audio comes back as a **URL, not bytes**. Base64 in JSON would inflate the
payload by a third, bypass the CDN, and push every megabyte through this
process instead of letting storage serve it.

| Status | Meaning |
|---|---|
| 200 | Audio ready at `audio_url`. |
| 401 | Missing or invalid Supabase session. |
| 422 | Unsupported language or voice, empty text, or text over the limit. |
| 429 | Per-user rate limit. Carries `Retry-After`. |
| 502 | Generation, encoding or storage failed. |
| 503 | Model not loaded. |
| 504 | Generation exceeded `TTS_REQUEST_TIMEOUT_SECONDS`. |

Error bodies never contain the model's own error text, a stack trace, or a
token — those go to the logs.

### `GET /health`, `GET /ready`, `GET /metrics`

`/health` is liveness and does **not** depend on the model, so a container that
is still loading is not killed as unhealthy. `/ready` returns 503 until the
model is resident — point the load balancer at `/ready` and the liveness probe
at `/health`. Both are also mounted under `/v1/`.

---

## Caching

A language-learning app asks for the same sentences constantly: every learner
who opens 학교 wants the same clip. Generating it once is the difference
between a GPU that idles and a GPU that is the bottleneck.

The cache key is

```
sha256(model_version ∥ language ∥ voice ∥ apply_TN ∥ use_cfg ∥ format ∥ NFC(text))
```

joined with a separator that cannot appear in any field, so no two different
inputs collide. Change any of those and the key changes — there is no
invalidation step to forget. **Bump `TTS_MODEL_VERSION` whenever you change the
model, its revision, or a generation default**, or learners keep hearing audio
made with the old settings.

Text is NFC-normalised and its whitespace collapsed before hashing, so Hangul
typed as composed syllables and as conjoining jamo — identical to read,
identical to hear — share one entry. Case and punctuation stay significant:
they change prosody.

Two further protections:

- **Cache hits are not rate limited.** They cost no GPU, so a learner drilling
  one flashcard is never throttled.
- **Concurrent identical requests are coalesced.** Thirty learners opening the
  same card produce one generation, not thirty (`app/single_flight.py`).

---

## Requirements

| | |
|---|---|
| Python | **≥ 3.10.12 and < 3.14.** The upper bound is load-bearing: NeMo's dependency tree does not resolve on 3.14. Built against 3.12 |
| GPU | The card lists Ada L4/L40, Ampere A10/A30/A100, Hopper H100 |
| VRAM | **Not stated by NVIDIA.** 357M parameters is small; the listed cards are all ≥ 24 GB. Budget 16–24 GB until you have measured your own load — see *Limitations*. |
| CUDA | Pinned by the base image (`nvcr.io/nvidia/pytorch:24.12-py3`). Your host driver must be new enough for that tag. |
| Model | `nemo_toolkit[tts]` from `main`, plus `kaldialign` (both per the model card) |
| Other | `ffmpeg` for mp3/opus, `libsndfile1` for soundfile |

---

## Local development

Two modes. Most work does not need a GPU.

### Without a GPU — API, validation, caching, tests

```sh
cd services/tts
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -e '.[dev]'

export SUPABASE_URL=https://YOUR-PROJECT.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=…
export TTS_SKIP_MODEL_LOAD=1     # start without the model

uvicorn app.main:app --reload
```

`TTS_SKIP_MODEL_LOAD` leaves `/ready` red — that is the point: a process
without a model must not receive traffic. Never set it in a deployment.

### With a GPU

```sh
pip install -r requirements.txt -r requirements-model.txt
unset TTS_SKIP_MODEL_LOAD
uvicorn app.main:app
```

The first start downloads ~1.5 GB of weights into `HF_HOME`.

### Tests

```sh
pytest          # 67 tests, no GPU needed
pytest -m gpu   # real model; skipped automatically without CUDA
```

The suite fakes the model so routing, auth, validation, caching, coalescing,
rate limiting and every error path are covered on a laptop. `-m gpu` is the
only part that can prove the model emits real speech rather than silence.

---

## Environment variables

Secrets are marked. **None of them belong in Flutter**, which only ever knows
`TTS_API_BASE_URL`.

| Variable | Default | Notes |
|---|---|---|
| `TTS_MODEL_ID` | `bertx18/magpie_tts_multilingual_357m` | |
| `TTS_MODEL_REVISION` | — | Pin a commit for reproducible builds |
| `TTS_MODEL_VERSION` | `magpie-357m-v1` | Cache-key component; bump on any model change |
| `TTS_DEVICE` | `cuda` | `cpu` works but is far too slow to serve |
| `TTS_DEFAULT_VOICE` | `Aria` | |
| `TTS_APPLY_TN` | `true` | Text normalisation for numbers/abbreviations |
| `TTS_MAX_TEXT_LENGTH` | `500` | |
| `TTS_MAX_CONCURRENCY` | `2` | Concurrent GPU generations |
| `TTS_RATE_LIMIT_PER_MINUTE` | `30` | Per user; `0` disables |
| `TTS_REQUEST_TIMEOUT_SECONDS` | `60` | |
| `TTS_AUDIO_FORMAT` | `mp3` | `mp3`, `opus` or `wav` |
| `TTS_AUDIO_BITRATE` | `64k` | |
| `TTS_CACHE_ENABLED` | `true` | |
| `SUPABASE_URL` | — | Required |
| **`SUPABASE_SERVICE_ROLE_KEY`** | — | **Secret.** Required. Server only |
| `SUPABASE_STORAGE_BUCKET` | `tts-audio` | |
| **`SUPABASE_JWT_SECRET`** | — | **Secret.** Optional; skips a network hop on legacy projects |
| `TTS_SIGNED_URL_TTL_SECONDS` | `3600` | |
| **`TTS_API_KEY`** | — | **Secret.** Optional, for trusted server callers only |
| `TTS_CORS_ORIGINS` | — | Only needed for Flutter Web |
| `LOG_LEVEL` | `INFO` | |

See `.env.example`. A filled-in `.env` is gitignored.

---

## Docker

```sh
# Build (large: CUDA + PyTorch + NeMo ≈ 20 GB)
docker build -t lango-tts:1.0.0 services/tts

# Run on a GPU host
docker run --gpus all -p 8000:8000 --env-file services/tts/.env lango-tts:1.0.0
```

Weights are baked into the image by default so a cold container starts
predictably instead of downloading on first request. To share one cache across
replicas instead:

```sh
docker build --build-arg PREFETCH_MODEL=false -t lango-tts:1.0.0 services/tts
docker run --gpus all -p 8000:8000 -v hf-cache:/opt/hf-cache \
  --env-file services/tts/.env lango-tts:1.0.0
```

The container runs as a non-root user, ships a `/health` healthcheck with a
10-minute start period (model loading is slow), and stops on `SIGTERM` with a
60-second graceful drain so in-flight generations finish.

---

## Supabase configuration

1. **Bucket.** The service creates `tts-audio` as a **private** bucket at
   startup if it is missing. Audio is served through short-lived signed URLs;
   nothing is world-readable.
2. **Keys.** The service-role key lives only in this service's environment. It
   is what lets it write to a private bucket, and it must never reach the app.
3. **Auth.** No second login system. The service verifies the learner's
   existing Supabase access token — JWKS first, then `SUPABASE_JWT_SECRET`,
   then the Auth API as a fallback — so it works on both current and legacy
   projects.
4. **Cleanup (optional).** Cached audio is small and reused forever, so there
   is no need to expire it. If you want to, a storage lifecycle rule on the
   bucket is the right place — the service treats a missing object as a cache
   miss and regenerates.

---

## Flutter configuration

One public value. There is no key to ship.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=… \
  --dart-define=TTS_API_BASE_URL=https://tts.example.com
```

Usage is unchanged from the on-device implementation — `AudioButton`, listening
and dictation all still call:

```dart
await ref.read(ttsServiceProvider).speak('학교에 가요', TargetLanguage.korean);

// English, which is not a study language, has its own entry point:
await ref.read(ttsServiceProvider).speakIn('Hello', TtsLanguage.english);
```

`TtsService` calls the API, plays the returned URL with `just_audio`, and falls
back to the on-device voice if the service cannot be reached — a different
voice, but better than silence mid-lesson. Set `fallbackToDevice: false` to
turn that off. Leave `TTS_API_BASE_URL` unset and the app runs entirely on the
device voice, exactly as before.

---

## Monitoring

`GET /metrics` exposes Prometheus text:

| Metric | Why it matters |
|---|---|
| `tts_cache_hits_total` / `tts_cache_misses_total` | **The number to watch.** Hit rate falling means GPU cost rising |
| `tts_coalesced_total` | Requests that joined an in-flight generation |
| `tts_inference_seconds` | Time in the model, excluding queueing and upload |
| `tts_request_seconds{cached}` | End-to-end latency, split by cache hit |
| `tts_queue_depth` | Requests waiting for a GPU slot — sustained > 0 means add capacity |
| `tts_inflight_generations` | Should never exceed `TTS_MAX_CONCURRENCY` |
| `tts_audio_seconds` | Duration of generated audio |
| `tts_errors_total{kind}` | `synthesis`, `storage`, `timeout`, `rate_limited`, … |
| `tts_model_loaded` | 1 when the process can serve |

Access tokens are never logged. Model errors are logged server-side and
replaced with a generic message in the response.

---

## Production deployment

**Where to host.** This needs an attached GPU, which rules out Vercel, Supabase
Edge Functions, and most serverless platforms. Reasonable options, cheapest
first:

| Option | Fits when |
|---|---|
| **RunPod / Lambda Labs / Vast.ai** | Cheapest per GPU-hour. Good for one always-on L4/A10 |
| **Fly.io GPU machines** | Simple deploys, scale-to-zero — but cold starts pay the model load |
| **Google Cloud Run with GPU** | Scales to zero, managed; watch cold-start latency |
| **AWS ECS/EKS on `g6`/`g5`, or GKE with an L4 pool** | Already on that cloud, want autoscaling and a load balancer |
| **Modal / Replicate** | Want the GPU lifecycle managed entirely |

A single L4 handles a surprising amount of traffic here, because the cache
absorbs the repeats — a language app's request distribution is extremely
top-heavy.

**Checklist**

- Terminate TLS at the load balancer; never expose this service directly.
- Readiness probe → `/ready`; liveness probe → `/health`.
- Set `TTS_MAX_CONCURRENCY` from measured VRAM, not optimism.
- Scrape `/metrics`.
- Keep one uvicorn worker per container: the model must not be loaded twice in
  one process's memory. Scale with replicas, not workers.

---

## Scaling

Going from one GPU to several changes nothing in the app:

```
                 Load balancer
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
      GPU TTS replica       GPU TTS replica
            └──────────┬──────────┘
                       ▼
            Supabase Storage / CDN
```

Replicas share the cache automatically, because the cache lives in Storage and
the key is a pure function of the request. A clip generated by one replica is
served by all of them.

Two things are per-process today and want promoting to Redis before a large
fleet, both noted in the code:

- **Rate limiting** (`app/rate_limit.py`) — each replica enforces its own
  budget, so the effective limit is `replicas × TTS_RATE_LIMIT_PER_MINUTE`.
- **Single-flight** (`app/single_flight.py`) — coalescing is per replica, so N
  replicas can each generate the same clip once. Storage upsert makes that
  correct, just wasteful.

Neither matters at one or two nodes. Both are contained in one small module.

---

## Verified

Run on CPU (macOS ARM, Python 3.12) through the service's own
`app/synthesis.py` and `app/audio.py` — not a reimplementation:

| | model load | audio out | CPU wall |
|---|---|---|---|
| `Hello, how are you?` | 105.6 s (once) | 1.53 s | 4.6 s |
| `안녕하세요. 오늘 한국어를 공부해 봅시다.` | — | 3.72 s | 9.9 s |
| `こんにちは。今日は日本語を勉強しましょう。` | — | 3.53 s | 10.6 s |

Output was int16 at 22.05 kHz as documented. Each clip was then encoded to
64 kbps mono MP3 and transcribed back with Whisper, which returned the input
**character for character, including punctuation, in all three languages**. So
the model produces intelligible speech, the int16 conversion is right, and
64 kbps does not damage Korean or Japanese.

Those CPU numbers are also the argument for a GPU: ~10 s of wall time for
3.5 s of Korean is roughly 3× slower than real time, which is unusable for a
tap-to-hear button. `TTS_DEVICE=cpu` is for development only.

---

## Limitations and open questions

Stated plainly rather than discovered in production:

1. **Never run on a GPU.** The verification above is CPU-only; no CUDA device
   was available. Throughput, VRAM and `TTS_MAX_CONCURRENCY` are therefore
   unmeasured. Run `pytest -m gpu` on the target host before trusting it.
2. **VRAM is unmeasured.** NVIDIA lists supported GPUs but no minimum. Measure
   with `nvidia-smi` under your real concurrency before sizing.
3. **Undeclared dependencies.** `nemo_toolkit[tts]` does not pull in `peft`,
   which its own import chain needs — it is listed in
   `requirements-model.txt` for that reason. Expect more of these when NeMo's
   `main` moves; the import fails fast and names the module.
4. **Per-voice language coverage is not documented.** The card says speaker
   identity is consistent across languages but does not promise every voice
   covers every language. If `Aria` sounds wrong in one language, try another
   voice — and remember that changing `TTS_DEFAULT_VOICE` changes every cache
   key.
5. **Text normalisation across languages.** `TTS_APPLY_TN=true` is on by
   default and covers all twelve languages per the card. If Korean or Japanese
   numerals read oddly, turn it off and bump `TTS_MODEL_VERSION`.
6. **Japanese pulls a dictionary on first use.** The frontend downloads a
   22 MB open_jtalk dictionary the first time it synthesizes Japanese — seen
   mid-run during verification. `scripts/prefetch_model.py` now warms one
   phrase per language at build time so a cold container does not stall on
   it; if you build with `PREFETCH_MODEL=false`, the first Japanese request
   pays that download.
7. **Licence.** NVIDIA Open Model License — commercial use is permitted, but
   read it before shipping.
