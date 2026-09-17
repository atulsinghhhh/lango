"""Per-user rate limiting.

GPU time is the scarce resource here, so the limit exists to stop one account
consuming a shared card. Cache hits are deliberately *not* charged against the
budget: replaying a word the service has already generated costs no inference,
and a learner drilling the same card should never be throttled for it.

In-process, so each replica enforces its own budget. That is the right
trade-off for one or two GPU nodes; behind a larger fleet, back this with
Redis so the limit is global (see the README's scaling section).
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field


@dataclass
class _Bucket:
    tokens: float
    updated_at: float


@dataclass
class RateLimiter:
    """Token bucket: [per_minute] requests a minute, burstable to the same."""

    per_minute: int
    _buckets: dict[str, _Bucket] = field(default_factory=dict)

    # Stale buckets are dropped during the sweep so an instance that has seen
    # many users does not hold a row per user forever.
    _last_sweep: float = 0.0
    _sweep_interval: float = 300.0

    def allow(self, key: str, now: float | None = None) -> bool:
        if self.per_minute <= 0:  # 0 disables limiting
            return True

        now = time.monotonic() if now is None else now
        self._maybe_sweep(now)

        refill_per_second = self.per_minute / 60.0
        bucket = self._buckets.get(key)
        if bucket is None:
            # A new caller starts with a full bucket, minus this request.
            self._buckets[key] = _Bucket(tokens=self.per_minute - 1.0, updated_at=now)
            return True

        elapsed = max(0.0, now - bucket.updated_at)
        bucket.tokens = min(
            float(self.per_minute), bucket.tokens + elapsed * refill_per_second
        )
        bucket.updated_at = now

        if bucket.tokens < 1.0:
            return False
        bucket.tokens -= 1.0
        return True

    def _maybe_sweep(self, now: float) -> None:
        if now - self._last_sweep < self._sweep_interval:
            return
        self._last_sweep = now
        # A bucket idle for a full refill window is indistinguishable from a
        # fresh one, so it can be forgotten.
        cutoff = now - 60.0
        for key in [k for k, b in self._buckets.items() if b.updated_at < cutoff]:
            del self._buckets[key]
