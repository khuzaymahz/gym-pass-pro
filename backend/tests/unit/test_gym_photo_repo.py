from __future__ import annotations

from decimal import Decimal

import pytest

from app.db.enums import Category, Tier
from app.db.models import Gym, GymPhoto
from app.repositories.gym_photo_repo import GymPhotoRepository
from app.utils.ids import uuid7


def _gym(slug: str, name: str) -> Gym:
    return Gym(
        id=uuid7(),
        slug=slug,
        name_en=name,
        address_en="addr",
        address_ar="addr",
        area="Amman",
        lat=Decimal("31.95"),
        lng=Decimal("35.91"),
        category=Category.GYM,
        required_tier=Tier.SILVER,
        per_visit_rate_jod=Decimal("2.00"),
    )


@pytest.mark.asyncio
async def test_count_by_gym_ids_returns_only_gyms_with_photos(db):
    g_two = _gym("count-two", "Two-Photo Gym")
    g_zero = _gym("count-zero", "No-Photo Gym")
    db.add_all([g_two, g_zero])
    await db.flush()

    db.add_all(
        [
            GymPhoto(id=uuid7(), gym_id=g_two.id, url="/x/a.jpg", sort_order=0),
            GymPhoto(id=uuid7(), gym_id=g_two.id, url="/x/b.jpg", sort_order=1),
        ]
    )
    await db.flush()

    counts = await GymPhotoRepository(db).count_by_gym_ids([g_two.id, g_zero.id])

    assert counts == {g_two.id: 2}


@pytest.mark.asyncio
async def test_count_by_gym_ids_empty_input(db):
    counts = await GymPhotoRepository(db).count_by_gym_ids([])
    assert counts == {}
