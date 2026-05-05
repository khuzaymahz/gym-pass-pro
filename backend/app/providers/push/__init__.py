from __future__ import annotations

from typing import Protocol


class PushProvider(Protocol):
    async def send(
        self, *, user_id: str, title: str, body: str, deep_link: str | None = None
    ) -> None: ...


def build_push_provider() -> PushProvider:
    from app.providers.push.mock_push import MockPushProvider

    return MockPushProvider()
