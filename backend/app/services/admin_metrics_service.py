from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any

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
    cleanly via `asyncio.gather`. Each task takes its own session
    from the factory because `AsyncSession` is not safe for
    concurrent use within a single session. The shared `session` is
    kept just for the connectivity probe in `_system_health`.
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

    async def overview(self) -> dict[str, Any]:
        now = datetime.now(UTC)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = start_of_today.replace(day=1)
        thirty_days_ago = start_of_today - timedelta(days=29)
        seven_days_ahead = now + timedelta(days=7)
        prev_month_start = (start_of_month - timedelta(days=1)).replace(day=1)

        async def _members():
            async with self._factory() as s:
                return await UserRepository(s).count_by_role(Role.MEMBER)

        async def _admins():
            async with self._factory() as s:
                return await UserRepository(s).count_by_role(Role.ADMIN)

        async def _gyms():
            async with self._factory() as s:
                return await GymRepository(s).count_active()

        async def _active_subs():
            async with self._factory() as s:
                return await SubscriptionRepository(s).count_active()

        async def _checkins_today():
            async with self._factory() as s:
                return await CheckinRepository(s).count_since(start_of_today)

        async def _checkins_mtd():
            async with self._factory() as s:
                return await CheckinRepository(s).count_since(start_of_month)

        async def _revenue_mtd():
            async with self._factory() as s:
                return await PaymentRepository(s).sum_succeeded_in_window(
                    start_of_month, None
                )

        async def _revenue_prev():
            async with self._factory() as s:
                return await PaymentRepository(s).sum_succeeded_in_window(
                    prev_month_start, start_of_month
                )

        async def _pending_payout():
            async with self._factory() as s:
                return await PayoutRepository(s).pending_total()

        async def _tier_counts():
            async with self._factory() as s:
                return await SubscriptionRepository(s).counts_by_tier()

        async def _last7():
            async with self._factory() as s:
                return await CheckinRepository(s).count_per_day_last(
                    days=7, now=now
                )

        async def _checkins_30():
            async with self._factory() as s:
                return await CheckinRepository(s).count_per_day_since(
                    thirty_days_ago
                )

        async def _revenue_30():
            async with self._factory() as s:
                return await PaymentRepository(s).succeeded_per_day_since(
                    thirty_days_ago
                )

        async def _signups_30():
            async with self._factory() as s:
                return await UserRepository(s).signups_per_day_since(
                    thirty_days_ago
                )

        async def _top_gyms():
            async with self._factory() as s:
                return await GymRepository(s).top_by_checkins_since(
                    start_of_month, limit=5
                )

        async def _recent_signups():
            async with self._factory() as s:
                return await UserRepository(s).recent_members(limit=8)

        async def _recent_checkins():
            async with self._factory() as s:
                return await CheckinRepository(s).recent_with_user_and_gym(
                    limit=8
                )

        async def _expiring():
            async with self._factory() as s:
                return await SubscriptionRepository(s).count_expiring_between(
                    after=now, before=seven_days_ahead
                )

        async def _open_tickets():
            async with self._factory() as s:
                return await SupportTicketRepository(s).count_open()

        async def _urgent_tickets():
            async with self._factory() as s:
                return await SupportTicketRepository(s).count_urgent_open()

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
            _members(),
            _admins(),
            _gyms(),
            _active_subs(),
            _checkins_today(),
            _checkins_mtd(),
            _revenue_mtd(),
            _revenue_prev(),
            _pending_payout(),
            _tier_counts(),
            _last7(),
            _checkins_30(),
            _revenue_30(),
            _signups_30(),
            _top_gyms(),
            _recent_signups(),
            _recent_checkins(),
            _expiring(),
            _open_tickets(),
            _urgent_tickets(),
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
            "checkinsLast7Days": [
                {"day": day, "count": count} for day, count in last7
            ],
            "checkinsLast30Days": [
                {"day": day, "count": count} for day, count in checkins_30
            ],
            "revenueLast30Days": [
                {"day": day, "total": str(total)} for day, total in revenue_30
            ],
            "signupsLast30Days": [
                {"day": day, "count": count} for day, count in signups_30
            ],
            "openTicketCount": open_tickets,
            "urgentTicketCount": urgent_tickets,
            "expiringSubscriptionsCount": expiring,
            "topGymsByCheckins": top_gyms,
            "recentSignups": recent_signups,
            "recentCheckins": recent_checkins,
            "systemHealth": health,
        }

    async def _system_health(self) -> dict[str, str]:
        # Probes use the shared session — connectivity check, not
        # a domain query. Spinning up a fresh session here would
        # waste a pool slot just to do `SELECT 1`.
        db_ok = "ok"
        redis_ok = "ok"
        try:
            await self.session.execute(select(1))
        except SQLAlchemyError:
            db_ok = "error"
        try:
            await self.redis.ping()
        except Exception:
            redis_ok = "error"
        return {"db": db_ok, "redis": redis_ok, "api": "ok"}


__all__ = ["AdminMetricsService"]
