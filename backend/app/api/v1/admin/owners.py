"""Admin endpoints to provision gym-partner logins.

Creates a `gym_owner` user linked to a specific gym (1:1). Partners
get credentials out of band; v1 has no invite-by-link flow. The
partial unique index `uq_users_gym_owner_gym_id` enforces the 1:1
invariant at the DB level — this router relies on it for race-safety
rather than re-checking in Python.
"""

from __future__ import annotations

import re
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app.api.deps import (
    audit_service,
    authed_actor,
    current_admin,
    db_session,
    gym_service,
    user_repo,
)
from app.core.exceptions import AppError, ErrorCode
from app.core.security import hash_password
from app.db.enums import Role
from app.db.models import User
from app.repositories.user_repo import UserRepository
from app.schemas.partner import CreatePartnerRequest, PartnerOwnerRead
from app.services.audit_service import AuditService
from app.services.gym_service import GymService

router = APIRouter(prefix="/admin/gyms", tags=["admin/gyms"])

PHONE_RE = re.compile(r"^\+962(7[789])\d{7}$")


@router.get("/{gym_id}/owner", response_model=PartnerOwnerRead | None)
async def get_owner(
    gym_id: UUID,
    _: Annotated[User, Depends(current_admin)],
    users: Annotated[UserRepository, Depends(user_repo)],
    svc: Annotated[GymService, Depends(gym_service)],
) -> PartnerOwnerRead | None:
    await svc.get(gym_id)  # 404s on unknown gym
    owner = await users.get_gym_owner_for_gym(gym_id)
    if owner is None:
        return None
    return PartnerOwnerRead(
        id=str(owner.id),
        phone=owner.phone or "",
        name=owner.name,
        gymId=str(gym_id),
    )


@router.post("/{gym_id}/owner", response_model=PartnerOwnerRead, status_code=201)
async def create_owner(
    gym_id: UUID,
    body: CreatePartnerRequest,
    request: Request,
    admin: Annotated[User, Depends(current_admin)],
    users: Annotated[UserRepository, Depends(user_repo)],
    svc: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerOwnerRead:
    """Mint a partner login for a gym.

    Refuses if the gym already has an owner (the partial unique
    index would refuse it anyway, but we prefer a clean 409 over an
    IntegrityError surfacing as a 500). Refuses if the phone is
    already registered as a *member* — re-using an existing member
    record as a partner conflates two identities; if a partner has
    a personal member account they should use a different number.
    """
    phone = body.phone.strip().replace(" ", "").replace("-", "")
    if not PHONE_RE.match(phone):
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Invalid Jordanian phone (expected +9627XXXXXXXX).",
            details={"field": "phone"},
        )

    gym = await svc.get(gym_id)

    existing_owner = await users.get_gym_owner_for_gym(gym_id)
    if existing_owner is not None:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "This gym already has a partner login.",
            details={"field": "gymId"},
        )

    existing_user = await users.get_by_phone(phone)
    if existing_user is not None:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Phone is already registered to another account.",
            details={"field": "phone"},
        )

    try:
        owner = await users.create_gym_owner(
            phone=phone,
            password_hash=hash_password(body.password),
            name=body.name,
            gym_id=gym.id,
        )
    except IntegrityError as exc:
        # Partial unique race (someone created the partner between
        # our check and this insert) → surface as 409 not 500.
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "This gym already has a partner login.",
            details={"field": "gymId"},
        ) from exc

    await audit.log(
        actor=authed_actor(request, admin),
        action="partner.create",
        entity_type="user",
        entity_id=owner.id,
        diff={
            "after": {
                "role": Role.GYM_OWNER.value,
                "gym_id": str(gym.id),
                "phone": phone,
                "name": body.name,
            }
        },
    )
    await session.commit()
    return PartnerOwnerRead(
        id=str(owner.id),
        phone=phone,
        name=owner.name,
        gymId=str(gym.id),
    )


@router.delete("/{gym_id}/owner", status_code=204)
async def delete_owner(
    gym_id: UUID,
    request: Request,
    admin: Annotated[User, Depends(current_admin)],
    users: Annotated[UserRepository, Depends(user_repo)],
    svc: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Soft-delete a partner login. The `users` row stays for audit;
    the partial unique index drops it from the active-owner set as
    soon as `deleted_at` is non-null, freeing the gym to receive a
    new partner without a manual cleanup."""
    await svc.get(gym_id)
    owner = await users.get_gym_owner_for_gym(gym_id)
    if owner is None:
        raise AppError(ErrorCode.NOT_FOUND, "No partner attached to this gym.")
    from app.utils.time import utcnow

    await users.soft_delete(owner, utcnow())
    await audit.log(
        actor=authed_actor(request, admin),
        action="partner.delete",
        entity_type="user",
        entity_id=owner.id,
        diff={"before": {"gym_id": str(gym_id), "phone": owner.phone}},
    )
    await session.commit()
