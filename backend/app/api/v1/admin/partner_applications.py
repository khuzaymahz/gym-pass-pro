"""Admin review queue for the public partner /join flow.

The matching public endpoints live in
`app/api/v1/partner_applications.py`. This file is admin-only:
list pending applications, fetch detail, approve (creates real
gym + gym_owner user), or reject with notes.
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_admin,
    db_session,
    partner_application_service,
)
from app.db.enums import ApplicationStatus
from app.db.models import User
from app.schemas.common import Page
from app.schemas.partner_application import (
    PartnerApplicationApprove,
    PartnerApplicationRead,
    PartnerApplicationReject,
)
from app.services.partner_application_service import PartnerApplicationService

router = APIRouter(
    prefix="/admin/partner-applications", tags=["admin/partner-applications"]
)


@router.get("", response_model=Page[PartnerApplicationRead])
async def list_applications(
    svc: Annotated[
        PartnerApplicationService, Depends(partner_application_service)
    ],
    _: Annotated[User, Depends(current_admin)],
    status: ApplicationStatus | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=30, ge=1, le=100, alias="pageSize"),
) -> Page[PartnerApplicationRead]:
    rows, total = await svc.list(status=status, page=page, page_size=page_size)
    return Page[PartnerApplicationRead](
        items=[PartnerApplicationRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        pageSize=page_size,
    )


@router.get("/pending-count", response_model=dict[str, int])
async def pending_count(
    svc: Annotated[
        PartnerApplicationService, Depends(partner_application_service)
    ],
    _: Annotated[User, Depends(current_admin)],
) -> dict[str, int]:
    """Used by the admin sidebar to render a pending-count badge."""

    return {"pending": await svc.count_pending()}


@router.get("/{app_id}", response_model=PartnerApplicationRead)
async def get_application(
    app_id: UUID,
    svc: Annotated[
        PartnerApplicationService, Depends(partner_application_service)
    ],
    _: Annotated[User, Depends(current_admin)],
) -> PartnerApplicationRead:
    app = await svc.get(app_id)
    return PartnerApplicationRead.model_validate(app)


@router.post("/{app_id}/approve", response_model=PartnerApplicationRead)
async def approve_application(
    app_id: UUID,
    body: PartnerApplicationApprove,
    request: Request,
    user: Annotated[User, Depends(current_admin)],
    svc: Annotated[
        PartnerApplicationService, Depends(partner_application_service)
    ],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerApplicationRead:
    app = await svc.approve(
        app_id,
        notes=body.notes,
        actor=authed_actor(request, user),
        admin_user_id=user.id,
    )
    await session.commit()
    return PartnerApplicationRead.model_validate(app)


@router.post("/{app_id}/reject", response_model=PartnerApplicationRead)
async def reject_application(
    app_id: UUID,
    body: PartnerApplicationReject,
    request: Request,
    user: Annotated[User, Depends(current_admin)],
    svc: Annotated[
        PartnerApplicationService, Depends(partner_application_service)
    ],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerApplicationRead:
    app = await svc.reject(
        app_id,
        notes=body.notes,
        actor=authed_actor(request, user),
        admin_user_id=user.id,
    )
    await session.commit()
    return PartnerApplicationRead.model_validate(app)
