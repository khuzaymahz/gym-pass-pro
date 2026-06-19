from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from redis.asyncio import Redis

from app.api.deps import admin_metrics_service, current_admin, redis_client
from app.core.response_cache import get_cached_json, set_cached_json
from app.db.models import User
from app.schemas.admin import DashboardMetrics
from app.services.admin_metrics_service import AdminMetricsService

router = APIRouter(prefix="/admin/metrics", tags=["admin/metrics"])

# 60 s window — the dashboard fires 21 parallel queries each cache
# miss, several of them on hot `checkins`. Five concurrent dashboard
# loads at TTL=10s briefly took ~105 connection slots, which is most
# of the pool. 60 s shares one miss across the whole minute and
# absorbs the reload-spam without making the "fresh data" lens go
# stale enough for ops to lose trust. Operators who need fresh data
# after a known action pass `forceRefresh=true` to bypass.
_CACHE_TTL_SECONDS = 60
_CACHE_KEY = "metrics:admin:overview"


@router.get("/overview", response_model=DashboardMetrics)
async def overview(
    svc: Annotated[AdminMetricsService, Depends(admin_metrics_service)],
    redis: Annotated[Redis, Depends(redis_client)],
    _: Annotated[User, Depends(current_admin)],
    force_refresh: Annotated[
        bool, Query(alias="forceRefresh", description="Bypass the 60s cache.")
    ] = False,
) -> Response:
    if not force_refresh:
        cached = await get_cached_json(redis, _CACHE_KEY)
        if cached is not None:
            return Response(
                content=cached,
                media_type="application/json",
                headers={"X-Cache": "HIT"},
            )
    data = await svc.overview(force_refresh=force_refresh)
    payload = DashboardMetrics(**data).model_dump_json(by_alias=True)  # type: ignore[arg-type]
    await set_cached_json(redis, _CACHE_KEY, payload, _CACHE_TTL_SECONDS)
    return Response(
        content=payload,
        media_type="application/json",
        headers={"X-Cache": "MISS" if not force_refresh else "BYPASS"},
    )
