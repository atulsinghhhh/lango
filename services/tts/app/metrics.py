"""Prometheus metrics.

The numbers that actually matter for this service: how often the cache saves a
generation, how long the GPU is busy, and how deep the queue is. Cache hit rate
is the single most useful one — if it falls, GPU cost rises immediately.
"""

from __future__ import annotations

from prometheus_client import CollectorRegistry, Counter, Gauge, Histogram

REGISTRY = CollectorRegistry()

REQUESTS = Counter(
    "tts_requests_total",
    "TTS requests by outcome.",
    labelnames=("result", "language"),
    registry=REGISTRY,
)

CACHE_HITS = Counter(
    "tts_cache_hits_total",
    "Requests served from stored audio without inference.",
    labelnames=("language",),
    registry=REGISTRY,
)

CACHE_MISSES = Counter(
    "tts_cache_misses_total",
    "Requests that required inference.",
    labelnames=("language",),
    registry=REGISTRY,
)

COALESCED = Counter(
    "tts_coalesced_total",
    "Requests that joined an in-flight generation instead of starting one.",
    registry=REGISTRY,
)

ERRORS = Counter(
    "tts_errors_total",
    "Failures by kind.",
    labelnames=("kind",),
    registry=REGISTRY,
)

REQUEST_SECONDS = Histogram(
    "tts_request_seconds",
    "End-to-end request latency.",
    labelnames=("cached",),
    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 30, 60),
    registry=REGISTRY,
)

INFERENCE_SECONDS = Histogram(
    "tts_inference_seconds",
    "Time inside the model, excluding queueing and upload.",
    buckets=(0.1, 0.25, 0.5, 1, 2, 5, 10, 30),
    registry=REGISTRY,
)

AUDIO_SECONDS = Histogram(
    "tts_audio_seconds",
    "Duration of generated audio.",
    buckets=(0.5, 1, 2, 3, 5, 10, 20, 30),
    registry=REGISTRY,
)

QUEUE_DEPTH = Gauge(
    "tts_queue_depth",
    "Requests waiting for a GPU slot.",
    registry=REGISTRY,
)

INFLIGHT = Gauge(
    "tts_inflight_generations",
    "Distinct generations currently running.",
    registry=REGISTRY,
)

MODEL_LOADED = Gauge(
    "tts_model_loaded",
    "1 when the model is resident and the service can serve traffic.",
    registry=REGISTRY,
)
