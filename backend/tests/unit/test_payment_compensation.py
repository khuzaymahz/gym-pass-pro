"""Compensation-pattern tests for the charge-then-activate flow.

When the payment provider charges the member but a post-charge step
(DB constraint, audit-log failure, etc.) raises, the member must not
end up paying for nothing. Both `SubscriptionService.purchase` and
`DayPassService.purchase` wrap their post-charge work in try/except
and call `_compensate_failed_activation`, which:

  1. Calls `payment_provider.refund(...)` to reverse the charge.
  2. Marks the `payments` row (REFUNDED on success; flagged in
     `raw_response` if the refund itself failed — that's the
     ops-page-the-team worst case).
  3. Writes a high-priority audit entry so ops can grep for the
     bad state without crawling Sentry.
  4. Lets the caller raise `PAYMENT_GATEWAY_ERROR` to the client.

These tests stub the day-pass repo so `activate` raises, then assert
each leg of the compensation actually happens against the real DB.
"""

from __future__ import annotations

from decimal import Decimal

import pytest
from sqlalchemy import select

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    AudienceGender,
    Category,
    DayPassStatus,
    Gender,
    PaymentStatus,
    Role,
    Tier,
)
from app.db.models import AuditLog, DayPass, Gym, Payment, User
from app.providers.payments.mock_payment import MockPaymentProvider
from app.repositories.audit_repo import AuditRepository
from app.repositories.day_pass_repo import (
    DayPassOfferingRepository,
    DayPassRepository,
)
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.day_pass_service import DayPassService
from app.utils.ids import uuid7


def _gym(slug: str) -> Gym:
    return Gym(
        id=uuid7(),
        slug=slug,
        name_en=slug.replace("-", " ").title(),
        name_ar=slug.replace("-", " ").title(),
        address_en="123 Test St",
        address_ar="123 شارع الاختبار",
        area="Amman",
        lat=Decimal("31.95"),
        lng=Decimal("35.91"),
        category=Category.GYM,
        required_tier=Tier.SILVER,
        audience_gender=AudienceGender.MIXED,
        per_visit_rate_jod=Decimal("2.00"),
    )


def _user(phone: str) -> User:
    return User(
        id=uuid7(),
        phone=phone,
        first_name="Test",
        last_name="User",
        role=Role.MEMBER,
        gender=Gender.MALE,
    )


def _actor(user: User) -> Actor:
    return Actor(
        user_id=user.id,
        role=user.role,
        ip_address="127.0.0.1",
        user_agent="pytest",
    )


class _ActivateFailsDayPassRepo(DayPassRepository):
    """Real repo, but `activate` raises. Lets us drive the
    `_compensate_failed_activation` branch without mocking the
    whole repo — every other method still hits the real DB so the
    test exercises the production code path until the moment of
    activation."""

    def __init__(self, session, exc: Exception) -> None:
        super().__init__(session)
        self._exc = exc

    async def activate(self, day_pass, payment_id):  # type: ignore[override]
        raise self._exc


def _build_service(
    db,
    *,
    activate_exc: Exception,
    refund_provider: MockPaymentProvider | None = None,
) -> DayPassService:
    return DayPassService(
        offerings=DayPassOfferingRepository(db),
        passes=_ActivateFailsDayPassRepo(db, activate_exc),
        gyms=GymRepository(db),
        subs=SubscriptionRepository(db),
        payments=PaymentRepository(db),
        payment_provider=refund_provider or MockPaymentProvider(),
        audit=AuditService(AuditRepository(db)),
    )


@pytest.mark.asyncio
async def test_activation_failure_refunds_and_audits(db):
    """Charge succeeds, `passes.activate` raises, refund succeeds.

    Verifies:
      * Caller sees PAYMENT_GATEWAY_ERROR (not the activation exc).
      * Payment row flipped to REFUNDED, refund metadata merged
        into `raw_response.refund`.
      * Audit log contains `day_pass.activation_failed_after_charge`
        with `refund_succeeded=True`.
      * Day-pass row stays in PENDING (never activated).
    """
    gym = _gym("compensate-happy")
    member = _user("+962790200001")
    db.add_all([gym, member])
    await db.flush()

    svc_setup = DayPassService(
        offerings=DayPassOfferingRepository(db),
        passes=DayPassRepository(db),
        gyms=GymRepository(db),
        subs=SubscriptionRepository(db),
        payments=PaymentRepository(db),
        payment_provider=MockPaymentProvider(),
        audit=AuditService(AuditRepository(db)),
    )
    await svc_setup.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("10.00"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    svc = _build_service(db, activate_exc=RuntimeError("DB write timed out"))

    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    assert exc.value.code == ErrorCode.PAYMENT_GATEWAY_ERROR

    # Day-pass row should still exist but PENDING — the audit-log
    # entry references it by id, and ops need to be able to find
    # the row when reconciling.
    pending = (
        await db.execute(select(DayPass).where(DayPass.user_id == member.id))
    ).scalar_one()
    assert pending.status == DayPassStatus.PENDING

    # Payment row was flipped to REFUNDED, refund metadata merged.
    payment = (
        await db.execute(select(Payment).where(Payment.amount_jod == Decimal("10.00")))
    ).scalar_one()
    assert payment.status == PaymentStatus.REFUNDED
    refund_meta = payment.raw_response.get("refund")
    assert refund_meta is not None
    assert refund_meta["succeeded"] is True
    assert refund_meta["refund_txn_id"] is not None

    # Audit trail records the compensation event so ops can grep.
    audit_rows = (
        await db.execute(
            select(AuditLog).where(
                AuditLog.action == "day_pass.activation_failed_after_charge"
            )
        )
    ).scalars().all()
    assert len(audit_rows) == 1
    assert audit_rows[0].diff_json["refund_succeeded"] is True
    assert "DB write timed out" in audit_rows[0].diff_json["activation_error"]


@pytest.mark.asyncio
async def test_activation_failure_with_refund_decline_flags_for_ops(db):
    """Worst case: charge succeeded, activation failed, AND the
    refund call itself was declined by the gateway. Payment row
    must NOT be flipped to REFUNDED (money is still gone), but
    the row gets stamped with `refund.succeeded=False` and the
    audit entry records `refund_succeeded=False` so ops can
    chase the manual reversal."""
    gym = _gym("compensate-refund-fail")
    member = _user("+962790200002")
    db.add_all([gym, member])
    await db.flush()

    svc_setup = DayPassService(
        offerings=DayPassOfferingRepository(db),
        passes=DayPassRepository(db),
        gyms=GymRepository(db),
        subs=SubscriptionRepository(db),
        payments=PaymentRepository(db),
        payment_provider=MockPaymentProvider(),
        audit=AuditService(AuditRepository(db)),
    )
    await svc_setup.upsert_offering(
        gym=gym,
        is_enabled=True,
        price_jod=Decimal("7.50"),
        daily_cap=None,
        audience_gender_override=None,
        actor=_actor(member),
    )
    await db.flush()

    # MockPaymentProvider.refund returns status='failed' when the
    # idempotency_key ends with ':decline'. DayPassService builds
    # the refund key as `refund:{day_pass.id}` so it does NOT end
    # with ':decline' by default. We need a thin wrapper around
    # the mock that forces a refund decline regardless of key.
    class _RefundDeclineProvider(MockPaymentProvider):
        async def refund(self, *, gateway_txn_id, amount_jod, idempotency_key):
            return await super().refund(
                gateway_txn_id=gateway_txn_id,
                amount_jod=amount_jod,
                # Force the decline branch in the mock.
                idempotency_key=f"{idempotency_key}:decline",
            )

    svc = _build_service(
        db,
        activate_exc=RuntimeError("constraint violated"),
        refund_provider=_RefundDeclineProvider(),
    )

    with pytest.raises(AppError) as exc:
        await svc.purchase(
            user=member,
            gym_slug=gym.slug,
            payment_method="mock",
            actor=_actor(member),
        )
    assert exc.value.code == ErrorCode.PAYMENT_GATEWAY_ERROR

    # Payment row is NOT flipped to REFUNDED — money is still gone.
    # `refund.succeeded=False` is the ops trigger.
    payment = (
        await db.execute(select(Payment).where(Payment.amount_jod == Decimal("7.50")))
    ).scalar_one()
    assert payment.status == PaymentStatus.SUCCEEDED
    refund_meta = payment.raw_response.get("refund")
    assert refund_meta is not None
    assert refund_meta["succeeded"] is False

    # Audit log records the failed refund so a grep for
    # `refund_succeeded:false` surfaces every row that needs ops
    # follow-up.
    audit_row = (
        await db.execute(
            select(AuditLog).where(
                AuditLog.action == "day_pass.activation_failed_after_charge"
            )
        )
    ).scalars().one()
    assert audit_row.diff_json["refund_succeeded"] is False
