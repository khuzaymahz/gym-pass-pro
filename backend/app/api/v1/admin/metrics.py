from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import admin_metrics_service, current_admin
from app.db.models import User
from app.schemas.admin import DashboardMetrics
from app.services.admin_metrics_service import AdminMetricsService

router = APIRouter(prefix="/admin/metrics", tags=["admin/metrics"])


@router.get("/overview", response_model=DashboardMetrics)
async def overview(
    svc: Annotated[AdminMetricsService, Depends(admin_metrics_service)],
    _: Annotated[User, Depends(current_admin)],
) -> DashboardMetrics:
    data = await svc.overview()
    return DashboardMetrics(**data)  # type: ignore[arg-type]
