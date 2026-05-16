from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import ApplicationStatus
from app.db.models import PartnerApplication
from app.utils.ids import uuid7


class PartnerApplicationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, app_id: UUID) -> PartnerApplication | None:
        return await self.session.get(PartnerApplication, app_id)

    async def create(self, **fields: object) -> PartnerApplication:
        app = PartnerApplication(id=uuid7(), **fields)
        self.session.add(app)
        await self.session.flush()
        return app

    async def list_with_status(
        self,
        *,
        status: ApplicationStatus | None = None,
        page: int = 1,
        page_size: int = 30,
    ) -> tuple[list[PartnerApplication], int]:
        conditions: list[Any] = []
        if status is not None:
            conditions.append(PartnerApplication.status == status)

        count_stmt = (
            select(func.count())
            .select_from(PartnerApplication)
            .where(*conditions)
        )
        total = int((await self.session.execute(count_stmt)).scalar_one())

        stmt = (
            select(PartnerApplication)
            .where(*conditions)
            .order_by(PartnerApplication.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return list(rows), total

    async def count_pending(self) -> int:
        """Used by the admin sidebar to render a pending-count badge
        next to the Partner Applications nav entry."""

        stmt = (
            select(func.count())
            .select_from(PartnerApplication)
            .where(PartnerApplication.status == ApplicationStatus.PENDING)
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def update(
        self, app: PartnerApplication, /, **fields: object
    ) -> PartnerApplication:
        for k, v in fields.items():
            setattr(app, k, v)
        await self.session.flush()
        return app
