from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_user,
    db_session,
    referral_service,
)
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.services.referral_service import ReferralService

router = APIRouter(prefix="/referrals", tags=["referrals"])


class ResolveResult(BaseModel):
    name: str


class ClaimRequest(BaseModel):
    code: str = Field(min_length=3, max_length=16)

    model_config = ConfigDict(populate_by_name=True)


class ClaimResult(BaseModel):
    referrer_name: str = Field(alias="referrerName")
    code: str

    model_config = ConfigDict(populate_by_name=True)


@router.get("/resolve", response_model=ResolveResult)
async def resolve_referral(
    code: Annotated[str, Query(min_length=3, max_length=16)],
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[ReferralService, Depends(referral_service)],
) -> ResolveResult:
    """Resolve a friend's referral code to a display-name only. Authentication
    required: leaking display names to anonymous callers would let scrapers
    enumerate the user table by code-guessing. Self-codes return 404 so the
    mobile UI doesn't have to special-case them."""
    referrer = await svc.resolve_code(code)
    if referrer is None or referrer.id == me.id:
        raise AppError(ErrorCode.NOT_FOUND, "Unknown referral code.")
    name = (referrer.display_name or "").strip()
    if not name:
        # No first/last/email/phone on file — should be rare since signup
        # enforces a name, but fall back to the masked phone tail so the UI
        # has *something* recognizable to render.
        phone = referrer.phone or ""
        name = phone[-4:] if len(phone) >= 4 else "—"
    return ResolveResult(name=name)


@router.post("/claim", response_model=ClaimResult)
async def claim_referral(
    body: ClaimRequest,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[ReferralService, Depends(referral_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> ClaimResult:
    """Attach the authenticated member to the referrer behind `code`.

    Idempotent on the invited side — a member with an existing referral row
    returns the same row's referrer instead of creating a second one. Errors
    on self-referral and unknown codes match the resolve endpoint's shape so
    the mobile UI can reuse one error mapping.
    """
    actor = authed_actor(request, me)
    try:
        referral = await svc.claim_on_signup(
            invited_user=me, referral_code=body.code, actor=actor
        )
    except AppError:
        # Service raises VALIDATION_ERROR for unknown / self codes. Surface
        # the same shape the resolve endpoint uses so mobile only needs one
        # error path.
        raise
    if referral is None:
        # Should never happen — claim_on_signup either raises or returns
        # an existing row when the user already has one. Defensive 500 so
        # any future change that returns None gets caught in tests.
        raise AppError(
            ErrorCode.INTERNAL_ERROR, "Referral claim returned no row."
        )
    referrer = await svc.users.get(referral.referrer_user_id)
    name = (referrer.display_name if referrer else "") or ""
    if not name and referrer is not None:
        phone = referrer.phone or ""
        name = phone[-4:] if len(phone) >= 4 else "—"
    await session.commit()
    return ClaimResult(referrerName=name, code=referral.referral_code)
