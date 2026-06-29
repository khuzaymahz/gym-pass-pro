from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import PartnerAccessRole
from app.db.models import Gym, PartnerAccess
from app.utils.ids import uuid7


class PartnerAccessRepository:
    """Reads/writes the partner↔gym membership table (`partner_access`)
    — the source of truth for which gyms a partner login can operate."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def gyms_for_user(self, user_id: UUID) -> list[tuple[Gym, PartnerAccessRole]]:
        """Active (non-deleted) gyms the user can operate, with their role,
        ordered by name. Drives the partner-portal branch list."""
        stmt = (
            select(Gym, PartnerAccess.role)
            .join(PartnerAccess, PartnerAccess.gym_id == Gym.id)
            .where(
                PartnerAccess.user_id == user_id,
                Gym.deleted_at.is_(None),
            )
            .order_by(Gym.name_en)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(gym, role) for gym, role in rows]

    async def gym_ids_for_user(self, user_id: UUID) -> list[UUID]:
        """Just the gym ids — cheap membership check for request scoping."""
        stmt = select(PartnerAccess.gym_id).where(PartnerAccess.user_id == user_id)
        return list((await self.session.execute(stmt)).scalars().all())

    async def has_access(self, user_id: UUID, gym_id: UUID) -> bool:
        stmt = select(PartnerAccess.id).where(
            PartnerAccess.user_id == user_id,
            PartnerAccess.gym_id == gym_id,
        )
        return (await self.session.execute(stmt)).first() is not None

    async def grant(self, *, user_id: UUID, gym_id: UUID, role: PartnerAccessRole) -> PartnerAccess:
        row = PartnerAccess(id=uuid7(), user_id=user_id, gym_id=gym_id, role=role)
        self.session.add(row)
        await self.session.flush()
        return row

    async def revoke(self, *, user_id: UUID, gym_id: UUID) -> None:
        access = await self.session.scalar(
            select(PartnerAccess).where(
                PartnerAccess.user_id == user_id,
                PartnerAccess.gym_id == gym_id,
            )
        )
        if access is not None:
            await self.session.delete(access)
