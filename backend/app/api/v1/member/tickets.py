from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_user,
    db_session,
    support_ticket_repo,
    support_ticket_service,
)
from app.core.exceptions import AppError, ErrorCode
from app.db.enums import TicketStatus
from app.db.models import User
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.schemas.common import Page
from app.schemas.support import (
    SupportTicketCreate,
    SupportTicketDetail,
    SupportTicketListItem,
    SupportTicketMessageRead,
    SupportTicketReply,
)
from app.services.support_ticket_service import SupportTicketService

router = APIRouter(prefix="/me/tickets", tags=["me/tickets"])


class MemberTicketReply(BaseModel):
    """Member-side reply payload — internal-note flag is admin-only and
    intentionally absent here. The service forces is_internal_note=False
    for member-authored messages regardless of the wire shape."""

    body: str = Field(min_length=1, max_length=8000)

    model_config = ConfigDict(populate_by_name=True)


@router.get("", response_model=Page[SupportTicketListItem])
async def list_my_tickets(
    me: Annotated[User, Depends(current_user)],
    repo: Annotated[SupportTicketRepository, Depends(support_ticket_repo)],
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, alias="pageSize")] = 25,
) -> Page[SupportTicketListItem]:
    rows, total = await repo.list_for_user(
        me.id, page=page, page_size=page_size
    )
    items = [
        SupportTicketListItem.model_validate(
            {
                "id": t.id,
                "userId": t.user_id,
                "userName": me.display_name,
                "userEmail": me.email,
                "userPhone": me.phone,
                "category": t.category,
                "priority": t.priority,
                "status": t.status,
                "subject": t.subject,
                "assignedAdminId": t.assigned_admin_id,
                "createdAt": t.created_at,
                "updatedAt": t.updated_at,
                "resolvedAt": t.resolved_at,
            }
        )
        for t in rows
    ]
    return Page[SupportTicketListItem](
        items=items, total=total, page=page, pageSize=page_size
    )


@router.post("", response_model=SupportTicketListItem, status_code=201)
async def create_my_ticket(
    body: SupportTicketCreate,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SupportTicketListItem:
    ticket = await svc.create(
        user_id=me.id,
        category=body.category,
        priority=body.priority,
        subject=body.subject,
        body=body.body,
        meta=body.meta,
        actor=authed_actor(request, me),
    )
    await session.commit()
    return SupportTicketListItem.model_validate(
        {
            "id": ticket.id,
            "userId": ticket.user_id,
            "userName": me.display_name,
            "userEmail": me.email,
            "userPhone": me.phone,
            "category": ticket.category,
            "priority": ticket.priority,
            "status": ticket.status,
            "subject": ticket.subject,
            "assignedAdminId": ticket.assigned_admin_id,
            "createdAt": ticket.created_at,
            "updatedAt": ticket.updated_at,
            "resolvedAt": ticket.resolved_at,
        }
    )


@router.get("/{ticket_id}", response_model=SupportTicketDetail)
async def get_my_ticket(
    ticket_id: UUID,
    me: Annotated[User, Depends(current_user)],
    repo: Annotated[SupportTicketRepository, Depends(support_ticket_repo)],
) -> SupportTicketDetail:
    ticket = await repo.get(ticket_id)
    if ticket is None or ticket.user_id != me.id:
        # 404 not 403 — don't leak the existence of someone else's ticket.
        raise AppError(ErrorCode.NOT_FOUND, "Ticket not found.")
    rows = await repo.visible_messages_for_member(ticket.id)
    messages = [
        SupportTicketMessageRead.model_validate(
            {
                "id": m.id,
                "ticketId": m.ticket_id,
                "authorUserId": m.author_user_id,
                "authorName": author_name,
                "authorRole": author_role,
                "body": m.body,
                "isInternalNote": m.is_internal_note,
                "createdAt": m.created_at,
            }
        )
        for m, author_name, author_role in rows
    ]
    return SupportTicketDetail.model_validate(
        {
            "id": ticket.id,
            "userId": ticket.user_id,
            "userName": me.display_name,
            "userEmail": me.email,
            "userPhone": me.phone,
            "category": ticket.category,
            "priority": ticket.priority,
            "status": ticket.status,
            "subject": ticket.subject,
            "assignedAdminId": ticket.assigned_admin_id,
            "createdAt": ticket.created_at,
            "updatedAt": ticket.updated_at,
            "resolvedAt": ticket.resolved_at,
            "body": ticket.body,
            "meta": ticket.meta or {},
            "messages": messages,
        }
    )


@router.post("/{ticket_id}/messages", response_model=SupportTicketMessageRead, status_code=201)
async def reply_to_my_ticket(
    ticket_id: UUID,
    body: MemberTicketReply,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    repo: Annotated[SupportTicketRepository, Depends(support_ticket_repo)],
    svc: Annotated[SupportTicketService, Depends(support_ticket_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> SupportTicketMessageRead:
    ticket = await repo.get(ticket_id)
    if ticket is None or ticket.user_id != me.id:
        raise AppError(ErrorCode.NOT_FOUND, "Ticket not found.")
    if ticket.status == TicketStatus.CLOSED:
        # Closed tickets shouldn't accept new replies — opening a new
        # ticket is the right path. The mobile UI mirrors this.
        raise AppError(
            ErrorCode.VALIDATION_ERROR,
            "Ticket is closed. Open a new ticket for further support.",
        )
    # The service handles the OPEN/WAITING_USER → IN_PROGRESS transition
    # for any public reply, so the route doesn't need to touch status.
    message = await svc.reply(
        ticket.id,
        author_user_id=me.id,
        author_role=me.role,
        body=body.body,
        is_internal_note=False,
        actor=authed_actor(request, me),
    )
    await session.commit()
    return SupportTicketMessageRead.model_validate(
        {
            "id": message.id,
            "ticketId": message.ticket_id,
            "authorUserId": message.author_user_id,
            "authorName": me.display_name,
            "authorRole": me.role.value,
            "body": message.body,
            "isInternalNote": message.is_internal_note,
            "createdAt": message.created_at,
        }
    )
