from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import SubscriptionPause
from app.utils.ids import uuid7


class SubscriptionPauseRepository:
    """Data access for `subscription_pauses`. The partial unique index on
    `(subscription_id) WHERE ended_at IS NULL` does the "one open pause
    at a time" enforcement at the DB level — service code can rely on
    `INSERT` raising `IntegrityError` when a duplicate slips through a
    race between two clients."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def open_for_subscription(
        self, subscription_id: UUID
    ) -> SubscriptionPause | None:
        """Return the scheduled-or-active pause for this subscription, if
        any. Used by the service to decide between "schedule new" vs
        "reject — already open"."""
        stmt = select(SubscriptionPause).where(
            SubscriptionPause.subscription_id == subscription_id,
            SubscriptionPause.ended_at.is_(None),
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def count_for_subscription(self, subscription_id: UUID) -> int:
        """Total pauses (open or finalised) ever created on this
        subscription. Used to check against the per-tier max-pauses
        allowance — a 12-month plan grants two, so a member who has
        already taken one is allowed one more."""
        stmt = select(SubscriptionPause).where(
            SubscriptionPause.subscription_id == subscription_id,
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return len(rows)

    async def total_days_consumed(self, subscription_id: UUID) -> int:
        """Sum of `days_consumed` across all finalised pauses on this
        subscription. Used to reject a new pause that would push the
        member past the per-term day allowance."""
        rows = await self.session.execute(
            select(SubscriptionPause.days_consumed).where(
                SubscriptionPause.subscription_id == subscription_id,
                SubscriptionPause.ended_at.is_not(None),
            )
        )
        return sum(int(d) for d in rows.scalars().all())

    async def create(
        self,
        *,
        subscription_id: UUID,
        starts_on: date,
        ends_on: date,
    ) -> SubscriptionPause:
        row = SubscriptionPause(
            id=uuid7(),
            subscription_id=subscription_id,
            starts_on=starts_on,
            ends_on=ends_on,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def finalize(
        self,
        row: SubscriptionPause,
        *,
        ended_at: datetime,
        days_consumed: int,
    ) -> SubscriptionPause:
        row.ended_at = ended_at
        row.days_consumed = days_consumed
        await self.session.flush()
        return row

    async def list_open_ending_on_or_before(
        self, cutoff: date
    ) -> list[SubscriptionPause]:
        """Cron sweep: open pauses whose window has elapsed. Ordered by
        `ends_on` so the oldest get auto-resumed first — bounded list,
        no pagination needed."""
        stmt = (
            select(SubscriptionPause)
            .where(
                SubscriptionPause.ended_at.is_(None),
                SubscriptionPause.ends_on <= cutoff,
            )
            .order_by(SubscriptionPause.ends_on.asc())
        )
        return list((await self.session.execute(stmt)).scalars().all())
