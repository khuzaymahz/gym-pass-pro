from __future__ import annotations

from functools import lru_cache

from redis.asyncio import Redis, from_url

from app.config import get_settings


@lru_cache
def get_redis() -> Redis:
    settings = get_settings()
    return from_url(str(settings.redis_url), decode_responses=True)
