from __future__ import annotations

import secrets
from uuid import UUID

from app.core.exceptions import AppError, ErrorCode
from app.db.enums import PaymentMethod as PaymentMethodKind
from app.db.models import StoredPaymentMethod
from app.repositories.payment_method_repo import PaymentMethodRepository
from app.services.audit_service import Actor, AuditService


class PaymentMethodService:
    """Owns the member's saved-payment-method lifecycle.

    The service intentionally treats payment-method storage as a UI affordance
    layer: the mock gateway issues a synthetic token; a real gateway would
    plug in here without touching the route. SOLID-wise, the route only
    knows about this service, and the service hides the token-issuing
    detail behind a narrow Protocol-shaped boundary.
    """

    def __init__(
        self,
        repo: PaymentMethodRepository,
        audit: AuditService,
    ) -> None:
        self.repo = repo
        self.audit = audit

    async def list_for_user(self, user_id: UUID) -> list[StoredPaymentMethod]:
        return await self.repo.list_for_user(user_id)

    async def add(
        self,
        *,
        user_id: UUID,
        kind: PaymentMethodKind,
        label: str,
        last4: str,
        holder: str | None,
        expiry_mm: int | None,
        expiry_yy: int | None,
        cliq_alias: str | None,
        cliq_phone: str | None,
        make_default: bool,
        actor: Actor,
    ) -> StoredPaymentMethod:
        # Synthetic token under the mock gateway — real provider replaces
        # this with whatever opaque reference its vault returns.
        gateway_token = f"mock-{secrets.token_hex(8)}"

        already_has_methods = await self.repo.has_any_active(user_id)
        # First method is implicitly default — saves the user a tap.
        is_default = make_default or not already_has_methods

        if is_default:
            await self.repo.clear_default_for_user(user_id)

        row = await self.repo.create(
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
        await self.audit.log(
            actor=actor,
            action="payment_method.add",
            entity_type="payment_method",
            entity_id=row.id,
            diff={
                "after": {
                    "kind": kind.value,
                    "label": label,
                    "last4": last4 or None,
                    "is_default": is_default,
                }
            },
        )
        return row

    async def remove(
        self, *, method_id: UUID, user_id: UUID, actor: Actor
    ) -> None:
        row = await self.repo.get_owned(method_id=method_id, user_id=user_id)
        if row is None:
            raise AppError(ErrorCode.NOT_FOUND, "Payment method not found.")
        was_default = row.is_default
        await self.repo.soft_delete(row)
        # If we just removed the default, promote the next available method
        # so the member still has a default for the next checkout.
        if was_default:
            remaining = await self.repo.list_for_user(user_id)
            if remaining:
                await self.repo.set_default(remaining[0])
        await self.audit.log(
            actor=actor,
            action="payment_method.remove",
            entity_type="payment_method",
            entity_id=row.id,
            diff={"before": {"label": row.label, "is_default": was_default}},
        )

    async def set_default(
        self, *, method_id: UUID, user_id: UUID, actor: Actor
    ) -> StoredPaymentMethod:
        row = await self.repo.get_owned(method_id=method_id, user_id=user_id)
        if row is None:
            raise AppError(ErrorCode.NOT_FOUND, "Payment method not found.")
        await self.repo.set_default(row)
        await self.audit.log(
            actor=actor,
            action="payment_method.set_default",
            entity_type="payment_method",
            entity_id=row.id,
            diff={"after": {"label": row.label}},
        )
        return row
