from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, text
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import Gender, Locale, Role
from app.db.types import (
    TimestampTZ,
    TimestampTZNullable,
    TimestampTZUpdate,
    UUIDCol,
    pg_enum_cls,
)


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUIDCol]
    phone: Mapped[str | None] = mapped_column(nullable=True)
    email: Mapped[str | None] = mapped_column(nullable=True)
    name: Mapped[str | None] = mapped_column(nullable=True)
    first_name: Mapped[str | None] = mapped_column(nullable=True)
    last_name: Mapped[str | None] = mapped_column(nullable=True)
    gender: Mapped[Gender | None] = mapped_column(
        pg_enum_cls("gender_enum", Gender), nullable=True
    )
    birthdate: Mapped[date | None] = mapped_column(Date(), nullable=True)
    google_sub: Mapped[str | None] = mapped_column(nullable=True)
    password_hash: Mapped[str | None] = mapped_column(nullable=True)

    role: Mapped[Role] = mapped_column(
        pg_enum_cls("role_enum", Role),
        nullable=False,
        server_default=text("'member'"),
    )
    locale: Mapped[Locale] = mapped_column(
        pg_enum_cls("locale_enum", Locale),
        nullable=False,
        server_default=text("'ar'"),
    )
    avatar_url: Mapped[str | None] = mapped_column(nullable=True)

    referral_code: Mapped[str | None] = mapped_column(nullable=True)
    invited_by_user_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    # Gym-owner ↔ gym linkage. Nullable because only `role='gym_owner'`
    # users carry it; partial unique index on (gym_id) WHERE
    # role='gym_owner' enforces the 1:1 partner-per-gym invariant the
    # product requires.
    gym_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey("gyms.id", ondelete="SET NULL"),
        nullable=True,
    )
    last_active_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[TimestampTZ]
    updated_at: Mapped[TimestampTZUpdate]
    deleted_at: Mapped[TimestampTZNullable]

    __table_args__ = (
        Index(
            "uq_users_phone",
            "phone",
            unique=True,
            postgresql_where=text("phone IS NOT NULL AND deleted_at IS NULL"),
        ),
        Index(
            "uq_users_email",
            "email",
            unique=True,
            postgresql_where=text("email IS NOT NULL AND deleted_at IS NULL"),
        ),
        Index(
            "uq_users_google_sub",
            "google_sub",
            unique=True,
            postgresql_where=text("google_sub IS NOT NULL"),
        ),
        Index(
            "uq_users_referral_code",
            "referral_code",
            unique=True,
            postgresql_where=text("referral_code IS NOT NULL"),
        ),
        Index("ix_users_role", "role"),
        Index("ix_users_invited_by_user_id", "invited_by_user_id"),
        Index("ix_users_last_active_at", "last_active_at"),
        Index(
            "uq_users_gym_owner_gym_id",
            "gym_id",
            unique=True,
            postgresql_where=text(
                "role = 'gym_owner' AND gym_id IS NOT NULL AND deleted_at IS NULL"
            ),
        ),
        Index(
            "ix_users_gym_id",
            "gym_id",
            postgresql_where=text("gym_id IS NOT NULL"),
        ),
        CheckConstraint(
            "phone IS NOT NULL OR email IS NOT NULL OR google_sub IS NOT NULL",
            name="identity",
        ),
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} role={self.role}>"

    @property
    def is_active(self) -> bool:
        return self.deleted_at is None

    @property
    def is_admin(self) -> bool:
        return self.role == Role.ADMIN

    @property
    def has_password(self) -> bool:
        return bool(self.password_hash)

    @property
    def display_name(self) -> str | None:
        parts = [p for p in (self.first_name, self.last_name) if p]
        if parts:
            return " ".join(parts)
        return self.name
