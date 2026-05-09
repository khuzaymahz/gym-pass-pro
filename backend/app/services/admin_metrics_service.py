from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import Role
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.payout_repo import PayoutRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.repositories.user_repo import UserRepository


class AdminMetricsService:
    """Dashboard aggregates. Everything here is a cheap point-in-time read
    against indexed columns; we deliberately skip caching so admins always
    see current state.
    """

    def __init__(
        self,
        session: AsyncSession,
        users: UserRepository,
        subs: SubscriptionRepository,
        checkins: CheckinRepository,
        payouts: PayoutRepository,
        tickets: SupportTicketRepository,
        gyms: GymRepository,
        payments: PaymentRepository,
        redis: Redis,
    ) -> None:
        self.session = session
        self.users = users
        self.subs = subs
        self.checkins = checkins
        self.payouts = payouts
        self.tickets = tickets
        self.gyms = gyms
        self.payments = payments
        self.redis = redis

    async def overview(self) -> dict[str, Any]:
        now = datetime.now(UTC)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = start_of_today.replace(day=1)
        thirty_days_ago = start_of_today - timedelta(days=29)
        seven_days_ahead = now + timedelta(days=7)
        prev_month_start = (start_of_month - timedelta(days=1)).replace(day=1)

        member_count = await self.users.count_by_role(Role.MEMBER)
        admin_count = await self.users.count_by_role(Role.ADMIN)

        gym_count = await self.gyms.count_active()

        active_subs = await self.subs.count_active()
        checkins_today = await self.checkins.count_since(start_of_today)
        checkins_mtd = await self.checkins.count_since(start_of_month)

        revenue_mtd = await self.payments.sum_succeeded_in_window(
            start_of_month, None
        )
        revenue_prev_month = await self.payments.sum_succeeded_in_window(
            prev_month_start, start_of_month
        )

        pending_payout_total = await self.payouts.pending_total()
        tier_counts = await self.subs.counts_by_tier()
        last7 = await self.checkins.count_per_day_last(days=7, now=now)
        checkins_30 = await self.checkins.count_per_day_since(thirty_days_ago)
        revenue_30 = await self.payments.succeeded_per_day_since(thirty_days_ago)
        signups_30 = await self.users.signups_per_day_since(thirty_days_ago)

        top_gyms = await self.gyms.top_by_checkins_since(start_of_month, limit=5)
        recent_signups = await self.users.recent_members(limit=8)
        recent_checkins = await self.checkins.recent_with_user_and_gym(limit=8)
        expiring = await self.subs.count_expiring_between(
            after=now, before=seven_days_ahead
        )

        open_tickets = await self.tickets.count_open()
        urgent_tickets = await self.tickets.count_urgent_open()

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
            "systemHealth": await self._system_health(),
        }

    async def _system_health(self) -> dict[str, str]:
        # System health probe still goes through the raw session because
        # it's not a domain query — `select(1)` against the configured
        # engine is exactly the connectivity check we want, and a repo
        # method here would be ceremony for ceremony's sake.
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
