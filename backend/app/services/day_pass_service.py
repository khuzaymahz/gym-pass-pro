from __future__ import annotations

from datetime import datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Any
from uuid import UUID

import structlog

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    AudienceGender,
    DayPassStatus,
    PaymentMethod,
    PaymentStatus,
)
from app.db.models import DayPass, DayPassOffering, Gym, User
from app.providers.payments import PaymentProvider
from app.realtime import publish as realtime_publish
from app.repositories.day_pass_repo import (
    DayPassOfferingRepository,
    DayPassRepository,
)
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow

log = structlog.get_logger(__name__)


async def _safe_publish(channel: str, payload: dict[str, Any]) -> None:
    """Fire-and-log realtime broadcasts — payment already committed,
    a flaky pubsub layer must not turn a successful purchase into a
    500 to the member. Same pattern as SubscriptionService.
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


# Quantize money to 2 decimal places with banker's-rounding-free
# half-up — matches what JOD invoices show.
_JOD = Decimal("0.01")


def _q(d: Decimal) -> Decimal:
    return d.quantize(_JOD, rounding=ROUND_HALF_UP)


class DayPassService:
    """Orchestrates the day-pass lifecycle.

    Three external operations:
      * `upsert_offering` — partner edits the per-gym config.
      * `purchase` — member buys a pass for a specific gym.
      * `list_for_user` — member's "Active passes" surface.

    A fourth operation, `redeem`, is invoked by the check-in
    service when a scan resolves a (user, gym) pair to an active
    pass. It lives here so the audit log entry and status
    transition stay co-located with the rest of the lifecycle.
    """

    def __init__(
        self,
        *,
        offerings: DayPassOfferingRepository,
        passes: DayPassRepository,
        gyms: GymRepository,
        subs: SubscriptionRepository,
        payments: PaymentRepository,
        payment_provider: PaymentProvider,
        audit: AuditService,
    ) -> None:
        self.offerings = offerings
        self.passes = passes
        self.gyms = gyms
        self.subs = subs
        self.payments = payments
        self.payment_provider = payment_provider
        self.audit = audit

    # ------------------------------------------------------------------
    # Partner: upsert the offering for a gym
    # ------------------------------------------------------------------
    async def upsert_offering(
        self,
        *,
        gym: Gym,
        is_enabled: bool,
        price_jod: Decimal,
        daily_cap: int | None,
        audience_gender_override: AudienceGender | None,
        actor: Actor,
    ) -> DayPassOffering:
        """Create or update the offering. Partner-callable only.

        Platform fee and validity hours are admin-owned: this
        method preserves their existing values on an update, and
        relies on the table defaults (10%, 24h) when creating a
        brand-new offering. The partner cannot reach those columns
        through this entry point.

        Audit'd on every save with a diff payload so we can answer
        "who turned this on / changed the price" from the audit
        trail alone.
        """
        before = await self.offerings.for_gym(gym.id)
        offering = await self.offerings.upsert(
            gym_id=gym.id,
            is_enabled=is_enabled,
            price_jod=_q(price_jod),
            daily_cap=daily_cap,
            audience_gender_override=audience_gender_override,
        )
        diff: dict[str, Any] = {
            "is_enabled": is_enabled,
            "price_jod": str(offering.price_jod),
            "daily_cap": daily_cap,
            "audience_gender_override": (
                audience_gender_override.value if audience_gender_override else None
            ),
        }
        if before is not None:
            diff["previous"] = {
                "is_enabled": before.is_enabled,
                "price_jod": str(before.price_jod),
                "daily_cap": before.daily_cap,
            }
        await self.audit.log(
            actor=actor,
            action=(
                "day_pass_offering.create"
                if before is None
                else "day_pass_offering.update"
            ),
            entity_type="day_pass_offering",
            entity_id=offering.id,
            diff=diff,
        )
        return offering

    # ------------------------------------------------------------------
    # Member: purchase a pass for a specific gym
    # ------------------------------------------------------------------
    async def purchase(
        self,
        *,
        user: User,
        gym_slug: str,
        payment_method: str,
        payment_method_id: UUID | None = None,
        actor: Actor,
    ) -> DayPass:
        """End-to-end purchase: validate -> charge -> activate.

        Refuses:
          * Subscriber already has an active plan covering the
            tier (use the subscription's visits instead).
          * No offering for the gym, or offering is disabled.
          * Audience-gender mismatch on the gym or the
            offering-level override.
          * Daily cap reached on the offering.
          * Existing unexpired active pass for the same (user, gym).

        On payment success: creates the matching `Payment` row,
        activates the pass, writes audit, fires realtime broadcast.

        On payment failure: leaves the pass row PENDING and raises
        PAYMENT_DECLINED. The PENDING row stays in the DB as a
        record of the attempt (visible to admin via the audit-log
        action `day_pass.purchase_failed`).
        """
        # Serialize concurrent attempts for the same user — same
        # idiom as SubscriptionService. A double-tap on Pay must
        # not charge twice.
        await self.passes.lock_user_for_purchase(user.id)

        gym = await self.gyms.get_by_slug(gym_slug)
        if gym is None or not gym.is_active or gym.deleted_at is not None:
            raise AppError(ErrorCode.GYM_NOT_FOUND, "Gym not found.")

        offering = await self.offerings.for_gym(gym.id)
        if offering is None or not offering.is_enabled:
            raise AppError(
                ErrorCode.DAY_PASS_NOT_AVAILABLE,
                "This gym does not offer day passes right now.",
            )

        # Subscribers whose tier ALREADY COVERS this gym don't buy
        # day passes — they should just check in via their plan.
        # But subscribers at a lower tier (e.g. Silver looking at a
        # Platinum gym) are valid customers for a one-off pass: a
        # low-friction trial of the higher-tier network that often
        # converts into a plan upgrade. The check refuses only the
        # already-covered case; the locked-tier case falls through
        # to the rest of the validation.
        sub = await self.subs.active_for_user(user.id)
        if sub is not None and sub.tier.rank >= gym.required_tier.rank:
            raise AppError(
                ErrorCode.DAY_PASS_ALREADY_SUBSCRIBED,
                "Your subscription already covers this gym.",
            )

        # Audience check — offering override wins over the gym's
        # default audience. Mirrors the resolution in
        # gym_service.audience_visible_for so the day-pass
        # ladies-night carve-out works.
        effective_audience = (
            offering.audience_gender_override or gym.audience_gender
        )
        if not _audience_match(effective_audience, user.gender):
            raise AppError(
                ErrorCode.DAY_PASS_AUDIENCE_LOCKED,
                "This gym restricts entry by gender; this day pass isn't "
                "available to your account.",
            )

        # Daily cap (cheap pre-flight check; concurrent attempts
        # are also blocked by the advisory lock above).
        if offering.daily_cap is not None:
            now = utcnow()
            day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            sold_today = await self.passes.count_for_offering_on_date(
                offering_id=offering.id,
                day_start=day_start,
                day_end=day_end,
            )
            if sold_today >= offering.daily_cap:
                raise AppError(
                    ErrorCode.DAY_PASS_DAILY_CAP_REACHED,
                    "Day passes for this gym have sold out for today.",
                )

        # Refuse stacking — an existing active pass for the same
        # (user, gym) covers them already. Refresh-to-buy on the
        # gym profile would otherwise produce duplicates.
        now = utcnow()
        existing = await self.passes.active_for_user_gym(
            user_id=user.id, gym_id=gym.id, now=now
        )
        if existing is not None:
            raise AppError(
                ErrorCode.DAY_PASS_DUPLICATE_ACTIVE,
                "You already have an active pass for this gym.",
            )

        # Snapshot the price + fee + net amounts onto the pass row,
        # so a future offering edit doesn't rewrite history.
        price = _q(offering.price_jod)
        fee = _q(price * offering.platform_fee_pct / Decimal("100"))
        # Floor net at zero just in case a 100% fee config slips
        # through — better a 0 JOD payout than a negative one.
        net = _q(max(price - fee, Decimal("0")))
        # Both purchased_at and expires_at come from `now` (the same
        # Python timestamp) so `expires_at - purchased_at` is exactly
        # `validity_hours`, not "validity_hours minus a few ms of
        # INSERT latency".
        expires_at = now + timedelta(hours=offering.validity_hours)

        day_pass = await self.passes.create_pending(
            user_id=user.id,
            gym_id=gym.id,
            offering_id=offering.id,
            price_jod=price,
            platform_fee_jod=fee,
            net_amount_jod=net,
            purchased_at=now,
            expires_at=expires_at,
        )

        # Charge via the same provider as subscriptions. The
        # idempotency key is the pass id so a retried request
        # (network blip on the client side) won't double-charge.
        result = await self.payment_provider.charge(
            amount_jod=price,
            method=payment_method,
            idempotency_key=str(day_pass.id),
        )

        status = (
            PaymentStatus.SUCCEEDED
            if result.status == "succeeded"
            else PaymentStatus.FAILED
        )
        raw = dict(result.raw or {})
        raw["sku"] = "day_pass"
        raw["dayPassId"] = str(day_pass.id)
        raw["gymId"] = str(gym.id)
        if payment_method_id is not None:
            raw["paymentMethodId"] = str(payment_method_id)

        payment = await self.payments.create(
            subscription_id=None,
            amount_jod=price,
            method=_coerce_method(payment_method),
            gateway_txn_id=result.gateway_txn_id,
            status=status,
            raw_response=raw,
            processed_at=utcnow(),
        )

        if status != PaymentStatus.SUCCEEDED:
            await self.audit.log(
                actor=actor,
                action="day_pass.purchase_failed",
                entity_type="day_pass",
                entity_id=day_pass.id,
                diff={
                    "gym_id": str(gym.id),
                    "amount_jod": str(price),
                    "gateway_txn_id": result.gateway_txn_id,
                },
            )
            raise AppError(ErrorCode.PAYMENT_DECLINED, "Payment declined.")

        await self.passes.activate(day_pass, payment_id=payment.id)
        await self.audit.log(
            actor=actor,
            action="day_pass.purchase",
            entity_type="day_pass",
            entity_id=day_pass.id,
            diff={
                "gym_id": str(gym.id),
                "offering_id": str(offering.id),
                "price_jod": str(price),
                "platform_fee_jod": str(fee),
                "net_amount_jod": str(net),
                "expires_at": expires_at.isoformat(),
            },
        )
        await _safe_publish(
            f"user/{user.id}",
            {
                "type": "day_pass.purchased",
                "dayPassId": str(day_pass.id),
                "gymId": str(gym.id),
                "expiresAt": expires_at.isoformat(),
            },
        )
        return day_pass

    # ------------------------------------------------------------------
    # Member: list active passes
    # ------------------------------------------------------------------
    async def list_for_user(self, user: User) -> list[DayPass]:
        return await self.passes.list_for_user(user_id=user.id)

    # ------------------------------------------------------------------
    # Internal: redeem on check-in (called from CheckinService)
    # ------------------------------------------------------------------
    async def redeem(
        self, day_pass: DayPass, *, checkin_id: UUID, actor: Actor
    ) -> None:
        """Mark a pass as used after a successful check-in.

        Called from `CheckinService.scan` once the check-in row is
        persisted. The audit trail records both the check-in id
        (so the redemption is traceable to the exact scan) and
        the pass id (so the pass's full lifecycle is recoverable
        from the audit log alone).
        """
        used_at = utcnow()
        await self.passes.mark_used(
            day_pass,
            checkin_id=checkin_id,
            used_at=used_at,
        )
        await self.audit.log(
            actor=actor,
            action="day_pass.redeem",
            entity_type="day_pass",
            entity_id=day_pass.id,
            diff={
                "checkin_id": str(checkin_id),
                "used_at": used_at.isoformat(),
            },
        )


def _audience_match(audience: AudienceGender, gender: Any) -> bool:
    """True when a member of `gender` is allowed at a venue with
    `audience`. Mirrors gym_service.audience_visible_for; kept
    inline here so the day-pass service doesn't import a sibling
    service just for one check.
    """
    if audience == AudienceGender.MIXED:
        return True
    if gender is None:
        return False
    return (
        audience == AudienceGender.MALE_ONLY and gender.value == "male"
    ) or (
        audience == AudienceGender.FEMALE_ONLY and gender.value == "female"
    )


def _coerce_method(raw: str) -> PaymentMethod:
    try:
        return PaymentMethod(raw)
    except ValueError:
        return PaymentMethod.MOCK
