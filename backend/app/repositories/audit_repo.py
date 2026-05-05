from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import Role
from app.db.models import AuditLog
from app.utils.ids import uuid7


class AuditRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def write(
        self,
        *,
        action: str,
        entity_type: str,
        entity_id: UUID | None,
        diff: dict[str, Any] | None = None,
        actor_user_id: UUID | None = None,
        actor_role: Role | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> AuditLog:
        row = AuditLog(
            id=uuid7(),
            actor_user_id=actor_user_id,
            actor_role=actor_role,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            diff_json=diff or {},
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def list_paginated(
        self,
        *,
        entity_type: str | None = None,
        actor_user_id: UUID | None = None,
        action: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[AuditLog], int]:
        conditions: list = []
        if entity_type is not None:
            conditions.append(AuditLog.entity_type == entity_type)
        if actor_user_id is not None:
            conditions.append(AuditLog.actor_user_id == actor_user_id)
        if action is not None:
            # Prefix match — `auth.` returns every auth-bucket event.
            # Escape SQL `%` and `_` in the user-supplied prefix so
            # an operator can't accidentally (or intentionally) sneak
            # a wildcard into the filter and pull more rows than the
            # UI implies. Same defence-in-depth pattern as
            # user_repo / gym_repo.
            safe = action.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            conditions.append(AuditLog.action.like(f"{safe}%", escape="\\"))

        count_stmt = select(func.count()).select_from(AuditLog)
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = select(AuditLog)
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(AuditLog.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return list(rows), int(total)
