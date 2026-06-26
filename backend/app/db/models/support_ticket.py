from __future__ import annotations

from typing import Any

from sqlalchemy import ForeignKey, Index, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import TicketCategory, TicketPriority, TicketStatus
from app.db.types import (
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    UUIDFk,
    pg_enum_cls,
)


class SupportTicket(Base):
    __tablename__ = "support_tickets"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    category: Mapped[TicketCategory] = mapped_column(
        pg_enum_cls("ticket_category_enum", TicketCategory),
        nullable=False,
        server_default=text("'other'"),
    )
    priority: Mapped[TicketPriority] = mapped_column(
        pg_enum_cls("ticket_priority_enum", TicketPriority),
        nullable=False,
        server_default=text("'normal'"),
    )
    status: Mapped[TicketStatus] = mapped_column(
        pg_enum_cls("ticket_status_enum", TicketStatus),
        nullable=False,
        server_default=text("'open'"),
    )
    subject: Mapped[str] = mapped_column(nullable=False)
    body: Mapped[str] = mapped_column(nullable=False)
    assigned_admin_id: Mapped[UUIDFk | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    meta: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )

    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]
    resolved_at: Mapped[TimestampTZNullable]

    __table_args__ = (
        Index("ix_support_tickets_status_created", "status", "created_at"),
        Index("ix_support_tickets_user_id", "user_id"),
        Index("ix_support_tickets_assigned", "assigned_admin_id"),
    )


class SupportTicketMessage(Base):
    __tablename__ = "support_ticket_messages"

    id: Mapped[UUIDCol]
    ticket_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("support_tickets.id", ondelete="CASCADE"), nullable=False
    )
    author_user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    body: Mapped[str] = mapped_column(nullable=False)
    is_internal_note: Mapped[bool] = mapped_column(nullable=False, server_default=text("false"))
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        Index("ix_support_ticket_messages_ticket", "ticket_id", "created_at"),
        Index("ix_support_ticket_messages_author", "author_user_id"),
    )
