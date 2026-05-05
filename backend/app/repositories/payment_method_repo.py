from __future__ import annotations

from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import PaymentMethod as PaymentMethodKind
from app.db.models import StoredPaymentMethod
from app.utils.ids import uuid7
from app.utils.time import utcnow


class PaymentMethodRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_for_user(self, user_id: UUID) -> list[StoredPaymentMethod]:
        stmt = (
            select(StoredPaymentMethod)
            .where(
                StoredPaymentMethod.user_id == user_id,
                StoredPaymentMethod.deleted_at.is_(None),
            )
            .order_by(
                StoredPaymentMethod.is_default.desc(),
                StoredPaymentMethod.created_at.asc(),
            )
        )
        return list((await self.session.execute(stmt)).scalars().all())

    async def get_owned(
        self, *, method_id: UUID, user_id: UUID
    ) -> StoredPaymentMethod | None:
        """Returns the row only if the caller owns it. The composite filter
        keeps callers from accidentally leaking another member's method."""
        stmt = select(StoredPaymentMethod).where(
            StoredPaymentMethod.id == method_id,
            StoredPaymentMethod.user_id == user_id,
            StoredPaymentMethod.deleted_at.is_(None),
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def create(
        self,
        *,
        user_id: UUID,
        kind: PaymentMethodKind,
        label: str,
        last4: str,
        holder: str | None = None,
        expiry_mm: int | None = None,
        expiry_yy: int | None = None,
        cliq_alias: str | None = None,
        cliq_phone: str | None = None,
        gateway_token: str | None = None,
        is_default: bool = False,
    ) -> StoredPaymentMethod:
        row = StoredPaymentMethod(
            id=uuid7(),
            user_id=user_id,
            kind=kind,
            label=label,
            last4=last4,
            holder=holder,
            expiry_mm=expiry_mm,
            expiry_yy=expiry_yy,
            cliq_alias=cliq_alias,
            cliq_phone=cliq_phone,
            gateway_token=gateway_token,
            is_default=is_default,
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def soft_delete(self, row: StoredPaymentMethod) -> None:
        row.deleted_at = utcnow()
        # Soft-deleted methods can never be the default — clear the flag so
        # a future default-setter doesn't trip the partial unique index.
        row.is_default = False
        await self.session.flush()

    async def clear_default_for_user(self, user_id: UUID) -> None:
        """Atomically clear `is_default` on every active row for the user.

        Used right before promoting a new default — the partial unique index
        would otherwise reject `UPDATE ... SET is_default=true` while the
        old default row still exists.
        """
        stmt = (
            update(StoredPaymentMethod)
            .where(
                StoredPaymentMethod.user_id == user_id,
                StoredPaymentMethod.is_default.is_(True),
                StoredPaymentMethod.deleted_at.is_(None),
            )
            .values(is_default=False)
        )
        await self.session.execute(stmt)
        await self.session.flush()

    async def set_default(self, row: StoredPaymentMethod) -> None:
        await self.clear_default_for_user(row.user_id)
        row.is_default = True
        await self.session.flush()

    async def has_any_active(self, user_id: UUID) -> bool:
        stmt = select(StoredPaymentMethod.id).where(
            StoredPaymentMethod.user_id == user_id,
            StoredPaymentMethod.deleted_at.is_(None),
        ).limit(1)
        return (await self.session.execute(stmt)).first() is not None
