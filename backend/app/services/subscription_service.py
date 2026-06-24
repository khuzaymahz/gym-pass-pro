from __future__ import annotations

from decimal import Decimal
from typing import Any
from uuid import UUID

import structlog

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PaymentStatus, SubscriptionStatus
from app.db.models import Payment, Plan, Subscription, User
from app.providers.payments import PaymentProvider
from app.realtime import publish as realtime_publish
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.referral_service import ReferralService
from app.utils.time import add_months, current_period_start, utcnow

log = structlog.get_logger(__name__)


async def _safe_publish(channel: str, payload: dict[str, Any]) -> None:
    """Fire-and-log realtime broadcasts. Publish failures (Redis
    down, pubsub serialization error) must not surface as 5xx to
    the member — the DB write has already committed, the live
    fan-out is a best-effort nice-to-have, and a flaky pubsub
    layer turning subscription purchases into 500s is a much
    bigger incident than a stale tab.
    """
    try:
        await realtime_publish(channel, payload)
    except Exception as exc:
        log.warning(
            "realtime.publish_failed",
            channel=channel,
            payload_type=payload.get("type"),
            error=str(exc),
        )


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
        current_period_visits`, floored at zero. Same shape for every tier
        — tier gates the gym network, not the visit count.
        """
        sub = await self.subs.active_for_user(user.id)
        if sub is None:
            return None, None, None, None
        plan = await self.plans.get(sub.plan_id)
        if plan is None:
            return sub, None, None, plan
        period_start = current_period_start(sub.starts_at, utcnow())
        period_visits = await self.checkins.count_success_since_for_user(user.id, period_start)
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
        # Serialize concurrent purchase attempts from the same user
        # so a double-tap on Pay / two open tabs can't both pass the
        # active-sub read check, charge twice, and crash on the
        # unique constraint at activate-time. Lock auto-releases at
        # transaction end. See SubscriptionRepository.lock_user_for_purchase.
        await self.subs.lock_user_for_purchase(user.id)
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
            purchased_price_jod=plan.price_jod,
        )

        await self._charge_and_activate(
            sub=sub,
            plan=plan,
            payment_method=payment_method,
            payment_method_id=payment_method_id,
            extra_raw=None,
            actor=actor,
            audit_action="subscription.purchase",
            audit_diff={"plan_id": str(plan.id), "tier": plan.tier.value},
        )

        await _safe_publish(
            f"user/{user.id}",
            {
                "type": "subscription.created",
                "subscriptionId": str(sub.id),
                "tier": plan.tier.value,
            },
        )
        return sub

    async def _charge_and_activate(
        self,
        *,
        sub: Subscription,
        plan: Plan,
        payment_method: str,
        payment_method_id: UUID | None,
        extra_raw: dict[str, Any] | None,
        actor: Actor,
        audit_action: str,
        audit_diff: dict[str, Any],
    ) -> None:
        """Charge for `sub`, record the payment row, then flip the
        subscription to ACTIVE with audit + referral conversion. Shared
        by `purchase()` and `replace()` — the only differences between
        those flows are the audit action/diff, the extra `raw_response`
        fields, and the realtime payload, which the callers own.

        If the charge declines, raises PAYMENT_DECLINED. If the charge
        succeeds but activation fails, refunds via
        `_compensate_failed_activation` and re-raises PAYMENT_GATEWAY_ERROR
        so the caller never double-charges on retry.
        """
        result = await self.payment_provider.charge(
            amount_jod=plan.price_jod,
            method=payment_method,
            idempotency_key=str(sub.id),
        )

        status = PaymentStatus.SUCCEEDED if result.status == "succeeded" else PaymentStatus.FAILED
        # Stamp the saved-method id into raw_response when the caller supplied
        # one — keeps the payments audit trail self-contained without
        # cluttering the dedicated columns. Mobile reads payments back via
        # admin-only endpoints, so this is for ops, not the member UI.
        raw = dict(result.raw or {})
        if payment_method_id is not None:
            raw["paymentMethodId"] = str(payment_method_id)
        if extra_raw is not None:
            raw.update(extra_raw)
        payment = await self.payments.create(
            subscription_id=sub.id,
            amount_jod=plan.price_jod,
            method=self._coerce_method(payment_method),
            gateway_txn_id=result.gateway_txn_id,
            status=status,
            raw_response=raw,
            processed_at=utcnow(),
        )

        if status != PaymentStatus.SUCCEEDED:
            raise AppError(ErrorCode.PAYMENT_DECLINED, "Payment declined.")

        # Charge succeeded. Try to flip the subscription to ACTIVE
        # + record audit + fire referral conversion. If ANY of
        # those raise (DB hiccup, unique-constraint race, audit-
        # log partition write fails, etc.) we MUST refund — the
        # member has been charged for a subscription that won't
        # exist. Compensation path:
        #   1. Call provider.refund() with an idempotent key.
        #   2. Mark the payment row REFUNDED (or stamp it with
        #      a "refund attempted but failed" flag for ops).
        #   3. Audit at high priority so ops sees the orphan.
        #   4. Re-raise as PAYMENT_GATEWAY_ERROR so the caller
        #      knows something went wrong post-charge — they
        #      should NOT retry, which would double-charge.
        try:
            await self.subs.activate(sub)
            await self.audit.log(
                actor=actor,
                action=audit_action,
                entity_type="subscription",
                entity_id=sub.id,
                diff=audit_diff,
            )
            # Convert any pending referral on the invited user's first paid
            # subscription. Safe to call unconditionally — no-op if no row.
            await self.referrals.mark_converted_if_pending(sub.user_id)
        except Exception as activation_err:
            await self._compensate_failed_activation(
                payment=payment,
                amount=plan.price_jod,
                idempotency_key=f"refund:{sub.id}",
                actor=actor,
                entity_type="subscription",
                entity_id=sub.id,
                activation_err=activation_err,
            )
            raise AppError(
                ErrorCode.PAYMENT_GATEWAY_ERROR,
                "We charged your card but couldn't activate your "
                "subscription. The payment has been refunded — "
                "please try again or contact support.",
            ) from activation_err

    async def _compensate_failed_activation(
        self,
        *,
        payment: Payment,
        amount: Decimal,
        idempotency_key: str,
        actor: Actor,
        entity_type: str,
        entity_id: UUID,
        activation_err: Exception,
    ) -> None:
        """Money-back compensation when a charge succeeded but the
        post-charge mutation failed. Shared between the
        subscription and day-pass purchase flows (see
        `DayPassService.purchase` for the parallel call). Always
        leaves an audit-log entry so ops can chase up; never
        re-raises (the caller raises PAYMENT_GATEWAY_ERROR).
        """
        refund_succeeded = False
        refund_txn_id: str | None = None
        refund_raw: dict[str, Any] = {}
        refund_call_failed: Exception | None = None
        try:
            refund = await self.payment_provider.refund(
                gateway_txn_id=payment.gateway_txn_id or "",
                amount_jod=Decimal(amount),
                idempotency_key=idempotency_key,
            )
            refund_succeeded = refund.status == "succeeded"
            refund_txn_id = refund.refund_txn_id
            refund_raw = dict(refund.raw or {})
        except Exception as refund_err:
            refund_call_failed = refund_err

        try:
            await self.payments.mark_refunded(
                payment,
                refund_txn_id=refund_txn_id,
                raw_refund=refund_raw or {"refund_call_failed": str(refund_call_failed)},
                refund_failed=not refund_succeeded,
            )
        except Exception as mark_err:
            # Even the bookkeeping update failed. Audit log is the
            # last line of defence — keep going.
            log.error(
                "payment.mark_refunded_failed",
                entity_type=entity_type,
                entity_id=str(entity_id),
                err=str(mark_err),
            )

        await self.audit.log(
            actor=actor,
            action=f"{entity_type}.activation_failed_after_charge",
            entity_type=entity_type,
            entity_id=entity_id,
            diff={
                "payment_id": str(payment.id),
                "activation_error": str(activation_err)[:512],
                "refund_succeeded": refund_succeeded,
                "refund_txn_id": refund_txn_id,
                "refund_call_failed": (
                    str(refund_call_failed)[:512] if refund_call_failed is not None else None
                ),
            },
        )
        log.error(
            "payment.compensation_required" if not refund_succeeded else "payment.compensated",
            entity_type=entity_type,
            entity_id=str(entity_id),
            payment_id=str(payment.id),
            refund_succeeded=refund_succeeded,
        )

    async def cancel(self, *, sub_id: UUID, user: User, actor: Actor) -> Subscription:
        sub = await self.subs.get(sub_id)
        if sub is None or sub.user_id != user.id:
            raise AppError(ErrorCode.SUB_NOT_FOUND, "Subscription not found.")
        if sub.status == SubscriptionStatus.CANCELLED:
            raise AppError(ErrorCode.SUB_CANCELLED, "Subscription already cancelled.")
        await self.subs.cancel(sub, utcnow())
        await self.audit.log(
            actor=actor,
            action="subscription.cancel",
            entity_type="subscription",
            entity_id=sub.id,
        )
        await _safe_publish(
            f"user/{user.id}",
            {
                "type": "subscription.canceled",
                "subscriptionId": str(sub.id),
            },
        )
        return sub

    async def replace(
        self,
        *,
        user: User,
        new_plan_id: UUID,
        payment_method: str,
        payment_method_id: UUID | None = None,
        actor: Actor,
    ) -> Subscription:
        """Atomically cancel the user's current subscription and buy a new
        plan in a single DB transaction.

        Replaces the mobile-side two-call flow (`cancel` then `purchase`)
        which left a window where a network drop after the cancel but
        before the purchase landed the member in a paid-cancelled-then-no-
        replacement state. Here both mutations share one transaction and
        one purchase lock: either both land or neither does.

        Semantics:
          - The current active subscription, if any, is cancelled inline.
          - The new plan is purchased through the same code path
            `purchase()` uses (lock → existence check → create_pending →
            charge → activate → audit → referral conversion → publish).
          - The active-sub existence check inside `purchase()` is skipped
            here because we've just cancelled it inside the same lock —
            no race window.
          - If the charge fails, the cancellation is rolled back with
            the rest of the transaction by the route layer (the
            session.commit() at the route is the only commit point).
        """
        await self.subs.lock_user_for_purchase(user.id)

        existing = await self.subs.active_for_user(user.id)
        now = utcnow()
        if existing is not None:
            if existing.plan_id == new_plan_id:
                raise AppError(
                    ErrorCode.SUB_DUPLICATE_ACTIVE,
                    "You're already on this plan.",
                )
            await self.subs.cancel(existing, now)
            await self.audit.log(
                actor=actor,
                action="subscription.cancel_for_replace",
                entity_type="subscription",
                entity_id=existing.id,
                diff={"new_plan_id": str(new_plan_id)},
            )

        plan = await self.plans.get(new_plan_id)
        if plan is None:
            raise AppError(ErrorCode.PLAN_NOT_FOUND, "Plan not found.")
        if not plan.is_active:
            raise AppError(ErrorCode.PLAN_INACTIVE, "Plan is inactive.")

        sub = await self.subs.create_pending(
            user_id=user.id,
            plan_id=plan.id,
            tier=plan.tier,
            starts_at=now,
            expires_at=add_months(now, plan.duration_months),
            purchased_price_jod=plan.price_jod,
        )

        replaced_id = str(existing.id) if existing is not None else None
        await self._charge_and_activate(
            sub=sub,
            plan=plan,
            payment_method=payment_method,
            payment_method_id=payment_method_id,
            extra_raw=({"replacedSubscriptionId": replaced_id} if existing is not None else None),
            actor=actor,
            audit_action="subscription.replace",
            audit_diff={
                "plan_id": str(plan.id),
                "tier": plan.tier.value,
                "replaced_subscription_id": replaced_id,
            },
        )

        await _safe_publish(
            f"user/{user.id}",
            {
                "type": "subscription.replaced",
                "subscriptionId": str(sub.id),
                "replacedSubscriptionId": replaced_id,
                "tier": plan.tier.value,
            },
        )
        return sub

    @staticmethod
    def _coerce_method(raw: str) -> PaymentMethod:  # noqa: F821
        from app.db.enums import PaymentMethod

        try:
            return PaymentMethod(raw)
        except ValueError:
            return PaymentMethod.MOCK
