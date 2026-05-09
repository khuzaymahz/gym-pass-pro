from __future__ import annotations

import asyncio

import structlog
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.db.session import get_engine
from app.repositories.audit_repo import AuditRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.pause_service import PauseService
from app.utils.time import utcnow
from app.workers.celery_app import celery_app

log = structlog.get_logger(__name__)


@celery_app.task(name="app.workers.tasks.scheduled.expire_subscriptions")
def expire_subscriptions() -> dict[str, int]:
    """Flip ACTIVE subscriptions whose `expires_at` has rolled past to
    EXPIRED. Runs hourly (see `celery_app.beat_schedule`). Bounded to
    `_EXPIRE_BATCH_SIZE` per invocation so a one-off backlog doesn't
    open a multi-minute transaction; if there's more work the next
    beat tick picks it up. Idempotent — already-expired rows are
    excluded by the `status == ACTIVE` filter, so re-running the job
    is a no-op once the queue drains.

    Each flip writes an `audit_log` row with `actor.user_id=None` so
    the trail makes it obvious the cron, not a person, made the
    change. Same actor convention as `auto_resume_pauses` above.
    """
    return asyncio.run(_run_expire_subscriptions())


# Cap per invocation. The task fires hourly; a queue of, say, 5k
# overdue rows from a multi-day outage will drain in ~5 hours rather
# than one giant transaction. Tuned conservatively — bump if the
# backend ever lags badly enough that hourly drainage falls behind.
_EXPIRE_BATCH_SIZE = 1000


async def _run_expire_subscriptions() -> dict[str, int]:
    engine = get_engine()
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with factory() as session:
        subs = SubscriptionRepository(session)
        audit = AuditService(AuditRepository(session))
        now = utcnow()
        # System actor — no user attribution, marks the row as a cron
        # write.
        actor = Actor(user_id=None, role=None)
        rows = await subs.list_expired_active(now=now, limit=_EXPIRE_BATCH_SIZE)
        for sub in rows:
            previous_expires_at = sub.expires_at
            await subs.expire(sub)
            await audit.log(
                actor=actor,
                action="subscription.expire",
                entity_type="subscription",
                entity_id=sub.id,
                diff={
                    "before": {"status": "active"},
                    "after": {
                        "status": "expired",
                        "expires_at": previous_expires_at.isoformat(),
                    },
                },
            )
        await session.commit()
        log.info("worker.expire_subscriptions.tick", expired=len(rows))
        return {"expired": len(rows)}


@celery_app.task(name="app.workers.tasks.scheduled.retry_failed_payouts")
def retry_failed_payouts() -> dict[str, int]:
    """Placeholder: retry payouts that failed in the last window."""
    log.info("worker.retry_failed_payouts.tick")
    return {"retried": 0}


@celery_app.task(name="app.workers.tasks.scheduled.auto_resume_pauses")
def auto_resume_pauses() -> dict[str, int]:
    """Sweep subscription pauses whose window has ended and finalise
    them: stamp `ended_at`, compute `days_consumed`, and shift the
    parent subscription's `expires_at` forward so the days a member
    couldn't use are credited back to the term.

    Runs hourly. Idempotent — pauses already finalised are skipped by
    the partial index `WHERE ended_at IS NULL`. The system actor
    (`user_id=None`) writes the audit row so it's clear the cron, not
    a person, made the change.
    """
    return asyncio.run(_run_auto_resume())


async def _run_auto_resume() -> dict[str, int]:
    engine = get_engine()
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with factory() as session:
        pauses = SubscriptionPauseRepository(session)
        subs = SubscriptionRepository(session)
        plans = PlanRepository(session)
        audit = AuditService(AuditRepository(session))
        svc = PauseService(pauses, subs, plans, audit)
        now = utcnow()
        # System actor — `user_id=None` flags the audit row as a cron
        # write rather than an attributed user action.
        actor = Actor(user_id=None, role=None)
        finalised = await svc.sweep_expired(now=now, actor=actor)
        await session.commit()
        log.info(
            "worker.auto_resume_pauses.tick", finalised=len(finalised)
        )
        return {"finalised": len(finalised)}
