from __future__ import annotations

import structlog

log = structlog.get_logger(__name__)


class MockPushProvider:
    async def send(
        self, *, user_id: str, title: str, body: str, deep_link: str | None = None
    ) -> None:
        log.info("push.dispatch", user_id=user_id, title=title, deep_link=deep_link)
