from __future__ import annotations

from redis.asyncio import Redis


class RateLimiter:
    """Fixed-window counter backed by Redis INCR + EXPIRE.

    **TTL is set only on the first hit of a window** (`EXPIRE … NX`),
    not on every increment. The previous implementation reset the TTL
    on each call, which meant an attacker hammering the endpoint kept
    the key alive forever — the counter never decayed back to allow
    legitimate retries, effectively locking the user out indefinitely.
    """

    def __init__(self, redis: Redis) -> None:
        self.redis = redis

    async def incr(self, key: str, *, window_seconds: int) -> int:
        pipe = self.redis.pipeline()
        pipe.incr(key)
        # `nx=True` → only set the TTL when no TTL exists (i.e. on the
        # first hit after a previous window expired). Subsequent hits
        # within the window leave the TTL alone, so the window decays
        # naturally regardless of attack volume.
        pipe.expire(key, window_seconds, nx=True)
        count, _ = await pipe.execute()
        return int(count)

    async def peek(self, key: str) -> int:
        """Return the current counter for `key` without incrementing.

        Used by UI-facing surfaces that want to show "you've used X of
        N attempts" without consuming an attempt themselves. Falls
        back to 0 when the key is absent (i.e. no hits yet, or the
        previous window already expired).
        """
        raw = await self.redis.get(key)
        if raw is None:
            return 0
        try:
            return int(raw)
        except (TypeError, ValueError):
            return 0

    async def remaining(self, key: str, *, limit: int) -> int:
        """How many attempts are left in the current window for `key`,
        without consuming one. Pure read, safe to call from a UI hint.
        Returns `limit` for an unseen key (full budget), 0 once the
        bucket is full."""
        current = await self.peek(key)
        return max(0, limit - current)

    async def allow(self, key: str, *, limit: int, window_seconds: int) -> bool:
        current = await self.incr(key, window_seconds=window_seconds)
        return current <= limit
