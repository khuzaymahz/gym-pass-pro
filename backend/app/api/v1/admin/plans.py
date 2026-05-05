from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import admin_plan_service, authed_actor, current_admin, db_session
from app.db.models import User
from app.schemas.admin import AdminPlanCreate, AdminPlanUpdate
from app.schemas.plan import PlanRead
from app.services.admin_plan_service import AdminPlanService

router = APIRouter(prefix="/admin/plans", tags=["admin/plans"])


@router.get("", response_model=list[PlanRead])
async def list_plans(
    svc: Annotated[AdminPlanService, Depends(admin_plan_service)],
    _: Annotated[User, Depends(current_admin)],
) -> list[PlanRead]:
    plans = await svc.list_all()
    return [PlanRead.model_validate(p) for p in plans]


@router.post("", response_model=PlanRead, status_code=201)
async def create_plan(
    body: AdminPlanCreate,
    request: Request,
    svc: Annotated[AdminPlanService, Depends(admin_plan_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PlanRead:
    plan = await svc.create(body, actor=authed_actor(request, admin))
    await session.commit()
    return PlanRead.model_validate(plan)


@router.get("/{plan_id}", response_model=PlanRead)
async def get_plan(
    plan_id: UUID,
    svc: Annotated[AdminPlanService, Depends(admin_plan_service)],
    _: Annotated[User, Depends(current_admin)],
) -> PlanRead:
    plan = await svc.get(plan_id)
    return PlanRead.model_validate(plan)


@router.patch("/{plan_id}", response_model=PlanRead)
async def update_plan(
    plan_id: UUID,
    body: AdminPlanUpdate,
    request: Request,
    svc: Annotated[AdminPlanService, Depends(admin_plan_service)],
    admin: Annotated[User, Depends(current_admin)],
    session: Annotated[AsyncSession, Depends(db_session)],
) -> PlanRead:
    plan = await svc.update(plan_id, body, actor=authed_actor(request, admin))
    await session.commit()
    return PlanRead.model_validate(plan)
