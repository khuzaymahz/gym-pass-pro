"""
Realtime fan-out layer.

A single thin abstraction over Redis pub/sub so any service that
mutates state can `await publish("gym/<id>", {...})` and every
connected member / partner / admin currently subscribed to that
channel sees the event within a frame. The WebSocket endpoint
(`app/api/v1/realtime.py`) is the only consumer of `subscribe`;
publish is called from service-layer mutations.

Channel naming convention (kept opaque to callers — events are
opaque JSON payloads, the channel string is the routing key):

    gym/<gym_id>            metadata changes (name, area, hours,
                            logo url, photos list version)
    gym/<gym_id>/photos     photo list mutated (add / delete)
    gym/<gym_id>/checkins   new check-in scanned at this gym
    user/<user_id>          subscription/billing/payment events
                            specific to a member
    partner/<gym_id>        partner-only fan-out (mirrors
                            `gym/<id>` plus partner-only events
                            like payouts; partners listen here
                            instead of `user/<their_user_id>` so
                            the event shape is consistent)

Any service that mutates a gym, a photo, a logo, a subscription, a
check-in, or a payout MUST call `publish(...)` in the same
transaction-bounded block (after the commit, before the response).
Missing a publish leaves the realtime view stale until the next
manual refetch — the test for "did I wire it" is "does the change
show up in another browser tab without refresh".

Failure mode: Redis down → publish swallows the error and logs.
The mutation already succeeded in Postgres; we never want a flaky
pub/sub layer to fail an HTTP write. Subscribers will reconnect
when Redis recovers and pick up future events.
"""

from __future__ import annotations

import json
import logging
from typing import Any, AsyncIterator

from app.core.redis_client import get_redis

log = logging.getLogger(__name__)


async def publish(channel: str, event: dict[str, Any]) -> None:
    """Push an event onto a Redis pub/sub channel. Best-effort —
    Redis hiccups must not fail the surrounding HTTP write."""
    try:
        redis = get_redis()
        payload = json.dumps({"channel": channel, **event})
        await redis.publish(channel, payload)
    except Exception as exc:  # noqa: BLE001
        # Surfacing in logs is fine; raising would unwind the
        # caller's commit.
        log.warning("realtime.publish failed channel=%s err=%s", channel, exc)


async def subscribe(channels: list[str]) -> AsyncIterator[dict[str, Any]]:
    """Listen on `channels`, yield decoded JSON events as they
    arrive. Caller is responsible for cancelling the iterator
    (typically via async context exit) — Redis subscriptions hold
    one connection from the pool until cancelled.

    Yields a dict shaped `{"channel": "...", "type": "...", ...}`
    matching what `publish` sends.
    """
    redis = get_redis()
    pubsub = redis.pubsub()
    await pubsub.subscribe(*channels)
    try:
        async for raw in pubsub.listen():
            # `listen` returns the underlying redis-py message
            # frames: subscribe/unsubscribe/message. We only care
            # about `message`.
            if raw.get("type") != "message":
                continue
            data = raw.get("data")
            if not isinstance(data, (str, bytes)):
                continue
            try:
                yield json.loads(data)
            except json.JSONDecodeError:
                # Bad publisher — skip rather than break the
                # whole subscriber.
                continue
    finally:
        try:
            await pubsub.unsubscribe(*channels)
            await pubsub.close()
        except Exception:  # noqa: BLE001
            pass
