from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime
from uuid import UUID

from sqlalchemy import and_, func, or_, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import SubscriptionStatus, Tier
from app.db.models import Plan, Subscription, User
from app.utils.ids import uuid7


class SubscriptionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, sub_id: UUID) -> Subscription | None:
        return await self.session.get(Subscription, sub_id)

    async def get_many(self, ids: Iterable[UUID]) -> dict[UUID, Subscription]:
        """Bulk-load subscriptions by id. Returns a mapping for O(1) lookup
        from a list of pause rows. Used by the pause sweep so a
        per-row `subs.get()` doesn't fan out into N round-trips.
        """
        ids_list = list(ids)
        if not ids_list:
            return {}
        stmt = select(Subscription).where(Subscription.id.in_(ids_list))
        rows = (await self.session.execute(stmt)).scalars().all()
        return {row.id: row for row in rows}

    async def lock_user_for_purchase(self, user_id: UUID) -> None:
        """Postgres advisory lock keyed on user_id, held for the rest
        of this transaction. Serializes concurrent purchase flows so
        a double-tap on Pay (or two open tabs) can't both pass the
        active-sub check, charge twice, and crash on the unique
        constraint at activate-time — which would leave a stranded
        payment without a paired subscription.

        `pg_advisory_xact_lock` blocks if another transaction holds
        the same key; releases automatically at commit/rollback.
        """
        await self.session.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:k))"),
            {"k": f"sub-purchase:{user_id}"},
        )

    async def active_for_user(self, user_id: UUID) -> Subscription | None:
        stmt = select(Subscription).where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def lock_active_for_user(self, user_id: UUID) -> Subscription | None:
        """Same as `active_for_user` but takes `FOR UPDATE` on the row.

        Held until the surrounding transaction commits, this serializes
        concurrent check-ins by the same user across any number of
        gyms. Without the lock, two `asyncio.gather`'d scans both read
        the visit-budget count, both pass the gate, and both INSERT —
        the visit budget gets exceeded by one (or more) every time the
        member has two devices, two tabs, or just a flaky network
        retrying mid-scan.

        Returns the locked row, or None if the user has no active
        subscription (which short-circuits the day-pass and tier
        ladders in `CheckinService.scan` without leaving a held lock).
        """
        stmt = (
            select(Subscription)
            .where(
                Subscription.user_id == user_id,
                Subscription.status == SubscriptionStatus.ACTIVE,
            )
            .with_for_update()
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
        purchased_price_jod: object | None = None,
    ) -> Subscription:
        # `purchased_price_jod` is a snapshot of `Plan.price_jod` at
        # purchase time. Once a price edit lands on the Plan row
        # (admin_plan_service.update), historical receipts + the
        # admin user-detail view read from this snapshot — never
        # back-join Plan to render a historical amount.
        sub = Subscription(
            id=uuid7(),
            user_id=user_id,
            plan_id=plan_id,
            tier=tier,
            status=SubscriptionStatus.PENDING,
            starts_at=starts_at,
            expires_at=expires_at,
            purchased_price_jod=purchased_price_jod,
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

    async def list_expired_active(self, *, now: datetime, limit: int) -> list[Subscription]:
        """Return ACTIVE subscriptions whose `expires_at` is in the past.

        Used by the `expire_subscriptions` Celery beat task. The `limit`
        keeps a single sweep bounded; the beat schedule re-fires on a
        regular cadence so a backlog drains across multiple invocations
        rather than one giant transaction. Ordered by `expires_at` so
        the longest-overdue rows are flipped first.
        """
        stmt = (
            select(Subscription)
            .where(
                Subscription.status == SubscriptionStatus.ACTIVE,
                Subscription.expires_at < now,
            )
            .order_by(Subscription.expires_at.asc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return list(rows)

    async def expire(self, sub: Subscription) -> None:
        """Flip an ACTIVE subscription to EXPIRED. Caller is responsible
        for the audit-log entry and the surrounding transaction commit.
        """
        sub.status = SubscriptionStatus.EXPIRED
        await self.session.flush()

    async def shift_expiry(self, sub: Subscription, new_expires_at: datetime) -> None:
        """Move the subscription's `expires_at` forward. Used by the
        pause service to credit days a member couldn't use back to the
        end of their term. The check-in service treats `expires_at` as
        the hard ceiling, so a successful shift extends real access.
        """
        sub.expires_at = new_expires_at
        await self.session.flush()

    async def set_visits(self, sub: Subscription, visits_used: int) -> None:
        """Absolute set of `visits_used`. Used by admin support to credit
        a member back visits a glitched check-in consumed, or to correct
        a miscount. Caller owns the audit-log entry + commit."""
        sub.visits_used = visits_used
        await self.session.flush()

    async def set_tier(self, sub: Subscription, tier: Tier) -> None:
        """Change the subscription's denormalized tier snapshot. The
        check-in tier ladder reads this column, so an admin upgrade/
        downgrade takes effect on the next scan. Caller owns audit + commit."""
        sub.tier = tier
        await self.session.flush()

    async def restore(self, sub: Subscription) -> None:
        """Flip a cancelled/expired subscription back to ACTIVE and clear
        the cancellation stamp. Caller must first confirm the user has no
        other active subscription (the partial unique index will raise
        otherwise) and that `expires_at` is still in the future. Caller
        owns the audit-log entry + commit."""
        sub.status = SubscriptionStatus.ACTIVE
        sub.cancelled_at = None
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

        stmt = select(Subscription, User).join(User, User.id == Subscription.user_id)
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

    async def count_expiring_between(self, *, after: datetime, before: datetime) -> int:
        """Count of ACTIVE subscriptions expiring in [`after`, `before`).
        Used by the admin overview to flag the at-risk set for a
        renewal nudge."""
        stmt = (
            select(func.count())
            .select_from(Subscription)
            .where(
                and_(
                    Subscription.status == SubscriptionStatus.ACTIVE,
                    Subscription.expires_at >= after,
                    Subscription.expires_at < before,
                )
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def history_for_user(self, user_id: UUID) -> list[tuple[Subscription, Plan | None]]:
        """Full subscription history for a user joined with the plan
        snapshot at the time of purchase. Outer-joined so a deleted
        plan still surfaces the row (with `plan=None`) — admins still
        need to see the tier history even if the plan was retired."""
        stmt = (
            select(Subscription, Plan)
            .join(Plan, Plan.id == Subscription.plan_id, isouter=True)
            .where(Subscription.user_id == user_id)
            .order_by(Subscription.created_at.desc())
        )
        rows = (await self.session.execute(stmt)).all()
        return [(s, p) for s, p in rows]
