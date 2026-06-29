from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_partner,
    day_pass_offering_repo,
    day_pass_service,
    db_session,
    gym_service,
    selected_gym,
)
from app.db.models import User
from app.realtime import publish as realtime_publish
from app.repositories.day_pass_repo import DayPassOfferingRepository
from app.schemas.day_pass import DayPassOfferingRead, DayPassOfferingUpsert
from app.services.day_pass_service import DayPassService
from app.services.gym_service import GymService

router = APIRouter(prefix="/partner/gym/day-pass-offering", tags=["partner/day-pass"])


@router.get("", response_model=DayPassOfferingRead | None)
async def get_offering(
    gym_id: Annotated[UUID, Depends(selected_gym)],
    svc: Annotated[GymService, Depends(gym_service)],
    offerings: Annotated[DayPassOfferingRepository, Depends(day_pass_offering_repo)],
) -> DayPassOfferingRead | None:
    """Return the partner's current offering or null if they haven't
    configured one yet. Null is a meaningful state — the gym profile
    editor renders an empty/off form rather than 404'ing.
    """
    # selected_gym already verified access; the GymService lookup ensures
    # the gym still exists + isn't soft-deleted.
    await svc.get(gym_id)
    offering = await offerings.for_gym(gym_id)
    if offering is None:
        return None
    return DayPassOfferingRead.model_validate(offering)


@router.put("", response_model=DayPassOfferingRead)
async def upsert_offering(
    body: DayPassOfferingUpsert,
    request: Request,
    gym_id: Annotated[UUID, Depends(selected_gym)],
    user: Annotated[User, Depends(current_partner)],
    svc: Annotated[GymService, Depends(gym_service)],
    dps: Annotated[DayPassService, Depends(day_pass_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> DayPassOfferingRead:
    """Create or update the offering. PUT (not PATCH) — the entire
    offering is sent every save, so the partner can flip
    `isEnabled` and edit the price in one round trip without the
    server merging partial state.
    """
    gym = await svc.get(gym_id)
    offering = await dps.upsert_offering(
        gym=gym,
        is_enabled=body.is_enabled,
        price_jod=body.price_jod,
        daily_cap=body.daily_cap,
        audience_gender_override=body.audience_gender_override,
        actor=authed_actor(request, user),
    )
    await session.commit()
    # Live fan-out so a member currently on the gym detail page sees
    # the day-pass CTA appear/disappear without a manual pull.
    await realtime_publish(
        f"gym/{gym.id}",
        {
            "type": "gym.day_pass.updated",
            "gymId": str(gym.id),
            "slug": gym.slug,
            "isEnabled": offering.is_enabled,
        },
    )
    return DayPassOfferingRead.model_validate(offering)
