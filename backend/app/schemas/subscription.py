from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.db.enums import PaymentMethod, SubscriptionStatus, Tier


class SubscriptionCreate(BaseModel):
    plan_id: UUID = Field(alias="planId")
    payment_method: PaymentMethod = Field(alias="paymentMethod", default=PaymentMethod.MOCK)
    # Optional reference to a stored payment method. When supplied, the
    # backend verifies the caller owns it and records the binding in the
    # payment audit trail. Null falls back to the bare `payment_method`
    # kind, which is what the mock gateway needs to accept the charge.
    payment_method_id: UUID | None = Field(
        default=None, alias="paymentMethodId"
    )

    model_config = ConfigDict(populate_by_name=True)


class SubscriptionRead(BaseModel):
    id: UUID
    user_id: UUID = Field(alias="userId")
    plan_id: UUID = Field(alias="planId")
    tier: Tier
    status: SubscriptionStatus
    starts_at: datetime = Field(alias="startsAt")
    expires_at: datetime = Field(alias="expiresAt")
    visits_used: int = Field(alias="visitsUsed")
    auto_renew: bool = Field(alias="autoRenew")
    cancelled_at: datetime | None = Field(alias="cancelledAt", default=None)

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class CurrentSubscription(BaseModel):
    subscription: SubscriptionRead | None = None
    # Visits consumed in the current 30-day period anchored to
    # `subscription.starts_at`. None when there is no subscription.
    # Same shape for every tier — tier gates the gym network, not the
    # visit count.
    current_period_visits: int | None = Field(
        alias="currentPeriodVisits", default=None
    )
    # `plan.monthly_visits - current_period_visits`, floored at zero.
    # None when there is no subscription. Mobile reads this for the
    # "X visits left" pill so it never has to do the subtraction.
    remaining_visits: int | None = Field(alias="remainingVisits", default=None)

    model_config = ConfigDict(populate_by_name=True)
