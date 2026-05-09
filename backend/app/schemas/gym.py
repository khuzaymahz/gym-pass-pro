from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import Category, Tier


class GymBase(BaseModel):
    slug: str = Field(min_length=2, max_length=64, pattern=r"^[a-z0-9-]+$")
    name_en: str = Field(alias="nameEn", min_length=1, max_length=128)
    name_ar: str = Field(alias="nameAr", min_length=1, max_length=128)
    address_en: str = Field(alias="addressEn", max_length=512)
    address_ar: str = Field(alias="addressAr", max_length=512)
    area: str = Field(min_length=1, max_length=64)
    # Jordan covers approx 29.18°N–33.40°N and 34.95°E–39.30°E. We
    # accept the standard global lat/lng range here (the admin form
    # is the only writer) but bound them so a typo or unit confusion
    # — sending degrees as radians, swapping fields — is rejected at
    # the schema layer instead of producing a gym that plots in the
    # ocean. The mobile map clamps to a Jordan-only bounding box at
    # the camera level; this is the schema-side complement.
    lat: Decimal = Field(ge=Decimal("-90"), le=Decimal("90"))
    lng: Decimal = Field(ge=Decimal("-180"), le=Decimal("180"))
    # 32 chars is enough for any plausible international format and
    # matches the bound on `GymUpdate.phone` so the create and update
    # paths agree on what's a valid value.
    phone: str | None = Field(default=None, max_length=32)
    category: Category
    required_tier: Tier = Field(alias="requiredTier", default=Tier.SILVER)
    # Per-visit payout to the gym in JOD. Negative makes no sense
    # (we'd be charging the gym), and a stray very-large number
    # would silently bleed the payout ledger; cap at 100 JOD which
    # is well above any realistic single-visit value.
    per_visit_rate_jod: Decimal = Field(
        alias="perVisitRateJod",
        default=Decimal("2.00"),
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    amenities: list[str] = Field(default_factory=list)
    opening_hours: dict[str, Any] = Field(alias="openingHours", default_factory=dict)
    cover_image_url: str | None = Field(alias="coverImageUrl", default=None)
    logo_url: str | None = Field(alias="logoUrl", default=None)

    model_config = ConfigDict(populate_by_name=True, from_attributes=True)


class GymCreate(GymBase):
    pass


class GymUpdate(BaseModel):
    # Length bounds mirror `GymBase` so a partner-driven update can't
    # bypass what the admin-create path enforces. Without these, the
    # partner profile form accepts arbitrary-length input and the only
    # backstop is whatever the DB column happens to be.
    name_en: str | None = Field(
        alias="nameEn", default=None, min_length=1, max_length=128,
    )
    name_ar: str | None = Field(
        alias="nameAr", default=None, min_length=1, max_length=128,
    )
    address_en: str | None = Field(alias="addressEn", default=None, max_length=512)
    address_ar: str | None = Field(alias="addressAr", default=None, max_length=512)
    area: str | None = Field(default=None, min_length=1, max_length=64)
    lat: Decimal | None = Field(default=None, ge=Decimal("-90"), le=Decimal("90"))
    lng: Decimal | None = Field(default=None, ge=Decimal("-180"), le=Decimal("180"))
    phone: str | None = Field(default=None, max_length=32)
    category: Category | None = None
    required_tier: Tier | None = Field(alias="requiredTier", default=None)
    per_visit_rate_jod: Decimal | None = Field(
        alias="perVisitRateJod",
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    # Cap amenities so a hostile or buggy client can't ship megabytes
    # of strings into a single update.
    amenities: list[str] | None = Field(default=None, max_length=64)
    opening_hours: dict[str, Any] | None = Field(alias="openingHours", default=None)
    cover_image_url: str | None = Field(alias="coverImageUrl", default=None)
    logo_url: str | None = Field(alias="logoUrl", default=None)
    is_active: bool | None = Field(alias="isActive", default=None)

    model_config = ConfigDict(populate_by_name=True)


class GymRead(GymBase):
    id: UUID
    rating: Decimal | None = None
    review_count: int = Field(alias="reviewCount", default=0)
    photo_count: int = Field(alias="photoCount", default=0)
    is_active: bool = Field(alias="isActive", default=True)


class GymListFilters(BaseModel):
    area: str | None = None
    category: Category | None = None
    tier: Tier | None = None
    q: str | None = None
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, alias="pageSize", ge=1, le=100)

    model_config = ConfigDict(populate_by_name=True)
