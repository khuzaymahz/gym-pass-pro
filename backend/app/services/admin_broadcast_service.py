from __future__ import annotations

from app.db.enums import NotificationType, Tier
from app.repositories.notification_repo import NotificationRepository
from app.repositories.user_repo import UserRepository
from app.services.audit_service import Actor, AuditService


class AdminBroadcastService:
    """Fan-out a system notification to all members matching a tier filter.

    Intentionally synchronous for now: per-user rows are cheap and the admin
    console warns if the recipient count is large. When push delivery is
    wired in, the broadcaster hands off to a Celery task instead.
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
        for user_id in recipients:
            await self.notifications.create(
                user_id=user_id,
                type=NotificationType.SYSTEM,
                title_en=title_en,
                title_ar=title_ar,
                body_en=body_en,
                body_ar=body_ar,
            )
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
