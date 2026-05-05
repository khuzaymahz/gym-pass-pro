from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import TimestampTZ, TimestampTZNullable, UUIDCol


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id: Mapped[UUIDCol]
    phone: Mapped[str] = mapped_column(nullable=False)
    code_hash: Mapped[str] = mapped_column(nullable=False)
    attempts: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[TimestampTZNullable]
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        Index("ix_otp_codes_phone_expires", "phone", "expires_at"),
    )
