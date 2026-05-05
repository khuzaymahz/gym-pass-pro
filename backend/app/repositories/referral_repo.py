from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.db.enums import ReferralStatus
from app.db.models import Referral, User
from app.utils.ids import uuid7


class ReferralRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, referral_id: UUID) -> Referral | None:
        return await self.session.get(Referral, referral_id)

    async def get_by_invited_user(self, invited_user_id: UUID) -> Referral | None:
        stmt = select(Referral).where(Referral.invited_user_id == invited_user_id)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def create(
        self,
        *,
        referrer_user_id: UUID,
        invited_user_id: UUID,
        referral_code: str,
    ) -> Referral:
        referral = Referral(
            id=uuid7(),
            referrer_user_id=referrer_user_id,
            invited_user_id=invited_user_id,
            referral_code=referral_code,
            status=ReferralStatus.PENDING,
        )
        self.session.add(referral)
        await self.session.flush()
        return referral

    async def mark_converted(self, referral: Referral, now: datetime) -> None:
        referral.status = ReferralStatus.CONVERTED
        referral.converted_at = now
        await self.session.flush()

    async def list_for_referrer(
        self, referrer_user_id: UUID
    ) -> list[tuple[Referral, User]]:
        invited = aliased(User)
        stmt = (
            select(Referral, invited)
            .join(invited, invited.id == Referral.invited_user_id)
            .where(Referral.referrer_user_id == referrer_user_id)
            .order_by(Referral.created_at.desc())
        )
        rows = (await self.session.execute(stmt)).all()
        return [(r, u) for r, u in rows]

    async def counts_for_referrer(
        self, referrer_user_id: UUID
    ) -> dict[str, int]:
        stmt = (
            select(Referral.status, func.count())
            .where(Referral.referrer_user_id == referrer_user_id)
            .group_by(Referral.status)
        )
        rows = (await self.session.execute(stmt)).all()
        out = {s.value: 0 for s in ReferralStatus}
        for status, count in rows:
            out[status.value] = int(count)
        return out
