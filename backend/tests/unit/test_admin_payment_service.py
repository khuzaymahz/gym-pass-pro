"""Service-level tests for AdminPaymentService record-only refunds."""

from __future__ import annotations

from decimal import Decimal

import pytest
from sqlalchemy import func, select

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PaymentMethod, PaymentStatus, Role
from app.db.models import AuditLog, Payment
from app.repositories.audit_repo import AuditRepository
from app.repositories.payment_repo import PaymentRepository
from app.services.admin_payment_service import AdminPaymentService
from app.services.audit_service import Actor, AuditService
from app.utils.ids import uuid7
from app.utils.time import utcnow


def _actor() -> Actor:
    return Actor(user_id=None, role=Role.ADMIN, ip_address="127.0.0.1", user_agent="pytest")


def _build(db) -> AdminPaymentService:
    return AdminPaymentService(PaymentRepository(db), AuditService(AuditRepository(db)))


async def _payment(db, status: PaymentStatus) -> Payment:
    return await PaymentRepository(db).create(
        subscription_id=None,
        amount_jod=Decimal("25.000"),
        method=PaymentMethod.MOCK,
        gateway_txn_id="mock-1",
        status=status,
        raw_response={"mock": True},
        processed_at=utcnow(),
    )


async def _audit_count(db, action: str) -> int:
    stmt = select(func.count()).select_from(AuditLog).where(AuditLog.action == action)
    return int((await db.execute(stmt)).scalar_one())


@pytest.mark.asyncio
async def test_refund_succeeded_payment(db):
    payment = await _payment(db, PaymentStatus.SUCCEEDED)
    svc = _build(db)
    out = await svc.refund(payment.id, actor=_actor())
    assert out.status is PaymentStatus.REFUNDED
    assert await _audit_count(db, "admin.payment.refund") == 1


@pytest.mark.asyncio
async def test_refund_unknown_payment_rejected(db):
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.refund(uuid7(), actor=_actor())
    assert ei.value.code is ErrorCode.PAYMENT_NOT_FOUND


@pytest.mark.asyncio
async def test_refund_non_succeeded_rejected(db):
    payment = await _payment(db, PaymentStatus.FAILED)
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.refund(payment.id, actor=_actor())
    assert ei.value.code is ErrorCode.PAYMENT_NOT_REFUNDABLE


@pytest.mark.asyncio
async def test_refund_already_refunded_rejected(db):
    payment = await _payment(db, PaymentStatus.REFUNDED)
    svc = _build(db)
    with pytest.raises(AppError) as ei:
        await svc.refund(payment.id, actor=_actor())
    assert ei.value.code is ErrorCode.PAYMENT_NOT_REFUNDABLE
