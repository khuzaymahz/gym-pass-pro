from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_user,
    db_session,
    payment_method_repo,
    plan_repo,
    subscription_service,
)
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.repositories.payment_method_repo import PaymentMethodRepository
from app.repositories.plan_repo import PlanRepository
from app.schemas.plan import PlanRead
from app.schemas.subscription import (
    CurrentSubscription,
    SubscriptionCreate,
    SubscriptionRead,
)
from app.services.subscription_service import SubscriptionService

router = APIRouter(tags=["subscriptions"])


@router.get("/plans", response_model=list[PlanRead])
async def list_plans(
    plans: Annotated[PlanRepository, Depends(plan_repo)],
) -> list[PlanRead]:
    rows = await plans.list_active()
    return [PlanRead.model_validate(r) for r in rows]


@router.get("/me/subscription", response_model=CurrentSubscription)
async def current_subscription(
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[SubscriptionService, Depends(subscription_service)],
) -> CurrentSubscription:
    sub, current_period_visits, remaining, _ = await svc.current(user)
    return CurrentSubscription(
        subscription=SubscriptionRead.model_validate(sub) if sub else None,
        currentPeriodVisits=current_period_visits,
        remainingVisits=remaining,
    )


@router.post("/subscriptions", response_model=SubscriptionRead, status_code=201)
async def purchase(
    body: SubscriptionCreate,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[SubscriptionService, Depends(subscription_service)],
    methods: Annotated[PaymentMethodRepository, Depends(payment_method_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SubscriptionRead:
    actor = authed_actor(request, user)
    # If the caller passed a stored-method id, confirm they own it. Mobile
    # picks the method locally; this guard prevents a malformed client from
    # charging "method X" while we record method Y in the audit trail.
    if body.payment_method_id is not None:
        owned = await methods.get_owned(
            method_id=body.payment_method_id, user_id=user.id
        )
        if owned is None:
            raise AppError(
                ErrorCode.NOT_FOUND, "Payment method not found."
            )
    sub = await svc.purchase(
        user=user,
        plan_id=body.plan_id,
        payment_method=body.payment_method.value,
        payment_method_id=body.payment_method_id,
        actor=actor,
    )
    await session.commit()
    return SubscriptionRead.model_validate(sub)


@router.post(
    "/subscriptions/{subscription_id}/cancel", response_model=SubscriptionRead
)
async def cancel(
    subscription_id: UUID,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[SubscriptionService, Depends(subscription_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SubscriptionRead:
    actor = authed_actor(request, user)
    sub = await svc.cancel(sub_id=subscription_id, user=user, actor=actor)
    await session.commit()
    return SubscriptionRead.model_validate(sub)


@router.post(
    "/subscriptions/replace",
    response_model=SubscriptionRead,
    status_code=201,
)
async def replace(
    body: SubscriptionCreate,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[SubscriptionService, Depends(subscription_service)],
    methods: Annotated[PaymentMethodRepository, Depends(payment_method_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SubscriptionRead:
    """Atomically cancel the user's current active subscription (if any)
    and purchase the new plan in a single transaction.

    Replaces the two-call client flow (cancel then purchase) which left
    a window where a network drop after cancel-succeeded and before
    purchase landed the member in a paid-cancelled-no-replacement
    state. Either both mutations land or neither does — the route
    commit is the single commit point.
    """
    actor = authed_actor(request, user)
    if body.payment_method_id is not None:
        owned = await methods.get_owned(
            method_id=body.payment_method_id, user_id=user.id
        )
        if owned is None:
            raise AppError(
                ErrorCode.NOT_FOUND, "Payment method not found."
            )
    sub = await svc.replace(
        user=user,
        new_plan_id=body.plan_id,
        payment_method=body.payment_method.value,
        payment_method_id=body.payment_method_id,
        actor=actor,
    )
    await session.commit()
    return SubscriptionRead.model_validate(sub)
