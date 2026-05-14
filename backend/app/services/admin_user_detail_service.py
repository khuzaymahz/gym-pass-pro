from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Any, Awaitable, Callable
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

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
from app.repositories.audit_repo import AuditRepository
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.referral_repo import ReferralRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import AuditService
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
    """Read-only aggregation for the admin user-detail page.

    Reads run in parallel via `asyncio.gather`, each in its own
    session because `AsyncSession` is not safe for concurrent use.
    Referral-code backfill (the one write this used to do mid-read)
    runs in its own committed session — previously it flushed on
    the request's shared GET session that never committed, so the
    backfilled code was effectively rolled back at request end.
    """

    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
    ) -> None:
        self._factory = session_factory

    async def _q(self, fn: Callable[[AsyncSession], Awaitable[Any]]) -> Any:
        async with self._factory() as s:
            return await fn(s)

    async def get(self, user_id: UUID) -> UserDetail:
        user = await self._q(lambda s: UserRepository(s).get(user_id))
        if user is None:
            raise AppError(ErrorCode.NOT_FOUND, "User not found.")

        referral_code = await self._ensure_referral_code(user)

        invited_by_fetch = (
            self._q(lambda s: UserRepository(s).get(user.invited_by_user_id))
            if user.invited_by_user_id is not None
            else _none()
        )
        (
            invited_by,
            sub_rows,
            payment_rows,
            tickets,
            recent_checkins,
            referral_rows,
            referral_counts,
        ) = await asyncio.gather(
            invited_by_fetch,
            self._q(lambda s: SubscriptionRepository(s).history_for_user(user.id)),
            self._q(lambda s: PaymentRepository(s).history_for_user(user.id, limit=100)),
            self._q(lambda s: SupportTicketRepository(s).history_for_user(user.id, limit=50)),
            self._q(lambda s: CheckinRepository(s).history_for_user(user.id, limit=25)),
            self._q(lambda s: ReferralRepository(s).list_for_referrer(user.id)),
            self._q(lambda s: ReferralRepository(s).counts_for_referrer(user.id)),
        )

        subscription_history = [
            SubscriptionHistoryItem(subscription=s, plan=p) for s, p in sub_rows
        ]
        payment_history = [
            PaymentHistoryItem(payment=p, subscription=s) for p, s in payment_rows
        ]
        referrals = [ReferralItem(referral=r, invited=u) for r, u in referral_rows]

        return UserDetail(
            user=user,
            invited_by=invited_by,
            subscription_history=subscription_history,
            payment_history=payment_history,
            tickets=tickets,
            recent_checkins=recent_checkins,
            referral_code=referral_code,
            referrals=referrals,
            referral_counts=referral_counts,
            payment_method_summary=_summarize_payment_methods(payment_history),
            totals=_compute_totals(
                subscription_history, payment_history, tickets, referrals
            ),
            last_active_at=user.last_active_at,
        )

    async def _ensure_referral_code(self, user: User) -> str:
        """Defensive backfill — most users have a code from signup;
        legacy / migrated rows may not. Runs in its own session
        with an explicit commit so the value actually persists
        instead of riding on a shared GET-request session.
        """
        if user.referral_code:
            return user.referral_code
        async with self._factory() as s:
            # Re-fetch inside the write session — guards against
            # racing another request that already backfilled.
            fresh = await UserRepository(s).get(user.id)
            if fresh is None:
                return ""
            if fresh.referral_code:
                return fresh.referral_code
            ref_svc = ReferralService(
                users=UserRepository(s),
                referrals=ReferralRepository(s),
                audit=AuditService(AuditRepository(s)),
            )
            code = await ref_svc.ensure_code_for_user(fresh)
            await s.commit()
            return code


async def _none() -> None:
    return None


def _summarize_payment_methods(
    payments: list[PaymentHistoryItem],
) -> dict[str, Any]:
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
        (
            entry.payment.amount_jod
            for entry in payments
            if entry.payment.status == PaymentStatus.SUCCEEDED
        ),
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
        if t.status
        in {TicketStatus.OPEN, TicketStatus.IN_PROGRESS, TicketStatus.WAITING_USER}
    )
    converted_referrals = sum(
        1 for r in referrals if r.referral.status == ReferralStatus.CONVERTED
    )
    return {
        "totalPaidJod": paid,
        "subscriptionCount": len(subs),
        "hasActiveSubscription": active_sub is not None,
        "activeTier": active_sub.subscription.tier.value if active_sub else None,
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
