from __future__ import annotations

import structlog

from app.providers.push import SendResult

log = structlog.get_logger(__name__)


class MockPushProvider:
    async def send(
        self,
        *,
        token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> SendResult:
        log.info(
            "push.mock_dispatch",
            token=token[:16] + "…",
            title=title,
            data=data,
        )
        return SendResult(status="delivered")
