from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import Category, Tier
from app.db.models import Gym
from app.utils.ids import uuid7


class GymRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, gym_id: UUID) -> Gym | None:
        return await self.session.get(Gym, gym_id)

    async def get_active(self, gym_id: UUID) -> Gym | None:
        stmt = select(Gym).where(
            Gym.id == gym_id, Gym.is_active.is_(True), Gym.deleted_at.is_(None)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_slug(self, slug: str) -> Gym | None:
        stmt = select(Gym).where(Gym.slug == slug, Gym.deleted_at.is_(None))
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_active(
        self,
        *,
        area: str | None = None,
        category: Category | None = None,
        max_tier: Tier | None = None,
        q: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[Gym], int]:
        conditions = [Gym.is_active.is_(True), Gym.deleted_at.is_(None)]
        if area:
            conditions.append(Gym.area == area)
        if category:
            conditions.append(Gym.category == category)
        if max_tier is not None:
            allowed = [t for t in Tier if t.rank <= max_tier.rank]
            conditions.append(Gym.required_tier.in_(allowed))
        if q:
            # Escape SQL `%`/`_` wildcards in user input — see
            # user_repo.py for the full rationale.
            safe = q.lower().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            like = f"%{safe}%"
            conditions.append(
                or_(
                    func.lower(Gym.name_en).like(like, escape="\\"),
                    func.lower(Gym.name_ar).like(like, escape="\\"),
                    func.lower(Gym.area).like(like, escape="\\"),
                )
            )

        count_stmt = select(func.count()).select_from(Gym).where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = (
            select(Gym)
            .where(*conditions)
            .order_by(Gym.name_en)
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return list(rows), int(total)

    async def create(self, **fields: object) -> Gym:
        gym = Gym(id=uuid7(), **fields)
        self.session.add(gym)
        await self.session.flush()
        return gym

    async def update(self, gym: Gym, **fields: object) -> Gym:
        for k, v in fields.items():
            if v is not None:
                setattr(gym, k, v)
        await self.session.flush()
        return gym

    async def soft_delete(self, gym: Gym, now: datetime) -> None:
        gym.deleted_at = now
        gym.is_active = False
        await self.session.flush()
