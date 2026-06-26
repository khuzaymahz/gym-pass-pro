from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import ForeignKey, Index, Numeric, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import ApplicationStatus, AudienceGender, Category
from app.db.types import (
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    pg_enum_cls,
)


class PartnerApplication(Base):
    """Pending gym-onboarding request submitted via the public partner
    /join form. Holds everything needed to spin up a real `Gym` + a
    gym-owner `User` once an admin clicks Approve.

    A pending row is invisible to members: it never reaches the
    member-facing `gyms` endpoint until the admin approval step
    creates the actual gym row. Rejected rows are retained for audit.
    """

    __tablename__ = "partner_applications"

    id: Mapped[UUIDCol]
    status: Mapped[ApplicationStatus] = mapped_column(
        pg_enum_cls("application_status_enum", ApplicationStatus),
        nullable=False,
        server_default=text("'pending'"),
    )

    # Owner identity — becomes the gym_owner User on approval.
    owner_name: Mapped[str] = mapped_column(nullable=False)
    owner_phone: Mapped[str] = mapped_column(nullable=False)
    owner_email: Mapped[str | None] = mapped_column(nullable=True)
    # Bcrypt hash of the password the partner typed during the form.
    # Copied verbatim into users.password_hash on approval; never
    # leaves this table in plaintext.
    password_hash: Mapped[str] = mapped_column(nullable=False)

    # Gym identity — becomes the Gym row on approval.
    gym_name_en: Mapped[str] = mapped_column(nullable=False)
    gym_name_ar: Mapped[str] = mapped_column(nullable=False)
    gym_area: Mapped[str] = mapped_column(nullable=False)
    gym_address_en: Mapped[str] = mapped_column(nullable=False)
    gym_address_ar: Mapped[str] = mapped_column(nullable=False)
    gym_lat: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    gym_lng: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    gym_category: Mapped[Category] = mapped_column(
        pg_enum_cls("category_enum", Category), nullable=False
    )
    gym_audience_gender: Mapped[AudienceGender] = mapped_column(
        pg_enum_cls("audience_gender_enum", AudienceGender),
        nullable=False,
        server_default=text("'mixed'"),
    )
    gym_phone: Mapped[str | None] = mapped_column(nullable=True)
    amenities: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    opening_hours: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )

    # Media — public URLs (relative to media_url_prefix) of files
    # uploaded via /partner-applications/upload BEFORE this row was
    # submitted. The upload endpoint deposits files under
    # `media_root/applications/<random-uuid>/...`; on approval the
    # service copies them into `media_root/gym_photos/<gym-id>/...`
    # so future partner uploads land in the same dir.
    logo_url: Mapped[str | None] = mapped_column(nullable=True)
    photo_urls: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )

    # Admin review trail.
    admin_notes: Mapped[str | None] = mapped_column(nullable=True)
    # `TimestampTZNullable` maps to `DateTime(timezone=True)` and the
    # DB column was created `timestamptz` in migration 0017. Without
    # the typed annotation, SQLAlchemy inferred a naive `DateTime`
    # and silently dropped the offset on every read/write.
    reviewed_at: Mapped[TimestampTZNullable]
    reviewed_by_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # Approval back-refs.
    approved_gym_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("gyms.id", ondelete="SET NULL"), nullable=True
    )
    approved_owner_user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    submitted_from_ip: Mapped[str | None] = mapped_column(nullable=True)

    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]
    # No soft-delete column — the `rejected` status serves the same
    # purpose (row retained for audit, no real gym/user spawned).

    __table_args__ = (
        # Status filter for the admin review queue (created in migration 0017;
        # declared here so the model is the full source of truth).
        Index("ix_partner_applications_status", "status"),
        # Supporting indexes for the three FK columns so SET NULL on a
        # deleted user/gym doesn't seq-scan this table (see migration 0024).
        Index("ix_partner_applications_reviewed_by", "reviewed_by_user_id"),
        Index("ix_partner_applications_approved_gym", "approved_gym_id"),
        Index("ix_partner_applications_approved_owner", "approved_owner_user_id"),
    )
