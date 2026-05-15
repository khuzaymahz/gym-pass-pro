from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.api.deps import current_user, gym_photo_repo, gym_service
from app.db.enums import Category, Tier
from app.db.models import User
from app.repositories.gym_photo_repo import GymPhotoRepository
from app.schemas.common import Page
from app.schemas.gym import GymRead
from app.schemas.gym_photo import GymPhotoRead
from app.services.gym_service import GymService

router = APIRouter(prefix="/gyms", tags=["gyms"])


@router.get("", response_model=Page[GymRead])
async def list_gyms(
    svc: Annotated[GymService, Depends(gym_service)],
    user: Annotated[User, Depends(current_user)],
    area: str | None = Query(default=None),
    category: Category | None = Query(default=None),
    tier: Tier | None = Query(default=None),
    q: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100, alias="pageSize"),
) -> Page[GymRead]:
    # Audience visibility is enforced server-side from the caller's
    # profile gender — a male member never receives `female_only`
    # rows and vice versa. `prefer_not_to_say` / unset sees only
    # mixed gyms.
    rows, total = await svc.list(
        area=area, category=category, tier=tier, q=q,
        viewer_gender=user.gender,
        page=page, page_size=page_size,
    )
    return Page[GymRead](
        items=[GymRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        pageSize=page_size,
    )


@router.get("/by-slug/{slug}", response_model=GymRead)
async def get_gym_by_slug(
    slug: str,
    svc: Annotated[GymService, Depends(gym_service)],
) -> GymRead:
    gym = await svc.get_by_slug(slug)
    return GymRead.model_validate(gym)


@router.get("/by-slug/{slug}/photos", response_model=list[GymPhotoRead])
async def list_gym_photos_by_slug(
    slug: str,
    svc: Annotated[GymService, Depends(gym_service)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
) -> list[GymPhotoRead]:
    gym = await svc.get_by_slug(slug)
    rows = await photos.list_by_gym_id(gym.id)
    return [GymPhotoRead.model_validate(r) for r in rows]


@router.get("/{gym_id}", response_model=GymRead)
async def get_gym(
    gym_id: UUID,
    svc: Annotated[GymService, Depends(gym_service)],
) -> GymRead:
    gym = await svc.get(gym_id)
    return GymRead.model_validate(gym)


@router.get("/{gym_id}/photos", response_model=list[GymPhotoRead])
async def list_gym_photos(
    gym_id: UUID,
    svc: Annotated[GymService, Depends(gym_service)],
    photos: Annotated[GymPhotoRepository, Depends(gym_photo_repo)],
) -> list[GymPhotoRead]:
    gym = await svc.get(gym_id)
    rows = await photos.list_by_gym_id(gym.id)
    return [GymPhotoRead.model_validate(r) for r in rows]
