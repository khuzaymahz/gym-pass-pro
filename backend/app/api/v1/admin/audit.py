from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.api.deps import audit_repo, current_admin
from app.db.models import User
from app.repositories.audit_repo import AuditRepository
from app.schemas.admin import AdminAuditRead
from app.schemas.common import Page

router = APIRouter(prefix="/admin/audit", tags=["admin/audit"])


@router.get("", response_model=Page[AdminAuditRead])
async def list_audit(
    repo: Annotated[AuditRepository, Depends(audit_repo)],
    _: Annotated[User, Depends(current_admin)],
    entity_type: str | None = Query(default=None, alias="entityType"),
    actor_user_id: UUID | None = Query(default=None, alias="actorUserId"),
    action: str | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminAuditRead]:
    rows, total = await repo.list_paginated(
        entity_type=entity_type,
        actor_user_id=actor_user_id,
        action=action,
        page=page,
        page_size=page_size,
    )
    items = [
        AdminAuditRead(
            id=r.id,
            actorUserId=r.actor_user_id,
            actorRole=r.actor_role,
            action=r.action,
            entityType=r.entity_type,
            entityId=r.entity_id,
            diff=r.diff_json,
            ipAddress=str(r.ip_address) if r.ip_address else None,
            createdAt=r.created_at,
        )
        for r in rows
    ]
    return Page[AdminAuditRead](
        items=items, total=total, page=page, pageSize=page_size
    )
