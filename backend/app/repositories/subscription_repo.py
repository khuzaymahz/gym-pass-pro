from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import SubscriptionStatus, Tier
from app.db.models import Subscription, User
from app.utils.ids import uuid7


class SubscriptionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, sub_id: UUID) -> Subscription | None:
        return await self.session.get(Subscription, sub_id)

    async def active_for_user(self, user_id: UUID) -> Subscription | None:
        stmt = select(Subscription).where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def create_pending(
        self,
        *,
        user_id: UUID,
        plan_id: UUID,
        tier: Tier,
        starts_at: datetime,
        expires_at: datetime,
    ) -> Subscription:
        sub = Subscription(
            id=uuid7(),
            user_id=user_id,
            plan_id=plan_id,
            tier=tier,
            status=SubscriptionStatus.PENDING,
            starts_at=starts_at,
            expires_at=expires_at,
        )
        self.session.add(sub)
        await self.session.flush()
        return sub

    async def activate(self, sub: Subscription) -> None:
        sub.status = SubscriptionStatus.ACTIVE
        await self.session.flush()

    async def cancel(self, sub: Subscription, now: datetime) -> None:
        sub.status = SubscriptionStatus.CANCELLED
        sub.cancelled_at = now
        await self.session.flush()

    async def shift_expiry(
        self, sub: Subscription, new_expires_at: datetime
    ) -> None:
        """Move the subscription's `expires_at` forward. Used by the
        pause service to credit days a member couldn't use back to the
        end of their term. The check-in service treats `expires_at` as
        the hard ceiling, so a successful shift extends real access.
        """
        sub.expires_at = new_expires_at
        await self.session.flush()

    async def increment_visits(self, sub_id: UUID) -> int:
        """Atomic `visits_used += 1`. Returns new value."""
        stmt = (
            update(Subscription)
            .where(Subscription.id == sub_id)
            .values(visits_used=Subscription.visits_used + 1)
            .returning(Subscription.visits_used)
        )
        result = await self.session.execute(stmt)
        return int(result.scalar_one())

    async def list_paginated(
        self,
        *,
        status: SubscriptionStatus | None = None,
        tier: Tier | None = None,
        q: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[tuple[Subscription, User]], int]:
        conditions: list = []
        if status is not None:
            conditions.append(Subscription.status == status)
        if tier is not None:
            conditions.append(Subscription.tier == tier)
        if q:
            # Escape SQL `%`/`_` wildcards in user input — see
            # user_repo.py for the full rationale.
            safe = q.lower().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            like = f"%{safe}%"
            phone_safe = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            conditions.append(
                or_(
                    func.lower(User.email).like(like, escape="\\"),
                    func.lower(User.name).like(like, escape="\\"),
                    User.phone.like(f"%{phone_safe}%", escape="\\"),
                )
            )

        count_stmt = (
            select(func.count())
            .select_from(Subscription)
            .join(User, User.id == Subscription.user_id)
        )
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = (
            select(Subscription, User)
            .join(User, User.id == Subscription.user_id)
        )
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(Subscription.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(s, u) for s, u in rows], int(total)

    async def count_active(self) -> int:
        stmt = (
            select(func.count())
            .select_from(Subscription)
            .where(Subscription.status == SubscriptionStatus.ACTIVE)
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def counts_by_tier(self) -> dict[str, int]:
        stmt = (
            select(Subscription.tier, func.count())
            .where(Subscription.status == SubscriptionStatus.ACTIVE)
            .group_by(Subscription.tier)
        )
        rows = (await self.session.execute(stmt)).all()
        return {tier.value: int(count) for tier, count in rows}
