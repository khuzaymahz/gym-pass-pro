"""Admin referrals listing.

The mobile-facing `/api/v1/referrals` router handles per-user code
resolution and self-history. This router is the operator's lens —
it lists referrals **across all users** so the admin can audit
conversion-rate, dispute claims, and reconcile invited→converted
flows without paginating through every user detail page.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_admin, db_session
from app.db.enums import ReferralStatus
from app.db.models import User
from app.repositories.referral_repo import ReferralRepository
from app.schemas.admin import AdminReferralPersonRef, AdminReferralRead
from app.schemas.common import Page

router = APIRouter(prefix="/admin/referrals", tags=["admin/referrals"])


def _person_ref(user: User) -> AdminReferralPersonRef:
    return AdminReferralPersonRef(
        id=user.id,
        name=user.display_name,
        email=user.email,
        phone=user.phone,
    )


@router.get("", response_model=Page[AdminReferralRead])
async def list_referrals(
    _: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
    status: ReferralStatus | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminReferralRead]:
    """Paginated list of every referral row in the database.

    `status` filters to `pending` (invitee has not yet converted to
    a paid sub) or `converted`. Sort is fixed: newest first.
    """
    repo = ReferralRepository(session)
    rows, total = await repo.list_all_admin(
        status=status, page=page, page_size=page_size
    )
    items = [
        AdminReferralRead(
            id=referral.id,
            referrer=_person_ref(referrer),
            invited=_person_ref(invited),
            referralCode=referral.referral_code,
            status=referral.status,
            createdAt=referral.created_at,
            convertedAt=referral.converted_at,
        )
        for referral, referrer, invited in rows
    ]
    return Page[AdminReferralRead](
        items=items, total=total, page=page, pageSize=page_size
    )
