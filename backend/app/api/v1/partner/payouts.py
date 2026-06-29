from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.api.deps import payout_agg_repo, selected_gym
from app.db.enums import PayoutStatus
from app.repositories.payout_repo import PayoutRepository
from app.schemas.admin import AdminPayoutRead
from app.schemas.common import Page

router = APIRouter(prefix="/partner/gym/payouts", tags=["partner/gym/payouts"])


@router.get("", response_model=Page[AdminPayoutRead])
async def list_my_payouts(
    gym_id: Annotated[UUID, Depends(selected_gym)],
    repo: Annotated[PayoutRepository, Depends(payout_agg_repo)],
    status: PayoutStatus | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminPayoutRead]:
    rows, total = await repo.list_paginated(
        status=status,
        gym_id=gym_id,
        page=page,
        page_size=page_size,
    )
    items = [
        AdminPayoutRead(
            id=p.id,
            gymId=g.id,
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
    return Page[AdminPayoutRead](items=items, total=total, page=page, pageSize=page_size)
