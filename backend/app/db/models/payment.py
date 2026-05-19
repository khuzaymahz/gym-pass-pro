from __future__ import annotations

from typing import Any

from sqlalchemy import ForeignKey, Index, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import PaymentMethod, PaymentStatus
from app.db.types import (
    Money,
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[UUIDCol]
    # Nullable because day-pass payments aren't tied to a subscription.
    # When NULL, the matching `day_passes.payment_id` carries the
    # back-pointer; the row is still queryable by `gateway_txn_id`.
    subscription_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="RESTRICT"), nullable=True
    )
    amount_jod: Mapped[Money]
    method: Mapped[PaymentMethod] = mapped_column(
        pg_enum_cls("payment_method_enum", PaymentMethod),
        nullable=False,
    )
    gateway_txn_id: Mapped[str | None] = mapped_column(nullable=True)
    status: Mapped[PaymentStatus] = mapped_column(
        pg_enum_cls("payment_status_enum", PaymentStatus),
        nullable=False,
        server_default=text("'pending'"),
    )
    raw_response: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    processed_at: Mapped[TimestampTZNullable]
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        Index("ix_payments_subscription_id", "subscription_id"),
        Index(
            "ix_payments_gateway_txn_id",
            "gateway_txn_id",
            unique=True,
            postgresql_where=text("gateway_txn_id IS NOT NULL"),
        ),
    )
