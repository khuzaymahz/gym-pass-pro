from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

from redis.asyncio import Redis
from sqlalchemy import and_, func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import (
    CheckinStatus,
    PaymentStatus,
    Role,
    SubscriptionStatus,
)
from app.db.models import (
    Checkin,
    Gym,
    Payment,
    Subscription,
    SupportTicket,
    User,
)
from app.repositories.checkin_repo import CheckinRepository
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
        redis: Redis,
    ) -> None:
        self.session = session
        self.users = users
        self.subs = subs
        self.checkins = checkins
        self.payouts = payouts
        self.tickets = tickets
        self.redis = redis

    async def overview(self) -> dict[str, Any]:
        now = datetime.now(timezone.utc)
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = start_of_today.replace(day=1)
        thirty_days_ago = start_of_today - timedelta(days=29)
        seven_days_ahead = now + timedelta(days=7)
        prev_month_start = (start_of_month - timedelta(days=1)).replace(day=1)

        member_count = await self.users.count_by_role(Role.MEMBER)
        admin_count = await self.users.count_by_role(Role.ADMIN)

        gym_count = int(
            (
                await self.session.execute(
                    select(func.count()).select_from(Gym).where(
                        Gym.deleted_at.is_(None)
                    )
                )
            ).scalar_one()
        )

        active_subs = await self.subs.count_active()
        checkins_today = await self.checkins.count_since(start_of_today)
        checkins_mtd = await self.checkins.count_since(start_of_month)

        revenue_mtd = await self._sum_payments(start_of_month, None)
        revenue_prev_month = await self._sum_payments(prev_month_start, start_of_month)

        pending_payout_total = await self.payouts.pending_total()
        tier_counts = await self.subs.counts_by_tier()
        last7 = await self.checkins.count_per_day_last(days=7, now=now)
        checkins_30 = await self._checkins_per_day_since(thirty_days_ago)
        revenue_30 = await self._revenue_per_day_since(thirty_days_ago)
        signups_30 = await self._signups_per_day_since(thirty_days_ago)

        top_gyms = await self._top_gyms_this_month(start_of_month)
        recent_signups = await self._recent_signups(limit=8)
        recent_checkins = await self._recent_checkins(limit=8)
        expiring = await self._expiring_subscriptions(now, seven_days_ahead)

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

    async def _sum_payments(
        self, since: datetime, until: datetime | None
    ) -> Decimal:
        stmt = select(func.coalesce(func.sum(Payment.amount_jod), 0)).where(
            Payment.status == PaymentStatus.SUCCEEDED,
            Payment.created_at >= since,
        )
        if until is not None:
            stmt = stmt.where(Payment.created_at < until)
        return Decimal(str((await self.session.execute(stmt)).scalar_one()))

    async def _checkins_per_day_since(
        self, since: datetime
    ) -> list[tuple[str, int]]:
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

    async def _revenue_per_day_since(
        self, since: datetime
    ) -> list[tuple[str, Decimal]]:
        stmt = (
            select(
                func.date_trunc("day", Payment.created_at).label("day"),
                func.coalesce(func.sum(Payment.amount_jod), 0),
            )
            .where(
                Payment.status == PaymentStatus.SUCCEEDED,
                Payment.created_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), Decimal(str(t))) for d, t in rows]

    async def _signups_per_day_since(
        self, since: datetime
    ) -> list[tuple[str, int]]:
        stmt = (
            select(
                func.date_trunc("day", User.created_at).label("day"),
                func.count(),
            )
            .where(
                User.role == Role.MEMBER,
                User.created_at >= since,
            )
            .group_by("day")
            .order_by("day")
        )
        rows = (await self.session.execute(stmt)).all()
        return [(d.date().isoformat(), int(c)) for d, c in rows]

    async def _top_gyms_this_month(
        self, since: datetime
    ) -> list[dict[str, Any]]:
        stmt = (
            select(
                Gym.id,
                Gym.name_en,
                Gym.name_ar,
                func.count(Checkin.id).label("count"),
            )
            .join(Checkin, Checkin.gym_id == Gym.id)
            .where(
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
                Gym.deleted_at.is_(None),
            )
            .group_by(Gym.id, Gym.name_en, Gym.name_ar)
            .order_by(func.count(Checkin.id).desc())
            .limit(5)
        )
        rows = (await self.session.execute(stmt)).all()
        return [
            {
                "gymId": str(r[0]),
                "nameEn": r[1],
                "nameAr": r[2],
                "count": int(r[3]),
            }
            for r in rows
        ]

    async def _recent_signups(self, limit: int) -> list[dict[str, Any]]:
        stmt = (
            select(User)
            .where(User.role == Role.MEMBER, User.deleted_at.is_(None))
            .order_by(User.created_at.desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return [
            {
                "id": str(u.id),
                "name": u.name,
                "email": u.email,
                "phone": u.phone,
                "createdAt": u.created_at.isoformat(),
            }
            for u in rows
        ]

    async def _recent_checkins(self, limit: int) -> list[dict[str, Any]]:
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

    async def _expiring_subscriptions(
        self, now: datetime, until: datetime
    ) -> int:
        stmt = select(func.count()).select_from(Subscription).where(
            and_(
                Subscription.status == SubscriptionStatus.ACTIVE,
                Subscription.expires_at >= now,
                Subscription.expires_at < until,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def _system_health(self) -> dict[str, str]:
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
