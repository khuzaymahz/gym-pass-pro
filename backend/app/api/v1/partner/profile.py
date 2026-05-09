from __future__ import annotations

from pathlib import Path
from typing import Annotated, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    audit_service,
    authed_actor,
    current_gym_owner,
    db_session,
    gym_service,
)
from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.realtime import publish as realtime_publish
from app.schemas.gym import GymRead, GymUpdate, LogoAlignment
from app.services.audit_service import AuditService
from app.services.gym_service import GymService
from app.utils.image_sniff import sniff_image

LogoFit = Literal["cover", "contain"]
LogoPosition = Literal["top", "center", "bottom"]

router = APIRouter(prefix="/partner/gym", tags=["partner/gym"])


@router.get("", response_model=GymRead)
async def get_my_gym(
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[GymService, Depends(gym_service)],
) -> GymRead:
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    gym = await svc.get(user.gym_id)
    return GymRead.model_validate(gym)


@router.patch("", response_model=GymRead)
async def update_my_gym(
    body: GymUpdate,
    request: Request,
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[GymService, Depends(gym_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymRead:
    """Partner edits their own gym profile.

    Constraints applied here that admin doesn't bother with: a partner
    cannot self-promote their gym to a higher `requiredTier` (that
    affects who can scan in and is a commercial decision), and a
    partner cannot raise their own `perVisitRateJod` (we don't want a
    self-serve revenue dial). Both fields silently fall back to the
    current value if the partner sends them — we don't 400 because
    NextAuth-authored forms commonly re-post the full record.
    """
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    gym = await svc.get(user.gym_id)
    safe = body.model_dump(by_alias=False, exclude_unset=True)
    safe.pop("required_tier", None)
    safe.pop("per_visit_rate_jod", None)
    safe.pop("is_active", None)
    gym = await svc.update(
        gym.id, GymUpdate.model_validate(safe), actor=authed_actor(request, user),
    )
    await session.commit()
    # Live fan-out so any member currently on this gym's detail
    # page (or the explore list) re-fetches without a manual pull.
    await realtime_publish(
        f"gym/{gym.id}",
        {"type": "gym.updated", "gymId": str(gym.id), "slug": gym.slug},
    )
    return GymRead.model_validate(gym)


@router.post("/logo", response_model=GymRead)
async def upload_logo(
    request: Request,
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
    file: Annotated[UploadFile, File()],
    fit: Annotated[LogoFit | None, Form()] = None,
    position: Annotated[LogoPosition | None, Form()] = None,
) -> GymRead:
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    gym = await svc.get(user.gym_id)
    settings = get_settings()

    max_bytes = settings.max_upload_mb * 1024 * 1024
    payload = await file.read(max_bytes + 1)
    if len(payload) > max_bytes:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            f"Image exceeds {settings.max_upload_mb} MB limit.",
            details={"field": "file"},
        )
    if len(payload) == 0:
        raise AppError(
            ErrorCode.VALIDATION_ERROR, "Empty file.", details={"field": "file"}
        )
    sniffed = sniff_image(payload)
    if sniffed is None:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Unsupported image type. Use JPEG, PNG, or WebP.",
            details={"field": "file", "contentType": file.content_type},
        )
    content_type, ext = sniffed

    logo_dir = Path(settings.media_root) / "gym_logos" / str(gym.id)
    logo_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}.{ext}"
    disk_path = logo_dir / filename
    disk_path.write_bytes(payload)

    public_url = f"{settings.media_url_prefix}/gym_logos/{gym.id}/{filename}"
    prefix = settings.media_url_prefix.rstrip("/") + "/"
    previous_url = gym.logo_url
    gym.logo_url = public_url
    # Persist alignment alongside the URL when the partner sent one;
    # falling back to the existing alignment (or None for first
    # upload) keeps the column representative of the latest choice.
    if fit is not None or position is not None:
        alignment = LogoAlignment(
            fit=fit or "cover",
            position=position or "center",
        )
        gym.logo_alignment = alignment.model_dump()
    await session.flush()

    await audit.log(
        actor=authed_actor(request, user),
        action="gym.logo.set",
        entity_type="gym",
        entity_id=gym.id,
        diff={
            "before": {"logo_url": previous_url},
            "after": {
                "logo_url": public_url,
                "size_bytes": len(payload),
                "content_type": content_type,
            },
        },
    )
    await session.commit()

    if previous_url and previous_url.startswith(prefix):
        old = Path(settings.media_root) / previous_url[len(prefix):]
        try:
            old.unlink(missing_ok=True)
        except OSError:
            pass

    await realtime_publish(
        f"gym/{gym.id}",
        {
            "type": "gym.logo.set",
            "gymId": str(gym.id),
            "slug": gym.slug,
            "logoUrl": public_url,
        },
    )
    return GymRead.model_validate(gym)


@router.delete("/logo", response_model=GymRead)
async def delete_logo(
    request: Request,
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymRead:
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN,
            "Partner account not linked to a gym.",
        )
    gym = await svc.get(user.gym_id)
    settings = get_settings()
    previous_url = gym.logo_url
    if previous_url is None:
        return GymRead.model_validate(gym)

    previous_alignment = gym.logo_alignment
    gym.logo_url = None
    gym.logo_alignment = None
    await session.flush()
    await audit.log(
        actor=authed_actor(request, user),
        action="gym.logo.clear",
        entity_type="gym",
        entity_id=gym.id,
        diff={
            "before": {
                "logo_url": previous_url,
                "logo_alignment": previous_alignment,
            },
            "after": {"logo_url": None, "logo_alignment": None},
        },
    )
    await session.commit()

    prefix = settings.media_url_prefix.rstrip("/") + "/"
    if previous_url.startswith(prefix):
        old = Path(settings.media_root) / previous_url[len(prefix):]
        try:
            old.unlink(missing_ok=True)
        except OSError:
            pass

    await realtime_publish(
        f"gym/{gym.id}",
        {
            "type": "gym.logo.cleared",
            "gymId": str(gym.id),
            "slug": gym.slug,
        },
    )
    return GymRead.model_validate(gym)
