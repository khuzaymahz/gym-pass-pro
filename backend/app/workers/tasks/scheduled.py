from __future__ import annotations

import asyncio

import structlog
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, OperationalError
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.db.session import make_engine
from app.repositories.audit_repo import AuditRepository
from app.repositories.plan_repo import PlanRepository
from app.repositories.subscription_pause_repo import SubscriptionPauseRepository
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.services.pause_service import PauseService
from app.utils.time import utcnow
from app.workers.celery_app import celery_app

log = structlog.get_logger(__name__)

# Shared autoretry policy for transient DB / Redis blips. Tasks that
# do real DB work pass this through their `@celery_app.task` decorator
# so a flaky moment doesn't drop the work entirely. `retry_backoff=True`
# uses Celery's exponential schedule (10s, 20s, 40s, ...); 5 retries
# plus the original attempt is ~10 minutes worst case before the task
# is shelved and Sentry breadcrumbs the failure.
_TRANSIENT_RETRY_KW: dict[str, object] = {
    "autoretry_for": (OperationalError, DBAPIError, ConnectionError),
    "retry_backoff": True,
    "retry_backoff_max": 600,
    "retry_jitter": True,
    "max_retries": 5,
}


@celery_app.task(
    name="app.workers.tasks.scheduled.expire_subscriptions",
    **_TRANSIENT_RETRY_KW,
)
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
    # Build the engine *inside* the per-task event loop and dispose it
    # before the loop closes. Reusing the process-cached engine across
    # Celery tasks raises `RuntimeError: Future attached to a different
    # loop` because asyncpg's pool tracks the loop that owned the first
    # task.
    engine = make_engine()
    try:
        factory = async_sessionmaker(engine, expire_on_commit=False)
        async with factory() as session:
            subs = SubscriptionRepository(session)
            audit = AuditService(AuditRepository(session))
            now = utcnow()
            # System actor — no user attribution, marks the row as a
            # cron write.
            actor = Actor(user_id=None, role=None)
            rows = await subs.list_expired_active(
                now=now, limit=_EXPIRE_BATCH_SIZE
            )
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
    finally:
        await engine.dispose()


@celery_app.task(
    name="app.workers.tasks.scheduled.auto_resume_pauses",
    **_TRANSIENT_RETRY_KW,
)
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
    # Fresh engine per task — see `_run_expire_subscriptions` for the
    # loop-attachment rationale.
    engine = make_engine()
    try:
        factory = async_sessionmaker(engine, expire_on_commit=False)
        async with factory() as session:
            pauses = SubscriptionPauseRepository(session)
            subs = SubscriptionRepository(session)
            plans = PlanRepository(session)
            audit = AuditService(AuditRepository(session))
            svc = PauseService(pauses, subs, plans, audit)
            now = utcnow()
            # System actor — `user_id=None` flags the audit row as a
            # cron write rather than an attributed user action.
            actor = Actor(user_id=None, role=None)
            finalised = await svc.sweep_expired(now=now, actor=actor)
            await session.commit()
            log.info(
                "worker.auto_resume_pauses.tick", finalised=len(finalised)
            )
            return {"finalised": len(finalised)}
    finally:
        await engine.dispose()


# How many months of audit_log to keep before dropping the
# partition. 12 is generous — Jordan's data-protection floor for
# financial / fitness records hasn't been mandated, but 12 months
# of mutation history makes "what changed in the last year" the
# longest-reach query the audit surface needs to support.
# Operators tighten via the AUDIT_LOG_RETENTION_MONTHS env var.
_AUDIT_LOG_RETENTION_MONTHS_DEFAULT = 12


@celery_app.task(
    name="app.workers.tasks.scheduled.audit_log_maintenance",
    **_TRANSIENT_RETRY_KW,
)
def audit_log_maintenance() -> dict[str, int]:
    """Pre-create next month's audit_log partition and drop any
    partition older than the retention window.

    Two-part maintenance, idempotent both ways:

      1. **Ensure** — call `audit_log_ensure_partition()` for the
         current month + the next month. The function is
         `CREATE TABLE IF NOT EXISTS`-style so re-runs are no-ops.
         This is the load-bearing half: without a partition for
         "tomorrow," an audit-log INSERT after midnight on the
         month boundary would fail with "no partition of relation
         audit_log found" and abort whatever transaction was
         writing it.

      2. **Prune** — drop any explicit partition whose date range
         ends before `(today - retention_months)`. The default
         partition stays — anything that ended up there is
         already off-schedule, leave it for an operator to
         inspect.

    Runs daily (see `celery_app.beat_schedule`).
    """
    return asyncio.run(_run_audit_log_maintenance())


async def _run_audit_log_maintenance() -> dict[str, int]:
    import os
    from datetime import date

    from sqlalchemy import text

    retention_months_raw = os.environ.get(
        "AUDIT_LOG_RETENTION_MONTHS",
        str(_AUDIT_LOG_RETENTION_MONTHS_DEFAULT),
    )
    try:
        retention_months = max(1, int(retention_months_raw))
    except ValueError:
        retention_months = _AUDIT_LOG_RETENTION_MONTHS_DEFAULT

    today = date.today()

    def _add_months(d: date, n: int) -> date:
        month_zero = (d.year * 12) + (d.month - 1) + n
        return date(month_zero // 12, (month_zero % 12) + 1, 1)

    current = today.replace(day=1)
    next_month = _add_months(current, 1)

    engine = make_engine()
    try:
        async with engine.begin() as conn:
            # 1. Ensure (current + next month).
            for m in (current, next_month):
                await conn.execute(
                    text(
                        "SELECT audit_log_ensure_partition(:m::date);"
                    ),
                    {"m": m.isoformat()},
                )

            # 2. Prune. Postgres exposes partition bounds via
            # pg_class + pg_inherits. We parse the partition name
            # convention (`audit_log_yYYYYmMM`) and drop anything
            # whose month-floor is older than the cutoff. The
            # default partition (audit_log_default) doesn't match
            # the name pattern and is left untouched.
            cutoff = _add_months(current, -retention_months)
            result = await conn.execute(
                text(
                    """
                    SELECT c.relname
                    FROM pg_inherits i
                    JOIN pg_class c ON c.oid = i.inhrelid
                    JOIN pg_class p ON p.oid = i.inhparent
                    WHERE p.relname = 'audit_log'
                      AND c.relname ~ '^audit_log_y[0-9]{4}m[0-9]{2}$'
                    """
                )
            )
            dropped = 0
            for (name,) in result.all():
                # Parse `audit_log_yYYYYmMM` → date(YYYY, MM, 1)
                try:
                    yyyy = int(name[12:16])
                    mm = int(name[17:19])
                    part_floor = date(yyyy, mm, 1)
                except (ValueError, IndexError):
                    continue
                if part_floor < cutoff:
                    await conn.execute(text(f'DROP TABLE "{name}";'))
                    dropped += 1
                    log.info(
                        "audit_log.partition_dropped",
                        partition=name,
                        floor=part_floor.isoformat(),
                        cutoff=cutoff.isoformat(),
                    )

        log.info(
            "worker.audit_log_maintenance.tick",
            ensured=[current.isoformat(), next_month.isoformat()],
            dropped=dropped,
            retention_months=retention_months,
        )
        return {"dropped": dropped}
    finally:
        await engine.dispose()


# Retention windows for the three unbounded-growth tables. Tuned for
# the smallest window that preserves the user-facing UX:
#   - notifications: 90 d  (member's "all" tab shows the last few
#                          weeks; beyond that nobody scrolls)
#   - otps:           7 d  (purely a verify cache; consumed rows
#                          age out within minutes anyway)
#   - refresh_tokens: 30 d (matches the JWT refresh TTL +
#                          a small grace for the reuse-detection
#                          look-back window)
_NOTIFICATION_RETENTION_DAYS = 90
_OTP_RETENTION_DAYS = 7
_REFRESH_TOKEN_RETENTION_DAYS = 30
_CLEANUP_BATCH_SIZE = 10_000


@celery_app.task(
    name="app.workers.tasks.scheduled.cleanup_old_notifications",
    **_TRANSIENT_RETRY_KW,
)
def cleanup_old_notifications() -> dict[str, int]:
    """Delete `notifications` rows older than the retention window.

    Only sweeps rows the member has already read OR that were created
    more than 2× the window ago — unread-but-still-fresh rows stay
    so a member returning after a quiet month still sees their queue.
    Bounded per-tick so a one-off backlog drains across runs rather
    than a single multi-million-row delete.
    """
    return asyncio.run(
        _run_cleanup(
            sql=(
                f"""
                DELETE FROM notifications
                WHERE id IN (
                    SELECT id
                    FROM notifications
                    WHERE (
                        read_at IS NOT NULL
                        AND created_at < now() - interval '{_NOTIFICATION_RETENTION_DAYS} days'
                    )
                    OR created_at < now() - interval '{_NOTIFICATION_RETENTION_DAYS * 2} days'
                    LIMIT {_CLEANUP_BATCH_SIZE}
                )
                """
            ),
            label="cleanup_old_notifications",
        )
    )


@celery_app.task(
    name="app.workers.tasks.scheduled.cleanup_old_otps",
    **_TRANSIENT_RETRY_KW,
)
def cleanup_old_otps() -> dict[str, int]:
    """Delete OTP rows older than the retention window.

    OTP rows are short-lived by design (5-min TTL) but accumulate
    forever without a sweep. After expiry there's no UX value to
    keeping them; the audit log already captured the request/verify.
    """
    return asyncio.run(
        _run_cleanup(
            sql=(
                f"""
                DELETE FROM otp_codes
                WHERE id IN (
                    SELECT id FROM otp_codes
                    WHERE expires_at < now() - interval '{_OTP_RETENTION_DAYS} days'
                    LIMIT {_CLEANUP_BATCH_SIZE}
                )
                """
            ),
            label="cleanup_old_otps",
        )
    )


@celery_app.task(
    name="app.workers.tasks.scheduled.cleanup_old_refresh_tokens",
    **_TRANSIENT_RETRY_KW,
)
def cleanup_old_refresh_tokens() -> dict[str, int]:
    """Delete `refresh_tokens` rows that are revoked or expired beyond
    the retention window.

    Kept long enough for the reuse-detection look-back to still catch
    a stolen token presented late; once outside the window the token
    is unrecoverable anyway and the row is dead weight.
    """
    return asyncio.run(
        _run_cleanup(
            sql=(
                f"""
                DELETE FROM refresh_tokens
                WHERE id IN (
                    SELECT id FROM refresh_tokens
                    WHERE (
                        (revoked_at IS NOT NULL OR expires_at < now())
                        AND created_at < now() - interval '{_REFRESH_TOKEN_RETENTION_DAYS} days'
                    )
                    LIMIT {_CLEANUP_BATCH_SIZE}
                )
                """
            ),
            label="cleanup_old_refresh_tokens",
        )
    )


async def _run_cleanup(*, sql: str, label: str) -> dict[str, int]:
    """Shared scaffolding for the retention tasks. One DELETE per call,
    bounded by `_CLEANUP_BATCH_SIZE`. Fresh engine per call — see
    `_run_expire_subscriptions` for the loop-attachment rationale.
    """
    engine = make_engine()
    try:
        async with engine.begin() as conn:
            result = await conn.execute(text(sql))
            deleted = int(result.rowcount or 0)
        log.info(f"worker.{label}.tick", deleted=deleted)
        return {"deleted": deleted}
    finally:
        await engine.dispose()
