from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import current_partner, partner_access_repo
from app.db.models import User
from app.repositories.partner_access_repo import PartnerAccessRepository
from app.schemas.partner import PartnerGymRef

router = APIRouter(prefix="/partner/gyms", tags=["partner/gyms"])


@router.get("", response_model=list[PartnerGymRef])
async def my_gyms(
    user: Annotated[User, Depends(current_partner)],
    access: Annotated[PartnerAccessRepository, Depends(partner_access_repo)],
) -> list[PartnerGymRef]:
    """Branches the calling partner can operate — drives the portal's branch
    switcher. One row → a single-gym partner (unchanged); many → a chain
    owner who can switch between / aggregate their branches."""
    rows = await access.gyms_for_user(user.id)
    return [
        PartnerGymRef(
            id=str(gym.id),
            slug=gym.slug,
            nameEn=gym.name_en,
            role=role.value,
        )
        for gym, role in rows
    ]
