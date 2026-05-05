from __future__ import annotations

from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import OtpCode
from app.utils.ids import uuid7


class OtpRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def insert(
        self, *, phone: str, code_hash: str, expires_at: datetime
    ) -> OtpCode:
        row = OtpCode(
            id=uuid7(), phone=phone, code_hash=code_hash, expires_at=expires_at
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def latest_for_phone(self, phone: str) -> OtpCode | None:
        stmt = (
            select(OtpCode)
            .where(OtpCode.phone == phone, OtpCode.consumed_at.is_(None))
            .order_by(OtpCode.expires_at.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def delete_expired_for_phone(self, phone: str, now: datetime) -> None:
        await self.session.execute(
            delete(OtpCode).where(
                OtpCode.phone == phone, OtpCode.expires_at < now
            )
        )

    async def mark_consumed(self, otp: OtpCode, now: datetime) -> None:
        otp.consumed_at = now
        await self.session.flush()

    async def increment_attempts(self, otp: OtpCode) -> None:
        otp.attempts += 1
        await self.session.flush()
