from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_subscription_service,
    authed_actor,
    current_admin,
    db_session,
)
from app.db.enums import SubscriptionStatus, Tier
from app.db.models import User
from app.schemas.admin import AdminSubscriptionListItem
from app.schemas.common import Page
from app.services.admin_subscription_service import AdminSubscriptionService

router = APIRouter(prefix="/admin/subscriptions", tags=["admin/subscriptions"])


@router.get("", response_model=Page[AdminSubscriptionListItem])
async def list_subscriptions(
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    _: Annotated[User, Depends(current_admin)],
    status: SubscriptionStatus | None = None,
    tier: Tier | None = None,
    q: str | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminSubscriptionListItem]:
    rows, total = await svc.list(
        status=status, tier=tier, q=q, page=page, page_size=page_size
    )
    items = [
        AdminSubscriptionListItem(
            id=s.id,
            userId=s.user_id,
            userEmail=u.email,
            userPhone=u.phone,
            userName=u.name,
            planId=s.plan_id,
            tier=s.tier,
            status=s.status,
            startsAt=s.starts_at,
            expiresAt=s.expires_at,
            visitsUsed=s.visits_used,
            autoRenew=s.auto_renew,
            cancelledAt=s.cancelled_at,
        )
        for s, u in rows
    ]
    return Page[AdminSubscriptionListItem](
        items=items, total=total, page=page, pageSize=page_size
    )


@router.post("/{sub_id}/cancel", status_code=204)
async def cancel_subscription(
    sub_id: UUID,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    await svc.cancel(sub_id, actor=authed_actor(request, admin))
    await session.commit()
