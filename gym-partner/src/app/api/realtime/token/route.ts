import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";

import { authOptions } from "@/lib/auth";
import { env } from "@/lib/env";

/// Hands the *current* service token to the browser so it can open
/// a WebSocket against the backend's `/api/v1/realtime/ws` endpoint.
/// The token only lives on the server (NextAuth JWT callback owns
/// refresh), so the client has to ask each time it (re)connects.
///
/// Also returns the channel set the partner is allowed to subscribe
/// to — the backend re-checks scope on the WS auth frame, but
/// computing the list here avoids a round-trip and keeps the client
/// dumb. A partner sees their own gym's channels and nothing else;
/// admin scope is not exposed here (admin uses its own portal).
///
/// Failure modes:
/// - No live session   → 401, client retries after re-login.
/// - Session has no gymId → 401 (shouldn't happen post-bootstrap; if
///   it does the partner record is broken and any answer would be
///   misleading).
export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.serviceToken || !session?.gymId) {
    return NextResponse.json({ error: "no_session" }, { status: 401 });
  }
  // Build the WS URL from the browser-facing public API URL — the
  // server-side `API_BASE_URL` is `http://backend:8000` inside Docker
  // and unreachable from the browser. Use the URL constructor so
  // ports, paths, and IPv6 hosts round-trip correctly; a string-slice
  // approach silently corrupts hosts like `[::1]:8000` and any URL
  // that doesn't start with the exact `http://` / `https://` prefix.
  let wsUrl: string;
  try {
    const apiUrl = new URL(env.PUBLIC_API_URL);
    if (apiUrl.protocol !== "http:" && apiUrl.protocol !== "https:") {
      // Anything other than http(s) means a misconfigured deploy
      // (e.g. someone set ws://… directly). Refuse rather than emit
      // a frankenstein URL the browser will reject anyway.
      return NextResponse.json(
        { error: "invalid_public_api_url" },
        { status: 500 },
      );
    }
    apiUrl.protocol = apiUrl.protocol === "https:" ? "wss:" : "ws:";
    apiUrl.pathname = apiUrl.pathname.replace(/\/$/, "") + "/api/v1/realtime/ws";
    apiUrl.search = "";
    apiUrl.hash = "";
    wsUrl = apiUrl.toString();
  } catch {
    return NextResponse.json(
      { error: "invalid_public_api_url" },
      { status: 500 },
    );
  }
  const gymId = session.gymId;
  const channels = [
    `gym/${gymId}`,
    `gym/${gymId}/photos`,
    `gym/${gymId}/checkins`,
    `partner/${session.partnerId}`,
  ];
  return NextResponse.json({
    token: session.serviceToken,
    wsUrl,
    channels,
  });
}
