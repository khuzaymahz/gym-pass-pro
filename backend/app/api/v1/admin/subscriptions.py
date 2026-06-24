from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_subscription_service,
    authed_actor,
    current_admin,
    current_admin_ops,
    db_session,
)
from app.db.enums import SubscriptionStatus, Tier
from app.db.models import User
from app.schemas.admin import (
    AdminSubscriptionComp,
    AdminSubscriptionExtend,
    AdminSubscriptionListItem,
    AdminSubscriptionRead,
    AdminSubscriptionTier,
    AdminSubscriptionVisits,
)
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
    rows, total = await svc.list(status=status, tier=tier, q=q, page=page, page_size=page_size)
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
    return Page[AdminSubscriptionListItem](items=items, total=total, page=page, pageSize=page_size)


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


@router.post("/{sub_id}/extend", response_model=AdminSubscriptionRead)
async def extend_subscription(
    sub_id: UUID,
    body: AdminSubscriptionExtend,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminSubscriptionRead:
    sub = await svc.extend(sub_id, days=body.days, actor=authed_actor(request, admin))
    await session.commit()
    return AdminSubscriptionRead.model_validate(sub)


@router.post("/{sub_id}/visits", response_model=AdminSubscriptionRead)
async def set_subscription_visits(
    sub_id: UUID,
    body: AdminSubscriptionVisits,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminSubscriptionRead:
    sub = await svc.set_visits(
        sub_id, visits_used=body.visits_used, actor=authed_actor(request, admin)
    )
    await session.commit()
    return AdminSubscriptionRead.model_validate(sub)


@router.post("/{sub_id}/tier", response_model=AdminSubscriptionRead)
async def change_subscription_tier(
    sub_id: UUID,
    body: AdminSubscriptionTier,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminSubscriptionRead:
    sub = await svc.change_tier(sub_id, tier=body.tier, actor=authed_actor(request, admin))
    await session.commit()
    return AdminSubscriptionRead.model_validate(sub)


@router.post("/{sub_id}/restore", response_model=AdminSubscriptionRead)
async def restore_subscription(
    sub_id: UUID,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminSubscriptionRead:
    sub = await svc.restore(sub_id, actor=authed_actor(request, admin))
    await session.commit()
    return AdminSubscriptionRead.model_validate(sub)


@router.post("/{sub_id}/resume-pause", status_code=204)
async def resume_subscription_pause(
    sub_id: UUID,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    await svc.resume_pause(sub_id, actor=authed_actor(request, admin))
    await session.commit()


@router.post("/comp", response_model=AdminSubscriptionRead, status_code=201)
async def comp_subscription(
    body: AdminSubscriptionComp,
    request: Request,
    svc: Annotated[AdminSubscriptionService, Depends(admin_subscription_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminSubscriptionRead:
    sub = await svc.comp(
        user_id=body.user_id,
        plan_id=body.plan_id,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return AdminSubscriptionRead.model_validate(sub)
