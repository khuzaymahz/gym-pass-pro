from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import CheckinStatus
from app.db.models import Checkin, Gym, Subscription, User
from app.utils.ids import uuid7


class CheckinRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        user_id: UUID,
        gym_id: UUID,
        subscription_id: UUID | None,
        status: CheckinStatus,
        failure_reason: str | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
    ) -> Checkin:
        row = Checkin(
            id=uuid7(),
            user_id=user_id,
            gym_id=gym_id,
            subscription_id=subscription_id,
            status=status,
            failure_reason=failure_reason,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def history_for_user(
        self, user_id: UUID, limit: int = 20
    ) -> list[tuple[Checkin, Gym]]:
        stmt = (
            select(Checkin, Gym)
            .join(Gym, Gym.id == Checkin.gym_id)
            .where(Checkin.user_id == user_id)
            .order_by(Checkin.scanned_at.desc())
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return [(c, g) for c, g in result.all()]

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
        conditions: list = []
        if gym_id is not None:
            conditions.append(Checkin.gym_id == gym_id)
        if user_id is not None:
            conditions.append(Checkin.user_id == user_id)
        if status is not None:
            conditions.append(Checkin.status == status)
        if since is not None:
            conditions.append(Checkin.scanned_at >= since)
        if until is not None:
            conditions.append(Checkin.scanned_at <= until)

        count_stmt = select(func.count()).select_from(Checkin)
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = (
            select(Checkin, Gym, User)
            .join(Gym, Gym.id == Checkin.gym_id)
            .join(User, User.id == Checkin.user_id)
        )
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(Checkin.scanned_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(c, g, u) for c, g, u in rows], int(total)

    async def count_since(self, since: datetime) -> int:
        stmt = (
            select(func.count())
            .select_from(Checkin)
            .where(Checkin.scanned_at >= since, Checkin.status == CheckinStatus.SUCCESS)
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def count_success_since_for_user(
        self, user_id: UUID, since: datetime
    ) -> int:
        """Number of successful check-ins for a single user since `since`.

        Used by the check-in service to compute a member's per-month visit
        budget on the fly — `subscriptions.visits_used` is the lifetime
        denormalized total, which is fine for audit but wrong as a monthly
        cap. Counting here against the indexed `(user_id, scanned_at)`
        composite is cheap (≤ 30 rows in the worst case).
        """
        stmt = (
            select(func.count())
            .select_from(Checkin)
            .where(
                Checkin.user_id == user_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def count_per_day_last(
        self, days: int, now: datetime | None = None
    ) -> list[tuple[str, int]]:
        now = now or datetime.now(timezone.utc)
        stmt = (
            select(
                func.date_trunc("day", Checkin.scanned_at).label("day"),
                func.count(),
            )
            .where(
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= now - _timedelta(days=days),
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), int(c)) for d, c in rows]

    async def count_per_day_since(
        self, since: datetime
    ) -> list[tuple[str, int]]:
        """SUCCESS checkin counts bucketed by day, since `since` (inclusive)."""
        stmt = (
            select(
                func.date_trunc("day", Checkin.scanned_at).label("day"),
                func.count(),
            )
            .where(
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), int(c)) for d, c in rows]

    async def recent_with_user_and_gym(
        self, *, limit: int
    ) -> list[dict[str, Any]]:
        """Most recent check-ins joined with their gym and user. Read-only
        admin-overview shape — returns plain dicts so the service layer
        doesn't have to know about the join."""
        stmt = (
            select(Checkin, Gym, User)
            .join(Gym, Gym.id == Checkin.gym_id)
            .join(User, User.id == Checkin.user_id)
            .order_by(Checkin.scanned_at.desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).all()
        return [
            {
                "id": str(c.id),
                "userId": str(u.id),
                "userName": u.name,
                "gymNameEn": g.name_en,
                "gymNameAr": g.name_ar,
                "status": c.status.value,
                "scannedAt": c.scanned_at.isoformat(),
            }
            for c, g, u in rows
        ]

    # ----- partner-scoped aggregates -----

    async def count_success_for_gym_since(
        self, gym_id: UUID, since: datetime
    ) -> int:
        stmt = (
            select(func.count())
            .select_from(Checkin)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def count_unique_members_for_gym_since(
        self, gym_id: UUID, since: datetime
    ) -> int:
        stmt = (
            select(func.count(func.distinct(Checkin.user_id)))
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def count_per_day_for_gym_since(
        self, gym_id: UUID, since: datetime
    ) -> list[tuple[str, int]]:
        stmt = (
            select(
                func.date_trunc("day", Checkin.scanned_at).label("day"),
                func.count(),
            )
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), int(c)) for d, c in rows]

    async def tier_breakdown_for_gym_since(
        self, gym_id: UUID, since: datetime
    ) -> dict[str, int]:
        stmt = (
            select(Subscription.tier, func.count(Checkin.id))
            .join(Subscription, Subscription.id == Checkin.subscription_id)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by(Subscription.tier)
        )
        rows = (await self.session.execute(stmt)).all()
        return {tier.value: int(count) for tier, count in rows}

    async def hour_breakdown_for_gym_since(
        self, gym_id: UUID, since: datetime
    ) -> list[tuple[int, int]]:
        stmt = (
            select(
                func.extract("hour", Checkin.scanned_at).label("hour"),
                func.count(),
            )
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
            )
            .group_by("hour")
            .order_by("hour")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(int(h), int(c)) for h, c in rows]

    async def recent_with_user_for_gym(
        self, gym_id: UUID, *, limit: int
    ) -> list[dict[str, Any]]:
        stmt = (
            select(Checkin, User)
            .join(User, User.id == Checkin.user_id)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
            )
            .order_by(Checkin.scanned_at.desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).all()
        return [
            {
                "id": str(c.id),
                "userId": str(u.id),
                "userName": u.name or u.first_name or None,
                "scannedAt": c.scanned_at.isoformat(),
            }
            for c, u in rows
        ]


def _timedelta(*, days: int):
    from datetime import timedelta

    return timedelta(days=days)
