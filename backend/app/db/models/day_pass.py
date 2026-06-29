from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import AudienceGender, DayPassStatus
from app.db.types import (
    Money,
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class DayPassOffering(Base):
    """Per-gym configuration row for the day-pass flow.

    One offering per gym (enforced by `uq_day_pass_offerings_gym`).
    When `is_enabled` is false the gym is hidden from the public
    "buy a day pass" surface; existing passes for that gym continue
    to honor their `expires_at`.

    The `platform_fee_pct` and `validity_hours` live on the offering
    (not on a global config) so admin can negotiate per-partner
    deals without a code change. Per-purchase the values are
    snapshotted into the `DayPass` row, so a future change here
    doesn't rewrite history.
    """

    __tablename__ = "day_pass_offerings"

    id: Mapped[UUIDCol]
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="RESTRICT"), nullable=False
    )
    is_enabled: Mapped[bool] = mapped_column(
        nullable=False, default=False, server_default=text("false")
    )
    price_jod: Mapped[Money]
    platform_fee_pct: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, server_default=text("10.00")
    )
    validity_hours: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("24"))
    daily_cap: Mapped[int | None] = mapped_column(Integer, nullable=True)
    audience_gender_override: Mapped[AudienceGender | None] = mapped_column(
        pg_enum_cls("audience_gender_enum", AudienceGender), nullable=True
    )
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        Index("uq_day_pass_offerings_gym", "gym_id", unique=True),
        CheckConstraint("price_jod >= 0", name="ck_day_pass_offerings_price_nonneg"),
        CheckConstraint(
            # Strict `< 100` (not `<= 100`) so a 100% fee — which
            # would silently zero out the gym's payout per
            # redemption — can never be saved. Tightened in
            # migration 0020 after the audit caught the gap.
            "platform_fee_pct >= 0 AND platform_fee_pct < 100",
            name="ck_day_pass_offerings_fee_pct_range",
        ),
        CheckConstraint(
            "validity_hours > 0 AND validity_hours <= 168",
            name="ck_day_pass_offerings_validity_range",
        ),
        CheckConstraint(
            "daily_cap IS NULL OR daily_cap > 0",
            name="ck_day_pass_offerings_daily_cap_positive",
        ),
    )


class DayPass(Base):
    """A single purchased pass entitling its holder to one check-in
    at a specific gym within a fixed validity window.

    Lifecycle: pending -> active -> (used | expired | refunded).
    See :class:`app.db.enums.DayPassStatus` for the exact semantics.

    The price / platform_fee / net amounts are a denormalized
    snapshot of the offering at purchase time. Future offering
    changes must NOT mutate these — both payouts and audit-trail
    readers depend on the row reflecting the actual money flow.
    """

    __tablename__ = "day_passes"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="RESTRICT"), nullable=False
    )
    offering_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("day_pass_offerings.id", ondelete="RESTRICT"), nullable=False
    )
    # Nullable: the row is created PENDING before the payment row
    # exists; the service flips this FK + status atomically on
    # payment success.
    payment_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("payments.id", ondelete="RESTRICT"), nullable=True
    )
    price_jod: Mapped[Money]
    platform_fee_jod: Mapped[Money]
    net_amount_jod: Mapped[Money]
    status: Mapped[DayPassStatus] = mapped_column(
        pg_enum_cls("day_pass_status_enum", DayPassStatus),
        nullable=False,
        server_default=text("'pending'"),
    )
    purchased_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=text("now()"),
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[TimestampTZNullable]
    checkin_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("checkins.id", ondelete="RESTRICT"), nullable=True
    )
    refunded_at: Mapped[TimestampTZNullable]
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        Index("ix_day_passes_user_status", "user_id", "status"),
        Index("ix_day_passes_payment_id", "payment_id"),
        Index("ix_day_passes_checkin_id", "checkin_id"),
        # At most one ACTIVE pass per (user, gym) — declared here so the
        # model matches the DB (created as raw DDL in migration
        # 0025_day_pass_unique_active_per_user_gym) and `alembic check`
        # stays a clean CI gate.
        Index(
            "uq_day_passes_one_active_per_user_gym",
            "user_id",
            "gym_id",
            unique=True,
            postgresql_where=text("status = 'active'"),
        ),
        Index(
            "ix_day_passes_active_lookup",
            "user_id",
            "gym_id",
            "expires_at",
            postgresql_where=text("status = 'active'"),
        ),
        Index(
            "ix_day_passes_expires_at",
            "expires_at",
            postgresql_where=text("status = 'active'"),
        ),
        Index(
            "ix_day_passes_offering_purchased",
            "offering_id",
            "purchased_at",
            postgresql_where=text("status IN ('active','used','expired')"),
        ),
        CheckConstraint(
            "expires_at > purchased_at",
            name="ck_day_passes_expires_after_purchase",
        ),
        CheckConstraint(
            "price_jod >= 0 AND platform_fee_jod >= 0 AND net_amount_jod >= 0",
            name="ck_day_passes_amounts_nonneg",
        ),
        CheckConstraint(
            "abs(price_jod - platform_fee_jod - net_amount_jod) < 0.01",
            name="ck_day_passes_amounts_consistent",
        ),
    )
