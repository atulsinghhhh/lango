"""Access to the process-wide singletons created in the lifespan."""

from __future__ import annotations

from fastapi import Request

from .rate_limit import RateLimiter
from .single_flight import SingleFlight
from .storage import SupabaseStorage
from .synthesis import MagpieSynthesizer


def get_synthesizer(request: Request) -> MagpieSynthesizer:
    return request.app.state.synthesizer


def get_storage(request: Request) -> SupabaseStorage:
    return request.app.state.storage


def get_rate_limiter(request: Request) -> RateLimiter:
    return request.app.state.rate_limiter


def get_single_flight(request: Request) -> SingleFlight:
    return request.app.state.single_flight
