from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.db.enums import (
    CheckinStatus,
    Gender,
    Locale,
    PaymentMethod,
    PaymentStatus,
    PayoutStatus,
    ReferralStatus,
    Role,
    SubscriptionStatus,
    TicketCategory,
    TicketPriority,
    TicketStatus,
    Tier,
)


class AdminUserRead(BaseModel):
    id: UUID
    email: str | None = None
    phone: str | None = None
    name: str | None = None
    first_name: str | None = Field(alias="firstName", default=None)
    last_name: str | None = Field(alias="lastName", default=None)
    gender: Gender | None = None
    birthdate: date | None = None
    role: Role
    locale: Locale
    avatar_url: str | None = Field(alias="avatarUrl", default=None)
    referral_code: str | None = Field(alias="referralCode", default=None)
    invited_by_user_id: UUID | None = Field(alias="invitedByUserId", default=None)
    last_active_at: datetime | None = Field(alias="lastActiveAt", default=None)
    created_at: datetime = Field(alias="createdAt")
    deleted_at: datetime | None = Field(alias="deletedAt", default=None)

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class AdminUserUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=128)
    first_name: str | None = Field(alias="firstName", default=None, max_length=64)
    last_name: str | None = Field(alias="lastName", default=None, max_length=64)
    gender: Gender | None = None
    birthdate: date | None = None
    role: Role | None = None
    locale: Locale | None = None
    is_active: bool | None = Field(alias="isActive", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminReferralPersonRef(BaseModel):
    id: UUID
    name: str | None = None
    email: str | None = None
    phone: str | None = None

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailSubscription(BaseModel):
    id: UUID
    tier: Tier
    status: SubscriptionStatus
    plan_id: UUID | None = Field(alias="planId", default=None)
    plan_tier: Tier | None = Field(alias="planTier", default=None)
    plan_duration_months: int | None = Field(alias="planDurationMonths", default=None)
    plan_price_jod: Decimal | None = Field(alias="planPriceJod", default=None)
    plan_monthly_visits: int | None = Field(alias="planMonthlyVisits", default=None)
    starts_at: datetime = Field(alias="startsAt")
    expires_at: datetime = Field(alias="expiresAt")
    visits_used: int = Field(alias="visitsUsed")
    auto_renew: bool = Field(alias="autoRenew")
    cancelled_at: datetime | None = Field(alias="cancelledAt", default=None)
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailPayment(BaseModel):
    id: UUID
    subscription_id: UUID | None = Field(alias="subscriptionId", default=None)
    subscription_tier: Tier | None = Field(alias="subscriptionTier", default=None)
    amount_jod: Decimal = Field(alias="amountJod")
    method: PaymentMethod
    status: PaymentStatus
    gateway_txn_id: str | None = Field(alias="gatewayTxnId", default=None)
    processed_at: datetime | None = Field(alias="processedAt", default=None)
    created_at: datetime = Field(alias="createdAt")
    meta: dict[str, Any] = Field(default_factory=dict)

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailTicket(BaseModel):
    id: UUID
    category: TicketCategory
    priority: TicketPriority
    status: TicketStatus
    subject: str
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")
    resolved_at: datetime | None = Field(alias="resolvedAt", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailCheckin(BaseModel):
    id: UUID
    gym_id: UUID = Field(alias="gymId")
    gym_name_en: str = Field(alias="gymNameEn")
    gym_name_ar: str = Field(alias="gymNameAr")
    status: CheckinStatus
    scanned_at: datetime = Field(alias="scannedAt")
    failure_reason: str | None = Field(alias="failureReason", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailReferral(BaseModel):
    id: UUID
    invited: AdminReferralPersonRef
    status: ReferralStatus
    created_at: datetime = Field(alias="createdAt")
    converted_at: datetime | None = Field(alias="convertedAt", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailPaymentMethodsEntry(BaseModel):
    method: PaymentMethod
    count: int
    last: dict[str, Any] | None = None

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetailTotals(BaseModel):
    total_paid_jod: Decimal = Field(alias="totalPaidJod")
    subscription_count: int = Field(alias="subscriptionCount")
    has_active_subscription: bool = Field(alias="hasActiveSubscription")
    active_tier: Tier | None = Field(alias="activeTier", default=None)
    ticket_count: int = Field(alias="ticketCount")
    open_ticket_count: int = Field(alias="openTicketCount")
    referral_count: int = Field(alias="referralCount")
    converted_referral_count: int = Field(alias="convertedReferralCount")

    model_config = ConfigDict(populate_by_name=True)


class AdminUserDetail(BaseModel):
    user: AdminUserRead
    invited_by: AdminReferralPersonRef | None = Field(alias="invitedBy", default=None)
    referral_code: str = Field(alias="referralCode")
    referral_counts: dict[str, int] = Field(alias="referralCounts")
    referrals: list[AdminUserDetailReferral]
    subscriptions: list[AdminUserDetailSubscription]
    payments: list[AdminUserDetailPayment]
    tickets: list[AdminUserDetailTicket]
    recent_checkins: list[AdminUserDetailCheckin] = Field(alias="recentCheckins")
    payment_methods: list[AdminUserDetailPaymentMethodsEntry] = Field(
        alias="paymentMethods"
    )
    totals: AdminUserDetailTotals

    model_config = ConfigDict(populate_by_name=True)


def _validate_admin_password(value: str) -> str:
    """Admin passwords need real complexity — these accounts can mint
    service tokens and reset other admins. Member passwords are still
    a softer 8-char minimum (see schemas/auth.py); admin gets the
    full classes-of-character bar.

    Rules: ≥12 chars, at least one upper, one lower, one digit, one
    non-alphanumeric. Blocks the most embarrassing passwords (the
    dev sentinel `admin123`, anything containing the literal word
    `password`) regardless of length.
    """
    if len(value) < 12:
        raise ValueError("Admin password must be at least 12 characters.")
    lower = value.lower()
    if "password" in lower or value in {"admin123", "changeme-dev"}:
        raise ValueError("Admin password is too common; pick a stronger one.")
    has_upper = any(c.isupper() for c in value)
    has_lower = any(c.islower() for c in value)
    has_digit = any(c.isdigit() for c in value)
    has_symbol = any(not c.isalnum() for c in value)
    if not (has_upper and has_lower and has_digit and has_symbol):
        raise ValueError(
            "Admin password must include uppercase, lowercase, a digit, "
            "and a non-alphanumeric character.",
        )
    return value


class AdminCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=12, max_length=128)

    model_config = ConfigDict(populate_by_name=True)

    @field_validator("password")
    @classmethod
    def _check_password(cls, v: str) -> str:
        return _validate_admin_password(v)


class AdminPasswordReset(BaseModel):
    password: str = Field(min_length=12, max_length=128)

    model_config = ConfigDict(populate_by_name=True)

    @field_validator("password")
    @classmethod
    def _check_password(cls, v: str) -> str:
        return _validate_admin_password(v)


class AdminPlanUpdate(BaseModel):
    price_jod: Decimal | None = Field(alias="priceJod", default=None, ge=0)
    monthly_visits: int | None = Field(alias="monthlyVisits", default=None, gt=0)
    included_gym_count: int | None = Field(
        alias="includedGymCount", default=None, ge=0
    )
    features_en: list[str] | None = Field(alias="featuresEn", default=None)
    features_ar: list[str] | None = Field(alias="featuresAr", default=None)
    discount_percent: Decimal | None = Field(
        alias="discountPercent", default=None, ge=0, le=100
    )
    is_active: bool | None = Field(alias="isActive", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminPlanCreate(BaseModel):
    tier: Tier
    duration_months: int = Field(alias="durationMonths", gt=0)
    price_jod: Decimal = Field(alias="priceJod", ge=0)
    monthly_visits: int = Field(alias="monthlyVisits", gt=0)
    included_gym_count: int = Field(alias="includedGymCount", ge=0)
    features_en: list[str] = Field(alias="featuresEn", default_factory=list)
    features_ar: list[str] = Field(alias="featuresAr", default_factory=list)
    discount_percent: Decimal = Field(
        alias="discountPercent", default=Decimal("0"), ge=0, le=100
    )
    is_active: bool = Field(alias="isActive", default=True)

    model_config = ConfigDict(populate_by_name=True)


class AdminSubscriptionListItem(BaseModel):
    id: UUID
    user_id: UUID = Field(alias="userId")
    user_email: str | None = Field(alias="userEmail", default=None)
    user_phone: str | None = Field(alias="userPhone", default=None)
    user_name: str | None = Field(alias="userName", default=None)
    plan_id: UUID = Field(alias="planId")
    tier: Tier
    status: SubscriptionStatus
    starts_at: datetime = Field(alias="startsAt")
    expires_at: datetime = Field(alias="expiresAt")
    visits_used: int = Field(alias="visitsUsed")
    auto_renew: bool = Field(alias="autoRenew")
    cancelled_at: datetime | None = Field(alias="cancelledAt", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminCheckinListItem(BaseModel):
    id: UUID
    user_id: UUID = Field(alias="userId")
    user_name: str | None = Field(alias="userName", default=None)
    user_phone: str | None = Field(alias="userPhone", default=None)
    gym_id: UUID = Field(alias="gymId")
    gym_name_en: str = Field(alias="gymNameEn")
    gym_name_ar: str = Field(alias="gymNameAr")
    status: CheckinStatus
    scanned_at: datetime = Field(alias="scannedAt")
    failure_reason: str | None = Field(alias="failureReason", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminPayoutRead(BaseModel):
    id: UUID
    gym_id: UUID = Field(alias="gymId")
    gym_name_en: str = Field(alias="gymNameEn")
    period_start: date = Field(alias="periodStart")
    period_end: date = Field(alias="periodEnd")
    total_amount_jod: Decimal = Field(alias="totalAmountJod")
    entry_count: int = Field(alias="entryCount")
    status: PayoutStatus
    paid_at: datetime | None = Field(alias="paidAt", default=None)
    notes: str | None = None

    model_config = ConfigDict(populate_by_name=True)


class AdminPayoutGenerate(BaseModel):
    period_start: date = Field(alias="periodStart")
    period_end: date = Field(alias="periodEnd")

    model_config = ConfigDict(populate_by_name=True)


class AdminPayoutMarkPaid(BaseModel):
    notes: str | None = None


class AdminAuditRead(BaseModel):
    id: UUID
    actor_user_id: UUID | None = Field(alias="actorUserId", default=None)
    actor_role: Role | None = Field(alias="actorRole", default=None)
    action: str
    entity_type: str = Field(alias="entityType")
    entity_id: UUID | None = Field(alias="entityId", default=None)
    diff_json: dict[str, Any] = Field(alias="diff", default_factory=dict)
    ip_address: str | None = Field(alias="ipAddress", default=None)
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class DashboardMetrics(BaseModel):
    member_count: int = Field(alias="memberCount")
    admin_count: int = Field(alias="adminCount")
    gym_count: int = Field(alias="gymCount")
    active_subscriptions: int = Field(alias="activeSubscriptions")
    checkins_today: int = Field(alias="checkinsToday")
    checkins_this_month: int = Field(alias="checkinsThisMonth")
    revenue_mtd_jod: Decimal = Field(alias="revenueMtdJod")
    revenue_previous_month_jod: Decimal = Field(alias="revenuePreviousMonthJod")
    pending_payout_total_jod: Decimal = Field(alias="pendingPayoutTotalJod")
    subscriptions_by_tier: dict[str, int] = Field(alias="subscriptionsByTier")
    checkins_last_7_days: list[dict[str, Any]] = Field(alias="checkinsLast7Days")
    checkins_last_30_days: list[dict[str, Any]] = Field(alias="checkinsLast30Days")
    revenue_last_30_days: list[dict[str, Any]] = Field(alias="revenueLast30Days")
    signups_last_30_days: list[dict[str, Any]] = Field(alias="signupsLast30Days")
    open_ticket_count: int = Field(alias="openTicketCount")
    urgent_ticket_count: int = Field(alias="urgentTicketCount")
    expiring_subscriptions_count: int = Field(alias="expiringSubscriptionsCount")
    top_gyms_by_checkins: list[dict[str, Any]] = Field(alias="topGymsByCheckins")
    recent_signups: list[dict[str, Any]] = Field(alias="recentSignups")
    recent_checkins: list[dict[str, Any]] = Field(alias="recentCheckins")
    system_health: dict[str, str] = Field(alias="systemHealth")

    model_config = ConfigDict(populate_by_name=True)


class AdminNotificationBroadcast(BaseModel):
    title_en: str = Field(alias="titleEn", min_length=1, max_length=128)
    title_ar: str = Field(alias="titleAr", min_length=1, max_length=128)
    body_en: str = Field(alias="bodyEn", max_length=1024)
    body_ar: str = Field(alias="bodyAr", max_length=1024)
    target_tier: Tier | None = Field(alias="targetTier", default=None)

    model_config = ConfigDict(populate_by_name=True)


class AdminNotificationBroadcastResult(BaseModel):
    recipients: int

    model_config = ConfigDict(populate_by_name=True)
