"""Public partner-application endpoints (the "Join Us" flow).

These routes are intentionally **un-authenticated** — they're the
public entry point for a gym owner who has never logged in. They
sit outside `api/v1/member/` / `api/v1/admin/` / `api/v1/partner/`
because none of those audiences fit (the caller is anonymous).

Rate limiting:
  * `POST /partner-applications` — 3 per IP per hour. Stops spray;
    a real applicant only submits once.
  * `POST /partner-applications/upload` — 30 per IP per hour. Each
    application can include up to 12 photos + 1 logo, so 13
    uploads is the legitimate ceiling; 30 leaves headroom for
    failed-and-retried uploads.
"""

from __future__ import annotations

from pathlib import Path
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    client_actor,
    db_session,
    partner_application_service,
    rate_limiter,
)
from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.schemas.partner_application import (
    PartnerApplicationSubmit,
    PartnerApplicationSubmitResponse,
    PartnerApplicationUploadResponse,
)
from app.services.partner_application_service import PartnerApplicationService
from app.services.rate_limit import RateLimiter
from app.utils.image_sniff import sniff_image

router = APIRouter(prefix="/partner-applications", tags=["partner-applications"])


@router.post(
    "/upload",
    response_model=PartnerApplicationUploadResponse,
    status_code=201,
)
async def upload_application_media(
    request: Request,
    file: Annotated[UploadFile, File()],
    rl: Annotated[RateLimiter, Depends(rate_limiter)],
) -> PartnerApplicationUploadResponse:
    """Public upload endpoint used by the partner /join form for the
    logo + each photo. Files land under
    `media_root/applications/<random-uuid>/<filename>` and are moved
    into the gym's permanent dir on approval — see
    `PartnerApplicationService.approve`.

    The application id is NOT known yet at upload time (the partner
    fills in the form before submitting), so we generate a separate
    staging dir per upload and the form's submit step references the
    full URL we return. The approve flow finds the file by URL
    prefix, no DB row needed for the staging step.
    """

    settings = get_settings()
    ip = request.client.host if request.client else "anon"
    allowed = await rl.allow(
        f"app_upload:{ip}",
        limit=30,
        window_seconds=3600,
    )
    if not allowed:
        raise AppError(
            ErrorCode.RATE_LIMITED,
            "Too many uploads from this address. Try again later.",
        )

    max_bytes = settings.max_upload_mb * 1024 * 1024
    payload = await file.read(max_bytes + 1)
    if len(payload) == 0:
        raise AppError(
            ErrorCode.VALIDATION_ERROR, "Empty file.", details={"field": "file"}
        )
    if len(payload) > max_bytes:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            f"Image exceeds {settings.max_upload_mb} MB limit.",
            details={"field": "file"},
        )
    sniffed = sniff_image(payload)
    if sniffed is None:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Unsupported image type. Use JPEG, PNG, or WebP.",
            details={"field": "file", "contentType": file.content_type},
        )
    _content_type, ext = sniffed

    # Staging dir keyed by a random UUID per upload so two concurrent
    # uploads from the same IP can't collide. The approve flow
    # accepts this URL shape and moves the file into the gym dir.
    staging_id = uuid4().hex
    app_dir = Path(settings.media_root) / "applications" / staging_id
    app_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}.{ext}"
    disk_path = app_dir / filename
    disk_path.write_bytes(payload)

    public_url = (
        f"{settings.media_url_prefix.rstrip('/')}"
        f"/applications/{staging_id}/{filename}"
    )
    return PartnerApplicationUploadResponse(url=public_url)


@router.post(
    "",
    response_model=PartnerApplicationSubmitResponse,
    status_code=201,
)
async def submit_application(
    request: Request,
    body: PartnerApplicationSubmit,
    svc: Annotated[
        PartnerApplicationService, Depends(partner_application_service)
    ],
    rl: Annotated[RateLimiter, Depends(rate_limiter)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PartnerApplicationSubmitResponse:
    ip = request.client.host if request.client else "anon"
    allowed = await rl.allow(
        f"app_submit:{ip}",
        limit=3,
        window_seconds=3600,
    )
    if not allowed:
        raise AppError(
            ErrorCode.RATE_LIMITED,
            "Too many applications from this address. "
            "Contact partners@gym-pass.net if you need help.",
        )

    actor = client_actor(request)
    app = await svc.submit(body, actor=actor)
    await session.commit()
    return PartnerApplicationSubmitResponse(id=app.id, status=app.status)
