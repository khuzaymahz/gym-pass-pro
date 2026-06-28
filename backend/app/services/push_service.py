from __future__ import annotations

from uuid import UUID

import structlog

from app.providers.push import PushProvider
from app.repositories.device_token_repo import DeviceTokenRepository

log = structlog.get_logger(__name__)


class PushService:
    """Fan-out push notifications to every device a user has registered.

    One call per token; dead tokens are pruned immediately so subsequent
    deliveries don't waste quota on corpses. Transient errors are logged
    but not retried here — the caller (or a Celery task for large
    broadcasts) is responsible for deciding whether to retry.
    """

    def __init__(
        self,
        tokens: DeviceTokenRepository,
        provider: PushProvider,
    ) -> None:
        self._tokens = tokens
        self._provider = provider

    async def notify(
        self,
        *,
        user_id: UUID,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> int:
        """Send to all registered devices for `user_id`.

        Returns the number of tokens that accepted delivery (status ==
        `delivered`). Zero is not an error — the user may have no
        registered device (OTP-only login from a browser) or all tokens
        may be stale.
        """
        device_tokens = await self._tokens.tokens_for_user(user_id)
        if not device_tokens:
            return 0

        delivered = 0
        for dt in device_tokens:
            result = await self._provider.send(
                token=dt.token,
                title=title,
                body=body,
                data=data,
            )
            if result.status == "delivered":
                delivered += 1
            elif result.status == "dead_token":
                await self._tokens.delete_token(dt.token)
                log.info(
                    "push.pruned_dead_token",
                    user_id=str(user_id),
                    token=dt.token[:16] + "…",
                )
        return delivered

    async def notify_many(
        self,
        *,
        user_ids: list[UUID],
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> int:
        """Broadcast to multiple users. Used by the admin broadcast service.

        Batch-fetches all tokens for `user_ids` in one query, then
        fans out. Returns total delivered count.
        """
        if not user_ids:
            return 0

        all_tokens = await self._tokens.tokens_for_users(user_ids)
        if not all_tokens:
            return 0

        delivered = 0
        for dt in all_tokens:
            result = await self._provider.send(
                token=dt.token,
                title=title,
                body=body,
                data=data,
            )
            if result.status == "delivered":
                delivered += 1
            elif result.status == "dead_token":
                await self._tokens.delete_token(dt.token)
        return delivered
