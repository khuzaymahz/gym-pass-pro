from __future__ import annotations

from sqlalchemy import ForeignKey, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import TimestampTZ, TimestampTZUpdate, UUIDCol, UUIDFk


class GymPhoto(Base):
    __tablename__ = "gym_photos"

    id: Mapped[UUIDCol]
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="CASCADE"), nullable=False
    )
    url: Mapped[str] = mapped_column(nullable=False)
    sort_order: Mapped[int] = mapped_column(
        nullable=False, default=0, server_default=text("0")
    )
    alt_text_en: Mapped[str | None] = mapped_column(nullable=True)
    alt_text_ar: Mapped[str | None] = mapped_column(nullable=True)

    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        Index("ix_gym_photos_gym_sort", "gym_id", "sort_order"),
    )
