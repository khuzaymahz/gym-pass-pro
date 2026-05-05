from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import TimestampTZ, TimestampTZNullable, UUIDCol, UUIDFk


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    device_info: Mapped[str | None] = mapped_column(nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[TimestampTZNullable]
    last_used_at: Mapped[TimestampTZNullable]
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        Index(
            "ix_refresh_tokens_user_revoked",
            "user_id",
            postgresql_where=text("revoked_at IS NULL"),
        ),
    )
