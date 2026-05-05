from __future__ import annotations

from sqlalchemy import ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import NotificationType
from app.db.types import TimestampTZ, TimestampTZNullable, UUIDCol, UUIDFk, pg_enum_cls


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[NotificationType] = mapped_column(
        pg_enum_cls("notification_type_enum", NotificationType),
        nullable=False,
    )
    title_en: Mapped[str] = mapped_column(nullable=False)
    title_ar: Mapped[str] = mapped_column(nullable=False)
    body_en: Mapped[str] = mapped_column(nullable=False)
    body_ar: Mapped[str] = mapped_column(nullable=False)
    deep_link: Mapped[str | None] = mapped_column(nullable=True)
    read_at: Mapped[TimestampTZNullable]
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        Index(
            "ix_notifications_user_unread",
            "user_id",
            "created_at",
            postgresql_where=text("read_at IS NULL"),
        ),
    )
