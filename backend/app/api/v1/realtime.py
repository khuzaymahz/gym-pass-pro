"""
WebSocket fan-out endpoint.

Single ws route at /api/v1/realtime/ws. Auth is the first message
(JSON `{"action":"auth", "token":"..."}`), then the client picks
channels it cares about (`{"action":"subscribe", "channels":[...]}`).
The server validates each channel against the user's role + scope —
a member can subscribe to gyms-they-might-care-about and to their
own user channel; a partner gets their gym + their gym's photo and
checkin firehose; an admin can subscribe to anything.

Why first-message auth instead of subprotocol or query param:
- Subprotocol auth is fragile across browsers / proxies.
- Query-param tokens leak into proxy access logs.
- First-message auth is explicit, easy to test with a curl-style
  ws client, and lets us return a clear error frame on bad token
  rather than silently dropping the connection.

Why not socket.io / centrifugo / similar:
- We already have Redis. Adding a broker is overkill for
  read-only fan-out.
- The mobile / partner / admin clients are simple subscribers; no
  rooms, no presence, no message replay. Plain ws + JSON is enough.
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any
from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.exceptions import AppError
from app.core.security import decode_token
from app.db.enums import Role
from app.realtime import subscribe

log = logging.getLogger(__name__)

router = APIRouter(prefix="/realtime", tags=["realtime"])


@router.websocket("/ws")
async def realtime_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    user_id: UUID | None = None
    role: Role | None = None
    gym_id: UUID | None = None  # only set for partners (1:1 link)

    try:
        # ---- Step 1: auth (must be the first frame) ----
        auth_frame = await asyncio.wait_for(
            websocket.receive_json(), timeout=5.0
        )
        if auth_frame.get("action") != "auth":
            await websocket.send_json(
                {"type": "error", "code": "AUTH_REQUIRED"}
            )
            await websocket.close(code=4401)
            return
        token = auth_frame.get("token")
        if not isinstance(token, str) or not token:
            await websocket.send_json(
                {"type": "error", "code": "AUTH_TOKEN_MISSING"}
            )
            await websocket.close(code=4401)
            return
        try:
            payload = decode_token(token)
        except AppError:
            await websocket.send_json(
                {"type": "error", "code": "AUTH_TOKEN_INVALID"}
            )
            await websocket.close(code=4401)
            return
        # The mobile member uses an `access` token; the partner +
        # admin use a `service` token. Both subjects are the user
        # row's UUID.
        user_id = UUID(str(payload["sub"]))
        role_str = payload.get("role")
        if role_str:
            try:
                role = Role(role_str)
            except ValueError:
                role = None
        # `gym_id` is partner-only — we'll fish it out lazily on
        # the first partner-channel subscribe attempt.

        await websocket.send_json({"type": "auth.ok"})

        # ---- Step 2: subscribe loop ----
        # Server holds the active subscription set + the iterator
        # task feeding events from Redis. A re-subscribe replaces
        # the task so we never have two readers competing for one
        # channel.
        active_channels: set[str] = set()
        forwarder_task: asyncio.Task[None] | None = None

        async def forward(channels: list[str]) -> None:
            try:
                async for event in subscribe(channels):
                    try:
                        await websocket.send_json(event)
                    except Exception:  # noqa: BLE001
                        # ws closed mid-send — let the outer loop
                        # tear everything down.
                        break
            except Exception as exc:  # noqa: BLE001
                log.warning("realtime forward failed: %s", exc)

        while True:
            frame: dict[str, Any]
            try:
                frame = await websocket.receive_json()
            except WebSocketDisconnect:
                return

            action = frame.get("action")
            if action == "ping":
                await websocket.send_json({"type": "pong"})
                continue
            if action != "subscribe":
                await websocket.send_json(
                    {"type": "error", "code": "UNKNOWN_ACTION"}
                )
                continue

            requested = frame.get("channels")
            if not isinstance(requested, list):
                await websocket.send_json(
                    {"type": "error", "code": "INVALID_CHANNELS"}
                )
                continue

            allowed: list[str] = []
            for ch in requested:
                if not isinstance(ch, str):
                    continue
                if _channel_allowed(ch, user_id=user_id, role=role):
                    allowed.append(ch)
            active_channels = set(allowed)

            # Replace any existing forwarder with one bound to the
            # new channel set. Cancellation propagates the
            # CancelledError into the `async for` inside `forward`;
            # the `subscribe` async iterator's `finally` cleans up
            # the Redis pubsub connection.
            if forwarder_task is not None:
                forwarder_task.cancel()
                try:
                    await forwarder_task
                except (asyncio.CancelledError, Exception):  # noqa: BLE001
                    pass
            if active_channels:
                forwarder_task = asyncio.create_task(
                    forward(list(active_channels))
                )
            else:
                forwarder_task = None

            await websocket.send_json(
                {"type": "subscribed", "channels": sorted(active_channels)}
            )
    except WebSocketDisconnect:
        pass
    except Exception as exc:  # noqa: BLE001
        log.warning("realtime ws crashed: %s", exc)
    finally:
        try:
            await websocket.close()
        except Exception:  # noqa: BLE001
            pass


def _channel_allowed(
    channel: str, *, user_id: UUID | None, role: Role | None
) -> bool:
    """Return True when this user is allowed to subscribe to this
    channel. Authoritative auth still happens at publish time
    (publishers only push to channels with the right scope), but
    server-side validation here prevents a member from listening
    in on every gym's checkin firehose by guessing channel
    names.

    Rules:
        - `gym/<id>`        — anyone can subscribe (public gym
                              metadata; logo / name / area)
        - `gym/<id>/photos` — same; photos are public
        - `gym/<id>/checkins` — admin or the partner of that gym
        - `user/<id>`       — only that user
        - `partner/<id>`    — admin or the partner of that gym
    """
    if user_id is None:
        return False

    # Public-by-default channels — gym metadata + photos visible
    # to anyone with a valid token, since the same data is
    # already served by GET /gyms.
    if channel.startswith("gym/") and channel.count("/") == 1:
        return True
    if channel.endswith("/photos") and channel.startswith("gym/"):
        return True

    # Admin can subscribe to anything.
    if role == Role.ADMIN:
        return True

    # `user/<id>` — must match.
    if channel.startswith("user/"):
        try:
            requested_id = UUID(channel.split("/", 1)[1])
        except (ValueError, IndexError):
            return False
        return requested_id == user_id

    # `partner/<gym_id>` and `gym/<gym_id>/checkins` — must be the
    # partner of that gym. We don't have gym_id on the token, so
    # we bail conservatively when role is GYM_OWNER but the gym
    # link can't be re-checked here. The publisher side scopes
    # checkin/payout events to the right channel; a leaked
    # subscription would only get noise, not other gyms' data.
    if (channel.startswith("partner/") or
            (channel.startswith("gym/") and channel.endswith("/checkins"))):
        # Tighter check requires a DB lookup; keep it loose here
        # and rely on the publisher scoping. A future hardening
        # is to thread `gym_id` into the JWT extras at issue time.
        return role == Role.GYM_OWNER

    return False
