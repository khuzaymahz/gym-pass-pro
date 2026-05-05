from __future__ import annotations

from typing import Any

from sqlalchemy import ForeignKey, Index, text
from sqlalchemy.dialects.postgresql import INET, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import Role
from app.db.types import TimestampTZ, UUIDCol, UUIDFk, pg_enum_cls


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[UUIDCol]
    actor_user_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    actor_role: Mapped[Role | None] = mapped_column(
        pg_enum_cls("role_enum", Role), nullable=True
    )
    action: Mapped[str] = mapped_column(nullable=False)
    entity_type: Mapped[str] = mapped_column(nullable=False)
    entity_id: Mapped[UUIDFk | None] = mapped_column(nullable=True)
    diff_json: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    ip_address: Mapped[str | None] = mapped_column(INET, nullable=True)
    user_agent: Mapped[str | None] = mapped_column(nullable=True)
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        Index("ix_audit_log_entity", "entity_type", "entity_id", "created_at"),
        Index("ix_audit_log_actor_created", "actor_user_id", "created_at"),
    )
