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

    async def remaining(self, key: str, *, limit: int, window_seconds: int) -> int:
        current = await self.incr(key, window_seconds=window_seconds)
        return max(0, limit - current)

    async def allow(self, key: str, *, limit: int, window_seconds: int) -> bool:
        current = await self.incr(key, window_seconds=window_seconds)
        return current <= limit
