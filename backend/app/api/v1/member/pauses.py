from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_user,
    db_session,
    pause_service,
    subscription_pause_repo,
    subscription_repo,
)
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.schemas.pause import PauseCreate, PauseRead
from app.services.pause_service import PauseService

router = APIRouter(prefix="/me/subscription/pause", tags=["me/subscription/pause"])


@router.get("", response_model=PauseRead | None)
async def get_open_pause(
    me: Annotated[User, Depends(current_user)],
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    pauses: Annotated[
        SubscriptionPauseRepository, Depends(subscription_pause_repo)
    ],
) -> PauseRead | None:
    """Return the active or scheduled pause if one exists, else null.

    Mobile uses this on the My Subscription screen to render the
    pause-status card. Returning `null` instead of 404 keeps the
    status check the same shape whether or not a pause exists.
    """
    sub = await subs.active_for_user(me.id)
    if sub is None:
        return None
    open_pause = await pauses.open_for_subscription(sub.id)
    return PauseRead.model_validate(open_pause) if open_pause else None


@router.post("", response_model=PauseRead, status_code=201)
async def schedule_pause(
    body: PauseCreate,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    svc: Annotated[PauseService, Depends(pause_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PauseRead:
    sub = await subs.active_for_user(me.id)
    if sub is None:
        raise AppError(
            ErrorCode.SUB_NOT_FOUND, "No active subscription to pause."
        )
    row = await svc.schedule(
        subscription=sub,
        starts_on=body.starts_on,
        ends_on=body.ends_on,
        actor=authed_actor(request, me),
    )
    await session.commit()
    return PauseRead.model_validate(row)


@router.post("/resume", response_model=PauseRead | None)
async def resume_pause(
    request: Request,
    me: Annotated[User, Depends(current_user)],
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    svc: Annotated[PauseService, Depends(pause_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PauseRead | None:
    """Manual early resume. No-op if no pause is open. Idempotent on
    repeated calls — the second call sees no open pause and returns
    null instead of erroring."""
    sub = await subs.active_for_user(me.id)
    if sub is None:
        raise AppError(
            ErrorCode.SUB_NOT_FOUND, "No active subscription."
        )
    row = await svc.resume(
        subscription=sub, actor=authed_actor(request, me)
    )
    await session.commit()
    return PauseRead.model_validate(row) if row else None
