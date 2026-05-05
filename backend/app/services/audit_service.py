from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from uuid import UUID

from app.db.enums import Role
from app.repositories.audit_repo import AuditRepository


@dataclass(frozen=True)
class Actor:
    user_id: UUID | None
    role: Role | None
    ip_address: str | None = None
    user_agent: str | None = None


class AuditService:
    def __init__(self, repo: AuditRepository) -> None:
        self.repo = repo

    async def log(
        self,
        *,
        actor: Actor,
        action: str,
        entity_type: str,
        entity_id: UUID | None,
        diff: dict[str, Any] | None = None,
    ) -> None:
        await self.repo.write(
            actor_user_id=actor.user_id,
            actor_role=actor.role,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            diff=diff,
            ip_address=actor.ip_address,
            user_agent=actor.user_agent,
        )
