from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import AudienceGender, DayPassStatus
from app.db.models import DayPass, DayPassOffering, Gym, User
from app.utils.ids import uuid7


class DayPassOfferingRepository:
    """Read/write the per-gym offering config. One row per gym."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def for_gym(self, gym_id: UUID) -> DayPassOffering | None:
        stmt = select(DayPassOffering).where(DayPassOffering.gym_id == gym_id)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def upsert(
        self,
        *,
        gym_id: UUID,
        is_enabled: bool,
        price_jod: Decimal,
        daily_cap: int | None,
        audience_gender_override: AudienceGender | None,
        platform_fee_pct: Decimal | None = None,
        validity_hours: int | None = None,
    ) -> DayPassOffering:
        """Idempotent create-or-update keyed on `gym_id`.

        Partners save the entire offering on every form submit (PUT
        semantics), so we mutate the existing row when it's there
        and insert otherwise. Platform fee + validity hours are
        admin-controlled: the partner path leaves them None so the
        existing values (or the table defaults of 10% / 24h) stand;
        the admin path passes explicit values to set them.
        """
        existing = await self.for_gym(gym_id)
        if existing is None:
            offering = DayPassOffering(
                id=uuid7(),
                gym_id=gym_id,
                is_enabled=is_enabled,
                price_jod=price_jod,
                daily_cap=daily_cap,
                audience_gender_override=audience_gender_override,
            )
            # Only set the admin-owned columns when explicitly given;
            # otherwise let the server_default (10% / 24h) apply.
            if platform_fee_pct is not None:
                offering.platform_fee_pct = platform_fee_pct
            if validity_hours is not None:
                offering.validity_hours = validity_hours
            self.session.add(offering)
            await self.session.flush()
            return offering
        existing.is_enabled = is_enabled
        existing.price_jod = price_jod
        existing.daily_cap = daily_cap
        existing.audience_gender_override = audience_gender_override
        if platform_fee_pct is not None:
            existing.platform_fee_pct = platform_fee_pct
        if validity_hours is not None:
            existing.validity_hours = validity_hours
        await self.session.flush()
        return existing

    async def list_with_gym(
        self,
        *,
        enabled: bool | None = None,
        page: int = 1,
        page_size: int = 50,
    ) -> tuple[list[tuple[DayPassOffering, Gym]], int]:
        """Admin overview: every configured offering joined to its gym,
        newest-config first. `enabled` filters to on/off offerings."""
        conditions: list = []
        if enabled is not None:
            conditions.append(DayPassOffering.is_enabled == enabled)

        count_stmt = (
            select(func.count())
            .select_from(DayPassOffering)
            .join(Gym, Gym.id == DayPassOffering.gym_id)
        )
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = select(DayPassOffering, Gym).join(Gym, Gym.id == DayPassOffering.gym_id)
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(DayPassOffering.updated_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(o, g) for o, g in rows], int(total)


class DayPassRepository:
    """Per-purchase day-pass rows."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, pass_id: UUID) -> DayPass | None:
        return await self.session.get(DayPass, pass_id)

    async def set_refunded(self, day_pass: DayPass, now: datetime) -> None:
        """Flip a pass to REFUNDED + stamp `refunded_at`. The refunded
        pass becomes ineligible for check-in. Caller owns the matching
        payment-row reversal + audit + commit."""
        day_pass.status = DayPassStatus.REFUNDED
        day_pass.refunded_at = now
        await self.session.flush()

    async def list_paginated(
        self,
        *,
        status: DayPassStatus | None = None,
        gym_id: UUID | None = None,
        user_id: UUID | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[tuple[DayPass, User, Gym]], int]:
        """Admin sold-passes view: passes joined to buyer + gym, newest
        purchase first, with optional status/gym/user filters."""
        conditions: list = []
        if status is not None:
            conditions.append(DayPass.status == status)
        if gym_id is not None:
            conditions.append(DayPass.gym_id == gym_id)
        if user_id is not None:
            conditions.append(DayPass.user_id == user_id)

        count_stmt = select(func.count()).select_from(DayPass)
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = (
            select(DayPass, User, Gym)
            .join(User, User.id == DayPass.user_id)
            .join(Gym, Gym.id == DayPass.gym_id)
        )
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(DayPass.purchased_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).all()
        return [(dp, u, g) for dp, u, g in rows], int(total)

    async def lock_user_for_purchase(self, user_id: UUID) -> None:
        """Same idiom as `SubscriptionRepository.lock_user_for_purchase`
        — serializes concurrent day-pass purchases by the same
        member so a double-tap doesn't create two pending rows that
        both succeed and double-charge. Released at commit/rollback.
        """
        await self.session.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:k))"),
            {"k": f"day-pass-purchase:{user_id}"},
        )

    async def create_pending(
        self,
        *,
        user_id: UUID,
        gym_id: UUID,
        offering_id: UUID,
        price_jod: Decimal,
        platform_fee_jod: Decimal,
        net_amount_jod: Decimal,
        purchased_at: datetime,
        expires_at: datetime,
    ) -> DayPass:
        """Both timestamps come from the caller's clock (the
        service's `utcnow()`), NOT the Postgres `now()` default —
        otherwise `expires_at - purchased_at` skews by however many
        ms the round trip + INSERT took. Tests assert
        `expires_at - purchased_at == validity_hours` exactly, and
        production audit-trail readers benefit from the same
        invariant.
        """
        row = DayPass(
            id=uuid7(),
            user_id=user_id,
            gym_id=gym_id,
            offering_id=offering_id,
            price_jod=price_jod,
            platform_fee_jod=platform_fee_jod,
            net_amount_jod=net_amount_jod,
            purchased_at=purchased_at,
            expires_at=expires_at,
            status=DayPassStatus.PENDING,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def activate(self, day_pass: DayPass, payment_id: UUID) -> None:
        day_pass.status = DayPassStatus.ACTIVE
        day_pass.payment_id = payment_id

    async def mark_used(
        self,
        day_pass: DayPass,
        *,
        checkin_id: UUID,
        used_at: datetime,
    ) -> None:
        day_pass.status = DayPassStatus.USED
        day_pass.checkin_id = checkin_id
        day_pass.used_at = used_at

    async def active_for_user_gym(
        self, *, user_id: UUID, gym_id: UUID, now: datetime
    ) -> DayPass | None:
        """The one active pass eligible to redeem a check-in *right now*.

        Uses the partial index `ix_day_passes_active_lookup` (keyed
        on status='active'), so this is a single index seek even on
        a fat table.
        """
        stmt = (
            select(DayPass)
            .where(
                DayPass.user_id == user_id,
                DayPass.gym_id == gym_id,
                DayPass.status == DayPassStatus.ACTIVE,
                DayPass.expires_at > now,
            )
            .order_by(DayPass.expires_at.desc())
            .limit(1)
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def list_for_user(
        self,
        *,
        user_id: UUID,
        include_expired: bool = False,
        limit: int = 50,
    ) -> list[DayPass]:
        """Returns the user's day passes, active first, then by
        purchased-at desc. Profile screen uses this to render the
        "Active passes" card.
        """
        active_statuses = (
            DayPassStatus.PENDING,
            DayPassStatus.ACTIVE,
            DayPassStatus.USED,
        )
        if include_expired:
            active_statuses = (*active_statuses, DayPassStatus.EXPIRED)
        stmt = (
            select(DayPass)
            .where(
                DayPass.user_id == user_id,
                DayPass.status.in_(active_statuses),
            )
            .order_by(
                # Active first, then newest-purchased.
                (DayPass.status == DayPassStatus.ACTIVE).desc(),
                DayPass.purchased_at.desc(),
            )
            .limit(limit)
        )
        return list((await self.session.execute(stmt)).scalars().all())

    async def count_for_offering_on_date(
        self, *, offering_id: UUID, day_start: datetime, day_end: datetime
    ) -> int:
        """How many passes have been sold against this offering today.

        Used for `daily_cap` enforcement at purchase time. Counts
        active + used + expired (anything that consumed inventory),
        excludes refunded (already returned).
        """

        stmt = (
            select(func.count())
            .select_from(DayPass)
            .where(
                DayPass.offering_id == offering_id,
                DayPass.purchased_at >= day_start,
                DayPass.purchased_at < day_end,
                DayPass.status.in_(
                    (
                        DayPassStatus.ACTIVE,
                        DayPassStatus.USED,
                        DayPassStatus.EXPIRED,
                    )
                ),
            )
        )
        return int((await self.session.execute(stmt)).scalar() or 0)
