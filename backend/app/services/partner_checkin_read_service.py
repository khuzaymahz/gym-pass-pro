from __future__ import annotations

from datetime import datetime
from uuid import UUID

from app.db.enums import CheckinStatus
from app.db.models import Checkin, Gym, User
from app.repositories.checkin_repo import CheckinRepository


class PartnerCheckinReadService:
    """Read-only listing surface for the partner gym dashboard.

    Always scopes by the partner's own `gym_id` — the route enforces
    the role; this service enforces the scope. A partner asking for
    `gym_id=<someone_else's>` would be rejected at the route layer
    by `current_gym_owner`, but having the scoping live here means
    the same service can be wired into a future "service-account"
    flow without re-deriving the rule.
    """

    def __init__(self, checkins: CheckinRepository) -> None:
        self.checkins = checkins

    async def list_for_gym(
        self,
        *,
        gym_id: UUID,
        status: CheckinStatus | None = None,
        since: datetime | None = None,
        until: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[tuple[Checkin, Gym, User]], int]:
        return await self.checkins.list_paginated(
            gym_id=gym_id,
            status=status,
            since=since,
            until=until,
            page=page,
            page_size=page_size,
        )


__all__ = ["PartnerCheckinReadService"]
