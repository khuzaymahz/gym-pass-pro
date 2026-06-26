from __future__ import annotations

import json
from datetime import datetime
from typing import Any
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import Role, TicketCategory, TicketPriority, TicketStatus
from app.db.models import SupportTicket, SupportTicketMessage
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow

# Caps for the freeform `meta` JSONB on a ticket. Members can attach
# arbitrary key/value context (build version, last-screen, etc.), and
# without bounds a malicious client can push megabytes of nested data
# into a JSONB column that the admin UI then rehydrates as raw
# key/value rows. Limits picked from the actually-useful payload size
# (under 4 KB once serialised) — anything bigger belongs in an
# attachment, not the meta blob.
_META_MAX_KEYS = 16
_META_MAX_SERIALISED_BYTES = 4 * 1024


def _validate_meta(meta: dict[str, Any] | None) -> dict[str, Any] | None:
    """Cap the size and shape of the freeform `meta` blob.

    Rejects anything with too many keys, too-deep nesting, or non-
    scalar values. Scalars are `str | int | float | bool | None`; lists
    of scalars are accepted (e.g. `featureFlags: ["A", "B"]`) but
    nested dicts and lists-of-dicts are not — they make the admin
    UI's "meta" panel useless and tend to carry payload that wants
    its own column.
    """
    if meta is None:
        return None
    if not isinstance(meta, dict):
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "meta must be an object.",
            details={"field": "meta"},
        )
    if len(meta) > _META_MAX_KEYS:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            f"meta cannot have more than {_META_MAX_KEYS} keys.",
            details={"field": "meta"},
        )
    for k, v in meta.items():
        if not isinstance(k, str) or len(k) > 64:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "meta keys must be strings ≤ 64 chars.",
                details={"field": f"meta.{k}"},
            )
        if isinstance(v, (str, int, float, bool)) or v is None:
            continue
        if isinstance(v, list) and all(
            isinstance(item, (str, int, float, bool)) or item is None for item in v
        ):
            continue
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "meta values must be scalars or lists of scalars.",
            details={"field": f"meta.{k}"},
        )
    try:
        serialised = json.dumps(meta, ensure_ascii=False)
    except (TypeError, ValueError) as exc:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "meta is not JSON-serialisable.",
            details={"field": "meta"},
        ) from exc
    if len(serialised.encode("utf-8")) > _META_MAX_SERIALISED_BYTES:
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            f"meta exceeds {_META_MAX_SERIALISED_BYTES} byte cap.",
            details={"field": "meta"},
        )
    return meta


class SupportTicketService:
    def __init__(self, repo: SupportTicketRepository, audit: AuditService) -> None:
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
        meta = _validate_meta(meta)
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
                resolved_at = utcnow()
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
        author_role: Role | None = None,
        body: str,
        is_internal_note: bool,
        actor: Actor,
    ) -> SupportTicketMessage:
        ticket = await self.repo.get(ticket_id)
        if ticket is None:
            raise AppError(ErrorCode.NOT_FOUND, "Ticket not found.")
        # Defence in depth. The route layer already enforces
        # author=owner for member replies, but a future caller (a
        # background task, a new partner endpoint) could silently
        # bypass that — so the service repeats the check using the
        # actor's role. Member-role authors can only reply to their
        # own ticket, never post internal notes, and never reply to a
        # CLOSED ticket. Admin-role actors are unrestricted.
        if author_role == Role.MEMBER:
            if author_user_id != ticket.user_id:
                raise AppError(
                    ErrorCode.AUTH_FORBIDDEN,
                    "Members can only reply to their own tickets.",
                )
            if is_internal_note:
                raise AppError(
                    ErrorCode.AUTH_FORBIDDEN,
                    "Members cannot post internal notes.",
                )
            if ticket.status == TicketStatus.CLOSED:
                raise AppError(
                    ErrorCode.VALIDATION_ERROR,
                    "Ticket is closed.",
                )
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
