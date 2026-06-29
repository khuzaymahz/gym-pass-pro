from __future__ import annotations

from pathlib import Path
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    Header,
    Query,
    Request,
    UploadFile,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_partner_service,
    audit_service,
    authed_actor,
    current_admin,
    current_admin_super,
    db_session,
    gym_photo_repo,
    gym_service,
)
from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.db.enums import AudienceGender
from app.db.models import User
from app.realtime import publish as realtime_publish
from app.repositories.gym_photo_repo import GymPhotoRepository
from app.schemas.common import Page
from app.schemas.gym import (
    GymCreate,
    GymRead,
    GymUpdate,
    GymWithOwnerCreate,
    GymWithOwnerResult,
)
from app.schemas.gym_photo import GymPhotoRead, GymPhotoUpdate
from app.schemas.partner import PartnerOwnerRead
from app.services.admin_partner_service import AdminPartnerService
from app.services.audit_service import AuditService
from app.services.gym_service import GymService
from app.utils.image_sniff import sniff_image

router = APIRouter(prefix="/admin/gyms", tags=["admin/gyms"])


@router.get("", response_model=Page[GymRead])
async def list_all(
    svc: Annotated[GymService, Depends(gym_service)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    _: Annotated[User, Depends(current_admin)],
    audience: AudienceGender | None = Query(default=None),
    category: str | None = Query(default=None),
    tier: str | None = Query(default=None),
    q: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[GymRead]:
    # Admin sees ALL gyms by default. All four filters (audience,
    # category, tier, q) are optional and combine with AND. Pushing
    # these to the backend replaces the earlier admin-side approach
    # of fetching 100 rows and filtering in JS — that capped real
    # results at 100 silently, and made every page render do server-
    # paginated work twice (once for the load, once for the filter).
    rows, total = await svc.list_unfiltered(
        area=None,
        category=category,
        tier=tier,
        q=q,
        audience=audience,
        page=page,
        page_size=page_size,
    )
    counts = await photos.count_by_gym_ids([r.id for r in rows])
    items = []
    for r in rows:
        gym = GymRead.model_validate(r)
        gym.photo_count = counts.get(r.id, 0)
        items.append(gym)
    return Page[GymRead](
        items=items,
        total=total,
        page=page,
        pageSize=page_size,
    )


@router.post("", response_model=GymRead, status_code=201)
async def create(
    body: GymCreate,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymRead:
    gym = await svc.create(body, actor=authed_actor(request, admin))
    await session.commit()
    return GymRead.model_validate(gym)


@router.post("/with-owner", response_model=GymWithOwnerResult, status_code=201)
async def create_with_owner(
    body: GymWithOwnerCreate,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    partners: Annotated[AdminPartnerService, Depends(admin_partner_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymWithOwnerResult:
    """Create a gym and (optionally) its owner in ONE transaction.

    Atomic: if the owner step fails, the gym rolls back with it — the admin
    never ends up with an orphan gym that has no login (the partial-failure
    bug that motivated this endpoint). `owner.mode`:
      - `new`  → mint a fresh partner login (needs name + password),
      - `link` → attach an existing partner by phone (multi-branch).
    With no `owner`, this behaves like plain create.
    """
    actor = authed_actor(request, admin)
    gym = await svc.create(body.gym, actor=actor)

    owner_payload: dict | None = None
    if body.owner is not None:
        if body.owner.mode == "new":
            if not body.owner.name or not body.owner.password:
                raise AppError(
                    ErrorCode.VALIDATION_ERROR,
                    "A new owner login needs a name and password.",
                    details={"field": "owner"},
                )
            _, owner_payload = await partners.create_owner(
                gym_id=gym.id,
                phone=body.owner.phone,
                password=body.owner.password,
                name=body.owner.name,
                actor=actor,
            )
        else:  # link an existing partner to this branch
            owner_payload = await partners.link_owner(
                gym_id=gym.id, phone=body.owner.phone, actor=actor
            )

    # Single commit — gym + owner land together or not at all.
    await session.commit()
    return GymWithOwnerResult(
        gym=GymRead.model_validate(gym),
        owner=PartnerOwnerRead(**owner_payload) if owner_payload else None,
    )


@router.get("/{gym_id}", response_model=GymRead)
async def get(
    gym_id: UUID,
    svc: Annotated[GymService, Depends(gym_service)],
    _: Annotated[User, Depends(current_admin)],
) -> GymRead:
    gym = await svc.get(gym_id)
    return GymRead.model_validate(gym)


@router.patch("/{gym_id}", response_model=GymRead)
async def update(
    gym_id: UUID,
    body: GymUpdate,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymRead:
    gym = await svc.update(gym_id, body, actor=authed_actor(request, admin))
    await session.commit()
    # Mirror the partner/profile.py publish so members on the gym
    # detail page (or the explore list) re-fetch immediately when an
    # admin edits the gym record.
    await realtime_publish(
        f"gym/{gym.id}",
        {"type": "gym.updated", "gymId": str(gym.id), "slug": gym.slug},
    )
    return GymRead.model_validate(gym)


@router.delete("/{gym_id}", status_code=204)
async def delete(
    gym_id: UUID,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    admin: Annotated[User, Depends(current_admin_super)],
    session: Annotated[AsyncSession, Depends(db_session)],
    confirm_slug: Annotated[str | None, Header(alias="X-Confirm-Gym-Slug")] = None,
) -> None:
    """Soft-delete a gym. Super-admin only.

    The caller must echo the gym's slug in `X-Confirm-Gym-Slug` —
    matches the typed-name confirmation pattern git uses for `branch -D`
    and Stripe uses for live-resource deletion. Gates against a stray
    UUID in a copy-pasted URL nuking the wrong row.

    The gym is soft-deleted regardless of historical activity (a hard
    delete would cascade through `checkins`, `payout_ledger`, and the
    audit trail — financial history we never want to lose). The
    audit-log entry records the success-checkin count at delete time
    so an accidental delete is easy to spot in the queue.
    """
    await svc.delete(
        gym_id,
        actor=authed_actor(request, admin),
        confirm_slug=confirm_slug,
    )
    await session.commit()


@router.post("/{gym_id}/logo", response_model=GymRead)
async def upload_logo(
    gym_id: UUID,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
    file: Annotated[UploadFile, File()],
) -> GymRead:
    gym = await svc.get(gym_id)
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
        raise AppError(ErrorCode.VALIDATION_ERROR, "Empty file.", details={"field": "file"})

    sniffed = sniff_image(payload)
    if sniffed is None:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Unsupported image type. Use JPEG, PNG, or WebP.",
            details={"field": "file", "contentType": file.content_type},
        )
    content_type, ext = sniffed

    logo_dir = Path(settings.media_root) / "gym_logos" / str(gym_id)
    logo_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}.{ext}"
    disk_path = logo_dir / filename
    disk_path.write_bytes(payload)

    public_url = f"{settings.media_url_prefix}/gym_logos/{gym_id}/{filename}"
    prefix = settings.media_url_prefix.rstrip("/") + "/"
    previous_url = gym.logo_url

    gym.logo_url = public_url
    await session.flush()

    await audit.log(
        actor=authed_actor(request, admin),
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

    # Clean up the previous locally-stored logo only after the new one is
    # committed — if the write fails, the old file is still referenced.
    if previous_url and previous_url.startswith(prefix):
        old = Path(settings.media_root) / previous_url[len(prefix) :]
        try:
            old.unlink(missing_ok=True)
        except OSError:
            pass

    return GymRead.model_validate(gym)


@router.delete("/{gym_id}/logo", response_model=GymRead)
async def delete_logo(
    gym_id: UUID,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymRead:
    gym = await svc.get(gym_id)
    settings = get_settings()
    previous_url = gym.logo_url
    if previous_url is None:
        return GymRead.model_validate(gym)

    gym.logo_url = None
    await session.flush()

    await audit.log(
        actor=authed_actor(request, admin),
        action="gym.logo.clear",
        entity_type="gym",
        entity_id=gym.id,
        diff={"before": {"logo_url": previous_url}, "after": {"logo_url": None}},
    )
    await session.commit()

    prefix = settings.media_url_prefix.rstrip("/") + "/"
    if previous_url.startswith(prefix):
        old = Path(settings.media_root) / previous_url[len(prefix) :]
        try:
            old.unlink(missing_ok=True)
        except OSError:
            pass

    return GymRead.model_validate(gym)


@router.get("/{gym_id}/photos", response_model=list[GymPhotoRead])
async def list_photos(
    gym_id: UUID,
    svc: Annotated[GymService, Depends(gym_service)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    _: Annotated[User, Depends(current_admin)],
) -> list[GymPhotoRead]:
    await svc.get(gym_id)
    rows = await photos.list_by_gym_id(gym_id)
    return [GymPhotoRead.model_validate(p) for p in rows]


@router.post("/{gym_id}/photos", response_model=GymPhotoRead, status_code=201)
async def upload_photo(
    gym_id: UUID,
    request: Request,
    svc: Annotated[GymService, Depends(gym_service)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
    file: Annotated[UploadFile, File()],
    alt_text_en: Annotated[str | None, Form(alias="altTextEn")] = None,
    alt_text_ar: Annotated[str | None, Form(alias="altTextAr")] = None,
    sort_order: Annotated[int | None, Form(alias="sortOrder")] = None,
) -> GymPhotoRead:
    await svc.get(gym_id)
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
            ErrorCode.VALIDATION_ERROR,
            "Empty file.",
            details={"field": "file"},
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
        sort_order = await photos.next_sort_order(gym_id)

    gym_dir = Path(settings.media_root) / "gym_photos" / str(gym_id)
    gym_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}.{ext}"
    disk_path = gym_dir / filename
    disk_path.write_bytes(payload)

    public_url = f"{settings.media_url_prefix}/gym_photos/{gym_id}/{filename}"

    try:
        photo = await photos.create(
            gym_id=gym_id,
            url=public_url,
            sort_order=sort_order,
            alt_text_en=alt_text_en,
            alt_text_ar=alt_text_ar,
        )
    except Exception:
        disk_path.unlink(missing_ok=True)
        raise

    await audit.log(
        actor=authed_actor(request, admin),
        action="gym_photo.create",
        entity_type="gym_photo",
        entity_id=photo.id,
        diff={
            "after": {
                "gym_id": str(gym_id),
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
    return GymPhotoRead.model_validate(photo)


@router.patch("/{gym_id}/photos/{photo_id}", response_model=GymPhotoRead)
async def update_photo(
    gym_id: UUID,
    photo_id: UUID,
    body: GymPhotoUpdate,
    request: Request,
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> GymPhotoRead:
    photo = await photos.get(photo_id)
    if photo is None or photo.gym_id != gym_id:
        raise AppError(ErrorCode.NOT_FOUND, "Photo not found.")
    before = {
        "sort_order": photo.sort_order,
        "alt_text_en": photo.alt_text_en,
        "alt_text_ar": photo.alt_text_ar,
    }
    updates = body.model_dump(by_alias=False, exclude_unset=True)
    await photos.update(photo, **updates)
    await audit.log(
        actor=authed_actor(request, admin),
        action="gym_photo.update",
        entity_type="gym_photo",
        entity_id=photo.id,
        diff={"before": before, "after": updates},
    )
    await session.commit()
    return GymPhotoRead.model_validate(photo)


@router.delete("/{gym_id}/photos/{photo_id}", status_code=204)
async def delete_photo(
    gym_id: UUID,
    photo_id: UUID,
    request: Request,
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    photo = await photos.get(photo_id)
    if photo is None or photo.gym_id != gym_id:
        raise AppError(ErrorCode.NOT_FOUND, "Photo not found.")
    stored_url = photo.url
    await photos.delete(photo)
    await audit.log(
        actor=authed_actor(request, admin),
        action="gym_photo.delete",
        entity_type="gym_photo",
        entity_id=photo_id,
    )
    await session.commit()

    # Best-effort disk cleanup: only for locally-stored files. URLs that point
    # elsewhere (e.g. legacy Unsplash seed data) are left alone.
    settings = get_settings()
    prefix = settings.media_url_prefix.rstrip("/") + "/"
    if stored_url.startswith(prefix):
        rel = stored_url[len(prefix) :]
        disk_path = Path(settings.media_root) / rel
        try:
            disk_path.unlink(missing_ok=True)
        except OSError:
            pass
