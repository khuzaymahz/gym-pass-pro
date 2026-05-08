from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    checkin_service,
    current_user,
    db_session,
    gym_repo,
    subscription_repo,
)
from app.db.enums import CheckinStatus, Tier
from app.db.models import User
from app.realtime import publish as realtime_publish
from app.repositories.gym_repo import GymRepository
from app.repositories.subscription_repo import SubscriptionRepository
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
    gyms: Annotated[GymRepository, Depends(gym_repo)],
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
) -> CheckinResult:
    from app.core.exceptions import AppError

    actor = authed_actor(request, user)
    try:
        checkin = await svc.scan(user=user, qr_payload=body.qr_payload, actor=actor)
        await session.commit()
    except AppError:
        # Service already wrote a Checkin row with the failure status; keep
        # that audit trail by committing the partial work before re-raising.
        await session.commit()
        raise

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

    gym = await gyms.get(checkin.gym_id)
    sub = await subs.active_for_user(user.id)
    remaining = None
    if sub is not None and sub.tier != Tier.DIAMOND:
        from app.repositories.plan_repo import PlanRepository
        from app.utils.time import current_period_start, utcnow

        plan_repo_ = PlanRepository(session)
        plan = await plan_repo_.get(sub.plan_id)
        if plan is not None:
            # Period count is derived from indexed `checkins` rows so the
            # response reflects the just-committed scan without re-reading
            # the (denormalized, lifetime) `subscriptions.visits_used`.
            period_start = current_period_start(sub.starts_at, utcnow())
            period_count = await svc.checkins.count_success_since_for_user(
                user.id, period_start
            )
            remaining = max(0, plan.monthly_visits - period_count)

    return CheckinResult(
        status=checkin.status,
        checkinId=checkin.id,
        gymId=gym.id if gym else None,
        gymNameEn=gym.name_en if gym else None,
        gymNameAr=gym.name_ar if gym else None,
        scannedAt=checkin.scanned_at,
        remainingVisits=remaining,
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
            gymNameAr=g.name_ar,
            scannedAt=c.scanned_at,
            status=c.status,
        )
        for c, g in rows
    ]
