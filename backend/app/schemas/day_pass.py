from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import AudienceGender, DayPassStatus, PaymentMethod


# ---------------------------------------------------------------------
# Offering (per-gym configuration)
# ---------------------------------------------------------------------


class DayPassOfferingRead(BaseModel):
    """Per-gym configuration row.

    Surfaced to:
      * Partners on the gym-profile editor (the canonical edit
        surface).
      * Members on the public gym page (`isEnabled` + `priceJod` are
        the only fields they see — everything else is operator
        detail).
      * Admin for read-only oversight.
    """

    id: UUID
    gym_id: UUID = Field(alias="gymId")
    is_enabled: bool = Field(alias="isEnabled")
    price_jod: Decimal = Field(alias="priceJod")
    platform_fee_pct: Decimal = Field(alias="platformFeePct")
    validity_hours: int = Field(alias="validityHours")
    daily_cap: int | None = Field(alias="dailyCap", default=None)
    audience_gender_override: AudienceGender | None = Field(
        alias="audienceGenderOverride", default=None
    )
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class DayPassOfferingPublic(BaseModel):
    """Trimmed view of an offering for the public gym page.

    Members don't need the platform-fee or audit columns — only
    whether the gym sells day passes, at what price, and for how
    long. Returned by `GET /api/v1/gyms/{slug}/day-pass-offering`.
    """

    is_enabled: bool = Field(alias="isEnabled")
    price_jod: Decimal = Field(alias="priceJod")
    validity_hours: int = Field(alias="validityHours")

    model_config = ConfigDict(populate_by_name=True)


class DayPassOfferingUpsert(BaseModel):
    """Partner-facing PUT body for the offering.

    PUT (not PATCH): the entire offering is sent every save, so the
    partner can flip `isEnabled` and adjust the price in one round
    trip without the server having to merge partial state.

    Operator-only fields (`platformFeePct`, `dailyCap`,
    `audienceGenderOverride`) are accepted from partners as
    advisory inputs but the service strips/clamps them — admin owns
    those.
    """

    is_enabled: bool = Field(alias="isEnabled")
    price_jod: Decimal = Field(alias="priceJod", ge=0)
    daily_cap: int | None = Field(alias="dailyCap", default=None, gt=0)
    audience_gender_override: AudienceGender | None = Field(
        alias="audienceGenderOverride", default=None
    )

    model_config = ConfigDict(populate_by_name=True)


# ---------------------------------------------------------------------
# Purchase (member buying a pass)
# ---------------------------------------------------------------------


class DayPassPurchase(BaseModel):
    """Member-facing POST body for buying a pass.

    `gymSlug` is the lookup key (same as the rest of the public gym
    surface) — the service resolves it to the offering, snapshots
    the price, and fires the charge. `paymentMethodId` is optional
    in dev (the mock provider doesn't require one), required in
    real production once a gateway lands.
    """

    gym_slug: str = Field(alias="gymSlug")
    payment_method: PaymentMethod = Field(
        alias="paymentMethod", default=PaymentMethod.MOCK
    )
    payment_method_id: UUID | None = Field(
        alias="paymentMethodId", default=None
    )

    model_config = ConfigDict(populate_by_name=True)


class DayPassRead(BaseModel):
    """Persisted day-pass instance, returned on purchase + list."""

    id: UUID
    gym_id: UUID = Field(alias="gymId")
    gym_slug: str = Field(alias="gymSlug")
    gym_name_en: str = Field(alias="gymNameEn")
    status: DayPassStatus
    price_jod: Decimal = Field(alias="priceJod")
    purchased_at: datetime = Field(alias="purchasedAt")
    expires_at: datetime = Field(alias="expiresAt")
    used_at: datetime | None = Field(alias="usedAt", default=None)

    model_config = ConfigDict(populate_by_name=True)


class DayPassListResponse(BaseModel):
    """List of day-passes the caller currently has. Active first."""

    items: list[DayPassRead]

    model_config = ConfigDict(populate_by_name=True)
