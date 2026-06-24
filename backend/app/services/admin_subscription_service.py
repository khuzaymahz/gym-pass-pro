from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import SubscriptionStatus, Tier
from app.db.models import Subscription, SubscriptionPause, User
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.pause_service import PauseService
from app.utils.time import add_months, utcnow


class AdminSubscriptionService:
    """Admin-side lifecycle controls over member subscriptions.

    Read + cancel were the original surface; the management verbs
    (extend, adjust visits, change tier, restore, comp, force-resume a
    pause) were added so support can resolve the day-to-day cases that
    previously needed a DB console. Every mutation writes an
    `audit_log` row in the same transaction (the endpoint commits).
    """

    def __init__(
        self,
        subs: SubscriptionRepository,
        plans: PlanRepository,
        pauses: SubscriptionPauseRepository,
        pause_service: PauseService,
        audit: AuditService,
    ) -> None:
        self.subs = subs
        self.plans = plans
        self.pauses = pauses
        self.pause_service = pause_service
        self.audit = audit

    async def list(
        self,
        *,
        status: SubscriptionStatus | None,
        tier: Tier | None,
        q: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[tuple[Subscription, User]], int]:
        return await self.subs.list_paginated(
            status=status, tier=tier, q=q, page=page, page_size=page_size
        )

    async def get(self, sub_id: UUID) -> Subscription:
        sub = await self.subs.get(sub_id)
        if sub is None:
            raise AppError(ErrorCode.SUB_NOT_FOUND, "Subscription not found.")
        return sub

    async def cancel(self, sub_id: UUID, *, actor: Actor) -> Subscription:
        sub = await self.get(sub_id)
        if sub.status == SubscriptionStatus.CANCELLED:
            raise AppError(ErrorCode.SUB_CANCELLED, "Already cancelled.")
        await self.subs.cancel(sub, utcnow())
        await self.audit.log(
            actor=actor,
            action="admin.subscription.cancel",
            entity_type="subscription",
            entity_id=sub.id,
        )
        return sub

    async def extend(self, sub_id: UUID, *, days: int, actor: Actor) -> Subscription:
        """Shift `expires_at` by `days` (positive grants more time, a
        negative value shortens). Used to comp a few days after an
        outage, or to claw back over-credited time."""
        if days == 0:
            raise AppError(ErrorCode.VALIDATION_ERROR, "Days must be non-zero.")
        sub = await self.get(sub_id)
        before = sub.expires_at
        await self.subs.shift_expiry(sub, before + timedelta(days=days))
        await self.audit.log(
            actor=actor,
            action="admin.subscription.extend",
            entity_type="subscription",
            entity_id=sub.id,
            diff={
                "before": {"expires_at": before.isoformat()},
                "after": {
                    "expires_at": sub.expires_at.isoformat(),
                    "days": days,
                },
            },
        )
        return sub

    async def set_visits(self, sub_id: UUID, *, visits_used: int, actor: Actor) -> Subscription:
        """Absolute set of the period visit counter. Credits a member
        back visits a glitched scan consumed, or corrects a miscount."""
        if visits_used < 0:
            raise AppError(ErrorCode.VALIDATION_ERROR, "Visits cannot be negative.")
        sub = await self.get(sub_id)
        before = sub.visits_used
        await self.subs.set_visits(sub, visits_used)
        await self.audit.log(
            actor=actor,
            action="admin.subscription.set_visits",
            entity_type="subscription",
            entity_id=sub.id,
            diff={
                "before": {"visits_used": before},
                "after": {"visits_used": visits_used},
            },
        )
        return sub

    async def change_tier(self, sub_id: UUID, *, tier: Tier, actor: Actor) -> Subscription:
        """Change the subscription's tier snapshot. Takes effect on the
        next check-in (the tier ladder reads this column)."""
        sub = await self.get(sub_id)
        if sub.tier == tier:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Subscription is already on this tier.",
            )
        before = sub.tier
        await self.subs.set_tier(sub, tier)
        await self.audit.log(
            actor=actor,
            action="admin.subscription.change_tier",
            entity_type="subscription",
            entity_id=sub.id,
            diff={
                "before": {"tier": before.value},
                "after": {"tier": tier.value},
            },
        )
        return sub

    async def restore(self, sub_id: UUID, *, actor: Actor) -> Subscription:
        """Bring a cancelled/expired subscription back to ACTIVE. Refuses
        if the member already has another active subscription (the
        one-active-per-user invariant) or if the term has already
        elapsed — extend the expiry first in that case."""
        sub = await self.get(sub_id)
        if sub.status == SubscriptionStatus.ACTIVE:
            raise AppError(ErrorCode.VALIDATION_ERROR, "Subscription is already active.")
        if sub.expires_at <= utcnow():
            raise AppError(
                ErrorCode.SUB_EXPIRED,
                "Term has elapsed — extend the expiry before restoring.",
            )
        existing = await self.subs.active_for_user(sub.user_id)
        if existing is not None:
            raise AppError(
                ErrorCode.SUB_DUPLICATE_ACTIVE,
                "Member already has an active subscription.",
            )
        before = sub.status
        await self.subs.restore(sub)
        await self.audit.log(
            actor=actor,
            action="admin.subscription.restore",
            entity_type="subscription",
            entity_id=sub.id,
            diff={
                "before": {"status": before.value},
                "after": {"status": sub.status.value},
            },
        )
        return sub

    async def comp(self, *, user_id: UUID, plan_id: UUID, actor: Actor) -> Subscription:
        """Grant a free (comped) subscription to a member from an existing
        plan — for goodwill, beta testers, or compensation. Mints an
        ACTIVE row at price 0 with the plan's normal duration. Refuses if
        the member already holds an active subscription."""
        plan = await self.plans.get(plan_id)
        if plan is None:
            raise AppError(ErrorCode.PLAN_NOT_FOUND, "Plan not found.")
        existing = await self.subs.active_for_user(user_id)
        if existing is not None:
            raise AppError(
                ErrorCode.SUB_DUPLICATE_ACTIVE,
                "Member already has an active subscription.",
            )
        now = utcnow()
        sub = await self.subs.create_pending(
            user_id=user_id,
            plan_id=plan.id,
            tier=plan.tier,
            starts_at=now,
            expires_at=add_months(now, plan.duration_months),
            purchased_price_jod=Decimal("0"),
        )
        await self.subs.activate(sub)
        await self.audit.log(
            actor=actor,
            action="admin.subscription.comp",
            entity_type="subscription",
            entity_id=sub.id,
            diff={
                "after": {
                    "user_id": str(user_id),
                    "plan_id": str(plan.id),
                    "tier": plan.tier.value,
                    "expires_at": sub.expires_at.isoformat(),
                    "purchased_price_jod": "0",
                }
            },
        )
        return sub

    async def resume_pause(self, sub_id: UUID, *, actor: Actor) -> SubscriptionPause:
        """Force-end an open pause now (the member's pause is stuck, or
        they asked support to lift it early). Delegates to PauseService so
        the expiry-credit + realtime fan-out match the member path."""
        sub = await self.get(sub_id)
        resumed = await self.pause_service.resume(subscription=sub, actor=actor)
        if resumed is None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "No open pause on this subscription.",
            )
        return resumed

    async def open_pause(self, sub_id: UUID) -> SubscriptionPause | None:
        """The scheduled-or-active pause on a subscription, if any. Lets
        the admin detail view show pause state + offer the resume action."""
        return await self.pauses.open_for_subscription(sub_id)
