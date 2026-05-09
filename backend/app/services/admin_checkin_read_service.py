from __future__ import annotations

from datetime import datetime
from uuid import UUID

from app.db.enums import CheckinStatus
from app.db.models import Checkin, Gym, User
from app.repositories.checkin_repo import CheckinRepository


class AdminCheckinReadService:
    """Read-only listing surface for `/admin/checkins`.

    Wraps the repo's pagination so the admin route doesn't reach into
    `CheckinRepository` directly. No mutation here — admins viewing
    the firehose is a pure read operation, no audit entry warranted.
    """

    def __init__(self, checkins: CheckinRepository) -> None:
        self.checkins = checkins

    async def list_paginated(
        self,
        *,
        gym_id: UUID | None = None,
        user_id: UUID | None = None,
        status: CheckinStatus | None = None,
        since: datetime | None = None,
        until: datetime | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[tuple[Checkin, Gym, User]], int]:
        return await self.checkins.list_paginated(
            gym_id=gym_id,
            user_id=user_id,
            status=status,
            since=since,
            until=until,
            page=page,
            page_size=page_size,
        )


__all__ = ["AdminCheckinReadService"]
