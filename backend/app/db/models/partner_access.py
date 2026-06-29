from __future__ import annotations

from sqlalchemy import ForeignKey, Index, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import PartnerAccessRole
from app.db.types import TimestampTZ, UUIDCol, UUIDFk, pg_enum_cls


class PartnerAccess(Base):
    """Many-to-many link between a partner user and the gyms they can
    operate in the partner portal — the basis for gym chains.

    A standalone gym has one `owner` row. A chain owner holds an `owner`
    row on every branch (one login, all branches). A branch manager has
    a single `manager` row. Replaces the implicit 1:1 `users.gym_id`,
    which migration 0028 back-fills into `owner` rows; `users.gym_id` is
    retained as a legacy "primary gym" pointer, but the set of gyms a
    partner can reach is read from here.
    """

    __tablename__ = "partner_access"

    id: Mapped[UUIDCol]
    user_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    gym_id: Mapped[UUIDFk] = mapped_column(
        ForeignKey("gyms.id", ondelete="CASCADE"), nullable=False
    )
    role: Mapped[PartnerAccessRole] = mapped_column(
        pg_enum_cls("partner_access_role_enum", PartnerAccessRole),
        nullable=False,
        server_default=text("'owner'"),
    )
    created_at: Mapped[TimestampTZ]

    __table_args__ = (
        UniqueConstraint("user_id", "gym_id", name="uq_partner_access_user_gym"),
        Index("ix_partner_access_user", "user_id"),
        Index("ix_partner_access_gym", "gym_id"),
    )
