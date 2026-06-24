from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PaymentStatus
from app.db.models import Payment
from app.repositories.payment_repo import PaymentRepository
from app.services.audit_service import Actor, AuditService


class AdminPaymentService:
    """Admin refund of a payment row.

    Record-only (CLAUDE.md §9): the provider is mocked, so we flip the
    payment to REFUNDED and stamp the row — no gateway call. When a real
    gateway lands, the reversal goes behind the PaymentProvider adapter;
    this service's contract (and its audit action) stays the same. Only
    a SUCCEEDED payment can be refunded.
    """

    def __init__(self, payments: PaymentRepository, audit: AuditService) -> None:
        self.payments = payments
        self.audit = audit

    async def refund(self, payment_id: UUID, *, actor: Actor) -> Payment:
        payment = await self.payments.get(payment_id)
        if payment is None:
            raise AppError(ErrorCode.PAYMENT_NOT_FOUND, "Payment not found.")
        if payment.status != PaymentStatus.SUCCEEDED:
            raise AppError(
                ErrorCode.PAYMENT_NOT_REFUNDABLE,
                "Only a succeeded payment can be refunded.",
            )
        before = payment.status
        await self.payments.mark_refunded(
            payment,
            refund_txn_id=f"admin-refund-{payment.id}",
            raw_refund={"mock": True, "reason": "admin_payment_refund"},
            refund_failed=False,
        )
        await self.audit.log(
            actor=actor,
            action="admin.payment.refund",
            entity_type="payment",
            entity_id=payment.id,
            diff={
                "before": {"status": before.value},
                "after": {
                    "status": payment.status.value,
                    "amount_jod": str(payment.amount_jod),
                },
            },
        )
        return payment
