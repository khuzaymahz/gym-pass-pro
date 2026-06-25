from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.repositories.checkin_repo import CheckinRepository
from app.repositories.payout_repo import PayoutLedgerRepository, PayoutRepository


class PartnerMetricsService:
    """Per-gym aggregates for the partner dashboard.

    Reads run in parallel. Each query gets its own AsyncSession from
    the factory because `AsyncSession` is not safe for concurrent
    use within a single session — sharing one session and
    `asyncio.gather`-ing the queries either errors or queues
    internally on the underlying connection, defeating the
    parallelism.
    """

    def __init__(
        self, session_factory: async_sessionmaker[AsyncSession]
    ) -> None:
        self._factory = session_factory

    async def _q(self, fn: Callable[[AsyncSession], Awaitable[Any]]) -> Any:
        async with self._factory() as s:
            return await fn(s)

    async def overview(
        self,
        gym_id: UUID,
        *,
        since: datetime | None = None,
        until: datetime | None = None,
    ) -> dict[str, Any]:
        now = datetime.now(UTC)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        if since is None:
            since = start_of_today.replace(day=1)
        if until is None:
            until = now

        (
            checkins_today,
            checkins_period,
            unique_members_period,
            revenue_period,
            pending_payout_total,
            paid_payout_period,
            checkins_per_day,
            revenue_per_day,
            tier_breakdown,
            hour_breakdown,
            recent_checkins,
        ) = await asyncio.gather(
            self._q(lambda s: CheckinRepository(s).count_success_for_gym_since(gym_id, start_of_today)),
            self._q(lambda s: CheckinRepository(s).count_success_for_gym_since(gym_id, since)),
            self._q(lambda s: CheckinRepository(s).count_unique_members_for_gym_since(gym_id, since)),
            self._q(lambda s: PayoutLedgerRepository(s).sum_for_gym_since(gym_id, since=since)),
            self._q(lambda s: PayoutRepository(s).pending_total_for_gym(gym_id)),
            self._q(lambda s: PayoutRepository(s).paid_total_for_gym_since(gym_id, since=since)),
            self._q(lambda s: CheckinRepository(s).count_per_day_for_gym_since(gym_id, since)),
            self._q(lambda s: PayoutLedgerRepository(s).sum_per_day_for_gym_since(gym_id, since=since)),
            self._q(lambda s: CheckinRepository(s).tier_breakdown_for_gym_since(gym_id, since)),
            self._q(lambda s: CheckinRepository(s).hour_breakdown_for_gym_since(gym_id, since)),
            self._q(lambda s: CheckinRepository(s).recent_with_user_for_gym(gym_id, limit=10)),
        )

        return {
            "checkinsToday": checkins_today,
            "checkinsThisMonth": checkins_period,
            "checkinsLast30Days": checkins_period,
            "uniqueMembersLast30Days": unique_members_period,
            "revenueMtdJod": revenue_period,
            "pendingPayoutTotalJod": pending_payout_total,
            "paidPayoutMtdJod": paid_payout_period,
            "checkinsPerDay": [{"day": d, "count": c} for d, c in checkins_per_day],
            "revenuePerDay": [{"day": d, "total": str(t)} for d, t in revenue_per_day],
            "tierBreakdown": tier_breakdown,
            "hourBreakdown": [{"hour": h, "count": c} for h, c in hour_breakdown],
            "recentCheckins": recent_checkins,
        }


__all__ = ["PartnerMetricsService"]
