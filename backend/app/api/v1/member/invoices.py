from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field

from app.api.deps import current_user, payment_repo
from app.db.enums import PaymentMethod, PaymentStatus, Tier
from app.db.models import User
from app.repositories.payment_repo import PaymentRepository

router = APIRouter(prefix="/me/invoices", tags=["me/invoices"])


class InvoiceRead(BaseModel):
    """Member-facing invoice. Sourced from the `payments` table joined to
    the matching `subscriptions` row so the wire shape carries enough
    context to render an item without a second fetch (tier + billing
    period + amount). Provider-specific gateway noise stays in the
    audit log; the member doesn't need it.
    """

    id: UUID
    subscription_id: UUID = Field(alias="subscriptionId")
    tier: Tier
    period_starts_at: datetime = Field(alias="periodStartsAt")
    period_ends_at: datetime = Field(alias="periodEndsAt")
    amount_jod: Decimal = Field(alias="amountJod")
    method: PaymentMethod
    status: PaymentStatus
    gateway_txn_id: str | None = Field(alias="gatewayTxnId", default=None)
    paid_at: datetime | None = Field(alias="paidAt", default=None)
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(populate_by_name=True)


@router.get("", response_model=list[InvoiceRead])
async def list_my_invoices(
    me: Annotated[User, Depends(current_user)],
    payments: Annotated[PaymentRepository, Depends(payment_repo)],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[InvoiceRead]:
    rows = await payments.list_for_user(me.id, limit=limit)
    return [
        InvoiceRead.model_validate(
            {
                "id": p.id,
                "subscriptionId": p.subscription_id,
                "tier": s.tier,
                "periodStartsAt": s.starts_at,
                "periodEndsAt": s.expires_at,
                "amountJod": p.amount_jod,
                "method": p.method,
                "status": p.status,
                "gatewayTxnId": p.gateway_txn_id,
                "paidAt": p.processed_at if p.status == PaymentStatus.SUCCEEDED else None,
                "createdAt": p.created_at,
            }
        )
        for p, s in rows
    ]
