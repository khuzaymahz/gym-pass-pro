from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import AudienceGender, DayPassStatus
from app.db.models import DayPass, DayPassOffering, Gym, User
from app.repositories.day_pass_repo import (
    DayPassOfferingRepository,
    DayPassRepository,
)
from app.repositories.gym_repo import GymRepository
from app.repositories.payment_repo import PaymentRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow


class AdminDayPassService:
    """Admin oversight of the day-pass revenue domain.

    The partner portal can toggle/price its own offering, but the
    platform-fee %, validity window, and refunds are admin territory.
    This service is the admin's window onto: every gym's offering
    config, the passes actually sold, and the record-only refund
    action. Refunds are record-only (no gateway call — payments are
    mocked; the real reversal lands later behind the PaymentProvider
    adapter), matching CLAUDE.md §9.
    """

    def __init__(
        self,
        offerings: DayPassOfferingRepository,
        passes: DayPassRepository,
        payments: PaymentRepository,
        gyms: GymRepository,
        audit: AuditService,
    ) -> None:
        self.offerings = offerings
        self.passes = passes
        self.payments = payments
        self.gyms = gyms
        self.audit = audit

    # ----- Offerings -----

    async def list_offerings(
        self, *, enabled: bool | None, page: int, page_size: int
    ) -> tuple[list[tuple[DayPassOffering, Gym]], int]:
        return await self.offerings.list_with_gym(enabled=enabled, page=page, page_size=page_size)

    async def configure_offering(
        self,
        gym_id: UUID,
        *,
        is_enabled: bool,
        price_jod: Decimal,
        platform_fee_pct: Decimal,
        validity_hours: int,
        daily_cap: int | None,
        audience_gender_override: AudienceGender | None,
        actor: Actor,
    ) -> DayPassOffering:
        """Create or update a gym's offering with the full admin field
        set (including the platform-fee % and validity window the
        partner can't touch). The DB check constraints enforce the
        money/validity bounds; we surface a clean error instead of a
        500 if they're violated."""
        gym = await self.gyms.get(gym_id)
        if gym is None:
            raise AppError(ErrorCode.GYM_NOT_FOUND, "Gym not found.")
        if platform_fee_pct < 0 or platform_fee_pct >= 100:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Platform fee must be between 0 and under 100 percent.",
            )
        if validity_hours <= 0 or validity_hours > 168:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Validity must be between 1 and 168 hours.",
            )
        before = await self.offerings.for_gym(gym_id)
        offering = await self.offerings.upsert(
            gym_id=gym_id,
            is_enabled=is_enabled,
            price_jod=price_jod,
            daily_cap=daily_cap,
            audience_gender_override=audience_gender_override,
            platform_fee_pct=platform_fee_pct,
            validity_hours=validity_hours,
        )
        await self.audit.log(
            actor=actor,
            action=(
                "admin.day_pass_offering.create"
                if before is None
                else "admin.day_pass_offering.update"
            ),
            entity_type="day_pass_offering",
            entity_id=offering.id,
            diff={
                "after": {
                    "is_enabled": is_enabled,
                    "price_jod": str(offering.price_jod),
                    "platform_fee_pct": str(offering.platform_fee_pct),
                    "validity_hours": offering.validity_hours,
                    "daily_cap": daily_cap,
                }
            },
        )
        return offering

    # ----- Sold passes -----

    async def list_passes(
        self,
        *,
        status: DayPassStatus | None,
        gym_id: UUID | None,
        user_id: UUID | None,
        page: int,
        page_size: int,
    ) -> tuple[list[tuple[DayPass, User, Gym]], int]:
        return await self.passes.list_paginated(
            status=status,
            gym_id=gym_id,
            user_id=user_id,
            page=page,
            page_size=page_size,
        )

    async def refund_pass(self, pass_id: UUID, *, actor: Actor) -> DayPass:
        """Record-only refund: mark the pass REFUNDED and reverse its
        payment row. A USED pass can't be refunded (already redeemed —
        the gym is owed via the payout ledger); an already-refunded one
        is a no-op error."""
        day_pass = await self.passes.get(pass_id)
        if day_pass is None:
            raise AppError(ErrorCode.DAY_PASS_NOT_FOUND, "Day pass not found.")
        if day_pass.status == DayPassStatus.REFUNDED:
            raise AppError(ErrorCode.DAY_PASS_NOT_REFUNDABLE, "Pass already refunded.")
        if day_pass.status == DayPassStatus.USED:
            raise AppError(
                ErrorCode.DAY_PASS_NOT_REFUNDABLE,
                "Pass was already redeemed at the gym.",
            )

        before = day_pass.status
        now = utcnow()
        await self.passes.set_refunded(day_pass, now)

        # Reverse the linked payment row (record-only — no gateway
        # call). `mark_refunded(refund_failed=False)` flips the payment
        # to REFUNDED and merges a refund stamp into raw_response.
        if day_pass.payment_id is not None:
            payment = await self.payments.get(day_pass.payment_id)
            if payment is not None:
                await self.payments.mark_refunded(
                    payment,
                    refund_txn_id=f"admin-refund-{day_pass.id}",
                    raw_refund={"mock": True, "reason": "admin_day_pass_refund"},
                    refund_failed=False,
                )

        await self.audit.log(
            actor=actor,
            action="admin.day_pass.refund",
            entity_type="day_pass",
            entity_id=day_pass.id,
            diff={
                "before": {"status": before.value},
                "after": {
                    "status": day_pass.status.value,
                    "refunded_at": now.isoformat(),
                    "amount_jod": str(day_pass.price_jod),
                },
            },
        )
        return day_pass
