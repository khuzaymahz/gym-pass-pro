from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Plan
from app.utils.ids import uuid7


class PlanRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, plan_id: UUID) -> Plan | None:
        return await self.session.get(Plan, plan_id)

    async def list_active(self) -> list[Plan]:
        stmt = (
            select(Plan)
            .where(Plan.is_active.is_(True))
            .order_by(Plan.tier, Plan.duration_months)
        )
        return list((await self.session.execute(stmt)).scalars().all())

    async def list_all(self) -> list[Plan]:
        stmt = select(Plan).order_by(Plan.tier, Plan.duration_months)
        return list((await self.session.execute(stmt)).scalars().all())

    async def create(self, **fields: object) -> Plan:
        plan = Plan(id=uuid7(), **fields)
        self.session.add(plan)
        await self.session.flush()
        return plan

    async def update(self, plan: Plan, **fields: object) -> Plan:
        # Caller uses Pydantic `exclude_unset=True`, so an explicit
        # null clears the field; "None means skip" silently dropped
        # legitimate unsets. See gym_repo.update for the matching
        # rationale.
        for k, v in fields.items():
            setattr(plan, k, v)
        await self.session.flush()
        return plan
