"""Admin endpoints to provision gym-partner logins.

Creates a `gym_owner` user linked to a specific gym (1:1). Partners
get credentials out of band; v1 has no invite-by-link flow. The
partial unique index `uq_users_gym_owner_gym_id` enforces the 1:1
invariant at the DB level — `AdminPartnerService` re-surfaces a
clean 409 if the race fires anyway.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_partner_service,
    authed_actor,
    current_admin,
    db_session,
)
from app.db.models import User
from app.schemas.partner import (
    CreatePartnerRequest,
    LinkPartnerRequest,
    PartnerOwnerRead,
    ResetPartnerPasswordRequest,
)
from app.services.admin_partner_service import AdminPartnerService

router = APIRouter(prefix="/admin/gyms", tags=["admin/gyms"])


@router.get("/{gym_id}/owner", response_model=PartnerOwnerRead | None)
async def get_owner(
    gym_id: UUID,
    _: Annotated[User, Depends(current_admin)],
    svc: Annotated[AdminPartnerService, Depends(admin_partner_service)],
) -> PartnerOwnerRead | None:
    owner = await svc.get_owner(gym_id)
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
    svc: Annotated[AdminPartnerService, Depends(admin_partner_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerOwnerRead:
    """Mint a partner login for a gym. Service handles validation,
    uniqueness, hashing, audit, and IntegrityError → 409 mapping."""
    _, payload = await svc.create_owner(
        gym_id=gym_id,
        phone=body.phone,
        password=body.password,
        name=body.name,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return PartnerOwnerRead(**payload)


@router.post("/{gym_id}/owner/link", response_model=PartnerOwnerRead, status_code=201)
async def link_owner(
    gym_id: UUID,
    body: LinkPartnerRequest,
    request: Request,
    admin: Annotated[User, Depends(current_admin)],
    svc: Annotated[AdminPartnerService, Depends(admin_partner_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerOwnerRead:
    """Attach an existing partner to this gym as an additional branch
    (multi-branch). Service validates the phone belongs to a partner who
    isn't already linked here, then writes the membership row + audit."""
    payload = await svc.link_owner(
        gym_id=gym_id,
        phone=body.phone,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return PartnerOwnerRead(**payload)


@router.patch("/{gym_id}/owner/password", status_code=204)
async def reset_owner_password(
    gym_id: UUID,
    body: ResetPartnerPasswordRequest,
    request: Request,
    admin: Annotated[User, Depends(current_admin)],
    svc: Annotated[AdminPartnerService, Depends(admin_partner_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Set a new password for the gym's partner login (admin-driven
    reset; no email/SMS flow in v1). Service validates + audit-logs."""
    await svc.reset_owner_password(
        gym_id=gym_id,
        password=body.password,
        actor=authed_actor(request, admin),
    )
    await session.commit()


@router.delete("/{gym_id}/owner", status_code=204)
async def delete_owner(
    gym_id: UUID,
    request: Request,
    admin: Annotated[User, Depends(current_admin)],
    svc: Annotated[AdminPartnerService, Depends(admin_partner_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    await svc.delete_owner(gym_id=gym_id, actor=authed_actor(request, admin))
    await session.commit()
