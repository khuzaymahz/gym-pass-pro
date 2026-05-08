"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef } from "react";

/// Mounted once at the dashboard shell, this opens a WebSocket to
/// the backend's `/api/v1/realtime/ws` endpoint and calls
/// `router.refresh()` on every event the partner is subscribed to.
/// `router.refresh()` re-runs the matching server components without
/// a full page reload, so any server-rendered data on the page (gym
/// profile, photos, recent check-ins) re-fetches from the backend
/// and the partner sees the change without doing anything.
///
/// The component is deliberately stateless from the React side —
/// the WS pump owns the lifecycle entirely, and React just hosts
/// it. Reconnect, backoff, and re-auth on token rotation all happen
/// inside the effect.
///
/// Auth model: the service token is server-only (lives in the
/// NextAuth JWT). The browser fetches it from `/api/realtime/token`
/// on every (re)connect so a refreshed token after the 5-min hop
/// expiry is picked up automatically.
export function RealtimeBridge() {
  const router = useRouter();
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pingTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const stoppedRef = useRef(false);
  const backoffMsRef = useRef(1000);
  // Coalesce bursts of events into a single router.refresh — the
  // server-render cycle is expensive enough that hammering it on
  // each frame produces a "stuttering" UX. ~250 ms gathers the
  // common patterns (a partner uploads 3 photos in quick succession,
  // a check-in spike).
  const refreshTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    stoppedRef.current = false;

    const scheduleRefresh = () => {
      if (refreshTimer.current) return;
      refreshTimer.current = setTimeout(() => {
        refreshTimer.current = null;
        router.refresh();
      }, 250);
    };

    const stopPing = () => {
      if (pingTimer.current) {
        clearInterval(pingTimer.current);
        pingTimer.current = null;
      }
    };

    const closeSocket = () => {
      stopPing();
      const ws = wsRef.current;
      wsRef.current = null;
      if (ws) {
        try {
          ws.close();
        } catch {
          /* already closed */
        }
      }
    };

    const scheduleReconnect = () => {
      if (stoppedRef.current) return;
      if (reconnectTimer.current) return;
      const delay = backoffMsRef.current;
      backoffMsRef.current = Math.min(backoffMsRef.current * 2, 30_000);
      reconnectTimer.current = setTimeout(() => {
        reconnectTimer.current = null;
        void connect();
      }, delay);
    };

    const connect = async () => {
      if (stoppedRef.current) return;
      let token: string;
      let wsUrl: string;
      let channels: string[];
      try {
        const resp = await fetch("/api/realtime/token", { cache: "no-store" });
        if (!resp.ok) {
          // 401 means "no live session" — backing off is the right
          // call; the dashboard layout will redirect to /login on the
          // next render anyway.
          scheduleReconnect();
          return;
        }
        const body = (await resp.json()) as {
          token: string;
          wsUrl: string;
          channels: string[];
        };
        token = body.token;
        wsUrl = body.wsUrl;
        channels = body.channels;
      } catch {
        scheduleReconnect();
        return;
      }

      let ws: WebSocket;
      try {
        ws = new WebSocket(wsUrl);
      } catch {
        scheduleReconnect();
        return;
      }
      wsRef.current = ws;

      ws.onopen = () => {
        // Auth must be the first frame — backend closes with 4401 if
        // we send anything else first. The `subscribe` follows
        // immediately; the server replies with `{type:"subscribed"}`
        // which we ignore.
        try {
          ws.send(JSON.stringify({ action: "auth", token }));
          ws.send(JSON.stringify({ action: "subscribe", channels }));
        } catch {
          /* sink already closed; onclose handles reconnect */
        }
        // Reset backoff once we've successfully opened. The server
        // can still tear us down, but a quick reconnect is the right
        // behaviour after a clean handshake.
        backoffMsRef.current = 1000;
        // Idle ping every 25 s — same cadence as the mobile client
        // — so a stuck NAT / proxy doesn't silently kill us.
        stopPing();
        pingTimer.current = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            try {
              ws.send(JSON.stringify({ action: "ping" }));
            } catch {
              /* will reconnect on close */
            }
          }
        }, 25_000);
      };

      ws.onmessage = (msg) => {
        if (typeof msg.data !== "string") return;
        let frame: { channel?: unknown; type?: unknown };
        try {
          frame = JSON.parse(msg.data);
        } catch {
          return;
        }
        // Ignore handshake frames (`auth.ok`, `subscribed`, `pong`).
        // Real events always carry both `channel` and `type`.
        if (typeof frame.channel !== "string" || typeof frame.type !== "string") {
          return;
        }
        scheduleRefresh();
      };

      ws.onerror = () => {
        // onclose will fire too; let it own the reconnect.
      };

      ws.onclose = () => {
        stopPing();
        wsRef.current = null;
        scheduleReconnect();
      };
    };

    void connect();

    return () => {
      stoppedRef.current = true;
      if (reconnectTimer.current) {
        clearTimeout(reconnectTimer.current);
        reconnectTimer.current = null;
      }
      if (refreshTimer.current) {
        clearTimeout(refreshTimer.current);
        refreshTimer.current = null;
      }
      closeSocket();
    };
  }, [router]);

  return null;
}
