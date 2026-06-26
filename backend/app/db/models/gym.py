from __future__ import annotations

from decimal import Decimal
from typing import Any

from sqlalchemy import Index, Numeric, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import AudienceGender, Category, Tier
from app.db.types import (
    Money,
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    pg_enum_cls,
)


class Gym(Base):
    __tablename__ = "gyms"

    id: Mapped[UUIDCol]
    slug: Mapped[str] = mapped_column(nullable=False, unique=True)
    name_en: Mapped[str] = mapped_column(nullable=False)
    name_ar: Mapped[str] = mapped_column(nullable=False)
    address_en: Mapped[str] = mapped_column(nullable=False)
    address_ar: Mapped[str] = mapped_column(nullable=False)
    area: Mapped[str] = mapped_column(nullable=False)
    lat: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    lng: Mapped[Decimal] = mapped_column(Numeric(9, 6), nullable=False)
    phone: Mapped[str | None] = mapped_column(nullable=True)
    category: Mapped[Category] = mapped_column(
        pg_enum_cls("category_enum", Category), nullable=False
    )
    required_tier: Mapped[Tier] = mapped_column(
        pg_enum_cls("tier_enum", Tier),
        nullable=False,
        server_default=text("'silver'"),
    )
    # Who the gym serves. `mixed` is the everyone-welcome default;
    # `female_only` and `male_only` are filtered server-side so members
    # don't see gyms they can't physically access, and the check-in
    # pipeline rejects mismatched scans with CHECKIN_GENDER_LOCKED.
    audience_gender: Mapped[AudienceGender] = mapped_column(
        pg_enum_cls("audience_gender_enum", AudienceGender),
        nullable=False,
        server_default=text("'mixed'"),
    )
    per_visit_rate_jod: Mapped[Money] = mapped_column(
        Numeric(10, 3), nullable=False, server_default=text("2.000")
    )
    rating: Mapped[Decimal | None] = mapped_column(Numeric(2, 1), nullable=True)
    review_count: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")
    cover_image_url: Mapped[str | None] = mapped_column(nullable=True)
    logo_url: Mapped[str | None] = mapped_column(nullable=True)
    # Optional render hints for the logo. Shape:
    #   {"fit": "cover" | "contain", "position": "top" | "center" | "bottom"}
    # NULL = use the default ({fit:"cover", position:"center"}). See
    # migration 0015 for the rationale.
    logo_alignment: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    amenities: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    opening_hours: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    is_active: Mapped[bool] = mapped_column(
        nullable=False, default=True, server_default=text("true")
    )

    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]
    deleted_at: Mapped[TimestampTZNullable]

    __table_args__ = (
        Index("ix_gyms_category_required_tier", "category", "required_tier"),
        Index(
            "ix_gyms_is_active",
            "is_active",
            postgresql_where=text("is_active = true AND deleted_at IS NULL"),
        ),
        Index("ix_gyms_area", "area"),
        Index("ix_gyms_audience_gender", "audience_gender"),
    )
