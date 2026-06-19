from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Annotated
from uuid import UUID

from sqlalchemy import DateTime, Enum as SAEnum, Numeric, func, text
from sqlalchemy.dialects.postgresql import ENUM as PgEnum
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import mapped_column

UUIDCol = Annotated[UUID, mapped_column(PgUUID(as_uuid=True), primary_key=True)]
UUIDFk = Annotated[UUID, mapped_column(PgUUID(as_uuid=True))]

TimestampTZ = Annotated[
    datetime,
    mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False),
]
TimestampTZUpdate = Annotated[
    datetime,
    mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        server_onupdate=func.now(),
        nullable=False,
    ),
]
TimestampTZNullable = Annotated[
    datetime | None,
    mapped_column(DateTime(timezone=True), nullable=True),
]

# JOD has 3 minor units (fils): 1.234 JOD is legal money. A 2-decimal
# scale silently rounds the third fil away on every write — over a
# payout batch this compounds to a real reconciliation gap. The
# 12-row migration `0021_jod_money_scale_3.py` widens every existing
# money column in lock-step.
Money = Annotated[Decimal, mapped_column(Numeric(10, 3), nullable=False)]
MoneyBig = Annotated[Decimal, mapped_column(Numeric(12, 3), nullable=False)]


def pg_enum(name: str, *values: str) -> PgEnum:
    return PgEnum(*values, name=name, create_type=False, native_enum=True)


def pg_enum_cls(name: str, enum_cls: type[Enum]) -> SAEnum:
    """Typed PG enum bound to a Python Enum class for read coercion."""
    return SAEnum(
        enum_cls,
        name=name,
        native_enum=True,
        create_type=False,
        values_callable=lambda e: [m.value for m in e],
    )


__all__ = [
    "Money",
    "MoneyBig",
    "TimestampTZ",
    "TimestampTZNullable",
    "TimestampTZUpdate",
    "UUIDCol",
    "UUIDFk",
    "pg_enum",
    "pg_enum_cls",
    "text",
]
