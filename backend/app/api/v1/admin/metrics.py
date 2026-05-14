from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Response
from redis.asyncio import Redis

from app.api.deps import admin_metrics_service, current_admin, redis_client
from app.core.response_cache import get_cached_json, set_cached_json
from app.db.models import User
from app.schemas.admin import DashboardMetrics
from app.services.admin_metrics_service import AdminMetricsService

router = APIRouter(prefix="/admin/metrics", tags=["admin/metrics"])

# 10 s is short enough that fresh check-ins surface within one
# refresh, long enough to dedupe a dashboard reload-spam without
# hammering the DB.
_CACHE_TTL_SECONDS = 10
_CACHE_KEY = "metrics:admin:overview"


@router.get("/overview", response_model=DashboardMetrics)
async def overview(
    svc: Annotated[AdminMetricsService, Depends(admin_metrics_service)],
    redis: Annotated[Redis, Depends(redis_client)],
    _: Annotated[User, Depends(current_admin)],
) -> Response:
    cached = await get_cached_json(redis, _CACHE_KEY)
    if cached is not None:
        return Response(
            content=cached,
            media_type="application/json",
            headers={"X-Cache": "HIT"},
        )
    data = await svc.overview()
    payload = DashboardMetrics(**data).model_dump_json(by_alias=True)  # type: ignore[arg-type]
    await set_cached_json(redis, _CACHE_KEY, payload, _CACHE_TTL_SECONDS)
    return Response(
        content=payload,
        media_type="application/json",
        headers={"X-Cache": "MISS"},
    )
