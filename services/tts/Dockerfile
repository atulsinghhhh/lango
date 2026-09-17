# Lango TTS — MagpieTTS Multilingual 357M on GPU.
#
# Base is NVIDIA's NGC PyTorch image: it already carries a CUDA-matched torch
# build, which is what NeMo expects. Installing torch from PyPI onto a bare
# CUDA image works too but is the usual source of "CUDA not available" at
# runtime, so it is not the default here.
#
# The image is large (~20 GB). That is the cost of a CUDA + PyTorch + NeMo
# stack; it is pulled once per node, not per request.
ARG BASE_IMAGE=nvcr.io/nvidia/pytorch:24.12-py3
FROM ${BASE_IMAGE}

# ffmpeg transcodes the model's 22.05 kHz WAV into mp3/opus for mobile.
# libsndfile1 backs soundfile.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        libsndfile1 \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv

# Hugging Face cache lives on its own path so it can be a mounted volume and
# survive image rebuilds — see PREFETCH_MODEL below.
ENV HF_HOME=/opt/hf-cache \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
RUN mkdir -p /opt/hf-cache

# Dependencies first, so editing application code does not reinstall NeMo.
COPY requirements.txt requirements-model.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir -r requirements-model.txt

COPY app ./app
COPY scripts ./scripts

# Bake the weights into the image so a cold container starts predictably
# instead of downloading ~1.5 GB on first request. Set to false and mount
# /opt/hf-cache when you would rather share one cache across many replicas.
ARG PREFETCH_MODEL=true
ARG TTS_MODEL_ID=bertx18/magpie_tts_multilingual_357m
RUN if [ "$PREFETCH_MODEL" = "true" ]; then \
        TTS_MODEL_ID="$TTS_MODEL_ID" python scripts/prefetch_model.py ; \
    fi

# Non-root: the process needs no privileges beyond the GPU device.
RUN useradd --create-home --uid 10001 tts \
    && chown -R tts:tts /srv /opt/hf-cache
USER tts

EXPOSE 8000

# Liveness only — deliberately not /ready, so a container that is still
# loading the model is not killed as unhealthy mid-startup.
HEALTHCHECK --interval=30s --timeout=5s --start-period=600s --retries=3 \
    CMD curl -fsS http://localhost:8000/health || exit 1

# SIGTERM lets uvicorn stop accepting and drain in-flight generations before
# the model is released.
STOPSIGNAL SIGTERM

CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--timeout-graceful-shutdown", "60"]
