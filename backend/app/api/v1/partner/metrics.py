from __future__ import annotations

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from redis.asyncio import Redis

from app.api.deps import partner_metrics_service, redis_client, selected_gym
from app.core.response_cache import get_cached_json, set_cached_json
from app.schemas.partner import PartnerDashboardMetrics
from app.services.partner_metrics_service import PartnerMetricsService

router = APIRouter(prefix="/partner/gym/metrics", tags=["partner/gym/metrics"])

_CACHE_TTL_SECONDS = 10


def _cache_key(gym_id, since: datetime | None, until: datetime | None) -> str:
    s = since.isoformat() if since else "default"
    u = until.isoformat() if until else "default"
    return f"metrics:partner:{gym_id}:{s}:{u}"


@router.get("/overview", response_model=PartnerDashboardMetrics)
async def overview(
    gym_id: Annotated[UUID, Depends(selected_gym)],
    svc: Annotated[PartnerMetricsService, Depends(partner_metrics_service)],
    redis: Annotated[Redis, Depends(redis_client)],
    since: datetime | None = Query(
        default=None,
        description="Window start (ISO datetime). Defaults to start of "
        "current month when omitted — preserves the legacy MTD view.",
    ),
    until: datetime | None = Query(
        default=None,
        description="Window end (ISO datetime). Defaults to 'now'.",
    ),
) -> Response:
    if since is not None and since.tzinfo is None:
        since = since.replace(tzinfo=UTC)
    if until is not None and until.tzinfo is None:
        until = until.replace(tzinfo=UTC)

    key = _cache_key(gym_id, since, until)
    cached = await get_cached_json(redis, key)
    if cached is not None:
        return Response(
            content=cached,
            media_type="application/json",
            headers={"X-Cache": "HIT"},
        )

    data = await svc.overview(gym_id, since=since, until=until)
    payload = PartnerDashboardMetrics(
        checkinsToday=data["checkinsToday"],
        checkinsThisMonth=data["checkinsThisMonth"],
        checkinsLast30Days=data["checkinsLast30Days"],
        uniqueMembersLast30Days=data["uniqueMembersLast30Days"],
        revenueMtdJod=str(data["revenueMtdJod"]),
        pendingPayoutTotalJod=str(data["pendingPayoutTotalJod"]),
        paidPayoutMtdJod=str(data["paidPayoutMtdJod"]),
        checkinsPerDay=data["checkinsPerDay"],
        revenuePerDay=data["revenuePerDay"],
        tierBreakdown=data["tierBreakdown"],
        hourBreakdown=data["hourBreakdown"],
        recentCheckins=data["recentCheckins"],
    ).model_dump_json(by_alias=True)
    await set_cached_json(redis, key, payload, _CACHE_TTL_SECONDS)
    return Response(
        content=payload,
        media_type="application/json",
        headers={"X-Cache": "MISS"},
    )
