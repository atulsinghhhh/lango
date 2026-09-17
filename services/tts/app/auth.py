"""Authentication against the caller's existing Supabase session.

There is no second login system: the Flutter client already holds a Supabase
access token and sends it as `Authorization: Bearer <token>`. This module
proves the token is genuine and extracts the user id used for rate limiting.

Verification order, cheapest first:
  1. the optional service key, for trusted server callers (never the app);
  2. asymmetric JWT via the project's JWKS (current Supabase projects);
  3. symmetric JWT via SUPABASE_JWT_SECRET (legacy projects);
  4. the Auth API, as a last resort.

Tokens are never logged, and never appear in an error returned to the caller.
"""

from __future__ import annotations

import hmac
import logging
import time
from dataclasses import dataclass

import httpx
import jwt
from fastapi import Depends, HTTPException, Request, status

from .config import Settings, get_settings

logger = logging.getLogger(__name__)

# Supabase stamps every end-user token with this audience.
_AUDIENCE = "authenticated"

# JWKS rotates rarely; an hour avoids a network hop on almost every request
# while still picking up a rotation promptly.
_JWKS_TTL_SECONDS = 3600


@dataclass(frozen=True)
class Principal:
    """Who is making the request."""

    subject: str
    is_service: bool = False

    @property
    def rate_limit_key(self) -> str:
        return f"service:{self.subject}" if self.is_service else self.subject


class _JwksCache:
    def __init__(self) -> None:
        self._keys: dict[str, jwt.PyJWK] = {}
        self._fetched_at: float = 0.0

    def _fresh(self) -> bool:
        return bool(self._keys) and (
            time.monotonic() - self._fetched_at < _JWKS_TTL_SECONDS
        )

    async def key_for(self, kid: str, settings: Settings) -> jwt.PyJWK | None:
        if not self._fresh() or kid not in self._keys:
            await self._refresh(settings)
        return self._keys.get(kid)

    async def _refresh(self, settings: Settings) -> None:
        url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(url)
            response.raise_for_status()
            payload = response.json()
        except Exception as exc:  # noqa: BLE001 - any failure falls through
            # Not fatal: a project on legacy symmetric keys has no JWKS.
            logger.debug("JWKS unavailable: %s", exc)
            return

        keys: dict[str, jwt.PyJWK] = {}
        for entry in payload.get("keys", []):
            kid = entry.get("kid")
            if not kid:
                continue
            try:
                keys[kid] = jwt.PyJWK(entry)
            except Exception as exc:  # noqa: BLE001
                logger.debug("skipping unusable JWK: %s", exc)
        if keys:
            self._keys = keys
            self._fetched_at = time.monotonic()


_jwks = _JwksCache()


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _bearer_token(request: Request) -> str:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise _unauthorized("Missing bearer token.")
    return token.strip()


async def _verify_supabase_jwt(token: str, settings: Settings) -> str | None:
    """Return the subject claim, or None if this path cannot verify it."""
    try:
        header = jwt.get_unverified_header(token)
    except jwt.PyJWTError:
        raise _unauthorized("Malformed token.") from None

    algorithm = header.get("alg", "")
    key: object | None = None

    if algorithm.startswith("HS"):
        if not settings.supabase_jwt_secret:
            return None
        key = settings.supabase_jwt_secret
    else:
        kid = header.get("kid")
        if not kid:
            return None
        jwk = await _jwks.key_for(kid, settings)
        if jwk is None:
            return None
        key = jwk.key

    try:
        claims = jwt.decode(
            token,
            key=key,  # type: ignore[arg-type]
            algorithms=[algorithm],
            audience=_AUDIENCE,
            options={"require": ["exp", "sub"]},
        )
    except jwt.ExpiredSignatureError:
        raise _unauthorized("Session expired.") from None
    except jwt.PyJWTError:
        raise _unauthorized("Invalid token.") from None

    subject = claims.get("sub")
    return str(subject) if subject else None


async def _verify_via_auth_api(token: str, settings: Settings) -> str:
    """Last resort: ask Supabase who this token belongs to."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                f"{settings.supabase_url}/auth/v1/user",
                headers={
                    "apikey": settings.supabase_service_role_key,
                    "authorization": f"Bearer {token}",
                },
            )
    except httpx.HTTPError as exc:
        logger.warning("auth API unreachable: %s", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not verify the session right now.",
        ) from None

    if response.status_code != 200:
        raise _unauthorized("Invalid token.")

    user_id = response.json().get("id")
    if not user_id:
        raise _unauthorized("Invalid token.")
    return str(user_id)


async def require_principal(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> Principal:
    """FastAPI dependency: the authenticated caller, or 401."""
    token = _bearer_token(request)

    # Constant-time compare so the service key cannot be discovered by timing.
    if settings.tts_api_key and hmac.compare_digest(token, settings.tts_api_key):
        return Principal(subject="internal", is_service=True)

    subject = await _verify_supabase_jwt(token, settings)
    if subject is None:
        subject = await _verify_via_auth_api(token, settings)
    return Principal(subject=subject)
