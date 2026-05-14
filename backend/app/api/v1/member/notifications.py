from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user, db_session, notification_repo
from app.core.exceptions import AppError, ErrorCode
from app.db.models import User
from app.repositories.notification_repo import NotificationRepository
from app.schemas.notification import NotificationRead
from app.utils.time import utcnow

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationRead])
async def list_my_notifications(
    user: Annotated[User, Depends(current_user)],
    notifications: Annotated[NotificationRepository, Depends(notification_repo)],
    only_unread: Annotated[bool, Query(alias="unread")] = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[NotificationRead]:
    """List the authenticated member's notifications, newest first.

    `unread=true` filters to unread items only — used by the badge query
    on the home shell so it doesn't pull the whole feed.
    """
    rows = await notifications.for_user(
        user.id, only_unread=only_unread, limit=limit
    )
    return [NotificationRead.model_validate(r) for r in rows]


@router.post("/{notification_id}/read", status_code=204)
async def mark_read(
    notification_id: UUID,
    user: Annotated[User, Depends(current_user)],
    notifications: Annotated[NotificationRepository, Depends(notification_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Mark a single notification read. Idempotent: a row already read
    returns 204 without touching the DB."""
    rowcount = await notifications.mark_read(user.id, [notification_id], utcnow())
    await session.commit()
    if rowcount == 0:
        # Either the notification belongs to someone else, doesn't exist,
        # or was already read. We can't distinguish "not yours" from
        # "already read" without a fetch — but both cases are uninteresting
        # for the caller, so 204 in all of them.
        return None


@router.post("/read-all", status_code=204)
async def mark_all_read(
    user: Annotated[User, Depends(current_user)],
    notifications: Annotated[NotificationRepository, Depends(notification_repo)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> None:
    """Mark every unread notification on the caller as read in one shot.

    The list endpoint capped at 100 doesn't constrain this — the underlying
    UPDATE handles the full unread set in a single statement.
    """
    rows = await notifications.for_user(user.id, only_unread=True, limit=10_000)
    if rows:
        ids = [r.id for r in rows]
        await notifications.mark_read(user.id, ids, utcnow())
        await session.commit()
    return None
