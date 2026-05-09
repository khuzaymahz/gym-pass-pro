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
        "retry-failed-payouts-hourly": {
            "task": "app.workers.tasks.scheduled.retry_failed_payouts",
            "schedule": 60 * 60,
        },
        # Auto-resume pauses whose window has ended. Hourly cadence —
        # worst-case lag between a pause expiring and the parent
        # subscription's `expires_at` getting shifted is 60 minutes,
        # well under the granularity a member would notice.
        "auto-resume-pauses-hourly": {
            "task": "app.workers.tasks.scheduled.auto_resume_pauses",
            "schedule": 60 * 60,
        },
    },
)
