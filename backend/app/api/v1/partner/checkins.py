from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import current_gym_owner, partner_checkin_read_service
from app.core.exceptions import AppError, ErrorCode
from app.db.enums import CheckinStatus
from app.db.models import User
from app.schemas.admin import AdminCheckinListItem
from app.schemas.common import Page
from app.services.partner_checkin_read_service import PartnerCheckinReadService
from app.utils.pii import mask_name_for_partner, mask_phone_for_partner

router = APIRouter(prefix="/partner/gym/checkins", tags=["partner/gym/checkins"])


@router.get("", response_model=Page[AdminCheckinListItem])
async def list_checkins(
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[
        PartnerCheckinReadService, Depends(partner_checkin_read_service)
    ],
    status: CheckinStatus | None = Query(default=None),
    since: datetime | None = Query(default=None),
    until: datetime | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminCheckinListItem]:
    """List check-ins recorded at the partner's own gym.

    Reuses `AdminCheckinListItem` shape so the partner SDK matches the admin
    SDK exactly for the same row — useful when we eventually add
    cross-app support tooling.
    """
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    rows, total = await svc.list_for_gym(
        gym_id=user.gym_id,
        status=status,
        since=since,
        until=until,
        page=page,
        page_size=page_size,
    )
    # PII policy for partner audience — see app/utils/pii.py.
    # Partners walk members through their gate; they don't own a
    # contact relationship with them. Names land as "Ahmad K." and
    # phones as "•• ••• 4567" so the front desk can still verify
    # identity for a lost-something-at-the-gym ticket without us
    # leaking E.164 numbers to every gym in the network.
    items = [
        AdminCheckinListItem(
            id=str(c.id),
            userId=str(u.id),
            userName=mask_name_for_partner(
                u.name, first_name=u.first_name, last_name=u.last_name
            ),
            userPhone=mask_phone_for_partner(u.phone),
            gymId=str(g.id),
            gymNameEn=g.name_en,
            gymNameAr=g.name_ar,
            status=c.status,
            scannedAt=c.scanned_at,
            failureReason=c.failure_reason,
        )
        for c, g, u in rows
    ]
    return Page[AdminCheckinListItem](items=items, total=total, page=page, pageSize=page_size)
