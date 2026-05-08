from __future__ import annotations

from pathlib import Path
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    audit_service,
    authed_actor,
    current_gym_owner,
    db_session,
    gym_photo_repo,
    gym_service,
)
from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.realtime import publish as realtime_publish
from app.repositories.gym_photo_repo import GymPhotoRepository
from app.schemas.gym_photo import GymPhotoRead, GymPhotoUpdate
from app.services.audit_service import AuditService
from app.services.gym_service import GymService
from app.utils.image_sniff import sniff_image

router = APIRouter(prefix="/partner/gym/photos", tags=["partner/gym/photos"])


@router.get("", response_model=list[GymPhotoRead])
async def list_photos(
    user: Annotated[User, Depends(current_gym_owner)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
) -> list[GymPhotoRead]:
    assert user.gym_id is not None
    rows = await photos.list_by_gym_id(user.gym_id)
    return [GymPhotoRead.model_validate(p) for p in rows]


@router.post("", response_model=GymPhotoRead, status_code=201)
async def upload_photo(
    request: Request,
    user: Annotated[User, Depends(current_gym_owner)],
    svc: Annotated[GymService, Depends(gym_service)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
    file: Annotated[UploadFile, File()],
    alt_text_en: Annotated[str | None, Form(alias="altTextEn")] = None,
    alt_text_ar: Annotated[str | None, Form(alias="altTextAr")] = None,
    sort_order: Annotated[int | None, Form(alias="sortOrder")] = None,
) -> GymPhotoRead:
    assert user.gym_id is not None
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

    if sort_order is None:
        sort_order = await photos.next_sort_order(gym.id)

    gym_dir = Path(settings.media_root) / "gym_photos" / str(gym.id)
    gym_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}.{ext}"
    disk_path = gym_dir / filename
    disk_path.write_bytes(payload)

    public_url = f"{settings.media_url_prefix}/gym_photos/{gym.id}/{filename}"
    try:
        photo = await photos.create(
            gym_id=gym.id,
            url=public_url,
            sort_order=sort_order,
            alt_text_en=alt_text_en,
            alt_text_ar=alt_text_ar,
        )
    except Exception:
        disk_path.unlink(missing_ok=True)
        raise

    await audit.log(
        actor=authed_actor(request, user),
        action="gym_photo.create",
        entity_type="gym_photo",
        entity_id=photo.id,
        diff={
            "after": {
                "gym_id": str(gym.id),
                "url": photo.url,
                "sort_order": photo.sort_order,
                "alt_text_en": photo.alt_text_en,
                "alt_text_ar": photo.alt_text_ar,
                "size_bytes": len(payload),
                "content_type": content_type,
            }
        },
    )
    await session.commit()
    await realtime_publish(
        f"gym/{gym.id}/photos",
        {
            "type": "gym.photo.added",
            "gymId": str(gym.id),
            "photoId": str(photo.id),
        },
    )
    return GymPhotoRead.model_validate(photo)


@router.patch("/{photo_id}", response_model=GymPhotoRead)
async def update_photo(
    photo_id: UUID,
    body: GymPhotoUpdate,
    request: Request,
    user: Annotated[User, Depends(current_gym_owner)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymPhotoRead:
    assert user.gym_id is not None
    photo = await photos.get(photo_id)
    # Tenant guard: a partner can only edit photos that belong to
    # their gym. NOT_FOUND (not FORBIDDEN) so we don't leak whether
    # an unrelated photo id exists.
    if photo is None or photo.gym_id != user.gym_id:
        raise AppError(ErrorCode.NOT_FOUND, "Photo not found.")
    before = {
        "sort_order": photo.sort_order,
        "alt_text_en": photo.alt_text_en,
        "alt_text_ar": photo.alt_text_ar,
    }
    updates = body.model_dump(by_alias=False, exclude_unset=True)
    await photos.update(photo, **updates)
    await audit.log(
        actor=authed_actor(request, user),
        action="gym_photo.update",
        entity_type="gym_photo",
        entity_id=photo.id,
        diff={"before": before, "after": updates},
    )
    await session.commit()
    return GymPhotoRead.model_validate(photo)


@router.delete("/{photo_id}", status_code=204)
async def delete_photo(
    photo_id: UUID,
    request: Request,
    user: Annotated[User, Depends(current_gym_owner)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    assert user.gym_id is not None
    photo = await photos.get(photo_id)
    if photo is None or photo.gym_id != user.gym_id:
        raise AppError(ErrorCode.NOT_FOUND, "Photo not found.")
    stored_url = photo.url
    await photos.delete(photo)
    await audit.log(
        actor=authed_actor(request, user),
        action="gym_photo.delete",
        entity_type="gym_photo",
        entity_id=photo_id,
    )
    await session.commit()

    await realtime_publish(
        f"gym/{user.gym_id}/photos",
        {
            "type": "gym.photo.removed",
            "gymId": str(user.gym_id),
            "photoId": str(photo_id),
        },
    )

    settings = get_settings()
    prefix = settings.media_url_prefix.rstrip("/") + "/"
    if stored_url.startswith(prefix):
        rel = stored_url[len(prefix):]
        disk_path = Path(settings.media_root) / rel
        try:
            disk_path.unlink(missing_ok=True)
        except OSError:
            pass
