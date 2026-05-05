from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import TicketCategory, TicketPriority, TicketStatus


class SupportTicketListItem(BaseModel):
    id: UUID
    user_id: UUID = Field(alias="userId")
    user_name: str | None = Field(alias="userName", default=None)
    user_email: str | None = Field(alias="userEmail", default=None)
    user_phone: str | None = Field(alias="userPhone", default=None)
    category: TicketCategory
    priority: TicketPriority
    status: TicketStatus
    subject: str
    assigned_admin_id: UUID | None = Field(alias="assignedAdminId", default=None)
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")
    resolved_at: datetime | None = Field(alias="resolvedAt", default=None)

    model_config = ConfigDict(populate_by_name=True)


class SupportTicketMessageRead(BaseModel):
    id: UUID
    ticket_id: UUID = Field(alias="ticketId")
    author_user_id: UUID = Field(alias="authorUserId")
    author_name: str | None = Field(alias="authorName", default=None)
    author_role: str | None = Field(alias="authorRole", default=None)
    body: str
    is_internal_note: bool = Field(alias="isInternalNote")
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(populate_by_name=True)


class SupportTicketDetail(SupportTicketListItem):
    body: str
    meta: dict[str, Any] = Field(default_factory=dict)
    messages: list[SupportTicketMessageRead] = Field(default_factory=list)


class SupportTicketUpdate(BaseModel):
    status: TicketStatus | None = None
    priority: TicketPriority | None = None
    category: TicketCategory | None = None
    assigned_admin_id: UUID | None = Field(alias="assignedAdminId", default=None)
    clear_assignee: bool = Field(alias="clearAssignee", default=False)

    model_config = ConfigDict(populate_by_name=True)


class SupportTicketReply(BaseModel):
    body: str = Field(min_length=1, max_length=8000)
    is_internal_note: bool = Field(alias="isInternalNote", default=False)

    model_config = ConfigDict(populate_by_name=True)


class SupportTicketCreate(BaseModel):
    category: TicketCategory = TicketCategory.OTHER
    priority: TicketPriority = TicketPriority.NORMAL
    subject: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1, max_length=8000)
    meta: dict[str, Any] = Field(default_factory=dict)

    model_config = ConfigDict(populate_by_name=True)


class SupportTicketStats(BaseModel):
    total: int = 0
    open: int = 0
    in_progress: int = Field(alias="inProgress", default=0)
    waiting_user: int = Field(alias="waitingUser", default=0)
    resolved: int = 0
    closed: int = 0

    model_config = ConfigDict(populate_by_name=True)
