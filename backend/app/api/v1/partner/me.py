from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import current_partner
from app.db.models import User
from app.schemas.auth import PartnerMeUser

router = APIRouter(prefix="/partner/me", tags=["partner/me"])


@router.get("", response_model=PartnerMeUser)
async def get_me(
    user: Annotated[User, Depends(current_partner)],
) -> PartnerMeUser:
    return PartnerMeUser.model_validate(user)
