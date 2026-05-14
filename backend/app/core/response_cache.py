"""Endpoint-level response cache.

Cache-aside over Redis for read-heavy GET endpoints where the
underlying aggregation is expensive but the value can be stale for
a few seconds without anyone noticing — dashboard metrics being
the prime case.

Storing the serialized JSON (not the dict) means a cache hit skips
the Pydantic round-trip entirely. The endpoint returns a plain
`Response` with the cached bytes when a hit lands; misses build
the model normally and write the JSON back.

Failures (Redis down, deserialization errors) silently fall back
to "compute it" so a flaky cache layer never blocks the real read.
"""

from __future__ import annotations

import structlog
from redis.asyncio import Redis

log = structlog.get_logger(__name__)


async def get_cached_json(redis: Redis, key: str) -> bytes | None:
    """Return the cached JSON bytes for `key`, or None on miss/error."""
    try:
        cached = await redis.get(key)
    except Exception as exc:
        log.warning("response_cache.read_failed", key=key, error=str(exc))
        return None
    if cached is None:
        return None
    if isinstance(cached, str):
        return cached.encode("utf-8")
    return cached


async def set_cached_json(
    redis: Redis, key: str, payload: bytes | str, ttl_seconds: int
) -> None:
    """Store `payload` under `key` for `ttl_seconds`. Errors logged
    and swallowed — a cache write failure must never affect the
    response the client already received.
    """
    try:
        await redis.set(key, payload, ex=ttl_seconds)
    except Exception as exc:
        log.warning("response_cache.write_failed", key=key, error=str(exc))


__all__ = ["get_cached_json", "set_cached_json"]
