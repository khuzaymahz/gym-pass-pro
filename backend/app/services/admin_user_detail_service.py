from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    PaymentMethod,
    PaymentStatus,
    ReferralStatus,
    SubscriptionStatus,
    TicketStatus,
)
from app.db.models import (
    Checkin,
    Gym,
    Payment,
    Plan,
    Referral,
    Subscription,
    SupportTicket,
    User,
)
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.referral_repo import ReferralRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.repositories.user_repo import UserRepository
from app.services.referral_service import ReferralService


@dataclass(frozen=True)
class SubscriptionHistoryItem:
    subscription: Subscription
    plan: Plan | None


@dataclass(frozen=True)
class PaymentHistoryItem:
    payment: Payment
    subscription: Subscription | None


@dataclass(frozen=True)
class ReferralItem:
    referral: Referral
    invited: User


@dataclass(frozen=True)
class UserDetail:
    user: User
    invited_by: User | None
    subscription_history: list[SubscriptionHistoryItem]
    payment_history: list[PaymentHistoryItem]
    tickets: list[SupportTicket]
    recent_checkins: list[tuple[Checkin, Gym]]
    referral_code: str
    referrals: list[ReferralItem]
    referral_counts: dict[str, int]
    payment_method_summary: dict[str, Any]
    totals: dict[str, Any]
    last_active_at: datetime | None


class AdminUserDetailService:
    """Read-only aggregation of everything the admin detail page needs.

    Assembles the user profile, tier history (all subscriptions with plan
    details), payment methods + receipts, support tickets, recent check-ins,
    and referral code/conversion stats. One round-trip per concern so we
    don't leak unbounded data.
    """

    def __init__(
        self,
        session: AsyncSession,
        users: UserRepository,
        subs: SubscriptionRepository,
        payments: PaymentRepository,
        checkins: CheckinRepository,
        tickets: SupportTicketRepository,
        referrals: ReferralRepository,
        referral_svc: ReferralService,
    ) -> None:
        self.session = session
        self.users = users
        self.subs = subs
        self.payments = payments
        self.checkins = checkins
        self.tickets = tickets
        self.referrals = referrals
        self.referral_svc = referral_svc

    async def get(self, user_id: UUID) -> UserDetail:
        user = await self.users.get(user_id)
        if user is None:
            raise AppError(ErrorCode.NOT_FOUND, "User not found.")

        invited_by: User | None = None
        if user.invited_by_user_id is not None:
            invited_by = await self.users.get(user.invited_by_user_id)

        sub_rows = await self.subs.history_for_user(user.id)
        subscription_history = [
            SubscriptionHistoryItem(subscription=s, plan=p) for s, p in sub_rows
        ]

        payment_rows = await self.payments.history_for_user(user.id, limit=100)
        payment_history = [
            PaymentHistoryItem(payment=p, subscription=s) for p, s in payment_rows
        ]

        tickets = await self.tickets.history_for_user(user.id, limit=50)
        recent_checkins = await self.checkins.history_for_user(user.id, limit=25)

        # Referral: ensure code exists (for older members, backfilled via
        # migration, but defensive in case of manual inserts).
        code = await self.referral_svc.ensure_code_for_user(user)
        referral_rows = await self.referrals.list_for_referrer(user.id)
        referrals = [ReferralItem(referral=r, invited=u) for r, u in referral_rows]
        referral_counts = await self.referrals.counts_for_referrer(user.id)

        payment_method_summary = _summarize_payment_methods(payment_history)
        totals = _compute_totals(
            subscription_history, payment_history, tickets, referrals
        )

        return UserDetail(
            user=user,
            invited_by=invited_by,
            subscription_history=subscription_history,
            payment_history=payment_history,
            tickets=tickets,
            recent_checkins=recent_checkins,
            referral_code=code,
            referrals=referrals,
            referral_counts=referral_counts,
            payment_method_summary=payment_method_summary,
            totals=totals,
            last_active_at=user.last_active_at,
        )


def _summarize_payment_methods(
    payments: list[PaymentHistoryItem],
) -> dict[str, Any]:
    """Derive methods used from payment raw_response + method.

    For CliQ: pull the alias/phone from raw_response if the provider included
    it. For cards: surface last-4 if present. For apple_pay: just tag. All
    fields are best-effort; mock gateway populates synthetic values.
    """
    counts: dict[str, int] = {m.value: 0 for m in PaymentMethod}
    last_by_method: dict[str, dict[str, Any]] = {}

    for entry in payments:
        p = entry.payment
        if p.status != PaymentStatus.SUCCEEDED:
            continue
        method = p.method.value
        counts[method] = counts.get(method, 0) + 1
        if method in last_by_method:
            continue

        meta: dict[str, Any] = {"processedAt": p.processed_at}
        raw = p.raw_response or {}
        if p.method == PaymentMethod.CLIQ:
            meta["alias"] = raw.get("cliq_alias") or raw.get("alias")
            meta["phone"] = raw.get("cliq_phone") or raw.get("phone")
        elif p.method == PaymentMethod.CARD:
            meta["last4"] = raw.get("last4") or raw.get("card_last4")
            meta["brand"] = raw.get("brand") or raw.get("card_brand")
        last_by_method[method] = meta

    methods = [
        {"method": method, "count": counts[method], "last": last_by_method.get(method)}
        for method in counts
        if counts[method] > 0
    ]
    return {"methods": methods}


def _compute_totals(
    subs: list[SubscriptionHistoryItem],
    payments: list[PaymentHistoryItem],
    tickets: list[SupportTicket],
    referrals: list[ReferralItem],
) -> dict[str, Any]:
    paid = sum(
        (entry.payment.amount_jod for entry in payments
         if entry.payment.status == PaymentStatus.SUCCEEDED),
        start=Decimal("0"),
    )
    active_sub = next(
        (
            item
            for item in subs
            if item.subscription.status == SubscriptionStatus.ACTIVE
        ),
        None,
    )
    open_ticket_count = sum(
        1
        for t in tickets
        if t.status in {TicketStatus.OPEN, TicketStatus.IN_PROGRESS, TicketStatus.WAITING_USER}
    )
    converted_referrals = sum(
        1 for r in referrals if r.referral.status == ReferralStatus.CONVERTED
    )
    return {
        "totalPaidJod": paid,
        "subscriptionCount": len(subs),
        "hasActiveSubscription": active_sub is not None,
        "activeTier": (
            active_sub.subscription.tier.value if active_sub else None
        ),
        "ticketCount": len(tickets),
        "openTicketCount": open_ticket_count,
        "referralCount": len(referrals),
        "convertedReferralCount": converted_referrals,
    }


__all__ = [
    "AdminUserDetailService",
    "PaymentHistoryItem",
    "ReferralItem",
    "SubscriptionHistoryItem",
    "UserDetail",
]
