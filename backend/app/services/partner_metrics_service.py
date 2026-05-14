from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
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
    parallelism. The fresh-session-per-task pattern lets independent
    aggregate queries run truly in parallel at the connection pool.
    """

    def __init__(
        self, session_factory: async_sessionmaker[AsyncSession]
    ) -> None:
        self._factory = session_factory

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

        # Each task runs in its own session so they can hit the DB
        # in parallel. The pool absorbs concurrent acquires up to
        # `pool_size + max_overflow`; ~11 tasks per dashboard request
        # is well within typical limits.
        async def _checkins_today() -> int:
            async with self._factory() as s:
                return await CheckinRepository(s).count_success_for_gym_since(
                    gym_id, start_of_today
                )

        async def _checkins_period() -> int:
            async with self._factory() as s:
                return await CheckinRepository(s).count_success_for_gym_since(
                    gym_id, since
                )

        async def _unique_members() -> int:
            async with self._factory() as s:
                return await CheckinRepository(
                    s
                ).count_unique_members_for_gym_since(gym_id, since)

        async def _revenue_period():
            async with self._factory() as s:
                return await PayoutLedgerRepository(s).sum_for_gym_since(
                    gym_id, since=since
                )

        async def _pending_payout():
            async with self._factory() as s:
                return await PayoutRepository(s).pending_total_for_gym(gym_id)

        async def _paid_period():
            async with self._factory() as s:
                return await PayoutRepository(s).paid_total_for_gym_since(
                    gym_id, since=since
                )

        async def _checkins_per_day():
            async with self._factory() as s:
                return await CheckinRepository(s).count_per_day_for_gym_since(
                    gym_id, since
                )

        async def _revenue_per_day():
            async with self._factory() as s:
                return await PayoutLedgerRepository(
                    s
                ).sum_per_day_for_gym_since(gym_id, since=since)

        async def _tier_breakdown():
            async with self._factory() as s:
                return await CheckinRepository(s).tier_breakdown_for_gym_since(
                    gym_id, since
                )

        async def _hour_breakdown():
            async with self._factory() as s:
                return await CheckinRepository(s).hour_breakdown_for_gym_since(
                    gym_id, since
                )

        async def _recent_checkins():
            async with self._factory() as s:
                return await CheckinRepository(s).recent_with_user_for_gym(
                    gym_id, limit=10
                )

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
            _checkins_today(),
            _checkins_period(),
            _unique_members(),
            _revenue_period(),
            _pending_payout(),
            _paid_period(),
            _checkins_per_day(),
            _revenue_per_day(),
            _tier_breakdown(),
            _hour_breakdown(),
            _recent_checkins(),
        )

        return {
            "checkinsToday": checkins_today,
            "checkinsThisMonth": checkins_period,
            "checkinsLast30Days": checkins_period,
            "uniqueMembersLast30Days": unique_members_period,
            "revenueMtdJod": revenue_period,
            "pendingPayoutTotalJod": pending_payout_total,
            "paidPayoutMtdJod": paid_payout_period,
            "checkinsPerDay": [
                {"day": d, "count": c} for d, c in checkins_per_day
            ],
            "revenuePerDay": [
                {"day": d, "total": str(t)} for d, t in revenue_per_day
            ],
            "tierBreakdown": tier_breakdown,
            "hourBreakdown": [
                {"hour": h, "count": c} for h, c in hour_breakdown
            ],
            "recentCheckins": recent_checkins,
        }


__all__ = ["PartnerMetricsService"]
