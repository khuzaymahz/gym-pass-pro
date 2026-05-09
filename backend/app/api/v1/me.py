from __future__ import annotations

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import auth_service, current_user, db_session, referral_service, user_repo
from app.config import Settings, get_settings
from app.core.exceptions import AppError, ErrorCode
from app.core.security import hash_password_async
from app.db.enums import ReferralStatus
from app.db.models import User
from app.repositories.user_repo import UserRepository
from app.schemas.auth import MeUpdate, MeUser, PhoneChangeStart, PhoneChangeVerify
from app.services.audit_service import Actor
from app.services.auth_service import AuthService
from app.services.referral_service import ReferralService

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=MeUser)
async def me(user: Annotated[User, Depends(current_user)]) -> MeUser:
    return MeUser.model_validate(user)


@router.patch("", response_model=MeUser)
async def update_me(
    body: MeUpdate,
    user: Annotated[User, Depends(current_user)],
    users: Annotated[UserRepository, Depends(user_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> MeUser:
    fields: dict[str, object] = {}
    if body.first_name is not None:
        fields["first_name"] = body.first_name.strip()
    if body.last_name is not None:
        fields["last_name"] = body.last_name.strip()
    # Mirror first/last into legacy `name` so existing code paths that read it
    # (admin list, referral display_name fallback) stay coherent.
    derived_name = " ".join(
        p for p in (
            fields.get("first_name", user.first_name),
            fields.get("last_name", user.last_name),
        ) if p
    ).strip()
    if derived_name:
        fields["name"] = derived_name
    if body.email is not None:
        existing = await users.get_by_email(body.email)
        if existing is not None and existing.id != user.id:
            raise AppError(
                ErrorCode.VALIDATION_ERROR, "Email already in use."
            )
        fields["email"] = body.email
    if body.gender is not None:
        fields["gender"] = body.gender
    if body.birthdate is not None:
        fields["birthdate"] = body.birthdate
    if body.locale is not None:
        fields["locale"] = body.locale
    if body.password is not None:
        fields["password_hash"] = await hash_password_async(body.password)
    if fields:
        await users.update_fields(user, **fields)
        await session.commit()
        await session.refresh(user)
    return MeUser.model_validate(user)


@router.post("/phone/start", status_code=204)
async def phone_change_start(
    body: PhoneChangeStart,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[AuthService, Depends(auth_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Start a phone-number change for the authenticated user.

    The same OTP infrastructure as the sign-in OTP is reused — keyed on the
    *new* phone, so an attacker can't redirect a stranger's account by
    requesting an OTP to a number they control without proving they own it.
    """
    actor = Actor(
        user_id=user.id,
        role=user.role,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    await svc.request_phone_change_otp(user, body.phone, actor=actor)
    await session.commit()


@router.post("/phone/verify", response_model=MeUser)
async def phone_change_verify(
    body: PhoneChangeVerify,
    request: Request,
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[AuthService, Depends(auth_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> MeUser:
    actor = Actor(
        user_id=user.id,
        role=user.role,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    updated = await svc.verify_phone_change(user, body.phone, body.code, actor=actor)
    await session.commit()
    await session.refresh(updated)
    return MeUser.model_validate(updated)


class ReferralInvited(BaseModel):
    id: UUID
    name: str | None = None
    created_at: datetime = Field(alias="createdAt")
    converted_at: datetime | None = Field(alias="convertedAt", default=None)
    status: ReferralStatus

    model_config = ConfigDict(populate_by_name=True)


class MyReferralSummary(BaseModel):
    code: str
    share_url: str = Field(alias="shareUrl")
    counts: dict[str, int]
    invited: list[ReferralInvited]

    model_config = ConfigDict(populate_by_name=True)


@router.get("/referral", response_model=MyReferralSummary)
async def my_referral(
    user: Annotated[User, Depends(current_user)],
    svc: Annotated[ReferralService, Depends(referral_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> MyReferralSummary:
    summary = await svc.summary_for(user)
    # ensure_code_for_user may have just written a code — commit it.
    await session.commit()

    code = str(summary["code"])
    counts = dict(summary["counts"])  # type: ignore[arg-type]
    rows = list(summary["items"])  # type: ignore[arg-type]
    invited = [
        ReferralInvited(
            id=invited_user.id,
            name=invited_user.display_name,
            createdAt=referral.created_at,
            convertedAt=referral.converted_at,
            status=referral.status,
        )
        for referral, invited_user in rows
    ]
    base = settings.share_base_url.rstrip("/")
    return MyReferralSummary(
        code=code,
        shareUrl=f"{base}/invite/{code}",
        counts=counts,
        invited=invited,
    )
