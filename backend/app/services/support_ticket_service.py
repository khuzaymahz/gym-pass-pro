from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import TicketCategory, TicketPriority, TicketStatus
from app.db.models import SupportTicket, SupportTicketMessage
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.services.audit_service import Actor, AuditService


class SupportTicketService:
    def __init__(
        self, repo: SupportTicketRepository, audit: AuditService
    ) -> None:
        self.repo = repo
        self.audit = audit

    async def list(
        self,
        *,
        status: TicketStatus | None,
        priority: TicketPriority | None,
        category: TicketCategory | None,
        assigned_admin_id: UUID | None,
        q: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[dict[str, Any]], int]:
        return await self.repo.list(
            status=status,
            priority=priority,
            category=category,
            assigned_admin_id=assigned_admin_id,
            q=q,
            page=page,
            page_size=page_size,
        )

    async def get_with_messages(
        self, ticket_id: UUID
    ) -> tuple[SupportTicket, list[tuple[SupportTicketMessage, str | None, str | None]]]:
        ticket = await self.repo.get(ticket_id)
        if ticket is None:
            raise AppError(ErrorCode.NOT_FOUND, "Ticket not found.")
        messages = await self.repo.messages_for(ticket_id)
        return ticket, messages

    async def create(
        self,
        *,
        user_id: UUID,
        category: TicketCategory,
        priority: TicketPriority,
        subject: str,
        body: str,
        meta: dict[str, Any] | None,
        actor: Actor,
    ) -> SupportTicket:
        ticket = await self.repo.create(
            user_id=user_id,
            category=category,
            priority=priority,
            subject=subject,
            body=body,
            meta=meta,
        )
        await self.audit.log(
            actor=actor,
            action="support.ticket.create",
            entity_type="support_ticket",
            entity_id=ticket.id,
            diff={
                "after": {
                    "category": ticket.category.value,
                    "priority": ticket.priority.value,
                    "subject": ticket.subject,
                }
            },
        )
        return ticket

    async def update(
        self,
        ticket_id: UUID,
        *,
        status: TicketStatus | None,
        priority: TicketPriority | None,
        category: TicketCategory | None,
        assigned_admin_id: UUID | None,
        clear_assignee: bool,
        actor: Actor,
    ) -> SupportTicket:
        ticket = await self.repo.get(ticket_id)
        if ticket is None:
            raise AppError(ErrorCode.NOT_FOUND, "Ticket not found.")
        before = {
            "status": ticket.status.value,
            "priority": ticket.priority.value,
            "category": ticket.category.value,
            "assigned_admin_id": (
                str(ticket.assigned_admin_id) if ticket.assigned_admin_id else None
            ),
        }
        resolved_at: datetime | None = None
        resolved_cleared = False
        if status is not None:
            if status in (TicketStatus.RESOLVED, TicketStatus.CLOSED):
                resolved_at = datetime.now(timezone.utc)
            elif ticket.resolved_at is not None:
                resolved_cleared = True

        updated = await self.repo.update_fields(
            ticket,
            status=status,
            priority=priority,
            category=category,
            assigned_admin_id=assigned_admin_id,
            assigned_admin_cleared=clear_assignee,
            resolved_at=resolved_at,
            resolved_cleared=resolved_cleared,
        )
        after = {
            "status": updated.status.value,
            "priority": updated.priority.value,
            "category": updated.category.value,
            "assigned_admin_id": (
                str(updated.assigned_admin_id) if updated.assigned_admin_id else None
            ),
        }
        await self.audit.log(
            actor=actor,
            action="support.ticket.update",
            entity_type="support_ticket",
            entity_id=updated.id,
            diff={"before": before, "after": after},
        )
        return updated

    async def reply(
        self,
        ticket_id: UUID,
        *,
        author_user_id: UUID,
        body: str,
        is_internal_note: bool,
        actor: Actor,
    ) -> SupportTicketMessage:
        ticket = await self.repo.get(ticket_id)
        if ticket is None:
            raise AppError(ErrorCode.NOT_FOUND, "Ticket not found.")
        message = await self.repo.add_message(
            ticket_id=ticket_id,
            author_user_id=author_user_id,
            body=body,
            is_internal_note=is_internal_note,
        )
        # Public replies (admin OR member) drag the ticket back into the
        # active queue: OPEN tickets become IN_PROGRESS on first contact,
        # and WAITING_USER tickets flip back when the member responds.
        # Internal admin notes never change ticket state.
        if not is_internal_note and ticket.status in (
            TicketStatus.OPEN,
            TicketStatus.WAITING_USER,
        ):
            await self.repo.update_fields(ticket, status=TicketStatus.IN_PROGRESS)
        await self.audit.log(
            actor=actor,
            action="support.ticket.reply",
            entity_type="support_ticket",
            entity_id=ticket.id,
            diff={
                "after": {
                    "message_id": str(message.id),
                    "is_internal_note": is_internal_note,
                }
            },
        )
        return message

    async def stats(self) -> dict[str, int]:
        counts = await self.repo.counts_by_status()
        counts["total"] = sum(counts.values())
        return counts
