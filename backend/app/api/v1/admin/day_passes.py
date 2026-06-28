from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_day_pass_service,
    authed_actor,
    current_admin,
    current_admin_ops,
    db_session,
)
from app.db.enums import DayPassStatus
from app.db.models import User
from app.schemas.admin import (
    AdminDayPassOfferingConfigure,
    AdminDayPassOfferingRead,
    AdminDayPassRead,
)
from app.schemas.common import Page
from app.services.admin_day_pass_service import AdminDayPassService

router = APIRouter(prefix="/admin/day-pass", tags=["admin/day-pass"])


@router.get("/offerings", response_model=Page[AdminDayPassOfferingRead])
async def list_offerings(
    svc: Annotated[AdminDayPassService, Depends(admin_day_pass_service)],
    _: Annotated[User, Depends(current_admin)],
    enabled: bool | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100, alias="pageSize"),
) -> Page[AdminDayPassOfferingRead]:
    rows, total = await svc.list_offerings(enabled=enabled, page=page, page_size=page_size)
    items = [
        AdminDayPassOfferingRead(
            id=o.id,
            gymId=g.id,
            gymNameEn=g.name_en,
            gymSlug=g.slug,
            isEnabled=o.is_enabled,
            priceJod=o.price_jod,
            platformFeePct=o.platform_fee_pct,
            validityHours=o.validity_hours,
            dailyCap=o.daily_cap,
            audienceGenderOverride=o.audience_gender_override,
        )
        for o, g in rows
    ]
    return Page[AdminDayPassOfferingRead](items=items, total=total, page=page, pageSize=page_size)


@router.put("/offerings/{gym_id}", response_model=AdminDayPassOfferingRead)
async def configure_offering(
    gym_id: UUID,
    body: AdminDayPassOfferingConfigure,
    request: Request,
    svc: Annotated[AdminDayPassService, Depends(admin_day_pass_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminDayPassOfferingRead:
    offering = await svc.configure_offering(
        gym_id,
        is_enabled=body.is_enabled,
        price_jod=body.price_jod,
        platform_fee_pct=body.platform_fee_pct,
        validity_hours=body.validity_hours,
        daily_cap=body.daily_cap,
        audience_gender_override=body.audience_gender_override,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return AdminDayPassOfferingRead(
        id=offering.id,
        gymId=gym_id,
        gymNameEn="",
        gymSlug="",
        isEnabled=offering.is_enabled,
        priceJod=offering.price_jod,
        platformFeePct=offering.platform_fee_pct,
        validityHours=offering.validity_hours,
        dailyCap=offering.daily_cap,
        audienceGenderOverride=offering.audience_gender_override,
    )


@router.get("/passes", response_model=Page[AdminDayPassRead])
async def list_passes(
    svc: Annotated[AdminDayPassService, Depends(admin_day_pass_service)],
    _: Annotated[User, Depends(current_admin)],
    status: DayPassStatus | None = None,
    gym_id: UUID | None = Query(default=None, alias="gymId"),
    user_id: UUID | None = Query(default=None, alias="userId"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminDayPassRead]:
    rows, total = await svc.list_passes(
        status=status,
        gym_id=gym_id,
        user_id=user_id,
        page=page,
        page_size=page_size,
    )
    items = [
        AdminDayPassRead(
            id=dp.id,
            userId=u.id,
            userName=u.name,
            userPhone=u.phone,
            gymId=g.id,
            gymNameEn=g.name_en,
            status=dp.status,
            priceJod=dp.price_jod,
            platformFeeJod=dp.platform_fee_jod,
            netAmountJod=dp.net_amount_jod,
            purchasedAt=dp.purchased_at,
            expiresAt=dp.expires_at,
            usedAt=dp.used_at,
            refundedAt=dp.refunded_at,
        )
        for dp, u, g in rows
    ]
    return Page[AdminDayPassRead](items=items, total=total, page=page, pageSize=page_size)


@router.post("/passes/{pass_id}/refund", response_model=AdminDayPassRead)
async def refund_pass(
    pass_id: UUID,
    request: Request,
    svc: Annotated[AdminDayPassService, Depends(admin_day_pass_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminDayPassRead:
    dp = await svc.refund_pass(pass_id, actor=authed_actor(request, admin))
    await session.commit()
    return AdminDayPassRead(
        id=dp.id,
        userId=dp.user_id,
        gymId=dp.gym_id,
        gymNameEn="",
        status=dp.status,
        priceJod=dp.price_jod,
        platformFeeJod=dp.platform_fee_jod,
        netAmountJod=dp.net_amount_jod,
        purchasedAt=dp.purchased_at,
        expiresAt=dp.expires_at,
        usedAt=dp.used_at,
        refundedAt=dp.refunded_at,
    )
