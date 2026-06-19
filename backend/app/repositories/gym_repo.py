from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import AudienceGender, Category, CheckinStatus, Tier
from app.db.models import Checkin, Gym
from app.utils.ids import uuid7


class GymRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, gym_id: UUID) -> Gym | None:
        return await self.session.get(Gym, gym_id)

    async def count_active(self) -> int:
        """Count of gyms not soft-deleted. Used by admin overview metrics."""
        stmt = (
            select(func.count())
            .select_from(Gym)
            .where(Gym.deleted_at.is_(None))
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def top_by_checkins_since(
        self, since: datetime, *, limit: int = 5
    ) -> list[dict[str, Any]]:
        """Top gyms by SUCCESS checkins since `since`. Excludes soft-deleted gyms."""
        stmt = (
            select(
                Gym.id,
                Gym.name_en,
                Gym.name_ar,
                func.count(Checkin.id).label("count"),
            )
            .join(Checkin, Checkin.gym_id == Gym.id)
            .where(
                Checkin.status == CheckinStatus.SUCCESS,
                Checkin.scanned_at >= since,
                Gym.deleted_at.is_(None),
            )
            .group_by(Gym.id, Gym.name_en, Gym.name_ar)
            .order_by(func.count(Checkin.id).desc())
            .limit(limit)
        )
        rows = (await self.session.execute(stmt)).all()
        return [
            {
                "gymId": str(r[0]),
                "nameEn": r[1],
                "nameAr": r[2],
                "count": int(r[3]),
            }
            for r in rows
        ]

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
        # Server-enforced visibility by audience. Member endpoints pass
        # the caller's profile gender here so a male member never sees
        # `female_only` gyms (and vice versa) — admin and partner
        # endpoints pass None to disable the filter. The set is the
        # list of audience values that should remain visible.
        audience_in: list[AudienceGender] | None = None,
        audience: AudienceGender | None = None,
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
        if audience_in is not None:
            conditions.append(Gym.audience_gender.in_(audience_in))
        if audience is not None:
            conditions.append(Gym.audience_gender == audience)
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

    async def count_successful_checkins(self, gym_id: UUID) -> int:
        """Lifetime successful check-ins at a gym.

        Used by the admin delete confirmation: anything with history
        must be soft-deleted (the default `delete()` path) or refused
        — never hard-deleted, since the payout ledger and audit log
        join through `checkins.gym_id` and a cascade would orphan
        irreplaceable financial history.
        """
        stmt = (
            select(func.count())
            .select_from(Checkin)
            .where(
                Checkin.gym_id == gym_id,
                Checkin.status == CheckinStatus.SUCCESS,
            )
        )
        return int((await self.session.execute(stmt)).scalar_one())
