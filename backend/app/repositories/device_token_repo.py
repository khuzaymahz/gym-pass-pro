from __future__ import annotations

from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import DeviceToken
from app.utils.ids import uuid7


class DeviceTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def upsert(
        self,
        *,
        user_id: UUID,
        token: str,
        platform: str = "android",
    ) -> DeviceToken:
        """Insert or update the token, moving it to the new user if it
        already belongs to a different account (e.g. device shared after
        sign-out and re-sign-in).

        Uses PostgreSQL `INSERT … ON CONFLICT (token) DO UPDATE` so the
        operation is atomic and races produce the correct winner.
        """
        stmt = (
            pg_insert(DeviceToken)
            .values(
                id=uuid7(),
                user_id=user_id,
                token=token,
                platform=platform,
            )
            .on_conflict_do_update(
                index_elements=["token"],
                set_={
                    "user_id": user_id,
                    "platform": platform,
                    "updated_at": func.now(),
                },
            )
            .returning(DeviceToken)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.scalar_one()

    async def delete_token(self, token: str) -> None:
        """Remove a single FCM token — called when the provider returns dead_token."""
        await self.session.execute(
            delete(DeviceToken).where(DeviceToken.token == token)
        )
        await self.session.flush()

    async def delete_for_user(self, user_id: UUID) -> None:
        """Remove all tokens for a user — called on logout."""
        await self.session.execute(
            delete(DeviceToken).where(DeviceToken.user_id == user_id)
        )
        await self.session.flush()

    async def tokens_for_user(self, user_id: UUID) -> list[DeviceToken]:
        result = await self.session.execute(
            select(DeviceToken).where(DeviceToken.user_id == user_id)
        )
        return list(result.scalars().all())

    async def tokens_for_users(self, user_ids: list[UUID]) -> list[DeviceToken]:
        """Batch lookup — used by the broadcast fan-out."""
        if not user_ids:
            return []
        result = await self.session.execute(
            select(DeviceToken).where(DeviceToken.user_id.in_(user_ids))
        )
        return list(result.scalars().all())
