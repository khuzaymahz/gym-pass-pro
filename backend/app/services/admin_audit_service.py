from __future__ import annotations

from uuid import UUID

from app.db.models import AuditLog
from app.repositories.audit_repo import AuditRepository


class AdminAuditService:
    """Read-only wrapper over the audit repository for the admin console.

    The audit log is append-only and read-mostly; the routes that surface
    it (`GET /admin/audit`) do nothing but paginate, so this service is
    a thin pass-through. The point isn't to add behaviour — it's to keep
    the boundary clean: routers depend on services, services own
    queries, repositories own SQL.
    """

    def __init__(self, repo: AuditRepository) -> None:
        self.repo = repo

    async def list_paginated(
        self,
        *,
        entity_type: str | None,
        actor_user_id: UUID | None,
        action: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[AuditLog], int]:
        return await self.repo.list_paginated(
            entity_type=entity_type,
            actor_user_id=actor_user_id,
            action=action,
            page=page,
            page_size=page_size,
        )


__all__ = ["AdminAuditService"]
