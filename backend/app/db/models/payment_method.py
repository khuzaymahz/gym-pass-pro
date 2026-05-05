from __future__ import annotations

from sqlalchemy import CheckConstraint, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import PaymentMethod as PaymentMethodKind
from app.db.types import (
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class StoredPaymentMethod(Base):
    """Member-saved payment method.

    The mock gateway round-trips a tokenized id; in production a real
    gateway would issue an opaque token we never store the PAN behind.
    Both cases share the same shape: kind + display label + last4 (or
    CliQ alias / phone). Anything that resembles a full PAN MUST never
    land in this table — the column shapes don't permit it.
    """

    __tablename__ = "payment_methods"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    kind: Mapped[PaymentMethodKind] = mapped_column(
        pg_enum_cls("payment_method_enum", PaymentMethodKind),
        nullable=False,
    )

    # Human label ("Visa · primary"), set by the mobile add-method sheet.
    label: Mapped[str] = mapped_column(nullable=False)

    # Display-safe identifier — last four digits for cards, masked tail for
    # CliQ phones, alias for CliQ aliases, empty string for Apple Pay.
    # Never the full PAN. Stored as text so callers don't accidentally do
    # arithmetic on a leading zero.
    last4: Mapped[str] = mapped_column(nullable=False, server_default=text("''"))

    # Card-only metadata. Holder is whatever the member typed; expiry is
    # used by the UI to flag a card that's about to age out of validity.
    holder: Mapped[str | None] = mapped_column(nullable=True)
    expiry_mm: Mapped[int | None] = mapped_column(nullable=True)
    expiry_yy: Mapped[int | None] = mapped_column(nullable=True)

    # CliQ-only — gateways accept either an alias OR a phone number, so
    # we keep both columns and let the caller populate whichever the user
    # registered with.
    cliq_alias: Mapped[str | None] = mapped_column(nullable=True)
    cliq_phone: Mapped[str | None] = mapped_column(nullable=True)

    # Tokens issued by the (mock) gateway. The mock provider generates
    # `mock-<uuid>`; a real gateway would put its opaque vault id here.
    gateway_token: Mapped[str | None] = mapped_column(nullable=True)

    is_default: Mapped[bool] = mapped_column(
        nullable=False, server_default=text("false")
    )

    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]
    deleted_at: Mapped[TimestampTZNullable]

    __table_args__ = (
        # Card needs expiry, CliQ needs alias-or-phone, Apple Pay needs
        # nothing extra. Mock kind has no constraint — it's the dev shape.
        CheckConstraint(
            "(kind <> 'card') OR ("
            "expiry_mm IS NOT NULL AND expiry_yy IS NOT NULL"
            ")",
            name="ck_payment_methods_card_has_expiry",
        ),
        CheckConstraint(
            "(kind <> 'cliq') OR ("
            "cliq_alias IS NOT NULL OR cliq_phone IS NOT NULL"
            ")",
            name="ck_payment_methods_cliq_has_identifier",
        ),
        Index(
            "ix_payment_methods_user_active",
            "user_id",
            postgresql_where=text("deleted_at IS NULL"),
        ),
        # At most one default per user. Partial unique so soft-deleted rows
        # don't fight a fresh default.
        Index(
            "uq_payment_methods_user_default",
            "user_id",
            unique=True,
            postgresql_where=text("is_default = true AND deleted_at IS NULL"),
        ),
    )
