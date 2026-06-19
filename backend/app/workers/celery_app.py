from __future__ import annotations

from celery import Celery

from app.config import get_settings

_settings = get_settings()

celery_app = Celery(
    "gympass",
    broker=str(_settings.celery_broker_url),
    backend=str(_settings.celery_result_backend),
    include=["app.workers.tasks.scheduled"],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="Asia/Amman",
    enable_utc=True,
    task_default_queue="default",
    # Acks at *task completion* rather than at receipt. Combined with
    # `task_reject_on_worker_lost` and `worker_prefetch_multiplier=1`,
    # a SIGKILLed worker mid-task returns the message to the broker
    # so a peer can re-run it; without this, a worker crash silently
    # loses every in-flight task. The trade-off is at-least-once
    # semantics — tasks must be idempotent (which the audit-logged
    # ones already are, since they UPDATE by id rather than INSERT).
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    # Soft + hard time limits. Soft raises `SoftTimeLimitExceeded`
    # inside the task so cleanup (transaction rollback, release
    # locks) can run; hard SIGKILLs the worker. The 5-min soft / 6-
    # min hard envelope covers `expire_subscriptions` worst-case
    # (1000 rows) while leaving a generous margin and stopping
    # runaway tasks from holding a worker forever.
    task_soft_time_limit=300,
    task_time_limit=360,
    # Auto-retry for transient DB / Redis errors. Tasks can still
    # opt out by passing `autoretry_for=()` or by catching the
    # error themselves; this is the global default.
    task_default_retry_delay=10,
    # Cancel in-flight long tasks when the broker connection drops
    # instead of letting them silently leak transactions. Without
    # this, a Redis hiccup leaves the task hanging until the broker
    # comes back and a fresh worker picks the same task up again,
    # producing duplicate audit-log rows.
    worker_cancel_long_running_tasks_on_connection_loss=True,
    beat_schedule={
        # Hourly cadence (was daily). With the `_EXPIRE_BATCH_SIZE`
        # cap inside the task, a backlog drains across multiple ticks
        # rather than one large daily transaction; the worst-case lag
        # between a subscription's `expires_at` rolling past and the
        # row reflecting `status=expired` is 60 minutes.
        "expire-subscriptions-hourly": {
            "task": "app.workers.tasks.scheduled.expire_subscriptions",
            "schedule": 60 * 60,
        },
        # `retry_failed_payouts` was scheduled while still a stub —
        # removed until the implementation lands. Leaving a beat-
        # scheduled no-op in production hides silent money-loss when
        # payouts actually start failing.
        # ---
        # Retention sweeps. Each runs daily; the tasks themselves cap
        # row counts so a backlog drains across multiple runs rather
        # than one giant transaction. All three keep DB growth bounded
        # without ad-hoc maintenance — the notifications + refresh_token
        # tables in particular grow with every check-in / refresh and
        # were the only ones with no cleanup story before this.
        "cleanup-notifications-daily": {
            "task": "app.workers.tasks.scheduled.cleanup_old_notifications",
            "schedule": 24 * 60 * 60,
        },
        "cleanup-otps-daily": {
            "task": "app.workers.tasks.scheduled.cleanup_old_otps",
            "schedule": 24 * 60 * 60,
        },
        "cleanup-refresh-tokens-daily": {
            "task": "app.workers.tasks.scheduled.cleanup_old_refresh_tokens",
            "schedule": 24 * 60 * 60,
        },
        # Auto-resume pauses whose window has ended. Hourly cadence —
        # worst-case lag between a pause expiring and the parent
        # subscription's `expires_at` getting shifted is 60 minutes,
        # well under the granularity a member would notice.
        "auto-resume-pauses-hourly": {
            "task": "app.workers.tasks.scheduled.auto_resume_pauses",
            "schedule": 60 * 60,
        },
        # audit_log maintenance: daily run at ~03:00 (`24 * 60 * 60`
        # is daily anchored to whenever the beat started). Two
        # halves to the task: ensure next month's partition exists
        # (load-bearing — without it, the first audit INSERT after
        # midnight on the month boundary aborts), and drop
        # partitions older than AUDIT_LOG_RETENTION_MONTHS (default
        # 12). Cheap, idempotent — re-running is a no-op.
        "audit-log-maintenance-daily": {
            "task": "app.workers.tasks.scheduled.audit_log_maintenance",
            "schedule": 24 * 60 * 60,
        },
    },
)
