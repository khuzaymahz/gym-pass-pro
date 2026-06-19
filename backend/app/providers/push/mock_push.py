from __future__ import annotations

from uuid import UUID

import structlog

from app.providers.push import SendResult

log = structlog.get_logger(__name__)


class MockPushProvider:
    async def send(
        self,
        *,
        user_id: UUID,
        title: str,
        body: str,
        deep_link: str | None = None,
    ) -> SendResult:
        log.info(
            "push.dispatch",
            user_id=str(user_id),
            title=title,
            deep_link=deep_link,
        )
        return SendResult(status="delivered")
