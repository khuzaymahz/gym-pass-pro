from __future__ import annotations

from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.models import Plan
from app.repositories.plan_repo import PlanRepository
from app.schemas.admin import AdminPlanCreate, AdminPlanUpdate
from app.services.audit_service import Actor, AuditService


class AdminPlanService:
    def __init__(self, plans: PlanRepository, audit: AuditService) -> None:
        self.plans = plans
        self.audit = audit

    async def list_all(self) -> list[Plan]:
        return await self.plans.list_all()

    async def get(self, plan_id: UUID) -> Plan:
        plan = await self.plans.get(plan_id)
        if plan is None:
            raise AppError(ErrorCode.PLAN_NOT_FOUND, "Plan not found.")
        return plan

    async def create(self, data: AdminPlanCreate, *, actor: Actor) -> Plan:
        payload = data.model_dump(by_alias=False)
        plan = await self.plans.create(**payload)
        await self.audit.log(
            actor=actor, action="plan.create",
            entity_type="plan", entity_id=plan.id, diff={"after": payload},
        )
        return plan

    async def update(
        self, plan_id: UUID, data: AdminPlanUpdate, *, actor: Actor
    ) -> Plan:
        plan = await self.get(plan_id)
        before = _snapshot(plan)
        updates = data.model_dump(by_alias=False, exclude_unset=True)
        await self.plans.update(plan, **updates)
        await self.audit.log(
            actor=actor, action="plan.update",
            entity_type="plan", entity_id=plan.id,
            diff={"before": before, "after": updates},
        )
        return plan


def _snapshot(plan: Plan) -> dict[str, object]:
    return {
        "tier": plan.tier.value,
        "duration_months": plan.duration_months,
        "price_jod": str(plan.price_jod),
        "monthly_visits": plan.monthly_visits,
        "is_active": plan.is_active,
    }
