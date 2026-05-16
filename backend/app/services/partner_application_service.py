from __future__ import annotations

import re
import shutil
from decimal import Decimal
from pathlib import Path
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.exceptions import AppError, ErrorCode
from app.core.security import hash_password
from app.db.enums import ApplicationStatus, Locale, Role
from app.db.models import Gym, GymPhoto, PartnerApplication, User
from app.repositories.gym_repo import GymRepository
from app.repositories.partner_application_repo import PartnerApplicationRepository
from app.repositories.user_repo import UserRepository
from app.schemas.partner_application import PartnerApplicationSubmit
from app.services.audit_service import Actor, AuditService
from app.utils.ids import uuid7
from app.utils.time import utcnow


def _slugify(name: str) -> str:
    """ASCII slug for the gym row. Lowercase, hyphenated, alnum-only.
    Falls back to `gym-<random>` when the input has no Latin
    characters (Arabic-only names produce an empty slug otherwise)."""

    s = re.sub(r"[^a-z0-9]+", "-", name.lower().strip()).strip("-")
    if not s or len(s) < 2:
        return f"gym-{uuid4().hex[:8]}"
    return s[:48]


class PartnerApplicationService:
    """Owns the lifecycle of a partner-onboarding request:

    * `submit` — public path: hashes the password, dedups by phone,
      writes a pending row.
    * `approve` — admin path: atomically creates a `Gym` + a
      gym-owner `User` from the row, copies media into the gym's
      photo dir, links back via FKs. Idempotent on a second call
      (returns the previously-approved gym/user).
    * `reject` — admin path: marks the row with notes, no gym/user.

    All mutations write an `audit_log` entry in the same transaction.
    """

    def __init__(
        self,
        repo: PartnerApplicationRepository,
        gyms: GymRepository,
        users: UserRepository,
        audit: AuditService,
        session: AsyncSession,
    ) -> None:
        self.repo = repo
        self.gyms = gyms
        self.users = users
        self.audit = audit
        self.session = session

    async def submit(
        self,
        payload: PartnerApplicationSubmit,
        *,
        actor: Actor,
    ) -> PartnerApplication:
        # Reject if the phone already belongs to a real user — the
        # auth model is "one user per phone", and silently creating a
        # pending app for an existing phone would mean approval blows
        # up at the User.create step. Surface it now.
        existing = await self.users.get_by_phone(payload.owner_phone)
        if existing is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "This phone is already registered. Sign in instead.",
                details={"field": "ownerPhone"},
            )

        app = await self.repo.create(
            status=ApplicationStatus.PENDING,
            owner_name=payload.owner_name,
            owner_phone=payload.owner_phone,
            owner_email=payload.owner_email,
            password_hash=hash_password(payload.password),
            gym_name_en=payload.gym_name_en,
            gym_name_ar=payload.gym_name_ar,
            gym_area=payload.gym_area,
            gym_address_en=payload.gym_address_en,
            gym_address_ar=payload.gym_address_ar,
            gym_lat=payload.gym_lat,
            gym_lng=payload.gym_lng,
            gym_category=payload.gym_category,
            gym_audience_gender=payload.gym_audience_gender,
            gym_phone=payload.gym_phone,
            amenities=payload.amenities,
            opening_hours=payload.opening_hours,
            logo_url=payload.logo_url,
            photo_urls=payload.photo_urls,
            submitted_from_ip=actor.ip_address,
        )
        await self.audit.log(
            actor=actor,
            action="partner_application.submit",
            entity_type="partner_application",
            entity_id=app.id,
            diff={
                "after": {
                    "owner_phone": payload.owner_phone,
                    "gym_name_en": payload.gym_name_en,
                    "gym_area": payload.gym_area,
                }
            },
        )
        return app

    async def get(self, app_id: UUID) -> PartnerApplication:
        app = await self.repo.get(app_id)
        if app is None:
            raise AppError(
                ErrorCode.NOT_FOUND, "Application not found."
            )
        return app

    async def list(
        self,
        *,
        status: ApplicationStatus | None,
        page: int,
        page_size: int,
    ) -> tuple[list[PartnerApplication], int]:
        return await self.repo.list_with_status(
            status=status, page=page, page_size=page_size,
        )

    async def count_pending(self) -> int:
        return await self.repo.count_pending()

    async def _unique_slug(self, base: str) -> str:
        """Find an unused gym slug starting from `base`. Tries the
        bare slug first, then `-2`, `-3`, ... up to a sane cap."""

        candidate = base
        for suffix in [None, *range(2, 50)]:
            tried = candidate if suffix is None else f"{base}-{suffix}"
            existing = await self.gyms.get_by_slug(tried)
            if existing is None:
                return tried
        return f"{base}-{uuid4().hex[:6]}"

    async def approve(
        self,
        app_id: UUID,
        *,
        notes: str | None,
        actor: Actor,
        admin_user_id: UUID,
    ) -> PartnerApplication:
        app = await self.get(app_id)
        if app.status == ApplicationStatus.APPROVED:
            # Idempotent: a double-click on the approve button should
            # NOT create a second gym. Return the existing record.
            return app
        if app.status == ApplicationStatus.REJECTED:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Application was already rejected.",
            )

        # Re-check phone uniqueness — a real user might have
        # registered in the time between submit and approve. Surface
        # to the admin instead of crashing on the user-insert step.
        existing_owner = await self.users.get_by_phone(app.owner_phone)
        if existing_owner is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "A user with this phone already exists. Reject this "
                "application and contact the partner directly.",
                details={"field": "ownerPhone"},
            )

        slug = await self._unique_slug(_slugify(app.gym_name_en))

        settings = get_settings()
        # Create the gym first so we have its UUID for the media dir
        # layout. The gym is created `is_active=True` so it goes live
        # in the member app immediately on approval — matches the
        # product expectation ("after approve he will be live").
        gym = Gym(
            id=uuid7(),
            slug=slug,
            name_en=app.gym_name_en,
            name_ar=app.gym_name_ar,
            address_en=app.gym_address_en,
            address_ar=app.gym_address_ar,
            area=app.gym_area,
            lat=app.gym_lat,
            lng=app.gym_lng,
            phone=app.gym_phone,
            category=app.gym_category,
            audience_gender=app.gym_audience_gender,
            per_visit_rate_jod=Decimal("2.00"),
            amenities=app.amenities or [],
            opening_hours=app.opening_hours or {},
        )
        self.session.add(gym)
        await self.session.flush()

        # Move media files from the application's staging dir into
        # the gym's permanent dir, and create gym_photo rows.
        media_root = Path(settings.media_root)
        app_dir = media_root / "applications" / str(app.id)
        gym_dir = media_root / "gym_photos" / str(gym.id)
        gym_dir.mkdir(parents=True, exist_ok=True)
        app_url_prefix = (
            f"{settings.media_url_prefix.rstrip('/')}/applications/{app.id}/"
        )
        gym_url_prefix = (
            f"{settings.media_url_prefix.rstrip('/')}/gym_photos/{gym.id}/"
        )

        def _move_one(src_url: str) -> str | None:
            """Move a single staged file into the gym dir. Returns
            the new media-prefix URL, or None if the source file
            couldn't be located (admin may have edited the row
            in adminer; we don't crash, just skip)."""

            if not src_url.startswith(app_url_prefix):
                return None
            filename = src_url[len(app_url_prefix):]
            src = app_dir / filename
            if not src.exists():
                return None
            dst = gym_dir / filename
            shutil.move(str(src), str(dst))
            return f"{gym_url_prefix}{filename}"

        new_logo_url = (
            _move_one(app.logo_url) if app.logo_url else None
        ) or app.logo_url
        if new_logo_url is not None:
            gym.logo_url = new_logo_url

        for order, photo_url in enumerate(app.photo_urls or []):
            new_url = _move_one(photo_url) or photo_url
            self.session.add(
                GymPhoto(
                    id=uuid7(),
                    gym_id=gym.id,
                    url=new_url,
                    sort_order=order,
                )
            )

        # Tidy up the now-empty application dir. Best-effort: if it
        # still has files (admin uploaded extras directly), leave it.
        try:
            if app_dir.exists():
                app_dir.rmdir()
        except OSError:
            pass

        # Create the gym-owner user with the password hash captured
        # at submit time. The partner can log in immediately with
        # the credentials they chose during the application.
        owner = User(
            id=uuid7(),
            phone=app.owner_phone,
            email=app.owner_email,
            name=app.owner_name,
            password_hash=app.password_hash,
            role=Role.GYM_OWNER,
            gym_id=gym.id,
            locale=Locale.AR,
        )
        self.session.add(owner)
        await self.session.flush()

        # Mark the application as approved with FK back-refs.
        app.status = ApplicationStatus.APPROVED
        app.admin_notes = notes
        app.reviewed_at = utcnow()
        app.reviewed_by_user_id = admin_user_id
        app.approved_gym_id = gym.id
        app.approved_owner_user_id = owner.id

        await self.audit.log(
            actor=actor,
            action="partner_application.approve",
            entity_type="partner_application",
            entity_id=app.id,
            diff={
                "after": {
                    "approved_gym_id": str(gym.id),
                    "approved_owner_user_id": str(owner.id),
                    "gym_slug": slug,
                    "notes": notes,
                }
            },
        )
        return app

    async def reject(
        self,
        app_id: UUID,
        *,
        notes: str,
        actor: Actor,
        admin_user_id: UUID,
    ) -> PartnerApplication:
        app = await self.get(app_id)
        if app.status != ApplicationStatus.PENDING:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                f"Application is already {app.status.value}.",
            )
        app.status = ApplicationStatus.REJECTED
        app.admin_notes = notes
        app.reviewed_at = utcnow()
        app.reviewed_by_user_id = admin_user_id

        await self.audit.log(
            actor=actor,
            action="partner_application.reject",
            entity_type="partner_application",
            entity_id=app.id,
            diff={"after": {"notes": notes}},
        )
        return app
