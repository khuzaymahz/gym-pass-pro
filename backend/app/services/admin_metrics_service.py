from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any, Awaitable, Callable

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.db.enums import Role
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.payout_repo import PayoutRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.repositories.user_repo import UserRepository


class AdminMetricsService:
    """Dashboard aggregates for the admin home page.

    All reads are point-in-time and independent — they parallelize
    via `asyncio.gather`. Each task takes its own session from the
    factory because `AsyncSession` is not safe for concurrent use
    within a single session. The shared `session` is retained only
    for the connectivity probe in `_system_health`.
    """

    def __init__(
        self,
        session: AsyncSession,
        redis: Redis,
        session_factory: async_sessionmaker[AsyncSession],
    ) -> None:
        self.session = session
        self.redis = redis
        self._factory = session_factory

    async def _q(self, fn: Callable[[AsyncSession], Awaitable[Any]]) -> Any:
        async with self._factory() as s:
            return await fn(s)

    async def overview(self) -> dict[str, Any]:
        now = datetime.now(UTC)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = start_of_today.replace(day=1)
        thirty_days_ago = start_of_today - timedelta(days=29)
        seven_days_ahead = now + timedelta(days=7)
        prev_month_start = (start_of_month - timedelta(days=1)).replace(day=1)

        (
            member_count,
            admin_count,
            gym_count,
            active_subs,
            checkins_today,
            checkins_mtd,
            revenue_mtd,
            revenue_prev_month,
            pending_payout_total,
            tier_counts,
            last7,
            checkins_30,
            revenue_30,
            signups_30,
            top_gyms,
            recent_signups,
            recent_checkins,
            expiring,
            open_tickets,
            urgent_tickets,
            health,
        ) = await asyncio.gather(
            self._q(lambda s: UserRepository(s).count_by_role(Role.MEMBER)),
            self._q(lambda s: UserRepository(s).count_by_role(Role.ADMIN)),
            self._q(lambda s: GymRepository(s).count_active()),
            self._q(lambda s: SubscriptionRepository(s).count_active()),
            self._q(lambda s: CheckinRepository(s).count_since(start_of_today)),
            self._q(lambda s: CheckinRepository(s).count_since(start_of_month)),
            self._q(lambda s: PaymentRepository(s).sum_succeeded_in_window(start_of_month, None)),
            self._q(lambda s: PaymentRepository(s).sum_succeeded_in_window(prev_month_start, start_of_month)),
            self._q(lambda s: PayoutRepository(s).pending_total()),
            self._q(lambda s: SubscriptionRepository(s).counts_by_tier()),
            self._q(lambda s: CheckinRepository(s).count_per_day_last(days=7, now=now)),
            self._q(lambda s: CheckinRepository(s).count_per_day_since(thirty_days_ago)),
            self._q(lambda s: PaymentRepository(s).succeeded_per_day_since(thirty_days_ago)),
            self._q(lambda s: UserRepository(s).signups_per_day_since(thirty_days_ago)),
            self._q(lambda s: GymRepository(s).top_by_checkins_since(start_of_month, limit=5)),
            self._q(lambda s: UserRepository(s).recent_members(limit=8)),
            self._q(lambda s: CheckinRepository(s).recent_with_user_and_gym(limit=8)),
            self._q(lambda s: SubscriptionRepository(s).count_expiring_between(after=now, before=seven_days_ahead)),
            self._q(lambda s: SupportTicketRepository(s).count_open()),
            self._q(lambda s: SupportTicketRepository(s).count_urgent_open()),
            self._system_health(),
        )

        return {
            "memberCount": member_count,
            "adminCount": admin_count,
            "gymCount": gym_count,
            "activeSubscriptions": active_subs,
            "checkinsToday": checkins_today,
            "checkinsThisMonth": checkins_mtd,
            "revenueMtdJod": revenue_mtd,
            "revenuePreviousMonthJod": revenue_prev_month,
            "pendingPayoutTotalJod": pending_payout_total,
            "subscriptionsByTier": tier_counts,
            "checkinsLast7Days": [{"day": d, "count": c} for d, c in last7],
            "checkinsLast30Days": [{"day": d, "count": c} for d, c in checkins_30],
            "revenueLast30Days": [{"day": d, "total": str(t)} for d, t in revenue_30],
            "signupsLast30Days": [{"day": d, "count": c} for d, c in signups_30],
            "openTicketCount": open_tickets,
            "urgentTicketCount": urgent_tickets,
            "expiringSubscriptionsCount": expiring,
            "topGymsByCheckins": top_gyms,
            "recentSignups": recent_signups,
            "recentCheckins": recent_checkins,
            "systemHealth": health,
        }

    async def _system_health(self) -> dict[str, str]:
        # Probes share the request session — `SELECT 1` isn't worth a
        # fresh pool slot.
        import structlog

        log = structlog.get_logger(__name__)
        db_ok = "ok"
        redis_ok = "ok"
        try:
            await self.session.execute(select(1))
        except SQLAlchemyError as exc:
            log.warning("health.db_probe_failed", error=str(exc))
            db_ok = "error"
        try:
            await self.redis.ping()
        except Exception as exc:
            # Catch-all here is intentional — Redis client raises
            # several unrelated exception types (ConnectionError,
            # TimeoutError, ResponseError, …). The health probe
            # cares only about reach/no-reach, not which kind. But
            # always log so a degraded Redis surfaces in the
            # operator's logs instead of disappearing.
            log.warning("health.redis_probe_failed", error=str(exc))
            redis_ok = "error"
        return {"db": db_ok, "redis": redis_ok, "api": "ok"}


__all__ = ["AdminMetricsService"]
