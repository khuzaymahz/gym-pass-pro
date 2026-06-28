from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import AudienceGender, Category, Gender, Tier
from app.db.models import Gym
from app.repositories.gym_repo import GymRepository
from app.schemas.gym import GymCreate, GymUpdate
from app.services.audit_service import Actor, AuditService
from app.utils.time import utcnow


def audience_visible_for(member_gender: Gender | None) -> list[AudienceGender]:
    """Audience values a member of `member_gender` is allowed to see.

    * Male → `mixed` + `male_only`
    * Female → `mixed` + `female_only`
    * None (anonymous / pre-signup browse) → no filter — every
      audience is returned so the unauthenticated landing on the
      explore tab sees the full network. Once they finish signup
      the registration form has set a gender and the filter kicks
      in on the next call.

    The "None → no filter" branch is the *only* time a caller can
    see opposite-gender single-sex gyms. After registration, gender
    is always Male or Female — the form makes it mandatory.
    """

    if member_gender == Gender.MALE:
        return [AudienceGender.MIXED, AudienceGender.MALE_ONLY]
    if member_gender == Gender.FEMALE:
        return [AudienceGender.MIXED, AudienceGender.FEMALE_ONLY]
    # Anonymous: no filter. List every audience so a signed-out
    # caller can browse the whole network during signup evaluation.
    return list(AudienceGender)


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
        viewer_gender: Gender | None,
        page: int,
        page_size: int,
    ) -> tuple[list[Gym], int]:
        """Member-facing list. Filters out gyms whose audience doesn't
        match the caller's profile gender — see `audience_visible_for`.
        """

        return await self.repo.list_active(
            area=area, category=category, max_tier=tier, q=q,
            audience_in=audience_visible_for(viewer_gender),
            page=page, page_size=page_size,
        )

    async def list_unfiltered(
        self,
        *,
        area: str | None,
        category: Category | None,
        tier: Tier | None,
        q: str | None,
        audience: AudienceGender | None = None,
        page: int,
        page_size: int,
    ) -> tuple[list[Gym], int]:
        """Admin-facing list. No automatic gender filter; the optional
        `audience` query param narrows to a single audience value when
        an operator wants to inspect e.g. all female-only venues.
        """

        return await self.repo.list_active(
            area=area, category=category, max_tier=tier, q=q,
            audience=audience,
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

    async def delete(
        self,
        gym_id: UUID,
        *,
        actor: Actor,
        confirm_slug: str | None = None,
    ) -> None:
        """Soft-delete a gym with a typed-slug confirmation guard.

        The route layer requires the caller to echo the gym's slug in an
        `X-Confirm-Gym-Slug` header. The service repeats that check so
        a direct service call (background task, repair script) gets the
        same protection.

        Gyms with successful check-in history are *always* soft-deleted —
        the route + service never hard-delete, because `checkins`,
        `payout_ledger`, and `audit_log` all join through `gym_id` and
        a cascade would destroy irreplaceable financial history. The
        existing `repo.soft_delete` flips `deleted_at` + `is_active`;
        the row stays queryable for audit drill-down.
        """
        gym = await self.get(gym_id)
        if confirm_slug is None or confirm_slug != gym.slug:
            raise AppError(
                ErrorCode.VALIDATION_ERROR,
                "Delete requires the gym slug as confirmation.",
                details={"field": "confirm_slug", "expected": gym.slug},
            )
        checkin_count = await self.repo.count_successful_checkins(gym.id)
        await self.repo.soft_delete(gym, utcnow())
        await self.audit.log(
            actor=actor,
            action="gym.delete",
            entity_type="gym",
            entity_id=gym.id,
            diff={
                "before": _snapshot(gym),
                "after": {"is_active": False, "deleted": True},
                "historical_checkins": checkin_count,
            },
        )


def _snapshot(gym: Gym) -> dict[str, object]:
    return {
        "name_en": gym.name_en,
        "area": gym.area,
        "category": gym.category.value,
        "required_tier": gym.required_tier.value,
        "per_visit_rate_jod": str(gym.per_visit_rate_jod),
        "is_active": gym.is_active,
    }
