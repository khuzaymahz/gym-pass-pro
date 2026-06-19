from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, Index, Numeric, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import PayoutStatus
from app.db.types import (
    Money,
    MoneyBig,
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class PayoutLedger(Base):
    __tablename__ = "payout_ledger"

    id: Mapped[UUIDCol]
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="RESTRICT"), nullable=False
    )
    checkin_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("checkins.id", ondelete="RESTRICT"), nullable=False
    )
    amount_jod: Mapped[Money]
    rate_applied: Mapped[Money] = mapped_column(Numeric(10, 3), nullable=False)
    payout_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("payouts.id", ondelete="RESTRICT"), nullable=True
    )
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        UniqueConstraint("checkin_id", name="uq_payout_ledger_checkin_id"),
        Index("ix_payout_ledger_gym_payout", "gym_id", "payout_id"),
        # Drives the partner-dashboard revenue aggregates
        # (`_success_payout_sum`, `_revenue_per_day_since`) which
        # filter by (gym_id, created_at >= since). The other composite
        # indexes the (gym_id, payout_id) pairing for batch lookups
        # but doesn't help a time-bounded sum. See migration 0014.
        Index("ix_payout_ledger_gym_created", "gym_id", "created_at"),
    )


class Payout(Base):
    __tablename__ = "payouts"

    id: Mapped[UUIDCol]
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="RESTRICT"), nullable=False
    )
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    total_amount_jod: Mapped[MoneyBig]
    entry_count: Mapped[int] = mapped_column(nullable=False)
    status: Mapped[PayoutStatus] = mapped_column(
        pg_enum_cls("payout_status_enum", PayoutStatus),
        nullable=False,
        server_default=text("'pending'"),
    )
    paid_at: Mapped[TimestampTZNullable]
    notes: Mapped[str | None] = mapped_column(nullable=True)
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        UniqueConstraint(
            "gym_id", "period_start", "period_end", name="uq_payouts_gym_period"
        ),
        Index(
            "ix_payouts_status",
            "status",
            postgresql_where=text("status = 'pending'"),
        ),
    )
