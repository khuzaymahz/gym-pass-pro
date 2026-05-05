from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import Category, Tier
from app.db.models import Gym
from app.repositories.gym_repo import GymRepository
from app.schemas.gym import GymCreate, GymUpdate
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow


class GymService:
    def __init__(self, repo: GymRepository, audit: AuditService) -> None:
        self.repo = repo
        self.audit = audit

    async def list(
        self,
        *,
        area: str | None,
        category: Category | None,
        tier: Tier | None,
        q: str | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Gym], int]:
        return await self.repo.list_active(
            area=area, category=category, max_tier=tier, q=q,
            page=page, page_size=page_size,
        )

    async def get(self, gym_id: UUID) -> Gym:
        gym = await self.repo.get(gym_id)
        if gym is None or gym.deleted_at is not None:
            raise AppError(ErrorCode.GYM_NOT_FOUND, "Gym not found.")
        return gym

    async def get_by_slug(self, slug: str) -> Gym:
        gym = await self.repo.get_by_slug(slug)
        if gym is None or gym.deleted_at is not None:
            raise AppError(ErrorCode.GYM_NOT_FOUND, "Gym not found.")
        return gym

    async def create(self, data: GymCreate, *, actor: Actor) -> Gym:
        payload = data.model_dump(by_alias=False)
        existing = await self.repo.get_by_slug(payload["slug"])
        if existing is not None:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Slug already in use.",
                details={"field": "slug"},
            )
        gym = await self.repo.create(**payload)
        await self.audit.log(
            actor=actor, action="gym.create",
            entity_type="gym", entity_id=gym.id, diff={"after": payload},
        )
        return gym

    async def update(self, gym_id: UUID, data: GymUpdate, *, actor: Actor) -> Gym:
        gym = await self.get(gym_id)
        before = _snapshot(gym)
        updates = data.model_dump(by_alias=False, exclude_unset=True)
        await self.repo.update(gym, **updates)
        await self.audit.log(
            actor=actor, action="gym.update",
            entity_type="gym", entity_id=gym.id,
            diff={"before": before, "after": updates},
        )
        return gym

    async def delete(self, gym_id: UUID, *, actor: Actor) -> None:
        gym = await self.get(gym_id)
        await self.repo.soft_delete(gym, utcnow())
        await self.audit.log(
            actor=actor, action="gym.delete",
            entity_type="gym", entity_id=gym.id,
        )


def _snapshot(gym: Gym) -> dict[str, object]:
    return {
        "name_en": gym.name_en,
        "name_ar": gym.name_ar,
        "area": gym.area,
        "category": gym.category.value,
        "required_tier": gym.required_tier.value,
        "per_visit_rate_jod": str(gym.per_visit_rate_jod),
        "is_active": gym.is_active,
    }
