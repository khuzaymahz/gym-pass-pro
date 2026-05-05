from __future__ import annotations

from sqlalchemy import ForeignKey, Index, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import ReferralStatus
from app.db.types import (
    TimestampTZ,
    TimestampTZNullable,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class Referral(Base):
    __tablename__ = "referrals"

    id: Mapped[UUIDCol]
    referrer_user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    invited_user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[ReferralStatus] = mapped_column(
        pg_enum_cls("referral_status_enum", ReferralStatus),
        nullable=False,
        server_default=text("'pending'"),
    )
    referral_code: Mapped[str] = mapped_column(nullable=False)

    created_at: Mapped[TimestampTZ]
    converted_at: Mapped[TimestampTZNullable]

    __table_args__ = (
        UniqueConstraint("invited_user_id", name="uq_referrals_invited_user_id"),
        Index(
            "ix_referrals_referrer_created",
            "referrer_user_id",
            "created_at",
        ),
        Index("ix_referrals_status", "status"),
    )
