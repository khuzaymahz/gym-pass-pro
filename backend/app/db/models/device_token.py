from __future__ import annotations

from sqlalchemy import ForeignKey, Index, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import TimestampTZ, TimestampTZUpdate, UUIDCol, UUIDFk, pg_enum
from sqlalchemy.dialects.postgresql import ENUM as PgEnum


class DeviceToken(Base):
    """One row per (user, device token) pair.

    A member can have multiple devices (phone + tablet, or they
    reinstalled the app and got a new token). Each token is unique
    across users — if someone signs into a new account on the same
    phone, `upsert` moves the token to the new user_id.

    Tokens are pruned when FCM returns `UNREGISTERED` (dead token)
    so the table only ever contains live delivery targets.
    """

    __tablename__ = "device_tokens"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    # 'android' | 'ios' — gates APNs vs FCM path when we add APNs.
    platform: Mapped[str] = mapped_column(
        PgEnum("android", "ios", name="device_platform_enum", create_type=False),
        nullable=False,
        server_default="android",
    )
    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]

    __table_args__ = (
        Index("ix_device_tokens_user_id", "user_id"),
    )
