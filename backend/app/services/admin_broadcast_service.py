from __future__ import annotations

from app.db.enums import NotificationType, Tier
from app.repositories.notification_repo import NotificationRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import Actor, AuditService


class AdminBroadcastService:
    """Fan-out a system notification to all members matching a tier filter.

    One bulk insert per broadcast (instead of N round-trips) — see
    `NotificationRepository.bulk_create`. When push delivery is wired
    in, the broadcaster hands off to a Celery task instead.
    """

    def __init__(
        self,
        notifications: NotificationRepository,
        users: UserRepository,
        audit: AuditService,
    ) -> None:
        self.notifications = notifications
        self.users = users
        self.audit = audit

    async def broadcast(
        self,
        *,
        title_en: str,
        title_ar: str,
        body_en: str,
        body_ar: str,
        target_tier: Tier | None,
        actor: Actor,
    ) -> int:
        recipients = await self.users.list_member_ids_by_tier(target_tier)
        rows = NotificationRepository.build_broadcast_rows(
            user_ids=recipients,
            type=NotificationType.SYSTEM,
            title_en=title_en,
            title_ar=title_ar,
            body_en=body_en,
            body_ar=body_ar,
        )
        await self.notifications.bulk_create(rows)
        await self.audit.log(
            actor=actor,
            action="notification.broadcast",
            entity_type="notification",
            entity_id=None,
            diff={
                "after": {
                    "tier": target_tier.value if target_tier else None,
                    "recipients": len(recipients),
                    "title_en": title_en,
                }
            },
        )
        return len(recipients)
