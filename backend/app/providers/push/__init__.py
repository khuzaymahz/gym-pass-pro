from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Literal, Protocol


@dataclass(frozen=True)
class SendResult:
    """Outcome of a single push delivery attempt to ONE device token.

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
        token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> SendResult:
        """Deliver a push notification to one device token.

        `data` is the FCM data payload — arbitrary string→string pairs
        the mobile app can read even in background delivery. We pass
        `deep_link` and `type` here so the app can navigate on tap
        without a server round-trip.

        Returns a `SendResult` rather than raising — silent failure in
        a fan-out loop would suppress the dead-token signal the caller
        needs to prune the `device_tokens` row.
        """
        ...


def build_push_provider() -> PushProvider:
    """Return the real FCM provider in production, mock in dev.

    Resolution order:
      1. `FCM_SERVICE_ACCOUNT_PATH` env var pointing at a service-account
         JSON → `FcmPushProvider`.
      2. Everything else → `MockPushProvider` (logs only, no network).

    Dev mode stays frictionless: no Firebase credentials needed, push
    messages are logged to stdout like OTP codes are.
    """
    sa_path = os.environ.get("FCM_SERVICE_ACCOUNT_PATH", "")
    if sa_path and os.path.isfile(sa_path):
        from app.providers.push.fcm_push import FcmPushProvider

        return FcmPushProvider(sa_path=sa_path)

    from app.providers.push.mock_push import MockPushProvider

    return MockPushProvider()
