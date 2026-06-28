from __future__ import annotations

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.api.deps import admin_checkin_read_service, current_admin
from app.db.enums import CheckinStatus
from app.db.models import User
from app.schemas.admin import AdminCheckinListItem
from app.schemas.common import Page
from app.services.admin_checkin_read_service import AdminCheckinReadService

router = APIRouter(prefix="/admin/checkins", tags=["admin/checkins"])


@router.get("", response_model=Page[AdminCheckinListItem])
async def list_checkins(
    svc: Annotated[AdminCheckinReadService, Depends(admin_checkin_read_service)],
    _: Annotated[User, Depends(current_admin)],
    gym_id: UUID | None = Query(default=None, alias="gymId"),
    user_id: UUID | None = Query(default=None, alias="userId"),
    status: CheckinStatus | None = None,
    since: datetime | None = None,
    until: datetime | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminCheckinListItem]:
    rows, total = await svc.list_paginated(
        gym_id=gym_id, user_id=user_id, status=status,
        since=since, until=until, page=page, page_size=page_size,
    )
    items = [
        AdminCheckinListItem(
            id=c.id,
            userId=c.user_id,
            userName=u.name,
            userPhone=u.phone,
            gymId=c.gym_id,
            gymNameEn=g.name_en,
            status=c.status,
            scannedAt=c.scanned_at,
            failureReason=c.failure_reason,
        )
        for c, g, u in rows
    ]
    return Page[AdminCheckinListItem](
        items=items, total=total, page=page, pageSize=page_size
    )
