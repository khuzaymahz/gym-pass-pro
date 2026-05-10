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

    async def list_all_admin(
        self,
        *,
        status: ReferralStatus | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[tuple[Referral, User, User]], int]:
        """Paginated list across **all** referrals for the admin
        dashboard. Returns triples of (referral, referrer, invited)
        joined eagerly so the response can render both names without
        a per-row N+1.

        Optional `status` filter narrows to pending or converted —
        useful for the "who hasn't paid yet?" reconciliation cut.
        """
        referrer = aliased(User)
        invited = aliased(User)
        base = (
            select(Referral, referrer, invited)
            .join(referrer, referrer.id == Referral.referrer_user_id)
            .join(invited, invited.id == Referral.invited_user_id)
        )
        count_stmt = select(func.count()).select_from(Referral)
        if status is not None:
            base = base.where(Referral.status == status)
            count_stmt = count_stmt.where(Referral.status == status)

        total = int((await self.session.execute(count_stmt)).scalar_one() or 0)
        offset = max(page - 1, 0) * page_size
        stmt = (
            base
            .order_by(Referral.created_at.desc())
            .limit(page_size)
            .offset(offset)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(r, ref, inv) for r, ref, inv in rows], total

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
