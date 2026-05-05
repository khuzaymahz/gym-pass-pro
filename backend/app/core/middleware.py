from __future__ import annotations

import time
import uuid
from typing import Any

import structlog
from starlette.types import ASGIApp, Message, Receive, Scope, Send

log = structlog.get_logger(__name__)


class RequestContextMiddleware:
    """Attach a request id and log one line per request with duration.

    Implemented as a pure ASGI middleware rather than a BaseHTTPMiddleware
    subclass: BaseHTTPMiddleware wraps the downstream app in an anyio task
    group, which decouples the downstream coroutine from the caller's event
    loop. In async DB test setups that reuse a session-scoped asyncpg pool,
    that decoupling surfaces as "Future attached to a different loop" errors.
    A pure ASGI middleware runs inline and avoids the extra task.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = _header(scope, b"x-request-id") or str(uuid.uuid4())
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        state: dict[str, Any] = scope.setdefault("state", {})
        state["request_id"] = request_id

        start = time.perf_counter()
        status_code = 500

        async def send_wrapper(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                headers = list(message.get("headers") or [])
                headers.append((b"x-request-id", request_id.encode("latin-1")))
                message = {**message, "headers": headers}
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception:
            log.exception(
                "request.unhandled",
                path=scope.get("path"),
                method=scope.get("method"),
            )
            raise
        finally:
            duration_ms = int((time.perf_counter() - start) * 1000)
            log.info(
                "request.done",
                method=scope.get("method"),
                path=scope.get("path"),
                status=status_code,
                duration_ms=duration_ms,
            )


def _header(scope: Scope, name: bytes) -> str | None:
    for key, value in scope.get("headers") or ():
        if key == name:
            return value.decode("latin-1")
    return None
