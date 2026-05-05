from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import Tier


class PlanRead(BaseModel):
    id: UUID
    tier: Tier
    duration_months: int = Field(alias="durationMonths")
    price_jod: Decimal = Field(alias="priceJod")
    monthly_visits: int = Field(alias="monthlyVisits")
    included_gym_count: int = Field(alias="includedGymCount")
    features_en: list[str] = Field(alias="featuresEn")
    features_ar: list[str] = Field(alias="featuresAr")
    discount_percent: Decimal = Field(alias="discountPercent")
    is_active: bool = Field(alias="isActive")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)
