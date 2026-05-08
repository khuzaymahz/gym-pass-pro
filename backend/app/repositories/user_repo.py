from __future__ import annotations

from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.enums import Locale, Role
from app.db.models import User
from app.utils.ids import uuid7


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get(self, user_id: UUID) -> User | None:
        return await self.session.get(User, user_id)

    async def get_by_phone(self, phone: str) -> User | None:
        stmt = select(User).where(User.phone == phone, User.deleted_at.is_(None))
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email, User.deleted_at.is_(None))
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_google_sub(self, sub: str) -> User | None:
        stmt = select(User).where(User.google_sub == sub)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_referral_code(self, code: str) -> User | None:
        stmt = select(User).where(
            User.referral_code == code, User.deleted_at.is_(None)
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def create_member_by_phone(self, phone: str) -> User:
        user = User(id=uuid7(), phone=phone, role=Role.MEMBER, locale=Locale.AR)
        self.session.add(user)
        await self.session.flush()
        return user

    async def create_member_by_google(
        self, *, email: str, name: str | None, google_sub: str, avatar_url: str | None
    ) -> User:
        user = User(
            id=uuid7(),
            email=email,
            name=name,
            google_sub=google_sub,
            avatar_url=avatar_url,
            role=Role.MEMBER,
            locale=Locale.AR,
        )
        self.session.add(user)
        await self.session.flush()
        return user

    async def create_admin(self, *, email: str, password_hash: str, name: str) -> User:
        user = User(
            id=uuid7(),
            email=email,
            name=name,
            password_hash=password_hash,
            role=Role.ADMIN,
            locale=Locale.EN,
        )
        self.session.add(user)
        await self.session.flush()
        return user

    async def create_gym_owner(
        self,
        *,
        phone: str,
        password_hash: str,
        name: str,
        gym_id: UUID,
    ) -> User:
        user = User(
            id=uuid7(),
            phone=phone,
            name=name,
            password_hash=password_hash,
            role=Role.GYM_OWNER,
            gym_id=gym_id,
            locale=Locale.AR,
        )
        self.session.add(user)
        await self.session.flush()
        return user

    async def get_gym_owner_for_gym(self, gym_id: UUID) -> User | None:
        stmt = select(User).where(
            User.gym_id == gym_id,
            User.role == Role.GYM_OWNER,
            User.deleted_at.is_(None),
        )
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def list_paginated(
        self,
        *,
        role: Role | None = None,
        q: str | None = None,
        include_deleted: bool = False,
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[User], int]:
        conditions = []
        if not include_deleted:
            conditions.append(User.deleted_at.is_(None))
        if role is not None:
            conditions.append(User.role == role)
        if q:
            # Escape SQL `%` and `_` wildcards in user input before
            # interpolating into a LIKE pattern. SQLAlchemy parameter-
            # binds the string itself (so this isn't a classic SQL
            # injection vector), but the wildcard SEMANTICS still leak
            # — without escaping, a search for `%` matches every row
            # and a search for `a_b` matches `aXb` for any X. Plain
            # `\` is the SQL-standard escape character; `escape='\\'`
            # tells the engine to interpret it as such.
            safe = q.lower().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            like = f"%{safe}%"
            phone_safe = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            conditions.append(
                or_(
                    func.lower(User.email).like(like, escape="\\"),
                    func.lower(User.name).like(like, escape="\\"),
                    User.phone.like(f"%{phone_safe}%", escape="\\"),
                )
            )

        count_stmt = select(func.count()).select_from(User)
        if conditions:
            count_stmt = count_stmt.where(*conditions)
        total = (await self.session.execute(count_stmt)).scalar_one()

        stmt = select(User)
        if conditions:
            stmt = stmt.where(*conditions)
        stmt = (
            stmt.order_by(User.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.session.execute(stmt)).scalars().all()
        return list(rows), int(total)

    async def count_by_role(self, role: Role) -> int:
        stmt = (
            select(func.count())
            .select_from(User)
            .where(User.role == role, User.deleted_at.is_(None))
        )
        return int((await self.session.execute(stmt)).scalar_one())

    async def update_fields(self, user: User, **fields: object) -> User:
        for k, v in fields.items():
            setattr(user, k, v)
        await self.session.flush()
        return user

    async def soft_delete(self, user: User, now: object) -> None:
        user.deleted_at = now  # type: ignore[assignment]
        await self.session.flush()

    async def restore(self, user: User) -> None:
        user.deleted_at = None
        await self.session.flush()

    async def list_member_ids_by_tier(self, tier: object | None) -> list[UUID]:
        """Return ids of members who currently hold an active subscription.

        If `tier` is provided, filter to members on that tier (or better, since
        higher tiers are supersets). Returning ids only keeps the payload light
        for broadcast fan-out.
        """
        from app.db.enums import SubscriptionStatus
        from app.db.models import Subscription

        conditions = [
            User.role == Role.MEMBER,
            User.deleted_at.is_(None),
            Subscription.status == SubscriptionStatus.ACTIVE,
        ]
        stmt = (
            select(User.id)
            .join(Subscription, Subscription.user_id == User.id)
            .where(*conditions)
        )
        if tier is not None:
            stmt = stmt.where(Subscription.tier == tier)
        rows = (await self.session.execute(stmt)).scalars().all()
        return list(rows)
