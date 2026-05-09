from __future__ import annotations

from datetime import date, datetime, timedelta
from uuid import UUID

import structlog
from sqlalchemy.exc import IntegrityError

from app.core.exceptions import AppError, ErrorCode
from app.db.models import Subscription, SubscriptionPause
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.pause_policy import max_pauses, pause_allowance_days
from app.utils.time import utcnow

log = structlog.get_logger(__name__)


class PauseService:
    """Owns pause / resume / auto-resume for subscriptions.

    Three entry points:
      - `schedule(...)`: validate the requested window against the per-
        plan allowance, refuse if it overlaps an existing open pause,
        insert the pause row.
      - `resume(...)`: manual early resume from the member. Computes
        days_consumed against today, finalises the pause row, and
        shifts the parent subscription's `expires_at` forward.
      - `sweep_expired(now)`: invoked by the Celery beat job. Finds
        all open pauses whose `ends_on` has rolled past, finalises
        each, and shifts the parent subscription's `expires_at` by
        the full window length.

    The shift-on-finalize approach (rather than shift-on-start) means
    a member who manually resumes early gets credit for the unused
    days — exactly what they expected from a "pause" feature.
    """

    def __init__(
        self,
        pauses: SubscriptionPauseRepository,
        subs: SubscriptionRepository,
        plans: PlanRepository,
        audit: AuditService,
    ) -> None:
        self.pauses = pauses
        self.subs = subs
        self.plans = plans
        self.audit = audit

    async def schedule(
        self,
        *,
        subscription: Subscription,
        starts_on: date,
        ends_on: date,
        actor: Actor,
    ) -> SubscriptionPause:
        if ends_on < starts_on:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Pause end date must be on or after the start date.",
            )
        today = utcnow().date()
        if starts_on < today:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Pause cannot start in the past.",
            )

        plan = await self.plans.get(subscription.plan_id)
        if plan is None:
            raise AppError(
                ErrorCode.PLAN_NOT_FOUND, "Plan missing for subscription."
            )

        allowance = pause_allowance_days(subscription.tier, plan.duration_months)
        if allowance == 0:
            raise AppError(
                ErrorCode.SUB_PAUSE_NOT_ALLOWED,
                "Pause is not available on this plan.",
            )

        max_count = max_pauses(plan.duration_months)
        used_count = await self.pauses.count_for_subscription(subscription.id)
        if used_count >= max_count:
            raise AppError(
                ErrorCode.SUB_PAUSE_NOT_ALLOWED,
                "Maximum number of pauses reached on this term.",
                details={"max": max_count, "used": used_count},
            )

        days_already_consumed = await self.pauses.total_days_consumed(
            subscription.id
        )
        # Inclusive day count: a same-day pause is one day, not zero.
        # Falls in line with how a member counts vacations on a calendar.
        requested_days = (ends_on - starts_on).days + 1
        if days_already_consumed + requested_days > allowance:
            raise AppError(
                ErrorCode.SUB_PAUSE_NOT_ALLOWED,
                "Pause window exceeds the term's day allowance.",
                details={
                    "allowance": allowance,
                    "alreadyConsumed": days_already_consumed,
                    "requested": requested_days,
                },
            )

        existing_open = await self.pauses.open_for_subscription(subscription.id)
        if existing_open is not None:
            raise AppError(
                ErrorCode.SUB_PAUSE_NOT_ALLOWED,
                "A pause is already scheduled or active.",
            )

        try:
            row = await self.pauses.create(
                subscription_id=subscription.id,
                starts_on=starts_on,
                ends_on=ends_on,
            )
        except IntegrityError as exc:
            # The partial unique index races with a concurrent client.
            # Map to the same error code the explicit-check branch uses.
            raise AppError(
                ErrorCode.SUB_PAUSE_NOT_ALLOWED,
                "A pause is already scheduled or active.",
            ) from exc

        await self.audit.log(
            actor=actor,
            action="subscription.pause.schedule",
            entity_type="subscription_pause",
            entity_id=row.id,
            diff={
                "after": {
                    "subscription_id": str(subscription.id),
                    "starts_on": starts_on.isoformat(),
                    "ends_on": ends_on.isoformat(),
                    "requested_days": requested_days,
                }
            },
        )
        return row

    async def resume(
        self,
        *,
        subscription: Subscription,
        actor: Actor,
        now: datetime | None = None,
    ) -> SubscriptionPause | None:
        """Manual early resume. No-op if no open pause exists. Returns
        the finalised pause row so the caller can surface the new
        `expires_at` in the response."""
        moment = now or utcnow()
        open_row = await self.pauses.open_for_subscription(subscription.id)
        if open_row is None:
            return None
        return await self._finalize(
            subscription=subscription,
            pause=open_row,
            now=moment,
            actor=actor,
            reason="manual_resume",
        )

    async def sweep_expired(
        self, *, now: datetime, actor: Actor
    ) -> list[SubscriptionPause]:
        """Cron entry: auto-resume every pause whose window has ended.
        Each finalisation shifts the parent subscription's `expires_at`
        forward by the days the member actually lost. Returns the list
        of pauses that were finalised this run for logging.

        Uses `subs.get_many(...)` so a sweep over N pauses runs a single
        IN-list query instead of N point-lookups; with the cron firing
        every minute and pause windows mostly clearing in batches
        (members on the same monthly cycle), the previous N+1 was a
        noticeable contributor to DB chatter.
        """
        cutoff = now.date()
        open_rows = await self.pauses.list_open_ending_on_or_before(cutoff)
        if not open_rows:
            return []

        sub_ids = {row.subscription_id for row in open_rows}
        sub_map = await self.subs.get_many(sub_ids)

        finalised: list[SubscriptionPause] = []
        for row in open_rows:
            sub = sub_map.get(row.subscription_id)
            if sub is None:
                # Parent subscription got deleted while a pause was open.
                # Mark the pause finalised with zero days consumed so the
                # cron doesn't try again next sweep.
                await self.pauses.finalize(
                    row, ended_at=now, days_consumed=0
                )
                continue
            finalised.append(
                await self._finalize(
                    subscription=sub,
                    pause=row,
                    now=now,
                    actor=actor,
                    reason="auto_resume",
                )
            )
        return finalised

    async def _finalize(
        self,
        *,
        subscription: Subscription,
        pause: SubscriptionPause,
        now: datetime,
        actor: Actor,
        reason: str,
    ) -> SubscriptionPause:
        today = now.date()
        # Effective window: clamp into [starts_on, ends_on]. A manual
        # resume before starts_on (cancel a scheduled pause that hadn't
        # begun yet) yields zero days consumed; the partial unique
        # index is freed once `ended_at` is set so the member can
        # reschedule.
        if today < pause.starts_on:
            days_consumed = 0
        else:
            effective_end = min(today, pause.ends_on)
            days_consumed = (effective_end - pause.starts_on).days + 1

        if days_consumed > 0:
            shifted = subscription.expires_at + timedelta(days=days_consumed)
            await self.subs.shift_expiry(subscription, shifted)

        finalised = await self.pauses.finalize(
            pause, ended_at=now, days_consumed=days_consumed
        )
        await self.audit.log(
            actor=actor,
            action=f"subscription.pause.{reason}",
            entity_type="subscription_pause",
            entity_id=finalised.id,
            diff={
                "before": {"days_consumed": 0},
                "after": {
                    "days_consumed": days_consumed,
                    "ended_at": now.isoformat(),
                    "new_expires_at": subscription.expires_at.isoformat(),
                },
            },
        )
        return finalised


__all__ = ["PauseService"]
