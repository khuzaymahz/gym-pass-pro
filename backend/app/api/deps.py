from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header, Request
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ErrorCode
from app.core.redis_client import get_redis
from app.core.security import decode_token
from app.db.enums import Role
from app.db.models import User
from app.db.session import get_session
from app.providers.payments import PaymentProvider, build_payment_provider
from app.providers.push import PushProvider, build_push_provider
from app.providers.sms import SmsProvider, build_sms_provider
from app.repositories.audit_repo import AuditRepository
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.gym_photo_repo import GymPhotoRepository
from app.repositories.gym_repo import GymRepository
from app.repositories.notification_repo import NotificationRepository
from app.repositories.otp_repo import OtpRepository
from app.repositories.payment_method_repo import PaymentMethodRepository
from app.repositories.payment_repo import PaymentRepository
from app.repositories.payout_repo import PayoutLedgerRepository, PayoutRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.referral_repo import ReferralRepository
from app.repositories.refresh_token_repo import RefreshTokenRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.repositories.support_ticket_repo import SupportTicketRepository
from app.repositories.user_repo import UserRepository
from app.services.admin_audit_service import AdminAuditService
from app.services.admin_broadcast_service import AdminBroadcastService
from app.services.admin_checkin_read_service import AdminCheckinReadService
from app.services.admin_metrics_service import AdminMetricsService
from app.services.admin_partner_service import AdminPartnerService
from app.services.admin_payout_service import AdminPayoutService
from app.services.admin_plan_service import AdminPlanService
from app.services.admin_subscription_service import AdminSubscriptionService
from app.services.admin_user_detail_service import AdminUserDetailService
from app.services.admin_user_service import AdminUserService
from app.services.audit_service import Actor, AuditService
from app.services.auth_service import AuthService
from app.services.checkin_service import CheckinService
from app.services.gym_service import GymService
from app.services.partner_checkin_read_service import PartnerCheckinReadService
from app.services.partner_metrics_service import PartnerMetricsService
from app.services.pause_service import PauseService
from app.services.payment_method_service import PaymentMethodService
from app.services.rate_limit import RateLimiter
from app.services.referral_service import ReferralService
from app.services.subscription_service import SubscriptionService
from app.services.support_ticket_service import SupportTicketService


async def db_session() -> AsyncIterator[AsyncSession]:
    async for session in get_session():
        yield session


async def redis_client() -> Redis:
    return get_redis()


# ----- Repos -----

SessionDep = Annotated[AsyncSession, Depends(db_session)]


def user_repo(session: SessionDep) -> UserRepository:
    return UserRepository(session)


def otp_repo(session: SessionDep) -> OtpRepository:
    return OtpRepository(session)


def gym_repo(session: SessionDep) -> GymRepository:
    return GymRepository(session)


def gym_photo_repo(session: SessionDep) -> GymPhotoRepository:
    return GymPhotoRepository(session)


def plan_repo(session: SessionDep) -> PlanRepository:
    return PlanRepository(session)


def subscription_repo(session: SessionDep) -> SubscriptionRepository:
    return SubscriptionRepository(session)


def subscription_pause_repo(
    session: SessionDep,
) -> SubscriptionPauseRepository:
    return SubscriptionPauseRepository(session)


def payment_repo(session: SessionDep) -> PaymentRepository:
    return PaymentRepository(session)


def payment_method_repo(session: SessionDep) -> PaymentMethodRepository:
    return PaymentMethodRepository(session)


def checkin_repo(session: SessionDep) -> CheckinRepository:
    return CheckinRepository(session)


def payout_repo(session: SessionDep) -> PayoutLedgerRepository:
    return PayoutLedgerRepository(session)


def payout_agg_repo(session: SessionDep) -> PayoutRepository:
    return PayoutRepository(session)


def audit_repo(session: SessionDep) -> AuditRepository:
    return AuditRepository(session)


def refresh_token_repo(session: SessionDep) -> RefreshTokenRepository:
    return RefreshTokenRepository(session)


def notification_repo(session: SessionDep) -> NotificationRepository:
    return NotificationRepository(session)


def support_ticket_repo(session: SessionDep) -> SupportTicketRepository:
    return SupportTicketRepository(session)


def referral_repo(session: SessionDep) -> ReferralRepository:
    return ReferralRepository(session)


# ----- Providers -----

def sms_provider() -> SmsProvider:
    return build_sms_provider()


def payment_provider() -> PaymentProvider:
    return build_payment_provider()


def push_provider() -> PushProvider:
    return build_push_provider()


# ----- Services -----

def rate_limiter(redis: Annotated[Redis, Depends(redis_client)]) -> RateLimiter:
    return RateLimiter(redis)


def audit_service(
    repo: Annotated[AuditRepository, Depends(audit_repo)]
) -> AuditService:
    return AuditService(repo)


def auth_service(
    users: Annotated[UserRepository, Depends(user_repo)],
    otps: Annotated[OtpRepository, Depends(otp_repo)],
    refreshes: Annotated[RefreshTokenRepository, Depends(refresh_token_repo)],
    rl: Annotated[RateLimiter, Depends(rate_limiter)],
    sms: Annotated[SmsProvider, Depends(sms_provider)],
    audit: Annotated[AuditService, Depends(audit_service)],
    referrals_svc: Annotated[ReferralService, Depends(referral_service)],
) -> AuthService:
    return AuthService(
        users, otps, refreshes, rl, sms, audit, referrals_svc
    )


def referral_service(
    users: Annotated[UserRepository, Depends(user_repo)],
    referrals: Annotated[ReferralRepository, Depends(referral_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> ReferralService:
    return ReferralService(users, referrals, audit)


def subscription_service(
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    plans: Annotated[PlanRepository, Depends(plan_repo)],
    payments: Annotated[PaymentRepository, Depends(payment_repo)],
    checkins: Annotated[CheckinRepository, Depends(checkin_repo)],
    provider: Annotated[PaymentProvider, Depends(payment_provider)],
    audit: Annotated[AuditService, Depends(audit_service)],
    referrals_svc: Annotated[ReferralService, Depends(referral_service)],
) -> SubscriptionService:
    return SubscriptionService(
        subs, plans, payments, checkins, provider, audit, referrals_svc
    )


def checkin_service(
    gyms: Annotated[GymRepository, Depends(gym_repo)],
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    plans: Annotated[PlanRepository, Depends(plan_repo)],
    checkins: Annotated[CheckinRepository, Depends(checkin_repo)],
    pauses: Annotated[
        SubscriptionPauseRepository, Depends(subscription_pause_repo)
    ],
    ledger: Annotated[PayoutLedgerRepository, Depends(payout_repo)],
    rl: Annotated[RateLimiter, Depends(rate_limiter)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> CheckinService:
    return CheckinService(
        gyms, subs, plans, checkins, pauses, ledger, rl, audit
    )


def gym_service(
    repo: Annotated[GymRepository, Depends(gym_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> GymService:
    return GymService(repo, audit)


def payment_method_service(
    repo: Annotated[PaymentMethodRepository, Depends(payment_method_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> PaymentMethodService:
    return PaymentMethodService(repo, audit)


def pause_service(
    pauses: Annotated[
        SubscriptionPauseRepository, Depends(subscription_pause_repo)
    ],
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    plans: Annotated[PlanRepository, Depends(plan_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> PauseService:
    return PauseService(pauses, subs, plans, audit)


# ----- Admin services -----

def admin_user_service(
    users: Annotated[UserRepository, Depends(user_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> AdminUserService:
    return AdminUserService(users, audit)


def admin_user_detail_service() -> AdminUserDetailService:
    # Pure read aggregator — uses the cached session factory directly
    # for parallel queries. No per-request shared session needed.
    from app.db.session import session_factory

    return AdminUserDetailService(session_factory())


def admin_plan_service(
    plans: Annotated[PlanRepository, Depends(plan_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> AdminPlanService:
    return AdminPlanService(plans, audit)


def admin_subscription_service(
    subs: Annotated[SubscriptionRepository, Depends(subscription_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> AdminSubscriptionService:
    return AdminSubscriptionService(subs, audit)


def admin_payout_service(
    payouts: Annotated[PayoutRepository, Depends(payout_agg_repo)],
    ledger: Annotated[PayoutLedgerRepository, Depends(payout_repo)],
    gyms: Annotated[GymRepository, Depends(gym_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> AdminPayoutService:
    return AdminPayoutService(payouts, ledger, gyms, audit)


def admin_metrics_service(
    session: SessionDep,
    redis: Annotated[Redis, Depends(redis_client)],
) -> AdminMetricsService:
    # Shared session is kept only for the system-health probe;
    # every domain query runs on a fresh session for parallelism.
    from app.db.session import session_factory

    return AdminMetricsService(session, redis, session_factory())


def admin_broadcast_service(
    notifications: Annotated[NotificationRepository, Depends(notification_repo)],
    users: Annotated[UserRepository, Depends(user_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> AdminBroadcastService:
    return AdminBroadcastService(notifications, users, audit)


def support_ticket_service(
    repo: Annotated[SupportTicketRepository, Depends(support_ticket_repo)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> SupportTicketService:
    return SupportTicketService(repo, audit)


def partner_metrics_service() -> PartnerMetricsService:
    # Takes the cached factory directly (no per-request shared
    # session) because each metric query opens its own session for
    # parallel execution. See PartnerMetricsService.overview.
    from app.db.session import session_factory

    return PartnerMetricsService(session_factory())


def admin_partner_service(
    users: Annotated[UserRepository, Depends(user_repo)],
    gyms: Annotated[GymService, Depends(gym_service)],
    audit: Annotated[AuditService, Depends(audit_service)],
) -> AdminPartnerService:
    return AdminPartnerService(users, gyms, audit)


def admin_audit_service(
    repo: Annotated[AuditRepository, Depends(audit_repo)],
) -> AdminAuditService:
    return AdminAuditService(repo)


def admin_checkin_read_service(
    checkins: Annotated[CheckinRepository, Depends(checkin_repo)],
) -> AdminCheckinReadService:
    return AdminCheckinReadService(checkins)


def partner_checkin_read_service(
    checkins: Annotated[CheckinRepository, Depends(checkin_repo)],
) -> PartnerCheckinReadService:
    return PartnerCheckinReadService(checkins)


# ----- Auth / actor -----

def _client_ip(request: Request) -> str | None:
    """Resolve the originating client IP, honoring `X-Forwarded-For` /
    `Forwarded` set by our nginx layer.

    Without this, every request behind the proxy collapses to nginx's
    container IP, so per-IP rate limiting becomes a single shared
    bucket for the whole world. We trust the **rightmost** entry of
    `X-Forwarded-For` only when the immediate peer is a known proxy
    (nginx or loopback in dev); otherwise we fall back to the peer
    IP and ignore the header (caller can spoof it).
    """
    peer = request.client.host if request.client else None
    if peer is None:
        return None
    # Trust the proxy chain only if the peer is one of our own
    # infra nodes. In production this is the nginx container on the
    # docker bridge; in dev it's loopback. Anything else: ignore the
    # forwarded headers — they're attacker-controlled.
    if not _is_trusted_proxy(peer):
        return peer
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        # XFF is `client, proxy1, proxy2, ...` — leftmost is the
        # original client. Strip whitespace and take the first
        # non-empty token.
        for part in forwarded.split(","):
            candidate = part.strip()
            if candidate:
                return candidate
    return peer


def _is_trusted_proxy(host: str) -> bool:
    # Loopback (dev) + RFC1918 private ranges (docker bridge / VPC).
    # Sufficient for our nginx-in-docker topology; tighten to a
    # specific CIDR in prod if we ever expose the API to additional
    # ingress paths.
    if host in ("127.0.0.1", "::1", "localhost"):
        return True
    if host.startswith("10.") or host.startswith("192.168."):
        return True
    if host.startswith("172."):
        try:
            second = int(host.split(".", 2)[1])
        except (IndexError, ValueError):
            return False
        return 16 <= second <= 31
    return False


def client_actor(request: Request) -> Actor:
    return Actor(
        user_id=None,
        role=None,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )


async def _authed(
    request: Request,
    users: UserRepository,
    authorization: str | None,
    expected_types: tuple[str, ...],
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Missing bearer token.")
    token = authorization.split(" ", 1)[1]
    payload = decode_token(token)
    if payload.get("type") not in expected_types:
        raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Wrong token type.")
    try:
        user_id = UUID(str(payload["sub"]))
    except (KeyError, ValueError) as exc:
        raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "Invalid subject.") from exc
    user = await users.get(user_id)
    if user is None or user.deleted_at is not None:
        raise AppError(ErrorCode.AUTH_TOKEN_INVALID, "User not found.")
    request.state.user_id = user.id
    request.state.user_role = user.role.value
    return user


async def current_user(
    request: Request,
    users: Annotated[UserRepository, Depends(user_repo)],
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    return await _authed(request, users, authorization, ("access",))


async def current_user_optional(
    request: Request,
    users: Annotated[UserRepository, Depends(user_repo)],
    authorization: Annotated[str | None, Header()] = None,
) -> User | None:
    """Same as `current_user` but returns None for unauthenticated
    callers instead of 401.

    Used by surfaces that need to *personalise* their response when a
    token is present but should still be reachable without one — most
    notably the gym list, which a signed-out member can browse pre-
    signup to evaluate the network. When the caller is anonymous the
    response is treated as prefer-not-to-say (mixed gyms only); when
    signed in, the caller's profile gender shapes visibility.
    """

    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    try:
        return await _authed(request, users, authorization, ("access",))
    except AppError:
        # Token present but invalid / expired. Treating this as
        # "anonymous" rather than re-raising lets the gym list keep
        # rendering after a token expires; the caller's mobile will
        # refresh the token on the *next* authed call and recover.
        return None


async def current_admin(
    request: Request,
    users: Annotated[UserRepository, Depends(user_repo)],
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    user = await _authed(request, users, authorization, ("service", "access"))
    if user.role != Role.ADMIN:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Admin role required.")
    return user


async def current_gym_owner(
    request: Request,
    users: Annotated[UserRepository, Depends(user_repo)],
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    """Resolve the calling gym-owner. Refuses if the bearer isn't a
    `gym_owner` role *and* doesn't have a gym linked. Both checks
    matter — a partner whose gym was deleted (FK SET NULL) becomes
    `gym_id IS NULL` and we want to reject that login session
    cleanly rather than 500 inside a downstream query.
    """
    user = await _authed(request, users, authorization, ("service", "access"))
    if user.role != Role.GYM_OWNER:
        raise AppError(ErrorCode.AUTH_FORBIDDEN, "Gym owner role required.")
    if user.gym_id is None:
        raise AppError(
            ErrorCode.AUTH_FORBIDDEN, "Gym owner is not linked to a gym."
        )
    return user


def authed_actor(request: Request, user: User) -> Actor:
    return Actor(
        user_id=user.id,
        role=user.role,
        ip_address=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
    )
