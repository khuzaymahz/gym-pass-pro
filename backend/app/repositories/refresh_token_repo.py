from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import RefreshToken


class RefreshTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        jti: UUID,
        user_id: UUID,
        expires_at: datetime,
    ) -> RefreshToken:
        row = RefreshToken(
            id=jti,
            user_id=user_id,
            expires_at=expires_at,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def get(self, jti: UUID) -> RefreshToken | None:
        return await self.session.get(RefreshToken, jti)

    async def list_for_user(self, user_id: UUID, *, limit: int = 50) -> list[RefreshToken]:
        """All refresh-token (session) rows for a user, newest first.
        Powers the admin "active devices" view + the force-logout
        decision. Includes revoked/expired rows so the admin can see
        recent session history, not just live ones."""
        stmt = (
            select(RefreshToken)
            .where(RefreshToken.user_id == user_id)
            .order_by(RefreshToken.created_at.desc())
            .limit(limit)
        )
        return list((await self.session.execute(stmt)).scalars().all())

    async def revoke(self, row: RefreshToken, now: datetime) -> None:
        row.revoked_at = now
        await self.session.flush()

    async def revoke_all_for_user(self, user_id: UUID, now: datetime) -> int:
        """Revoke every live refresh token for a user. Used on logout
        and on refresh-token-reuse detection (suspected theft).
        Returns the number of rows actually revoked.
        """
        stmt = (
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user_id,
                RefreshToken.revoked_at.is_(None),
                RefreshToken.expires_at > now,
            )
            .values(revoked_at=now)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount or 0
