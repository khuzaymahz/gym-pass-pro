from __future__ import annotations

import json
from typing import Any

import httpx
import structlog
import urllib3
from google.auth.transport.urllib3 import Request
from google.oauth2 import service_account

from app.providers.push import SendResult

log = structlog.get_logger(__name__)

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_FCM_URL = "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"

# FCM error codes that mean the token is permanently dead and should be
# pruned from `device_tokens`. All others are retryable transient errors.
_DEAD_TOKEN_CODES = {
    "UNREGISTERED",
    "INVALID_ARGUMENT",  # malformed token — also unrecoverable
}


class FcmPushProvider:
    """FCM HTTP v1 push provider.

    Uses a Google service-account JSON file to obtain a short-lived
    OAuth2 bearer token (auto-refreshed by `google-auth`), then calls
    the FCM HTTP v1 `messages:send` endpoint for each delivery.

    The v1 API is the current standard — the legacy server-key API was
    deprecated in June 2024. v1 requires a service account with the
    `cloudmessaging.messages.create` IAM permission (granted by the
    "Firebase Cloud Messaging API Admin" role).
    """

    def __init__(self, sa_path: str) -> None:
        with open(sa_path) as fh:
            sa_info = json.load(fh)
        self._project_id: str = sa_info["project_id"]
        self._credentials = service_account.Credentials.from_service_account_info(
            sa_info, scopes=[_FCM_SCOPE]
        )
        self._url = _FCM_URL.format(project_id=self._project_id)

    def _access_token(self) -> str:
        """Return a valid OAuth2 bearer token, refreshing if expired."""
        if not self._credentials.valid:
            self._credentials.refresh(Request(urllib3.PoolManager()))
        return self._credentials.token  # type: ignore[return-value]

    async def send(
        self,
        *,
        token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> SendResult:
        payload: dict[str, Any] = {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "android": {
                    "priority": "high",
                    "notification": {
                        "channel_id": "gympass_default",
                        "sound": "default",
                    },
                },
                "apns": {
                    "headers": {"apns-priority": "10"},
                    "payload": {
                        "aps": {
                            "alert": {"title": title, "body": body},
                            "sound": "default",
                            "badge": 1,
                        }
                    },
                },
            }
        }
        if data:
            payload["message"]["data"] = data

        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.post(
                    self._url,
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {self._access_token()}",
                        "Content-Type": "application/json",
                    },
                )
        except httpx.TransportError as exc:
            log.warning("push.fcm.network_error", error=str(exc))
            return SendResult(status="transient_error", detail=str(exc))

        if resp.status_code == 200:
            return SendResult(status="delivered")

        try:
            err_body = resp.json()
            err_code: str = (
                err_body.get("error", {})
                .get("details", [{}])[0]
                .get("errorCode", "")
            )
        except Exception:
            err_code = ""

        if err_code in _DEAD_TOKEN_CODES or resp.status_code == 404:
            log.info(
                "push.fcm.dead_token",
                token=token[:16] + "…",
                code=err_code,
            )
            return SendResult(status="dead_token", detail=err_code)

        log.warning(
            "push.fcm.error",
            status=resp.status_code,
            body=resp.text[:200],
        )
        return SendResult(status="transient_error", detail=resp.text[:200])
