from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    checkin_service,
    current_user,
    db_session,
)
from app.db.enums import CheckinStatus
from app.db.models import User
from app.realtime import publish as realtime_publish
from app.schemas.checkin import CheckinHistoryItem, CheckinResult, CheckinScanRequest
from app.services.checkin_service import CheckinService

router = APIRouter(prefix="/checkins", tags=["checkins"])


@router.post("/scan", response_model=CheckinResult)
async def scan(
    body: CheckinScanRequest,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[CheckinService, Depends(checkin_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> CheckinResult:
    from app.core.exceptions import AppError

    actor = authed_actor(request, user)
    try:
        result = await svc.scan(user=user, qr_payload=body.qr_payload, actor=actor)
        await session.commit()
    except AppError:
        # Service already wrote a Checkin row with the failure status; keep
        # that audit trail by committing the partial work before re-raising.
        await session.commit()
        raise

    checkin = result.checkin
    gym = result.gym

    # Live-update the partner dashboard for this gym (recent
    # check-ins panel) and the member's own personal channel
    # (their checkin history). Best-effort — `realtime_publish`
    # swallows transport errors so the HTTP response is never held
    # up by a flaky pub/sub.
    if checkin.status == CheckinStatus.SUCCESS:
        await realtime_publish(
            f"gym/{checkin.gym_id}/checkins",
            {
                "type": "checkin.success",
                "checkinId": str(checkin.id),
                "gymId": str(checkin.gym_id),
            },
        )
        await realtime_publish(
            f"user/{user.id}",
            {"type": "checkin.created", "checkinId": str(checkin.id)},
        )

    return CheckinResult(
        status=checkin.status,
        checkinId=checkin.id,
        gymId=gym.id if gym else None,
        gymNameEn=gym.name_en if gym else None,
        scannedAt=checkin.scanned_at,
        remainingVisits=result.remaining,
    )


@router.get("/me", response_model=list[CheckinHistoryItem])
async def my_checkins(
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[CheckinService, Depends(checkin_service)],
) -> list[CheckinHistoryItem]:
    rows = await svc.history(user)
    return [
        CheckinHistoryItem(
            id=c.id,
            gymId=g.id,
            gymNameEn=g.name_en,
            scannedAt=c.scanned_at,
            status=c.status,
        )
        for c, g in rows
    ]
