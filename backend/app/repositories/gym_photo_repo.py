from __future__ import annotations

from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import GymPhoto
from app.utils.ids import uuid7


class GymPhotoRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_by_gym_id(self, gym_id: UUID) -> list[GymPhoto]:
        stmt = (
            select(GymPhoto)
            .where(GymPhoto.gym_id == gym_id)
            .order_by(GymPhoto.sort_order, GymPhoto.created_at)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def count_by_gym_ids(self, gym_ids: list[UUID]) -> dict[UUID, int]:
        if not gym_ids:
            return {}
        stmt = (
            select(GymPhoto.gym_id, func.count())
            .where(GymPhoto.gym_id.in_(gym_ids))
            .group_by(GymPhoto.gym_id)
        )
        rows = (await self.session.execute(stmt)).all()
        return {gym_id: int(count) for gym_id, count in rows}

    async def get(self, photo_id: UUID) -> GymPhoto | None:
        return await self.session.get(GymPhoto, photo_id)

    async def next_sort_order(self, gym_id: UUID) -> int:
        """Sort order one past the current max for a gym, so appended photos
        land at the end of the slider without the caller managing ordering."""
        stmt = select(func.coalesce(func.max(GymPhoto.sort_order), -1)).where(
            GymPhoto.gym_id == gym_id
        )
        result = await self.session.execute(stmt)
        return int(result.scalar_one()) + 1

    async def create(
        self,
        *,
        gym_id: UUID,
        url: str,
        sort_order: int,
        alt_text_en: str | None = None,
        alt_text_ar: str | None = None,
    ) -> GymPhoto:
        photo = GymPhoto(
            id=uuid7(),
            gym_id=gym_id,
            url=url,
            sort_order=sort_order,
            alt_text_en=alt_text_en,
            alt_text_ar=alt_text_ar,
        )
        self.session.add(photo)
        await self.session.flush()
        return photo

    async def update(
        self,
        photo: GymPhoto,
        *,
        url: str | None = None,
        sort_order: int | None = None,
        alt_text_en: str | None = None,
        alt_text_ar: str | None = None,
    ) -> GymPhoto:
        if url is not None:
            photo.url = url
        if sort_order is not None:
            photo.sort_order = sort_order
        if alt_text_en is not None:
            photo.alt_text_en = alt_text_en
        if alt_text_ar is not None:
            photo.alt_text_ar = alt_text_ar
        await self.session.flush()
        return photo

    async def delete(self, photo: GymPhoto) -> None:
        await self.session.delete(photo)
        await self.session.flush()

    async def delete_by_id(self, photo_id: UUID) -> int:
        """Bulk-delete by id; returns the row count so callers can distinguish
        a no-op (photo already gone) from a successful delete."""
        result = await self.session.execute(
            delete(GymPhoto).where(GymPhoto.id == photo_id)
        )
        return result.rowcount or 0
