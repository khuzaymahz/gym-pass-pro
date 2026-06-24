from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_payment_service,
    authed_actor,
    current_admin_ops,
    db_session,
)
from app.db.models import User
from app.schemas.admin import AdminPaymentRead
from app.services.admin_payment_service import AdminPaymentService

router = APIRouter(prefix="/admin/payments", tags=["admin/payments"])


@router.post("/{payment_id}/refund", response_model=AdminPaymentRead)
async def refund_payment(
    payment_id: UUID,
    request: Request,
    svc: Annotated[AdminPaymentService, Depends(admin_payment_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminPaymentRead:
    payment = await svc.refund(payment_id, actor=authed_actor(request, admin))
    await session.commit()
    return AdminPaymentRead.model_validate(payment)
