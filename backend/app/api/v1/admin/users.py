from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    admin_user_detail_service,
    admin_user_service,
    authed_actor,
    current_admin,
    current_admin_ops,
    current_admin_super,
    db_session,
)
from app.db.enums import Role
from app.db.models import User
from app.schemas.admin import (
    AdminCreate,
    AdminPasswordReset,
    AdminReferralPersonRef,
    AdminSessionRead,
    AdminUserDetail,
    AdminUserDetailCheckin,
    AdminUserDetailPayment,
    AdminUserDetailPaymentMethodsEntry,
    AdminUserDetailReferral,
    AdminUserDetailSubscription,
    AdminUserDetailTicket,
    AdminUserDetailTotals,
    AdminUserRead,
    AdminUserUpdate,
)
from app.schemas.common import Page
from app.services.admin_user_detail_service import AdminUserDetailService, UserDetail
from app.services.admin_user_service import AdminUserService

router = APIRouter(prefix="/admin/users", tags=["admin/users"])


@router.get("", response_model=Page[AdminUserRead])
async def list_users(
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    _: Annotated[User, Depends(current_admin)],
    role: Role | None = None,
    q: str | None = None,
    include_deleted: bool = Query(default=False, alias="includeDeleted"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[AdminUserRead]:
    rows, total = await svc.list(
        role=role,
        q=q,
        include_deleted=include_deleted,
        page=page,
        page_size=page_size,
    )
    return Page[AdminUserRead](
        items=[AdminUserRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        pageSize=page_size,
    )


@router.get("/{user_id}", response_model=AdminUserRead)
async def get_user(
    user_id: UUID,
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    _: Annotated[User, Depends(current_admin)],
) -> AdminUserRead:
    user = await svc.get(user_id)
    return AdminUserRead.model_validate(user)


@router.get("/{user_id}/detail", response_model=AdminUserDetail)
async def get_user_detail(
    user_id: UUID,
    request: Request,
    svc: Annotated[AdminUserDetailService, Depends(admin_user_detail_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminUserDetail:
    # Passing the actor lets the service write a `user.pii_read` audit
    # row in its own committed session. Without that trail, a curious
    # or malicious admin scraping member contact info leaves no
    # signal at all.
    detail = await svc.get(user_id, actor=authed_actor(request, admin))
    # ensure_code_for_user may have generated a new code for an older account
    await session.commit()
    return _to_detail_schema(detail)


@router.patch("/{user_id}", response_model=AdminUserRead)
async def update_user(
    user_id: UUID,
    body: AdminUserUpdate,
    request: Request,
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminUserRead:
    user = await svc.update(user_id, body, actor=authed_actor(request, admin))
    await session.commit()
    return AdminUserRead.model_validate(user)


@router.post("/admins", response_model=AdminUserRead, status_code=201)
async def create_admin(
    body: AdminCreate,
    request: Request,
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    admin: Annotated[User, Depends(current_admin_super)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> AdminUserRead:
    # Minting a new admin row is super-only: combined with
    # `reset_admin_password` (also super-only) and the still-broad
    # `Role.ADMIN` JWT claim, an `ops` admin who could create another
    # admin would have a trivial privilege-escalation path. Gating
    # this here closes that loop.
    user = await svc.create_admin(body, actor=authed_actor(request, admin))
    await session.commit()
    return AdminUserRead.model_validate(user)


@router.post("/{user_id}/reset-password", status_code=204)
async def reset_password(
    user_id: UUID,
    body: AdminPasswordReset,
    request: Request,
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    admin: Annotated[User, Depends(current_admin_super)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    # Resetting another admin's password — same risk shape as
    # creating one. Super-only.
    await svc.reset_admin_password(user_id, body.password, actor=authed_actor(request, admin))
    await session.commit()


@router.get("/{user_id}/sessions", response_model=list[AdminSessionRead])
async def list_sessions(
    user_id: UUID,
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    _: Annotated[User, Depends(current_admin)],
) -> list[AdminSessionRead]:
    rows = await svc.list_sessions(user_id)
    return [AdminSessionRead.model_validate(r) for r in rows]


@router.post("/{user_id}/revoke-sessions", status_code=204)
async def revoke_sessions(
    user_id: UUID,
    request: Request,
    svc: Annotated[AdminUserService, Depends(admin_user_service)],
    admin: Annotated[User, Depends(current_admin_ops)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    # Force-logout: any ops admin can revoke a member's (or admin's)
    # sessions — a security/account-recovery action, not a privilege
    # escalation, so it doesn't need super.
    await svc.revoke_sessions(user_id, actor=authed_actor(request, admin))
    await session.commit()


def _person_ref(user: User) -> AdminReferralPersonRef:
    return AdminReferralPersonRef(
        id=user.id,
        name=user.display_name,
        email=user.email,
        phone=user.phone,
    )


def _to_detail_schema(detail: UserDetail) -> AdminUserDetail:
    user = detail.user
    return AdminUserDetail(
        user=AdminUserRead.model_validate(user),
        invitedBy=_person_ref(detail.invited_by) if detail.invited_by else None,
        referralCode=detail.referral_code,
        referralCounts=detail.referral_counts,
        referrals=[
            AdminUserDetailReferral(
                id=item.referral.id,
                invited=_person_ref(item.invited),
                status=item.referral.status,
                createdAt=item.referral.created_at,
                convertedAt=item.referral.converted_at,
            )
            for item in detail.referrals
        ],
        subscriptions=[
            AdminUserDetailSubscription(
                id=item.subscription.id,
                tier=item.subscription.tier,
                status=item.subscription.status,
                planId=item.subscription.plan_id,
                planTier=item.plan.tier if item.plan else None,
                planDurationMonths=(
                    item.plan.duration_months if item.plan else None
                ),
                purchasedPriceJod=(
                    item.subscription.purchased_price_jod
                    if item.subscription.purchased_price_jod is not None
                    else (item.plan.price_jod if item.plan else None)
                ),
                planPriceJod=item.plan.price_jod if item.plan else None,
                planMonthlyVisits=(item.plan.monthly_visits if item.plan else None),
                startsAt=item.subscription.starts_at,
                expiresAt=item.subscription.expires_at,
                visitsUsed=item.subscription.visits_used,
                autoRenew=item.subscription.auto_renew,
                cancelledAt=item.subscription.cancelled_at,
                createdAt=item.subscription.created_at,
            )
            for item in detail.subscription_history
        ],
        payments=[
            AdminUserDetailPayment(
                id=entry.payment.id,
                subscriptionId=(entry.subscription.id if entry.subscription else None),
                subscriptionTier=(entry.subscription.tier if entry.subscription else None),
                amountJod=entry.payment.amount_jod,
                method=entry.payment.method,
                status=entry.payment.status,
                gatewayTxnId=entry.payment.gateway_txn_id,
                processedAt=entry.payment.processed_at,
                createdAt=entry.payment.created_at,
                meta=_payment_meta(entry.payment.method, entry.payment.raw_response),
            )
            for entry in detail.payment_history
        ],
        tickets=[
            AdminUserDetailTicket(
                id=t.id,
                category=t.category,
                priority=t.priority,
                status=t.status,
                subject=t.subject,
                createdAt=t.created_at,
                updatedAt=t.updated_at,
                resolvedAt=t.resolved_at,
            )
            for t in detail.tickets
        ],
        recentCheckins=[
            AdminUserDetailCheckin(
                id=c.id,
                gymId=g.id,
                gymNameEn=g.name_en,
                status=c.status,
                scannedAt=c.scanned_at,
                failureReason=c.failure_reason,
            )
            for c, g in detail.recent_checkins
        ],
        paymentMethods=[
            AdminUserDetailPaymentMethodsEntry(method=m["method"], count=m["count"], last=m["last"])
            for m in detail.payment_method_summary["methods"]
        ],
        totals=AdminUserDetailTotals(
            totalPaidJod=detail.totals["totalPaidJod"],
            subscriptionCount=detail.totals["subscriptionCount"],
            hasActiveSubscription=detail.totals["hasActiveSubscription"],
            activeTier=detail.totals["activeTier"],
            ticketCount=detail.totals["ticketCount"],
            openTicketCount=detail.totals["openTicketCount"],
            referralCount=detail.totals["referralCount"],
            convertedReferralCount=detail.totals["convertedReferralCount"],
        ),
    )


def _payment_meta(method: object, raw: dict | None) -> dict:
    # Surface only safe, user-facing fields from the payment provider's raw
    # blob — never the whole payload (may contain secrets).
    raw = raw or {}
    out: dict[str, object] = {}
    m = method.value if hasattr(method, "value") else str(method)
    if m == "cliq":
        alias = raw.get("cliq_alias") or raw.get("alias")
        phone = raw.get("cliq_phone") or raw.get("phone")
        if alias:
            out["alias"] = alias
        if phone:
            out["phone"] = phone
    elif m == "card":
        last4 = raw.get("last4") or raw.get("card_last4")
        brand = raw.get("brand") or raw.get("card_brand")
        if last4:
            out["last4"] = last4
        if brand:
            out["brand"] = brand
    return out
