from __future__ import annotations

from sqlalchemy import ForeignKey, Index, text
from sqlalchemy.dialects.postgresql import INET
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import CheckinStatus
from app.db.types import TimestampTZ, UUIDCol, UUIDFk, pg_enum_cls


class Checkin(Base):
    __tablename__ = "checkins"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="RESTRICT"), nullable=False
    )
    subscription_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="RESTRICT"), nullable=True
    )
    scanned_at: Mapped[TimestampTZ]
    ip_address: Mapped[str | None] = mapped_column(INET, nullable=True)
    user_agent: Mapped[str | None] = mapped_column(nullable=True)
    status: Mapped[CheckinStatus] = mapped_column(
        pg_enum_cls("checkin_status_enum", CheckinStatus),
        nullable=False,
    )
    failure_reason: Mapped[str | None] = mapped_column(nullable=True)
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        Index("ix_checkins_user_scanned_at", "user_id", "scanned_at"),
        Index("ix_checkins_gym_scanned_at", "gym_id", "scanned_at"),
        Index(
            "ix_checkins_status",
            "status",
            postgresql_where=text("status <> 'success'"),
        ),
    )
