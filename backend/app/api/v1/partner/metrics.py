from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import current_gym_owner, partner_metrics_service
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.schemas.partner import PartnerDashboardMetrics
from app.services.partner_metrics_service import PartnerMetricsService

router = APIRouter(prefix="/partner/gym/metrics", tags=["partner/gym/metrics"])


@router.get("/overview", response_model=PartnerDashboardMetrics)
async def overview(
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[PartnerMetricsService, Depends(partner_metrics_service)],
) -> PartnerDashboardMetrics:
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    data = await svc.overview(user.gym_id)
    return PartnerDashboardMetrics(
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
    )
