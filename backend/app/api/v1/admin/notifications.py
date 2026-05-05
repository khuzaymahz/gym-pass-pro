from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_broadcast_service,
    authed_actor,
    current_admin,
    db_session,
)
from app.db.models import User
from app.schemas.admin import (
    AdminNotificationBroadcast,
    AdminNotificationBroadcastResult,
)
from app.services.admin_broadcast_service import AdminBroadcastService

router = APIRouter(prefix="/admin/notifications", tags=["admin/notifications"])


@router.post("/broadcast", response_model=AdminNotificationBroadcastResult)
async def broadcast(
    body: AdminNotificationBroadcast,
    request: Request,
    svc: Annotated[AdminBroadcastService, Depends(admin_broadcast_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminNotificationBroadcastResult:
    count = await svc.broadcast(
        title_en=body.title_en,
        title_ar=body.title_ar,
        body_en=body.body_en,
        body_ar=body.body_ar,
        target_tier=body.target_tier,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return AdminNotificationBroadcastResult(recipients=count)
