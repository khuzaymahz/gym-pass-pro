from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user, db_session, device_token_repo
from app.db.models import User
from app.repositories.device_token_repo import DeviceTokenRepository

router = APIRouter(prefix="/me/device-token", tags=["push"])


class DeviceTokenBody(BaseModel):
    token: str
    platform: str = "android"


@router.put("", status_code=204)
async def register_device_token(
    body: DeviceTokenBody,
    user: Annotated[User, Depends(current_user)],
    tokens: Annotated[DeviceTokenRepository, Depends(device_token_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Register or refresh the FCM / APNs token for the current device.

    Called on every app foreground after sign-in. Uses an upsert so
    reinstalling the app (which generates a new token) or signing into
    a new account on the same phone both produce the correct owner.
    """
    await tokens.upsert(
        user_id=user.id,
        token=body.token,
        platform=body.platform,
    )
    await session.commit()


@router.delete("", status_code=204)
async def delete_device_token(
    body: DeviceTokenBody,
    user: Annotated[User, Depends(current_user)],
    tokens: Annotated[DeviceTokenRepository, Depends(device_token_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Unregister a device token on sign-out.

    Only deletes the specific token sent in the body so a member
    signed in on two devices only loses the one they signed out of.
    """
    await tokens.delete_token(body.token)
    await session.commit()
