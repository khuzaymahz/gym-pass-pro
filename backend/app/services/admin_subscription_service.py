from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import SubscriptionStatus, Tier
from app.db.models import Subscription, User
from app.repositories.subscription_repo import SubscriptionRepository
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow


class AdminSubscriptionService:
    def __init__(
        self, subs: SubscriptionRepository, audit: AuditService
    ) -> None:
        self.subs = subs
        self.audit = audit

    async def list(
        self,
        *,
        status: SubscriptionStatus | None,
        tier: Tier | None,
        q: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[tuple[Subscription, User]], int]:
        return await self.subs.list_paginated(
            status=status, tier=tier, q=q, page=page, page_size=page_size
        )

    async def get(self, sub_id: UUID) -> Subscription:
        sub = await self.subs.get(sub_id)
        if sub is None:
            raise AppError(ErrorCode.SUB_NOT_FOUND, "Subscription not found.")
        return sub

    async def cancel(self, sub_id: UUID, *, actor: Actor) -> Subscription:
        sub = await self.get(sub_id)
        if sub.status == SubscriptionStatus.CANCELLED:
            raise AppError(ErrorCode.SUB_CANCELLED, "Already cancelled.")
        await self.subs.cancel(sub, utcnow())
        await self.audit.log(
            actor=actor,
            action="admin.subscription.cancel",
            entity_type="subscription",
            entity_id=sub.id,
        )
        return sub
