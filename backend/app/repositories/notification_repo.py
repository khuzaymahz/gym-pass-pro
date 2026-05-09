from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import insert, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import NotificationType
from app.db.models import Notification
from app.utils.ids import uuid7


class NotificationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def for_user(
        self, user_id: UUID, *, only_unread: bool = False, limit: int = 50
    ) -> list[Notification]:
        stmt = select(Notification).where(Notification.user_id == user_id)
        if only_unread:
            stmt = stmt.where(Notification.read_at.is_(None))
        stmt = stmt.order_by(Notification.created_at.desc()).limit(limit)
        return list((await self.session.execute(stmt)).scalars().all())

    async def mark_read(self, user_id: UUID, ids: list[UUID], now: datetime) -> int:
        if not ids:
            return 0
        stmt = (
            update(Notification)
            .where(
                Notification.user_id == user_id,
                Notification.id.in_(ids),
                Notification.read_at.is_(None),
            )
            .values(read_at=now)
        )
        result = await self.session.execute(stmt)
        return int(result.rowcount or 0)

    async def create(
        self,
        *,
        user_id: UUID,
        type: NotificationType,
        title_en: str,
        title_ar: str,
        body_en: str,
        body_ar: str,
        deep_link: str | None = None,
    ) -> Notification:
        row = Notification(
            id=uuid7(),
            user_id=user_id,
            type=type,
            title_en=title_en,
            title_ar=title_ar,
            body_en=body_en,
            body_ar=body_ar,
            deep_link=deep_link,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def bulk_create(self, rows: list[dict[str, Any]]) -> int:
        """Insert many notifications in one round-trip.

        Each row dict must carry the same keys `create()` accepts plus an
        explicit `id` (uuid7) — we supply the id here so callers don't
        have to know about uuid generation. Returns the row count
        actually inserted; an empty list is a no-op (`session.execute`
        on an empty `insert().values([])` raises in some drivers).

        Used by the admin broadcast service to fan out one notification
        per matching member in a single statement instead of N
        individual inserts.
        """
        if not rows:
            return 0
        prepared: list[dict[str, Any]] = []
        for r in rows:
            row = dict(r)
            row.setdefault("id", uuid7())
            prepared.append(row)
        await self.session.execute(insert(Notification), prepared)
        await self.session.flush()
        return len(prepared)

    @staticmethod
    def build_broadcast_rows(
        *,
        user_ids: Iterable[UUID],
        type: NotificationType,
        title_en: str,
        title_ar: str,
        body_en: str,
        body_ar: str,
        deep_link: str | None = None,
    ) -> list[dict[str, Any]]:
        """Helper: shape user_ids into bulk_create payloads."""
        return [
            {
                "user_id": uid,
                "type": type,
                "title_en": title_en,
                "title_ar": title_ar,
                "body_en": body_en,
                "body_ar": body_ar,
                "deep_link": deep_link,
            }
            for uid in user_ids
        ]
