from __future__ import annotations

from decimal import Decimal

from sqlalchemy import CheckConstraint, Numeric, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import Tier
from app.db.types import Money, TimestampTZ, TimestampTZUpdate, UUIDCol, pg_enum_cls


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[UUIDCol]
    tier: Mapped[Tier] = mapped_column(
        pg_enum_cls("tier_enum", Tier), nullable=False
    )
    duration_months: Mapped[int] = mapped_column(nullable=False)
    price_jod: Mapped[Money]
    monthly_visits: Mapped[int] = mapped_column(nullable=False)
    included_gym_count: Mapped[int] = mapped_column(nullable=False)
    features_en: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    features_ar: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    discount_percent: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, server_default=text("0")
    )
    is_active: Mapped[bool] = mapped_column(
        nullable=False, default=True, server_default=text("true")
    )
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        UniqueConstraint("tier", "duration_months", name="uq_plans_tier_duration"),
        CheckConstraint("monthly_visits > 0", name="monthly_visits_positive"),
    )
