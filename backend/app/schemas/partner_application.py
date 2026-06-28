from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import ApplicationStatus, AudienceGender, Category


class PartnerApplicationSubmit(BaseModel):
    """Shape the public /partner-applications POST endpoint accepts.

    No `status` / `id` / `reviewed_*` fields — those are server-managed.
    The password is hashed at submit time before this schema's value
    is persisted (see `PartnerApplicationService.submit`).

    Phone format mirrors the JOR-mobile regex enforced by the auth
    endpoints — keeps the application + the eventual user row
    consistent.
    """

    owner_name: str = Field(alias="ownerName", min_length=2, max_length=128)
    owner_phone: str = Field(
        alias="ownerPhone",
        # +962 7[789] then 7 digits — Jordanian mobile.
        pattern=r"^\+962(7[789])\d{7}$",
    )
    owner_email: str | None = Field(
        alias="ownerEmail", default=None, max_length=255,
    )
    # Minimum 8, mirror the member-app rule. The schema receives
    # plaintext over TLS; the service hashes it before persisting.
    password: str = Field(min_length=8, max_length=128)

    gym_name_en: str = Field(alias="gymNameEn", min_length=1, max_length=128)
    gym_area: str = Field(alias="gymArea", min_length=1, max_length=64)
    gym_address_en: str = Field(
        alias="gymAddressEn", min_length=1, max_length=512,
    )
    gym_address_ar: str = Field(
        alias="gymAddressAr", min_length=1, max_length=512,
    )
    # Bounded to globe; the admin form is the only writer so unit
    # confusion (degrees-as-radians) is the bug to guard against.
    gym_lat: Decimal = Field(
        alias="gymLat", ge=Decimal("-90"), le=Decimal("90"),
    )
    gym_lng: Decimal = Field(
        alias="gymLng", ge=Decimal("-180"), le=Decimal("180"),
    )
    gym_category: Category = Field(alias="gymCategory")
    gym_audience_gender: AudienceGender = Field(
        alias="gymAudienceGender", default=AudienceGender.MIXED,
    )
    gym_phone: str | None = Field(
        alias="gymPhone", default=None, max_length=32,
    )
    amenities: list[str] = Field(default_factory=list, max_length=64)
    opening_hours: dict[str, Any] = Field(
        alias="openingHours", default_factory=dict,
    )
    # URLs returned by the /partner-applications/upload endpoint
    # before this form was submitted.
    logo_url: str | None = Field(alias="logoUrl", default=None)
    photo_urls: list[str] = Field(
        alias="photoUrls", default_factory=list, max_length=12,
    )

    model_config = ConfigDict(populate_by_name=True)


class PartnerApplicationRead(BaseModel):
    """Full application row as the admin sees it. Excludes
    `password_hash` — the admin never needs the hashed password, and
    omitting it from the schema prevents accidental log leakage."""

    id: UUID
    status: ApplicationStatus
    owner_name: str = Field(alias="ownerName")
    owner_phone: str = Field(alias="ownerPhone")
    owner_email: str | None = Field(alias="ownerEmail")
    gym_name_en: str = Field(alias="gymNameEn")
    gym_area: str = Field(alias="gymArea")
    gym_address_en: str = Field(alias="gymAddressEn")
    gym_address_ar: str = Field(alias="gymAddressAr")
    gym_lat: Decimal = Field(alias="gymLat")
    gym_lng: Decimal = Field(alias="gymLng")
    gym_category: Category = Field(alias="gymCategory")
    gym_audience_gender: AudienceGender = Field(alias="gymAudienceGender")
    gym_phone: str | None = Field(alias="gymPhone")
    amenities: list[str]
    opening_hours: dict[str, Any] = Field(alias="openingHours")
    logo_url: str | None = Field(alias="logoUrl")
    photo_urls: list[str] = Field(alias="photoUrls")
    admin_notes: str | None = Field(alias="adminNotes")
    reviewed_at: datetime | None = Field(alias="reviewedAt")
    approved_gym_id: UUID | None = Field(alias="approvedGymId")
    approved_owner_user_id: UUID | None = Field(alias="approvedOwnerUserId")
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")

    model_config = ConfigDict(populate_by_name=True, from_attributes=True)


class PartnerApplicationSubmitResponse(BaseModel):
    """Bare-bones response the public submit endpoint returns. We
    deliberately don't echo the full row — anyone could submit, and
    leaking back the full owner/gym fields makes scrape-detect
    harder. Just the ID + status so the partner can show the
    success screen."""

    id: UUID
    status: ApplicationStatus


class PartnerApplicationApprove(BaseModel):
    """Optional admin notes captured at approval time. The slug for
    the new gym is auto-derived from the gym name; admin can rename
    it later via the gym-edit page if needed."""

    notes: str | None = Field(default=None, max_length=2000)


class PartnerApplicationReject(BaseModel):
    notes: str = Field(min_length=1, max_length=2000)


class PartnerApplicationUploadResponse(BaseModel):
    """Returned by the public /partner-applications/upload endpoint.
    `url` is a media-prefix URL the partner pastes back into the
    submit form's `logoUrl` / `photoUrls`."""

    url: str
