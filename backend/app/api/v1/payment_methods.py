from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    authed_actor,
    current_user,
    db_session,
    payment_method_service,
)
from app.db.models import User
from app.schemas.payment_method import PaymentMethodCreate, PaymentMethodRead
from app.services.payment_method_service import PaymentMethodService

router = APIRouter(prefix="/me/payment-methods", tags=["me/payment-methods"])


@router.get("", response_model=list[PaymentMethodRead])
async def list_my_methods(
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[PaymentMethodService, Depends(payment_method_service)],
) -> list[PaymentMethodRead]:
    rows = await svc.list_for_user(me.id)
    return [PaymentMethodRead.model_validate(r) for r in rows]


@router.post("", response_model=PaymentMethodRead, status_code=201)
async def add_my_method(
    body: PaymentMethodCreate,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[PaymentMethodService, Depends(payment_method_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PaymentMethodRead:
    row = await svc.add(
        user_id=me.id,
        kind=body.kind,
        label=body.label,
        last4=body.last4,
        holder=body.holder,
        expiry_mm=body.expiry_mm,
        expiry_yy=body.expiry_yy,
        cliq_alias=body.cliq_alias,
        cliq_phone=body.cliq_phone,
        make_default=body.is_default,
        actor=authed_actor(request, me),
    )
    await session.commit()
    return PaymentMethodRead.model_validate(row)


@router.delete("/{method_id}", status_code=204)
async def remove_my_method(
    method_id: UUID,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[PaymentMethodService, Depends(payment_method_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    await svc.remove(
        method_id=method_id,
        user_id=me.id,
        actor=authed_actor(request, me),
    )
    await session.commit()


@router.post("/{method_id}/default", response_model=PaymentMethodRead)
async def set_default_method(
    method_id: UUID,
    request: Request,
    me: Annotated[User, Depends(current_user)],
    svc: Annotated[PaymentMethodService, Depends(payment_method_service)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PaymentMethodRead:
    row = await svc.set_default(
        method_id=method_id,
        user_id=me.id,
        actor=authed_actor(request, me),
    )
    await session.commit()
    return PaymentMethodRead.model_validate(row)
