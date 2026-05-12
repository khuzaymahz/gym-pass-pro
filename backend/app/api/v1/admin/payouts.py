from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_payout_service,
    authed_actor,
    current_admin,
    db_session,
)
from app.db.enums import PayoutStatus
from app.db.models import User
from app.schemas.admin import (
    AdminPayoutDetail,
    AdminPayoutEntryRead,
    AdminPayoutGenerate,
    AdminPayoutMarkPaid,
    AdminPayoutRead,
)
from app.schemas.common import Page
from app.services.admin_payout_service import AdminPayoutService

router = APIRouter(prefix="/admin/payouts", tags=["admin/payouts"])


@router.get("", response_model=Page[AdminPayoutRead])
async def list_payouts(
    svc: Annotated[AdminPayoutService, Depends(admin_payout_service)],
    _: Annotated[User, Depends(current_admin)],
    status: PayoutStatus | None = None,
    gym_id: UUID | None = Query(default=None, alias="gymId"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminPayoutRead]:
    rows, total = await svc.list(
        status=status, gym_id=gym_id, page=page, page_size=page_size
    )
    items = [
        AdminPayoutRead(
            id=p.id,
            gymId=p.gym_id,
            gymNameEn=g.name_en,
            periodStart=p.period_start,
            periodEnd=p.period_end,
            totalAmountJod=p.total_amount_jod,
            entryCount=p.entry_count,
            status=p.status,
            paidAt=p.paid_at,
            notes=p.notes,
        )
        for p, g in rows
    ]
    return Page[AdminPayoutRead](
        items=items, total=total, page=page, pageSize=page_size
    )


@router.post("/generate", response_model=list[AdminPayoutRead])
async def generate_payouts(
    body: AdminPayoutGenerate,
    request: Request,
    svc: Annotated[AdminPayoutService, Depends(admin_payout_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> list[AdminPayoutRead]:
    created = await svc.generate(
        period_start=body.period_start,
        period_end=body.period_end,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    # Reload for consistent response shape with gym name
    results, _ = await svc.list(status=None, gym_id=None, page=1, page_size=len(created) or 1)
    return [
        AdminPayoutRead(
            id=p.id,
            gymId=p.gym_id,
            gymNameEn=g.name_en,
            periodStart=p.period_start,
            periodEnd=p.period_end,
            totalAmountJod=p.total_amount_jod,
            entryCount=p.entry_count,
            status=p.status,
            paidAt=p.paid_at,
            notes=p.notes,
        )
        for p, g in results if p.id in {c.id for c in created}
    ]


@router.get("/{payout_id}", response_model=AdminPayoutDetail)
async def get_payout(
    payout_id: UUID,
    svc: Annotated[AdminPayoutService, Depends(admin_payout_service)],
    _: Annotated[User, Depends(current_admin)],
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=200, ge=1, le=500, alias="pageSize"),
) -> AdminPayoutDetail:
    """Drill-down: payout summary + paginated ledger entries, each
    joined to the checkin (scan time) and the user (display name +
    phone for the reconciliation lens). Default page size of 200
    covers most monthly payouts in one fetch; the cap at 500
    bounds the largest response.
    """
    payout, gym = await svc.get_with_gym(payout_id)
    offset = (page - 1) * page_size
    rows, total = await svc.list_entries(
        payout_id, limit=page_size, offset=offset
    )
    entries = [
        AdminPayoutEntryRead(
            ledgerId=ledger.id,
            checkinId=checkin.id,
            userId=user.id,
            userName=user.display_name,
            userPhone=user.phone,
            scannedAt=checkin.scanned_at,
            amountJod=ledger.amount_jod,
            rateApplied=ledger.rate_applied,
        )
        for ledger, checkin, user in rows
    ]
    return AdminPayoutDetail(
        payout=AdminPayoutRead(
            id=payout.id,
            gymId=payout.gym_id,
            gymNameEn=gym.name_en,
            periodStart=payout.period_start,
            periodEnd=payout.period_end,
            totalAmountJod=payout.total_amount_jod,
            entryCount=payout.entry_count,
            status=payout.status,
            paidAt=payout.paid_at,
            notes=payout.notes,
        ),
        entries=entries,
        totalEntries=total,
        page=page,
        pageSize=page_size,
    )


@router.post("/{payout_id}/mark-paid", response_model=AdminPayoutRead)
async def mark_paid(
    payout_id: UUID,
    body: AdminPayoutMarkPaid,
    request: Request,
    svc: Annotated[AdminPayoutService, Depends(admin_payout_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminPayoutRead:
    payout, gym = await svc.mark_paid(
        payout_id, notes=body.notes, actor=authed_actor(request, admin)
    )
    await session.commit()
    return AdminPayoutRead(
        id=payout.id,
        gymId=payout.gym_id,
        gymNameEn=gym.name_en,
        periodStart=payout.period_start,
        periodEnd=payout.period_end,
        totalAmountJod=payout.total_amount_jod,
        entryCount=payout.entry_count,
        status=payout.status,
        paidAt=payout.paid_at,
        notes=payout.notes,
    )
