from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.db.enums import TicketCategory, TicketPriority, TicketStatus
from app.db.models import SupportTicket, SupportTicketMessage, User
from app.utils.ids import uuid7


class SupportTicketRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list(
        self,
        *,
        status: TicketStatus | None = None,
        priority: TicketPriority | None = None,
        category: TicketCategory | None = None,
        assigned_admin_id: UUID | None = None,
        q: str | None = None,
        page: int = 1,
        page_size: int = 25,
    ) -> tuple[list[dict[str, Any]], int]:
        author = aliased(User)
        stmt = (
            select(
                SupportTicket,
                author.name.label("user_name"),
                author.email.label("user_email"),
                author.phone.label("user_phone"),
            )
            .join(author, author.id == SupportTicket.user_id)
        )
        count_stmt = select(func.count()).select_from(SupportTicket)

        if status is not None:
            stmt = stmt.where(SupportTicket.status == status)
            count_stmt = count_stmt.where(SupportTicket.status == status)
        if priority is not None:
            stmt = stmt.where(SupportTicket.priority == priority)
            count_stmt = count_stmt.where(SupportTicket.priority == priority)
        if category is not None:
            stmt = stmt.where(SupportTicket.category == category)
            count_stmt = count_stmt.where(SupportTicket.category == category)
        if assigned_admin_id is not None:
            stmt = stmt.where(SupportTicket.assigned_admin_id == assigned_admin_id)
            count_stmt = count_stmt.where(
                SupportTicket.assigned_admin_id == assigned_admin_id
            )
        if q:
            like = f"%{q}%"
            stmt = stmt.where(
                (SupportTicket.subject.ilike(like))
                | (SupportTicket.body.ilike(like))
            )
            count_stmt = count_stmt.where(
                (SupportTicket.subject.ilike(like))
                | (SupportTicket.body.ilike(like))
            )

        stmt = stmt.order_by(SupportTicket.created_at.desc()).limit(page_size).offset(
            (page - 1) * page_size
        )
        rows = (await self.session.execute(stmt)).all()
        total = int((await self.session.execute(count_stmt)).scalar_one())
        items = [
            {
                "ticket": row[0],
                "user_name": row[1],
                "user_email": row[2],
                "user_phone": row[3],
            }
            for row in rows
        ]
        return items, total

    async def get(self, ticket_id: UUID) -> SupportTicket | None:
        stmt = select(SupportTicket).where(SupportTicket.id == ticket_id)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def list_for_user(
        self,
        user_id: UUID,
        *,
        page: int = 1,
        page_size: int = 25,
    ) -> tuple[list[SupportTicket], int]:
        """Member-facing list — every ticket owned by `user_id`, newest first.

        Tickets opened by other members are never returned, even if a stale
        token somehow reaches this method. The admin list is the only path
        that reads across users.
        """
        base = select(SupportTicket).where(SupportTicket.user_id == user_id)
        count_stmt = (
            select(func.count())
            .select_from(SupportTicket)
            .where(SupportTicket.user_id == user_id)
        )
        stmt = (
            base.order_by(SupportTicket.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        total = int((await self.session.execute(count_stmt)).scalar_one())
        return list(rows), total

    async def visible_messages_for_member(
        self, ticket_id: UUID
    ) -> list[tuple[SupportTicketMessage, str | None, str | None]]:
        """Member-visible messages: same shape as `messages_for` but filters
        out internal admin notes. Used by the mobile detail view so a member
        never sees the operator's private commentary."""
        stmt = (
            select(
                SupportTicketMessage,
                User.name,
                User.role,
            )
            .join(User, User.id == SupportTicketMessage.author_user_id)
            .where(
                SupportTicketMessage.ticket_id == ticket_id,
                SupportTicketMessage.is_internal_note.is_(False),
            )
            .order_by(SupportTicketMessage.created_at.asc())
        )
        rows = (await self.session.execute(stmt)).all()
        return [(r[0], r[1], r[2].value if r[2] is not None else None) for r in rows]

    async def messages_for(
        self, ticket_id: UUID
    ) -> list[tuple[SupportTicketMessage, str | None, str | None]]:
        stmt = (
            select(
                SupportTicketMessage,
                User.name,
                User.role,
            )
            .join(User, User.id == SupportTicketMessage.author_user_id)
            .where(SupportTicketMessage.ticket_id == ticket_id)
            .order_by(SupportTicketMessage.created_at.asc())
        )
        rows = (await self.session.execute(stmt)).all()
        return [(r[0], r[1], r[2].value if r[2] is not None else None) for r in rows]

    async def create(
        self,
        *,
        user_id: UUID,
        category: TicketCategory,
        priority: TicketPriority,
        subject: str,
        body: str,
        meta: dict[str, Any] | None = None,
    ) -> SupportTicket:
        row = SupportTicket(
            id=uuid7(),
            user_id=user_id,
            category=category,
            priority=priority,
            status=TicketStatus.OPEN,
            subject=subject,
            body=body,
            meta=meta or {},
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def add_message(
        self,
        *,
        ticket_id: UUID,
        author_user_id: UUID,
        body: str,
        is_internal_note: bool = False,
    ) -> SupportTicketMessage:
        row = SupportTicketMessage(
            id=uuid7(),
            ticket_id=ticket_id,
            author_user_id=author_user_id,
            body=body,
            is_internal_note=is_internal_note,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def counts_by_status(self) -> dict[str, int]:
        stmt = select(SupportTicket.status, func.count()).group_by(
            SupportTicket.status
        )
        rows = (await self.session.execute(stmt)).all()
        return {row[0].value: int(row[1]) for row in rows}

    async def count_open(self) -> int:
        stmt = select(func.count()).select_from(SupportTicket).where(
            SupportTicket.status.in_(
                [TicketStatus.OPEN, TicketStatus.IN_PROGRESS, TicketStatus.WAITING_USER]
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def count_urgent_open(self) -> int:
        stmt = select(func.count()).select_from(SupportTicket).where(
            SupportTicket.priority == TicketPriority.URGENT,
            SupportTicket.status.in_(
                [TicketStatus.OPEN, TicketStatus.IN_PROGRESS, TicketStatus.WAITING_USER]
            ),
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def update_fields(
        self,
        ticket: SupportTicket,
        *,
        status: TicketStatus | None = None,
        priority: TicketPriority | None = None,
        category: TicketCategory | None = None,
        assigned_admin_id: UUID | None = None,
        assigned_admin_cleared: bool = False,
        resolved_at: datetime | None = None,
        resolved_cleared: bool = False,
    ) -> SupportTicket:
        if status is not None:
            ticket.status = status
        if priority is not None:
            ticket.priority = priority
        if category is not None:
            ticket.category = category
        if assigned_admin_cleared:
            ticket.assigned_admin_id = None
        elif assigned_admin_id is not None:
            ticket.assigned_admin_id = assigned_admin_id
        if resolved_cleared:
            ticket.resolved_at = None
        elif resolved_at is not None:
            ticket.resolved_at = resolved_at
        await self.session.flush()
        return ticket
