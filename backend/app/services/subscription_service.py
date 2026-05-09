from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PaymentStatus, SubscriptionStatus
from app.db.models import Plan, Subscription, User
from app.providers.payments import PaymentProvider
from app.realtime import publish as realtime_publish
from app.repositories.payment_repo import PaymentRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.referral_service import ReferralService
from app.repositories.checkin_repo import CheckinRepository
from app.utils.time import add_months, current_period_start, utcnow


class SubscriptionService:
    def __init__(
        self,
        subs: SubscriptionRepository,
        plans: PlanRepository,
        payments: PaymentRepository,
        checkins: CheckinRepository,
        payment_provider: PaymentProvider,
        audit: AuditService,
        referrals: ReferralService,
    ) -> None:
        self.subs = subs
        self.plans = plans
        self.payments = payments
        self.checkins = checkins
        self.payment_provider = payment_provider
        self.audit = audit
        self.referrals = referrals

    async def current(
        self, user: User
    ) -> tuple[Subscription | None, int | None, int | None, Plan | None]:
        """Return `(subscription, current_period_visits, remaining_visits, plan)`.

        `current_period_visits` is computed against indexed `checkins` rows
        anchored at `current_period_start(sub.starts_at, now)` — independent
        of the stored `subscriptions.visits_used` counter, which is the
        denormalized lifetime total. `remaining_visits` is `monthly_visits -
        current_period_visits`, floored at zero. Diamond returns `None` for
        both since its budget is unlimited.
        """
        sub = await self.subs.active_for_user(user.id)
        if sub is None:
            return None, None, None, None
        plan = await self.plans.get(sub.plan_id)
        if plan is None or sub.tier.value == "diamond":
            return sub, None, None, plan
        period_start = current_period_start(sub.starts_at, utcnow())
        period_visits = await self.checkins.count_success_since_for_user(
            user.id, period_start
        )
        remaining = max(0, plan.monthly_visits - period_visits)
        return sub, period_visits, remaining, plan

    async def purchase(
        self,
        *,
        user: User,
        plan_id: UUID,
        payment_method: str,
        payment_method_id: UUID | None = None,
        actor: Actor,
    ) -> Subscription:
        existing = await self.subs.active_for_user(user.id)
        if existing is not None:
            raise AppError(
                ErrorCode.SUB_DUPLICATE_ACTIVE,
                "User already has an active subscription.",
            )
        plan = await self.plans.get(plan_id)
        if plan is None:
            raise AppError(ErrorCode.PLAN_NOT_FOUND, "Plan not found.")
        if not plan.is_active:
            raise AppError(ErrorCode.PLAN_INACTIVE, "Plan is inactive.")

        now = utcnow()
        sub = await self.subs.create_pending(
            user_id=user.id,
            plan_id=plan.id,
            tier=plan.tier,
            starts_at=now,
            expires_at=add_months(now, plan.duration_months),
        )

        result = await self.payment_provider.charge(
            amount_jod=plan.price_jod,
            method=payment_method,
            idempotency_key=str(sub.id),
        )

        status = (
            PaymentStatus.SUCCEEDED
            if result.status == "succeeded"
            else PaymentStatus.FAILED
        )
        # Stamp the saved-method id into raw_response when the caller supplied
        # one — keeps the payments audit trail self-contained without
        # cluttering the dedicated columns. Mobile reads payments back via
        # admin-only endpoints, so this is for ops, not the member UI.
        raw = dict(result.raw or {})
        if payment_method_id is not None:
            raw["paymentMethodId"] = str(payment_method_id)
        await self.payments.create(
            subscription_id=sub.id,
            amount_jod=plan.price_jod,
            method=self._coerce_method(payment_method),
            gateway_txn_id=result.gateway_txn_id,
            status=status,
            raw_response=raw,
            processed_at=utcnow(),
        )

        if status == PaymentStatus.SUCCEEDED:
            await self.subs.activate(sub)
            await self.audit.log(
                actor=actor, action="subscription.purchase",
                entity_type="subscription", entity_id=sub.id,
                diff={"plan_id": str(plan.id), "tier": plan.tier.value},
            )
            # Convert any pending referral on the invited user's first paid
            # subscription. Safe to call unconditionally — no-op if no row.
            await self.referrals.mark_converted_if_pending(user.id)
            # Live fan-out so any other tab/device the member has open
            # re-fetches /me/subscription instead of waiting for a
            # manual pull.
            await realtime_publish(
                f"user/{user.id}",
                {
                    "type": "subscription.created",
                    "subscriptionId": str(sub.id),
                    "tier": plan.tier.value,
                },
            )
            return sub
        raise AppError(ErrorCode.PAYMENT_DECLINED, "Payment declined.")

    async def cancel(self, *, sub_id: UUID, user: User, actor: Actor) -> Subscription:
        sub = await self.subs.get(sub_id)
        if sub is None or sub.user_id != user.id:
            raise AppError(ErrorCode.SUB_NOT_FOUND, "Subscription not found.")
        if sub.status == SubscriptionStatus.CANCELLED:
            raise AppError(ErrorCode.SUB_CANCELLED, "Subscription already cancelled.")
        await self.subs.cancel(sub, utcnow())
        await self.audit.log(
            actor=actor, action="subscription.cancel",
            entity_type="subscription", entity_id=sub.id,
        )
        await realtime_publish(
            f"user/{user.id}",
            {
                "type": "subscription.canceled",
                "subscriptionId": str(sub.id),
            },
        )
        return sub

    @staticmethod
    def _coerce_method(raw: str) -> "PaymentMethod":  # noqa: F821
        from app.db.enums import PaymentMethod

        try:
            return PaymentMethod(raw)
        except ValueError:
            return PaymentMethod.MOCK
