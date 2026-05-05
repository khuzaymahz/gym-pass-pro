from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.db.enums import PaymentMethod as PaymentMethodKind


class PaymentMethodRead(BaseModel):
    id: UUID
    kind: PaymentMethodKind
    label: str
    last4: str
    holder: str | None = None
    expiry_mm: int | None = Field(default=None, alias="expiryMm")
    expiry_yy: int | None = Field(default=None, alias="expiryYy")
    cliq_alias: str | None = Field(default=None, alias="cliqAlias")
    cliq_phone: str | None = Field(default=None, alias="cliqPhone")
    is_default: bool = Field(alias="isDefault")
    created_at: datetime = Field(alias="createdAt")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class PaymentMethodCreate(BaseModel):
    """Add-method payload from the mobile add-method sheet.

    Per-kind required fields are checked in `_check_kind_specific` so the
    error response points at the wrong field instead of failing on a
    cross-cutting `details` blob.
    """

    kind: PaymentMethodKind
    label: str = Field(min_length=1, max_length=80)
    last4: str = Field(default="", max_length=4)
    holder: str | None = Field(default=None, max_length=80)
    expiry_mm: int | None = Field(default=None, alias="expiryMm", ge=1, le=12)
    expiry_yy: int | None = Field(default=None, alias="expiryYy", ge=0, le=99)
    cliq_alias: str | None = Field(default=None, alias="cliqAlias", max_length=64)
    cliq_phone: str | None = Field(default=None, alias="cliqPhone", max_length=20)
    is_default: bool = Field(default=False, alias="isDefault")

    model_config = ConfigDict(populate_by_name=True)

    @model_validator(mode="after")
    def _check_kind_specific(self) -> "PaymentMethodCreate":
        if self.kind == PaymentMethodKind.CARD:
            if self.expiry_mm is None or self.expiry_yy is None:
                raise ValueError("Card requires expiry month and year.")
            if not self.last4 or len(self.last4) != 4 or not self.last4.isdigit():
                raise ValueError("Card requires a 4-digit last4.")
        if self.kind == PaymentMethodKind.CLIQ:
            if not (self.cliq_alias or self.cliq_phone):
                raise ValueError(
                    "CliQ requires either an alias or a phone number."
                )
        return self


class PaymentMethodSetDefault(BaseModel):
    """Empty body marker — semantic sugar over POST /default."""

    model_config = ConfigDict(populate_by_name=True)
