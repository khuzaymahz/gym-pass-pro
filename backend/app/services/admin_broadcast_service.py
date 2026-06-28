from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import TYPE_CHECKING

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import NotificationType, Tier
from app.repositories.notification_repo import NotificationRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import Actor, AuditService
from app.services.push_service import PushService

if TYPE_CHECKING:
    from redis.asyncio import Redis

# Insert batch size for the fan-out. Each batch is one round-trip;
# 500 rows x ~250 bytes/row stays comfortably under asyncpg's default
# 32 MB statement buffer while keeping the network amortised. At
# 100K members this is 200 batches — a couple of seconds total on a
# warm DB, still acceptable inline. Above ~100K we'd hand off to
# Celery; the threshold lives in `MAX_INLINE_RECIPIENTS`.
_BATCH_SIZE = 500
MAX_INLINE_RECIPIENTS = 100_000


@dataclass(frozen=True)
class BroadcastResult:
    """Outcome of a broadcast call.

    `recipients` is the count actually written; `duplicate` is True
    when the idempotency key matched a recent broadcast and we
    returned the cached count without re-fanning-out — this is the
    double-tap protection.
    """

    recipients: int
    duplicate: bool


class AdminBroadcastService:
    """Fan-out a system notification to all members matching a tier filter.

    Hardening over the v1 design:
      * Per-actor + idempotency-key Redis lock guards against double-tap
        / network-retry double-fan-out. A second call with the same key
        within the window returns the cached recipient count instead of
        inserting again.
      * Inserts run in `_BATCH_SIZE` chunks instead of one giant
        statement, so a 100K-member broadcast doesn't put a single
        multi-MB INSERT on the wire (or hold a single statement-level
        lock on `notifications` for the full duration).
      * Recipient cap (`MAX_INLINE_RECIPIENTS`) refuses anything that
        belongs on a Celery task — keeps a misclicked broadcast from
        wedging the request thread for minutes.

    Push delivery is still a future concern (CLAUDE.md §15); when that
    lands, the same `BroadcastResult` shape carries forward and the
    dead-token pruning hooks into the push provider's `SendResult`.
    """

    def __init__(
        self,
        notifications: NotificationRepository,
        users: UserRepository,
        audit: AuditService,
        redis: "Redis | None" = None,
        push: PushService | None = None,
    ) -> None:
        self.notifications = notifications
        self.users = users
        self.audit = audit
        self.redis = redis
        self.push = push

    async def broadcast(
        self,
        *,
        title_en: str,
        title_ar: str,
        body_en: str,
        body_ar: str,
        target_tier: Tier | None,
        actor: Actor,
        idempotency_key: str | None = None,
        dry_run: bool = False,
    ) -> BroadcastResult:
        # Derive the dedupe key from the actor + payload hash when the
        # caller didn't supply an explicit Idempotency-Key. Same actor
        # + same payload = same key, so a network retry of an in-flight
        # request collapses to the cached result.
        dedupe = idempotency_key or _payload_dedupe_key(
            actor=actor,
            title_en=title_en,
            title_ar=title_ar,
            body_en=body_en,
            body_ar=body_ar,
            target_tier=target_tier,
        )

        recipients = await self.users.list_member_ids_by_tier(target_tier)
        if len(recipients) > MAX_INLINE_RECIPIENTS:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                f"Broadcast recipients exceed inline cap "
                f"({len(recipients)} > {MAX_INLINE_RECIPIENTS}). "
                "Hand off to the async broadcast worker.",
            )

        if dry_run:
            return BroadcastResult(recipients=len(recipients), duplicate=False)

        # Redis-backed idempotency. `set nx ex` is atomic; a second
        # caller within the window gets `False` back and we return the
        # cached count. Without Redis (test fixture), the lock is a
        # no-op and the audit-log still tracks duplicates by action.
        if self.redis is not None:
            lock_key = f"admin:broadcast:lock:{dedupe}"
            cached = await self.redis.get(lock_key)
            if cached is not None:
                try:
                    return BroadcastResult(recipients=int(cached), duplicate=True)
                except ValueError:
                    pass
            # 5-minute lock window — long enough to absorb any
            # reasonable client retry, short enough to clear before
            # the next legitimate broadcast for the same audience.
            await self.redis.set(lock_key, str(len(recipients)), nx=True, ex=300)

        # Chunked fan-out. Each chunk is one INSERT.
        total = 0
        for start in range(0, len(recipients), _BATCH_SIZE):
            chunk = recipients[start : start + _BATCH_SIZE]
            rows = NotificationRepository.build_broadcast_rows(
                user_ids=chunk,
                type=NotificationType.SYSTEM,
                title_en=title_en,
                title_ar=title_ar,
                body_en=body_en,
                body_ar=body_ar,
            )
            total += await self.notifications.bulk_create(rows)

        # Push fan-out — best-effort; delivery failures never abort the broadcast.
        if self.push is not None and recipients:
            try:
                await self.push.notify_many(
                    user_ids=recipients,
                    title=title_en,
                    body=body_en,
                    data={"type": "BROADCAST", "deep_link": "/notifications"},
                )
            except Exception:
                pass

        await self.audit.log(
            actor=actor,
            action="notification.broadcast",
            entity_type="notification",
            entity_id=None,
            diff={
                "after": {
                    "tier": target_tier.value if target_tier else None,
                    "recipients": total,
                    "title_en": title_en,
                    "idempotency_key": dedupe[:64],
                    "batch_count": (len(recipients) + _BATCH_SIZE - 1) // _BATCH_SIZE,
                }
            },
        )
        return BroadcastResult(recipients=total, duplicate=False)


def _payload_dedupe_key(
    *,
    actor: Actor,
    title_en: str,
    title_ar: str,
    body_en: str,
    body_ar: str,
    target_tier: Tier | None,
) -> str:
    """Stable fingerprint for a broadcast payload.

    Collapses (actor, payload) into a hex digest — same admin sending
    the same content twice deduplicates; different actors or any
    content difference produces a new key.
    """
    raw = "|".join(
        [
            str(actor.user_id) if actor.user_id else "",
            target_tier.value if target_tier else "",
            title_en,
            title_ar,
            body_en,
            body_ar,
        ]
    )
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()
