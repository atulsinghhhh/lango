"""Supabase Storage access, using the service-role key.

The bucket is private: the service uploads with the service-role key and hands
the client a short-lived signed URL. The service-role key exists only in this
process — it is never returned, logged, or sent to Flutter.
"""

from __future__ import annotations

import logging

import httpx

from .config import Settings

logger = logging.getLogger(__name__)


class StorageError(RuntimeError):
    """Storage refused an operation the service depends on."""


class SupabaseStorage:
    def __init__(self, settings: Settings, client: httpx.AsyncClient) -> None:
        self._settings = settings
        self._client = client
        self._base = f"{settings.supabase_url}/storage/v1"
        self._bucket = settings.supabase_storage_bucket

    @property
    def _headers(self) -> dict[str, str]:
        key = self._settings.supabase_service_role_key
        return {"apikey": key, "authorization": f"Bearer {key}"}

    async def exists(self, path: str) -> bool:
        """Whether an object is already stored at [path].

        Any failure answers "no": the caller then regenerates, which is slower
        but always correct. A cache lookup must never be able to fail a
        request.
        """
        try:
            response = await self._client.get(
                f"{self._base}/object/info/{self._bucket}/{path}",
                headers=self._headers,
            )
        except httpx.HTTPError as exc:
            logger.warning("cache lookup failed: %s", type(exc).__name__)
            return False
        return response.status_code == 200

    async def upload(self, path: str, data: bytes, content_type: str) -> None:
        try:
            response = await self._client.post(
                f"{self._base}/object/{self._bucket}/{path}",
                headers={
                    **self._headers,
                    "content-type": content_type,
                    # Idempotent: two racing generations of the same clip must
                    # not turn into a 409.
                    "x-upsert": "true",
                },
                content=data,
            )
        except httpx.HTTPError as exc:
            raise StorageError(f"upload failed: {type(exc).__name__}") from exc

        if response.status_code not in (200, 201):
            raise StorageError(
                f"upload rejected with {response.status_code}"
            )

    async def signed_url(self, path: str) -> str:
        ttl = self._settings.tts_signed_url_ttl_seconds
        try:
            response = await self._client.post(
                f"{self._base}/object/sign/{self._bucket}/{path}",
                headers={**self._headers, "content-type": "application/json"},
                json={"expiresIn": ttl},
            )
        except httpx.HTTPError as exc:
            raise StorageError(f"signing failed: {type(exc).__name__}") from exc

        if response.status_code != 200:
            raise StorageError(f"signing rejected with {response.status_code}")

        signed = response.json().get("signedURL")
        if not signed:
            raise StorageError("signing response had no URL")
        # Supabase returns a path relative to /storage/v1.
        return f"{self._base}{signed if signed.startswith('/') else '/' + signed}"

    async def ensure_bucket(self) -> None:
        """Create the private bucket if it is missing.

        Makes a fresh deployment work without a manual console step. An
        existing bucket is left exactly as configured.
        """
        try:
            response = await self._client.get(
                f"{self._base}/bucket/{self._bucket}", headers=self._headers
            )
            if response.status_code == 200:
                return
            await self._client.post(
                f"{self._base}/bucket",
                headers={**self._headers, "content-type": "application/json"},
                json={"name": self._bucket, "id": self._bucket, "public": False},
            )
        except httpx.HTTPError as exc:
            # Not fatal at startup: uploads will report the real problem.
            logger.warning("could not ensure bucket: %s", type(exc).__name__)
