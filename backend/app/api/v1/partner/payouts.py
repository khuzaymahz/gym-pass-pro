from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import current_gym_owner, payout_agg_repo
from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PayoutStatus
from app.db.models import User
from app.repositories.payout_repo import PayoutRepository
from app.schemas.admin import AdminPayoutRead
from app.schemas.common import Page

router = APIRouter(prefix="/partner/gym/payouts", tags=["partner/gym/payouts"])


@router.get("", response_model=Page[AdminPayoutRead])
async def list_my_payouts(
    user: Annotated[User, Depends(current_gym_owner)],
    repo: Annotated[PayoutRepository, Depends(payout_agg_repo)],
    status: PayoutStatus | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminPayoutRead]:
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    rows, total = await repo.list_paginated(
        status=status,
        gym_id=user.gym_id,
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
    return Page[AdminPayoutRead](
        items=items, total=total, page=page, pageSize=page_size
    )
