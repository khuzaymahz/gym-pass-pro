from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Protocol
from uuid import UUID


@dataclass(frozen=True)
class SendResult:
    """Outcome of a single push delivery attempt.

    Three buckets matter to the caller:
      - `delivered`        — provider accepted the payload; assume it
                             reaches the device.
      - `dead_token`       — the device token is no longer valid
                             (FCM `UNREGISTERED`, APNs `Unregistered`).
                             The caller must prune the row from
                             `device_tokens` so we stop wasting calls
                             on it and stop occupying the token-quota
                             with a corpse.
      - `transient_error`  — provider returned a 5xx / network blip.
                             Caller may retry through Celery.

    Mock returns `delivered`. Real FCM / APNs adapters map their
    error codes into one of the three buckets so the caller is
    provider-agnostic.
    """

    status: Literal["delivered", "dead_token", "transient_error"]
    detail: str | None = None


class PushProvider(Protocol):
    async def send(
        self,
        *,
        user_id: UUID,
        title: str,
        body: str,
        deep_link: str | None = None,
    ) -> SendResult:
        """Deliver a push notification.

        Returns a `SendResult` rather than raising — silent failure in
        a fan-out loop would leak the dead-token signal the caller
        needs to prune the `device_tokens` row.
        """
        ...


def build_push_provider() -> PushProvider:
    from app.providers.push.mock_push import MockPushProvider

    return MockPushProvider()
