"""Liveness, readiness and metrics.

`/health` answers "is this process alive" — it must stay cheap and must not
depend on the model, or a slow model load would make an orchestrator kill a
container that is starting correctly.

`/ready` answers "can this process serve traffic", which does require the
model. Point the load balancer at `/ready` and the liveness probe at
`/health`.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Response, status
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from .. import metrics
from ..config import Settings, get_settings
from ..deps import get_synthesizer
from ..languages import Language
from ..schemas import HealthResponse
from ..synthesis import MagpieSynthesizer

router = APIRouter(tags=["ops"])


@router.get("/health", response_model=HealthResponse)
@router.get("/v1/health", response_model=HealthResponse)
async def health(
    settings: Settings = Depends(get_settings),
    synthesizer: MagpieSynthesizer = Depends(get_synthesizer),
) -> HealthResponse:
    return HealthResponse(
        status="ok",
        model_id=settings.tts_model_id,
        model_loaded=synthesizer.is_loaded,
        device=synthesizer.device,
        languages=Language.values(),
    )


@router.get("/ready")
@router.get("/v1/ready")
async def ready(
    response: Response,
    settings: Settings = Depends(get_settings),
    synthesizer: MagpieSynthesizer = Depends(get_synthesizer),
) -> dict[str, object]:
    if not synthesizer.is_loaded:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"ready": False, "reason": "model not loaded"}
    return {"ready": True, "model_id": settings.tts_model_id}


@router.get("/metrics", include_in_schema=False)
async def prometheus_metrics() -> Response:
    return Response(
        content=generate_latest(metrics.REGISTRY),
        media_type=CONTENT_TYPE_LATEST,
    )
