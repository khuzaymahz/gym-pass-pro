from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import (
    AudienceGender,
    CheckinStatus,
    Gender,
    SubscriptionStatus,
    Tier,
)
from app.db.models import Checkin, DayPass, Gym, User
from app.repositories.checkin_repo import CheckinRepository
from app.repositories.day_pass_repo import DayPassRepository
from app.repositories.gym_repo import GymRepository
from app.repositories.payout_repo import PayoutLedgerRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.day_pass_service import DayPassService
from app.services.rate_limit import RateLimiter
from app.utils.time import current_period_start, utcnow

# Per-(user, gym) dedupe window. Protects against rapid re-scans at
# the same gym (double-tap, network retry) and surfaces a friendly
# "already scanned here" error rather than a budget-burn. Strictly a
# UX gate — does NOT close the concurrency race against the visit
# budget, which is what the FOR UPDATE row lock below is for.
CHECKIN_RATE_LIMIT = 1
CHECKIN_RATE_WINDOW_SECONDS = 30 * 60
# Per-user global concurrency gate. Short window — just enough to
# blunt the obvious case of one member's two devices scanning at
# two different gyms in the same millisecond. The real correctness
# guarantee is the `lock_active_for_user` row lock; this limiter is
# a cheap early bounce so we don't waste a DB round-trip on every
# rapid double-scan across gyms.
CHECKIN_USER_RATE_LIMIT = 1
CHECKIN_USER_RATE_WINDOW_SECONDS = 5


@dataclass(frozen=True)
class CheckinResult:
    """Outcome of a successful (or recorded-failure) check-in scan.

    `gym` is set whenever a real `Gym` row was resolved; only the
    invalid-QR path leaves it `None`. `remaining` is the per-period
    visit budget after this scan — None for the failure paths that
    don't consume a visit; otherwise `monthly_visits - period_count`,
    floored at zero, the same shape for every tier.
    """

    checkin: Checkin
    gym: Gym | None
    remaining: int | None


class CheckinService:
    def __init__(
        self,
        gyms: GymRepository,
        subs: SubscriptionRepository,
        plans: PlanRepository,
        checkins: CheckinRepository,
        pauses: SubscriptionPauseRepository,
        ledger: PayoutLedgerRepository,
        rate_limiter: RateLimiter,
        audit: AuditService,
        day_passes: DayPassRepository,
        day_pass_service: DayPassService,
    ) -> None:
        self.gyms = gyms
        self.subs = subs
        self.plans = plans
        self.checkins = checkins
        self.pauses = pauses
        self.ledger = ledger
        self.rate_limiter = rate_limiter
        self.audit = audit
        self.day_passes = day_passes
        self.day_pass_service = day_pass_service

    async def scan(
        self,
        *,
        user: User,
        qr_payload: str,
        actor: Actor,
    ) -> CheckinResult:
        gym = await self._resolve_gym(qr_payload)

        if gym is None or not gym.is_active or gym.deleted_at is not None:
            # If we couldn't resolve a real gym at all, skip the
            # `checkins` row — `gym_id` is FK NOT NULL, and writing a
            # phantom UUID raises an IntegrityError that surfaces to
            # the client as a 500. The audit-log entry below preserves
            # the failed-scan trail without polluting the gym FK.
            if gym is not None:
                await self.checkins.create(
                    user_id=user.id,
                    gym_id=gym.id,
                    subscription_id=None,
                    status=CheckinStatus.INVALID_QR,
                    failure_reason="gym_inactive_or_deleted",
                    ip_address=actor.ip_address,
                    user_agent=actor.user_agent,
                )
            await self.audit.log(
                actor=actor,
                action="checkin.invalid_qr",
                entity_type="checkin",
                entity_id=None,
                diff={"qr_payload": qr_payload[:64]},
            )
            raise AppError(ErrorCode.CHECKIN_QR_INVALID, "Invalid QR.") from None

        # Two-stage rate limit BEFORE touching the subscription. The
        # per-(user, gym) bucket carries the friendly "scanned here
        # recently" UX message; the per-user bucket blunts concurrent
        # scans across gyms before they reach the DB. Neither is the
        # primary race-correctness guarantee — `lock_active_for_user`
        # below is — but they're cheap enough that letting an obvious
        # spam pattern reach the row lock would just be wasteful.
        rl_key = f"checkin:{user.id}:{gym.id}"
        if not await self.rate_limiter.allow(
            rl_key, limit=CHECKIN_RATE_LIMIT,
            window_seconds=CHECKIN_RATE_WINDOW_SECONDS,
        ):
            await self.checkins.create(
                user_id=user.id, gym_id=gym.id, subscription_id=None,
                status=CheckinStatus.RATE_LIMITED,
                failure_reason="duplicate_scan_within_window",
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            )
            raise AppError(
                ErrorCode.CHECKIN_ALREADY_SCANNED,
                "Already scanned recently at this gym.",
            )
        user_rl_key = f"checkin:{user.id}"
        if not await self.rate_limiter.allow(
            user_rl_key, limit=CHECKIN_USER_RATE_LIMIT,
            window_seconds=CHECKIN_USER_RATE_WINDOW_SECONDS,
        ):
            await self.checkins.create(
                user_id=user.id, gym_id=gym.id, subscription_id=None,
                status=CheckinStatus.RATE_LIMITED,
                failure_reason="concurrent_scan_across_gyms",
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            )
            raise AppError(
                ErrorCode.CHECKIN_ALREADY_SCANNED,
                "Another scan is in progress. Try again in a moment.",
            )

        # Day-pass branch: a non-subscriber (or even a subscriber
        # holding a one-off pass for this gym) bypasses the
        # subscription / tier / audience / visit-budget ladder and
        # redeems the pass directly. The pass row already carries
        # the audience check from purchase time and is gym-specific,
        # so re-doing those gates here would be redundant and
        # could deny a holder who, e.g., changed gender after
        # purchase. The check-in is still recorded and the gym
        # still gets paid via the payout ledger (using the pass's
        # net amount, not the gym's per_visit_rate).
        now = utcnow()
        active_pass = await self.day_passes.active_for_user_gym(
            user_id=user.id, gym_id=gym.id, now=now
        )
        if active_pass is not None:
            return await self._success_via_day_pass(
                user=user,
                gym=gym,
                day_pass=active_pass,
                actor=actor,
            )

        # Take `SELECT … FOR UPDATE` on the active subscription row.
        # Holding this lock until the transaction commits is what
        # makes the visit-budget gate below race-safe: two concurrent
        # scans for the same user (different gyms or otherwise)
        # serialize on the lock, so the count + INSERT pair runs
        # atomically per-subscription. The lock is released at the
        # session-level commit/rollback the route layer drives.
        sub = await self.subs.lock_active_for_user(user.id)
        if sub is None or sub.status != SubscriptionStatus.ACTIVE:
            await self.checkins.create(
                user_id=user.id, gym_id=gym.id, subscription_id=None,
                status=CheckinStatus.EXPIRED, failure_reason="no_active_subscription",
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            )
            raise AppError(ErrorCode.SUB_EXPIRED, "No active subscription.")

        # Pause guard. An open pause whose window straddles today blocks
        # the scan — a paused member is paying nothing for these days
        # and the gym should see them as inactive at the door. We log
        # the failure as `expired` since `checkin_status_enum` doesn't
        # have a `paused` variant; `failure_reason` carries the detail
        # for the admin queue.
        open_pause = await self.pauses.open_for_subscription(sub.id)
        if open_pause is not None:
            today = utcnow().date()
            in_window = (
                open_pause.starts_on <= today <= open_pause.ends_on
            )
            if in_window:
                await self.checkins.create(
                    user_id=user.id, gym_id=gym.id, subscription_id=sub.id,
                    status=CheckinStatus.EXPIRED,
                    failure_reason="subscription_paused",
                    ip_address=actor.ip_address, user_agent=actor.user_agent,
                )
                raise AppError(
                    ErrorCode.SUB_PAUSED,
                    "Subscription is paused. Resume to check in.",
                    details={
                        "endsOn": open_pause.ends_on.isoformat(),
                    },
                )

        if sub.tier.rank < gym.required_tier.rank:
            await self.checkins.create(
                user_id=user.id, gym_id=gym.id, subscription_id=sub.id,
                status=CheckinStatus.TIER_LOCKED,
                failure_reason=f"required_tier={gym.required_tier.value}",
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            )
            raise AppError(
                ErrorCode.CHECKIN_TIER_LOCKED,
                f"{gym.required_tier.value.capitalize()} tier required.",
                details={"requiredTier": gym.required_tier.value,
                         "userTier": sub.tier.value},
            )

        # Gender-audience check: a male member scanning at a
        # `female_only` gym (or vice versa) is refused. A member with
        # a null gender (legacy row predating the mandatory-gender
        # form) cannot match a single-sex audience either — the gym
        # would verify gender at the door anyway, so we surface the
        # same failure here. Mixed gyms are always reachable. Failure
        # rows are audited so a partner can see when scans bounced on
        # this gate.
        if gym.audience_gender != AudienceGender.MIXED:
            allowed_gender = (
                Gender.MALE
                if gym.audience_gender == AudienceGender.MALE_ONLY
                else Gender.FEMALE
            )
            if user.gender != allowed_gender:
                await self.checkins.create(
                    user_id=user.id, gym_id=gym.id, subscription_id=sub.id,
                    status=CheckinStatus.GENDER_LOCKED,
                    failure_reason=(
                        f"audience={gym.audience_gender.value}"
                        f" user_gender="
                        f"{user.gender.value if user.gender else 'unset'}"
                    ),
                    ip_address=actor.ip_address, user_agent=actor.user_agent,
                )
                label = (
                    "Women-only"
                    if gym.audience_gender == AudienceGender.FEMALE_ONLY
                    else "Men-only"
                )
                raise AppError(
                    ErrorCode.CHECKIN_GENDER_LOCKED,
                    f"{label} gym — check-in not available.",
                    details={
                        "audienceGender": gym.audience_gender.value,
                        "userGender": (
                            user.gender.value if user.gender else None
                        ),
                    },
                )

        # Visit budget — same per-period cap for every tier. The cap is
        # *per billing period*, not lifetime: counting from
        # `current_period_start` means a 12-month plan resets every 30
        # days without a cron, and the answer is always derivable from
        # immutable check-in rows.
        #
        # Per business model: tier gates the gym network (Silver = entry
        # gyms, Diamond = full partner network), not the visit count.
        # Every plan in the catalog seeds with `monthly_visits = 30`, and
        # the gate applies uniformly. The earlier `if sub.tier !=
        # Tier.DIAMOND` bypass was a model leak — it let Diamond members
        # scan past the cap their plan was actually selling.
        plan = await self.plans.get(sub.plan_id)
        if plan is None:
            raise AppError(ErrorCode.PLAN_NOT_FOUND, "Plan missing for subscription.")
        period_start = current_period_start(sub.starts_at, utcnow())
        current_period_visits = (
            await self.checkins.count_success_since_for_user(
                user.id, period_start
            )
        )
        if current_period_visits >= plan.monthly_visits:
            await self.checkins.create(
                user_id=user.id, gym_id=gym.id, subscription_id=sub.id,
                status=CheckinStatus.NO_VISITS,
                failure_reason="visits_exhausted",
                ip_address=actor.ip_address, user_agent=actor.user_agent,
            )
            raise AppError(
                ErrorCode.CHECKIN_NO_VISITS, "Visit budget exhausted."
            )

        # Success path.
        checkin = await self.checkins.create(
            user_id=user.id, gym_id=gym.id, subscription_id=sub.id,
            status=CheckinStatus.SUCCESS,
            ip_address=actor.ip_address, user_agent=actor.user_agent,
        )
        await self.subs.increment_visits(sub.id)
        await self.ledger.record(
            gym_id=gym.id, checkin_id=checkin.id, rate=gym.per_visit_rate_jod
        )
        await self.audit.log(
            actor=actor, action="checkin.success",
            entity_type="checkin", entity_id=checkin.id,
            diff={"gym_id": str(gym.id)},
        )

        # Compute the period-remaining visit budget so the caller
        # doesn't need to re-query. Reuses the same indexed `checkins`
        # rows the budget gate above used, so the response stays
        # coherent with the just-committed scan without re-reading
        # the (denormalized, lifetime) `subscriptions.visits_used`.
        # Same shape for every tier: `monthly_visits - period_count`,
        # floored at zero.
        remaining = max(0, plan.monthly_visits - (current_period_visits + 1))

        return CheckinResult(checkin=checkin, gym=gym, remaining=remaining)

    async def _success_via_day_pass(
        self,
        *,
        user: User,
        gym: Gym,
        day_pass: DayPass,
        actor: Actor,
    ) -> CheckinResult:
        """Day-pass redemption check-in. Records the check-in,
        marks the pass used, and writes a payout-ledger entry with
        the pass's NET amount (price minus platform fee, snapshotted
        at purchase). Returns `remaining=None` because day-pass
        holders have no per-period visit budget to surface.
        """
        checkin = await self.checkins.create(
            user_id=user.id,
            gym_id=gym.id,
            subscription_id=None,
            status=CheckinStatus.SUCCESS,
            ip_address=actor.ip_address,
            user_agent=actor.user_agent,
        )
        # Mark the pass used + audit (delegated to DayPassService so
        # the full pass lifecycle stays in one audit-action namespace).
        await self.day_pass_service.redeem(
            day_pass, checkin_id=checkin.id, actor=actor
        )
        # Payout ledger: gym is owed the NET amount the day pass
        # snapshotted at purchase time. Distinct from the
        # per_visit_rate path subscription scans take, but lands in
        # the same `payout_ledger` table so the monthly aggregation
        # query picks both kinds of revenue up without changes.
        await self.ledger.record(
            gym_id=gym.id,
            checkin_id=checkin.id,
            rate=day_pass.net_amount_jod,
        )
        await self.audit.log(
            actor=actor,
            action="checkin.success_via_day_pass",
            entity_type="checkin",
            entity_id=checkin.id,
            diff={
                "gym_id": str(gym.id),
                "day_pass_id": str(day_pass.id),
                "payout_amount_jod": str(day_pass.net_amount_jod),
            },
        )
        return CheckinResult(checkin=checkin, gym=gym, remaining=None)

    async def history(self, user: User, *, limit: int = 20) -> list[tuple[Checkin, Gym]]:
        return await self.checkins.history_for_user(user.id, limit=limit)

    async def _resolve_gym(self, qr_payload: str) -> Gym | None:
        """QR formats accepted, in priority order:

        1. `https://gym-pass.net/g/<uuid>` — production printable QR.
           Stored as a real URL so a member without the app gets a
           friendly browser landing (handled at the edge by nginx)
           instead of an unhandled `gympass:` URI scheme prompt.
        2. `gympass:<uuid>` — legacy printable QR. Older prints in
           the wild still scan; kept for back-compat.
        3. Plain UUID — direct / API-level.
        4. Plain slug (e.g. `iron-forge`) — used by the mobile dev
           panel's "Scan Silver / Gold / ..." shortcuts so testers
           can exercise the real backend round-trip without needing
           a printed code. Slug lookup is gated on no-leading-colon
           and no-slash so it never collides with the URL or
           `gympass:` prefix forms.
        """
        payload = qr_payload.strip()
        # Strip the HTTPS prefix first so the trailing UUID flows
        # through the same UUID-or-slug branch as the bare forms.
        # We match both apex and `www.` for forgiveness against
        # camera apps that auto-add the canonical host.
        for prefix in ("https://gym-pass.net/g/", "https://www.gym-pass.net/g/"):
            if payload.startswith(prefix):
                payload = payload[len(prefix) :]
                break
        else:
            if payload.startswith("gympass:"):
                payload = payload.split(":", 1)[1]
        # A trailing slash or query string from a manual URL paste
        # would otherwise fail the UUID parse — strip them.
        payload = payload.split("?", 1)[0].split("#", 1)[0].rstrip("/")
        try:
            gym_id = UUID(payload)
        except ValueError:
            # Not a UUID — try the slug path. Slugs are
            # `[a-z0-9-]+` so anything containing other characters
            # is bogus and short-circuits to None without a DB hit.
            if payload and all(c.isalnum() or c == "-" for c in payload):
                return await self.gyms.get_by_slug(payload)
            return None
        return await self.gyms.get(gym_id)


__all__ = ["CheckinResult", "CheckinService"]
