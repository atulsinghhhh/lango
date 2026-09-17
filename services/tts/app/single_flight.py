"""Collapse concurrent identical work.

A class of thirty learners opening the same lesson produces thirty requests for
the same sentence within a second. Without this, the first cache lookup misses
thirty times and thirty identical generations queue for the GPU.

With it, the first caller generates and the other twenty-nine await that same
result.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import TypeVar

T = TypeVar("T")


class SingleFlight:
    def __init__(self) -> None:
        self._inflight: dict[str, asyncio.Future] = {}

    @property
    def inflight_count(self) -> int:
        return len(self._inflight)

    async def run(self, key: str, factory: Callable[[], Awaitable[T]]) -> T:
        """Run [factory] for [key], or await the run already in progress.

        The exception from a failed run is delivered to every waiter, so a
        failure is not silently swallowed for the followers — and the key is
        released either way, so the next request retries rather than inheriting
        a permanently failed entry.
        """
        existing = self._inflight.get(key)
        if existing is not None:
            return await asyncio.shield(existing)

        loop = asyncio.get_running_loop()
        future: asyncio.Future = loop.create_future()
        self._inflight[key] = future

        try:
            result = await factory()
        except BaseException as exc:  # noqa: BLE001 - re-raised below
            if not future.done():
                future.set_exception(exc)
            # Waiters observe the exception through their own await; consume it
            # here so Python does not report it as never-retrieved.
            future.exception()
            raise
        else:
            if not future.done():
                future.set_result(result)
            return result
        finally:
            self._inflight.pop(key, None)
