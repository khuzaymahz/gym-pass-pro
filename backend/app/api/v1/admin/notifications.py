from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Header, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_broadcast_service,
    authed_actor,
    current_admin_super,
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
    admin: Annotated[User, Depends(current_admin_super)],
    session: Annotated[AsyncSession, Depends(db_session)],
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
    dry_run: Annotated[bool, Query(alias="dryRun")] = False,
) -> AdminNotificationBroadcastResult:
    """Send a system notification to every member matching a tier filter.

    Super-admin only. Accepts an `Idempotency-Key` header so a double-
    click / network retry collapses to a single fan-out — the second
    call returns the cached recipient count with `duplicate=True` in
    the audit trail. `dryRun=true` returns the recipient count without
    inserting any notifications so an admin can preview the audience
    before sending.
    """
    result = await svc.broadcast(
        title_en=body.title_en,
        title_ar=body.title_ar,
        body_en=body.body_en,
        body_ar=body.body_ar,
        target_tier=body.target_tier,
        actor=authed_actor(request, admin),
        idempotency_key=idempotency_key,
        dry_run=dry_run,
    )
    if not dry_run:
        await session.commit()
    return AdminNotificationBroadcastResult(recipients=result.recipients)
