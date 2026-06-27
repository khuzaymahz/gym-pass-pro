from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_user,
    day_pass_offering_repo,
    day_pass_service,
    db_session,
    gym_repo,
    payment_method_repo,
)
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.repositories.day_pass_repo import DayPassOfferingRepository
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_method_repo import PaymentMethodRepository
from app.schemas.day_pass import (
    DayPassListResponse,
    DayPassOfferingPublic,
    DayPassPurchase,
    DayPassRead,
)
from app.services.day_pass_service import DayPassService

router = APIRouter(tags=["day-passes"])


@router.get(
    "/gyms/{slug}/day-pass-offering",
    response_model=DayPassOfferingPublic,
)
async def public_offering(
    slug: str,
    gyms: Annotated[GymRepository, Depends(gym_repo)],
    offerings: Annotated[
        DayPassOfferingRepository, Depends(day_pass_offering_repo)
    ],
) -> DayPassOfferingPublic:
    """Public read of the offering. Members hit this from the gym
    profile page to decide whether to render the "Try today" CTA.

    Returns a disabled offering ({isEnabled: false}) when the gym
    has no row OR has the offering turned off — the mobile UI
    treats both states identically and never needs to distinguish.
    """
    gym = await gyms.get_by_slug(slug)
    if gym is None or not gym.is_active or gym.deleted_at is not None:
        raise AppError(ErrorCode.GYM_NOT_FOUND, "Gym not found.")
    offering = await offerings.for_gym(gym.id)
    if offering is None or not offering.is_enabled:
        # Synthesize a disabled response — the mobile client only
        # needs the boolean to decide whether to render the CTA.
        return DayPassOfferingPublic(
            is_enabled=False, price_jod=0, validity_hours=0
        )
    return DayPassOfferingPublic.model_validate(
        {
            "isEnabled": offering.is_enabled,
            "priceJod": offering.price_jod,
            "validityHours": offering.validity_hours,
        }
    )


@router.post("/day-passes", response_model=DayPassRead, status_code=201)
async def purchase(
    body: DayPassPurchase,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[DayPassService, Depends(day_pass_service)],
    methods: Annotated[
        PaymentMethodRepository, Depends(payment_method_repo)
    ],
    gyms: Annotated[GymRepository, Depends(gym_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> DayPassRead:
    """Member buys a day pass for a specific gym.

    Same shape as `POST /subscriptions` — verifies caller owns the
    payment method (when supplied), calls the service, commits.
    """
    if body.payment_method_id is not None:
        owned = await methods.get_owned(
            method_id=body.payment_method_id, user_id=user.id
        )
        if owned is None:
            raise AppError(ErrorCode.NOT_FOUND, "Payment method not found.")

    day_pass = await svc.purchase(
        user=user,
        gym_slug=body.gym_slug,
        payment_method=body.payment_method.value,
        payment_method_id=body.payment_method_id,
        actor=authed_actor(request, user),
    )
    await session.commit()

    # Hydrate the gym name fields for the response — the row only
    # carries gym_id, but the mobile pass-list surface wants names
    # so it can render without a follow-up gym lookup.
    gym = await gyms.get(day_pass.gym_id)
    return DayPassRead.model_validate(
        {
            "id": day_pass.id,
            "gymId": day_pass.gym_id,
            "gymSlug": gym.slug if gym else "",
            "gymNameEn": gym.name_en if gym else "",
            "status": day_pass.status,
            "priceJod": day_pass.price_jod,
            "purchasedAt": day_pass.purchased_at,
            "expiresAt": day_pass.expires_at,
            "usedAt": day_pass.used_at,
        }
    )


@router.get("/day-passes", response_model=DayPassListResponse)
async def list_my(
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[DayPassService, Depends(day_pass_service)],
    gyms: Annotated[GymRepository, Depends(gym_repo)],
) -> DayPassListResponse:
    """List the caller's day passes, active first. Profile page's
    "Active passes" surface watches this.
    """
    rows = await svc.list_for_user(user)
    if not rows:
        return DayPassListResponse(items=[])
    # Resolve gym names in one batched lookup.
    gym_ids = list({r.gym_id for r in rows})
    gym_map = {gid: await gyms.get(gid) for gid in gym_ids}
    items = []
    for r in rows:
        gym = gym_map.get(r.gym_id)
        items.append(
            DayPassRead.model_validate(
                {
                    "id": r.id,
                    "gymId": r.gym_id,
                    "gymSlug": gym.slug if gym else "",
                    "gymNameEn": gym.name_en if gym else "",
                    "status": r.status,
                    "priceJod": r.price_jod,
                    "purchasedAt": r.purchased_at,
                    "expiresAt": r.expires_at,
                    "usedAt": r.used_at,
                }
            )
        )
    return DayPassListResponse(items=items)
