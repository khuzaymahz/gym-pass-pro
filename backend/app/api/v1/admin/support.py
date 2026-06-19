from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_admin,
    db_session,
    support_ticket_service,
)
from app.db.enums import TicketCategory, TicketPriority, TicketStatus
from app.db.models import User
from app.schemas.common import Page
from app.schemas.support import (
    SupportTicketDetail,
    SupportTicketListItem,
    SupportTicketMessageRead,
    SupportTicketReply,
    SupportTicketStats,
    SupportTicketUpdate,
)
from app.services.support_ticket_service import SupportTicketService

router = APIRouter(prefix="/admin/support", tags=["admin/support"])


@router.get("/stats", response_model=SupportTicketStats)
async def stats(
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    _: Annotated[User, Depends(current_admin)],
) -> SupportTicketStats:
    counts = await svc.stats()
    return SupportTicketStats(
        total=counts.get("total", 0),
        open=counts.get("open", 0),
        in_progress=counts.get("in_progress", 0),
        waiting_user=counts.get("waiting_user", 0),
        resolved=counts.get("resolved", 0),
        closed=counts.get("closed", 0),
    )


@router.get("/tickets", response_model=Page[SupportTicketListItem])
async def list_tickets(
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    _: Annotated[User, Depends(current_admin)],
    status: TicketStatus | None = None,
    priority: TicketPriority | None = None,
    category: TicketCategory | None = None,
    assigned_admin_id: UUID | None = Query(default=None, alias="assignedAdminId"),
    q: str | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100, alias="pageSize"),
) -> Page[SupportTicketListItem]:
    items, total = await svc.list(
        status=status,
        priority=priority,
        category=category,
        assigned_admin_id=assigned_admin_id,
        q=q,
        page=page,
        page_size=page_size,
    )
    return Page[SupportTicketListItem](
        items=[
            SupportTicketListItem(
                id=r["ticket"].id,
                user_id=r["ticket"].user_id,
                user_name=r["user_name"],
                user_email=r["user_email"],
                user_phone=r["user_phone"],
                category=r["ticket"].category,
                priority=r["ticket"].priority,
                status=r["ticket"].status,
                subject=r["ticket"].subject,
                assigned_admin_id=r["ticket"].assigned_admin_id,
                created_at=r["ticket"].created_at,
                updated_at=r["ticket"].updated_at,
                resolved_at=r["ticket"].resolved_at,
            )
            for r in items
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/tickets/{ticket_id}", response_model=SupportTicketDetail)
async def get_ticket(
    ticket_id: UUID,
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    _: Annotated[User, Depends(current_admin)],
) -> SupportTicketDetail:
    ticket, messages = await svc.get_with_messages(ticket_id)
    return SupportTicketDetail(
        id=ticket.id,
        user_id=ticket.user_id,
        user_name=None,
        user_email=None,
        user_phone=None,
        category=ticket.category,
        priority=ticket.priority,
        status=ticket.status,
        subject=ticket.subject,
        body=ticket.body,
        assigned_admin_id=ticket.assigned_admin_id,
        meta=ticket.meta,
        created_at=ticket.created_at,
        updated_at=ticket.updated_at,
        resolved_at=ticket.resolved_at,
        messages=[
            SupportTicketMessageRead(
                id=m.id,
                ticket_id=m.ticket_id,
                author_user_id=m.author_user_id,
                author_name=name,
                author_role=role,
                body=m.body,
                is_internal_note=m.is_internal_note,
                created_at=m.created_at,
            )
            for (m, name, role) in messages
        ],
    )


@router.patch("/tickets/{ticket_id}", response_model=SupportTicketListItem)
async def update_ticket(
    ticket_id: UUID,
    body: SupportTicketUpdate,
    request: Request,
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SupportTicketListItem:
    updated = await svc.update(
        ticket_id,
        status=body.status,
        priority=body.priority,
        category=body.category,
        assigned_admin_id=body.assigned_admin_id,
        clear_assignee=body.clear_assignee,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return SupportTicketListItem(
        id=updated.id,
        user_id=updated.user_id,
        category=updated.category,
        priority=updated.priority,
        status=updated.status,
        subject=updated.subject,
        assigned_admin_id=updated.assigned_admin_id,
        created_at=updated.created_at,
        updated_at=updated.updated_at,
        resolved_at=updated.resolved_at,
    )


@router.post(
    "/tickets/{ticket_id}/messages",
    response_model=SupportTicketMessageRead,
)
async def reply(
    ticket_id: UUID,
    body: SupportTicketReply,
    request: Request,
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SupportTicketMessageRead:
    message = await svc.reply(
        ticket_id,
        author_user_id=admin.id,
        author_role=admin.role,
        body=body.body,
        is_internal_note=body.is_internal_note,
        actor=authed_actor(request, admin),
    )
    await session.commit()
    return SupportTicketMessageRead(
        id=message.id,
        ticket_id=message.ticket_id,
        author_user_id=message.author_user_id,
        author_name=admin.name,
        author_role=admin.role.value,
        body=message.body,
        is_internal_note=message.is_internal_note,
        created_at=message.created_at,
    )
