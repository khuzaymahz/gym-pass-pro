from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import SubscriptionStatus, Tier
from app.db.types import (
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    plan_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("plans.id", ondelete="RESTRICT"), nullable=False
    )
    tier: Mapped[Tier] = mapped_column(
        pg_enum_cls("tier_enum", Tier), nullable=False
    )
    status: Mapped[SubscriptionStatus] = mapped_column(
        pg_enum_cls("sub_status_enum", SubscriptionStatus),
        nullable=False,
        server_default=text("'pending'"),
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    visits_used: Mapped[int] = mapped_column(
        nullable=False, default=0, server_default="0"
    )
    # Price the member actually paid at purchase time, snapshotted from
    # `Plan.price_jod` so a later admin edit to the plan doesn't
    # retroactively rewrite history. Nullable for legacy rows from
    # before this column existed; new rows are always populated by
    # `SubscriptionRepository.create_pending`.
    purchased_price_jod: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 3), nullable=True
    )
    auto_renew: Mapped[bool] = mapped_column(
        nullable=False, default=False, server_default=text("false")
    )
    cancelled_at: Mapped[TimestampTZNullable]
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        Index(
            "uq_subscriptions_active_per_user",
            "user_id",
            unique=True,
            postgresql_where=text("status = 'active'"),
        ),
        Index("ix_subscriptions_user_status", "user_id", "status"),
        Index("ix_subscriptions_expires_at", "expires_at"),
    )
