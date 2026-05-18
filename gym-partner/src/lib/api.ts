import "server-only";

import { redirect } from "next/navigation";

import { serverEnv } from "@/lib/env.server";

// Web Crypto API — works identically in Node 20+ and the browser, no
// `node:crypto` import. The previous `import { createHmac, randomBytes
// } from "node:crypto"` blew up the production webpack bundle with
// `UnhandledSchemeError: Reading from "node:crypto" is not handled by
// plugins` because the module graph reaches `api.ts` via paths that
// webpack treats as client-bundled. Web Crypto sidesteps the
// `node:` scheme entirely.
const cryptoApi: Crypto =
  typeof globalThis !== "undefined" && globalThis.crypto
    ? globalThis.crypto
    : (() => {
        throw new Error("Web Crypto API not available in this runtime");
      })();

function bytesToHex(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, "0");
  }
  return out;
}

async function hmacSha256Hex(secret: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await cryptoApi.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await cryptoApi.subtle.sign(
    "HMAC",
    key,
    encoder.encode(data),
  );
  return bytesToHex(new Uint8Array(sig));
}

export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number,
    public details?: unknown,
  ) {
    super(message);
  }
}

/// Thrown when the request couldn't reach the backend at all — DNS
/// failure, connection refused, request aborted by our own timeout,
/// or the runtime's `fetch` throwing `TypeError("fetch failed")`.
/// Distinct from [ApiError] because the error.tsx boundary renders
/// it as "check your connection" instead of generic "something went
/// wrong".
export class NetworkError extends Error {
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = "NetworkError";
  }
}

/// Backend codes that mean "the partner's session is no longer valid".
/// We redirect to /login on these instead of bubbling a 500 — the gym
/// owner sees a clean "please sign in again" surface, not a stack
/// trace. Distinct from generic 5xx errors (which `error.tsx` catches
/// and presents as "something went wrong, retry").
const SESSION_EXPIRED_CODES = new Set([
  "AUTH_TOKEN_EXPIRED",
  "AUTH_TOKEN_INVALID",
  "AUTH_UNAUTHORIZED",
]);

/// HTTP methods we can safely retry. POST is excluded because the
/// backend would happily create two ban rows / two payouts / two
/// password resets if a slow 502 lured us into a second attempt.
const IDEMPOTENT_METHODS = new Set(["GET", "HEAD", "OPTIONS", "DELETE"]);

const TRANSIENT_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

type Init = RequestInit & {
  token?: string;
  /** When true, suppress the auto-redirect on session-expired errors
   *  and just throw `ApiError` like any other failure. Use this on
   *  paths where we want to render a custom auth-failure surface
   *  (e.g. NextAuth's `authorize()` callback already handles auth by
   *  returning null, so it doesn't want a redirect underneath). */
  bypassAuthRedirect?: boolean;
  /** Per-request timeout in ms. Default 15s. */
  timeoutMs?: number;
  /** Set to 0 to disable retries. Default 1 retry on transient
   *  errors for safe methods only. */
  maxRetries?: number;
};

export async function api<T>(path: string, init: Init = {}): Promise<T> {
  const {
    token,
    headers,
    bypassAuthRedirect,
    timeoutMs = 15_000,
    maxRetries = 1,
    ...rest
  } = init;
  const method = (rest.method ?? "GET").toUpperCase();
  const canRetry = IDEMPOTENT_METHODS.has(method);
  const attempts = canRetry ? maxRetries + 1 : 1;

  let lastError: unknown;
  for (let attempt = 0; attempt < attempts; attempt++) {
    if (attempt > 0) {
      const jitter = 100 * (Math.random() * 2 - 1);
      await new Promise((r) => setTimeout(r, 500 + jitter));
    }

    const controller = new AbortController();
    const abortTimer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(`${serverEnv.API_BASE_URL}${path}`, {
        ...rest,
        headers: {
          "content-type": "application/json",
          ...(token ? { authorization: `Bearer ${token}` } : {}),
          ...headers,
        },
        cache: "no-store",
        signal: controller.signal,
      });

      if (response.status === 204) {
        return undefined as T;
      }

      const body = await response.json().catch(() => ({}));
      if (!response.ok) {
        const err = body?.error;
        const code = (err?.code ?? "UNKNOWN") as string;

        // Server-side redirect on a stale partner session. Throws the
        // special NEXT_REDIRECT signal that Next.js catches at the
        // server-component boundary, navigating the browser to /login
        // with a flag the login page picks up to show a "session
        // expired, sign in again" banner.
        if (
          !bypassAuthRedirect &&
          response.status === 401 &&
          SESSION_EXPIRED_CODES.has(code)
        ) {
          redirect("/login?reason=session_expired");
        }

        if (canRetry && TRANSIENT_STATUS.has(response.status) && attempt < attempts - 1) {
          lastError = new ApiError(
            code,
            err?.message ?? response.statusText,
            response.status,
            err?.details,
          );
          continue;
        }

        throw new ApiError(
          code,
          err?.message ?? response.statusText,
          response.status,
          err?.details,
        );
      }
      return body as T;
    } catch (fetchErr) {
      // AbortError (timeout) and TypeError ("fetch failed") are both
      // "we never got an HTTP response" failures. Treat uniformly as
      // NetworkError. Retry once for idempotent methods.
      const isAbort =
        fetchErr instanceof DOMException && fetchErr.name === "AbortError";
      const isTypeError = fetchErr instanceof TypeError;
      if (isAbort || isTypeError) {
        lastError = new NetworkError(
          isAbort ? "Request timed out" : "Network request failed",
          fetchErr,
        );
        if (canRetry && attempt < attempts - 1) continue;
        throw lastError;
      }
      // ApiError + NEXT_REDIRECT signal + anything else bubbles
      // unchanged.
      throw fetchErr;
    } finally {
      clearTimeout(abortTimer);
    }
  }
  throw lastError ?? new NetworkError("Request failed without diagnosis");
}

export async function exchangePartnerToken(phone: string): Promise<{
  token: string;
  expiresAt: string;
}> {
  // Same HMAC envelope as the admin app — phone is the partner's
  // identifier (gym-owners may not have an email on file). Backend
  // verifies signature + skew + nonce single-use before minting.
  const signedAt = Math.floor(Date.now() / 1000);
  const nonce = bytesToHex(cryptoApi.getRandomValues(new Uint8Array(16)));
  const signature = await hmacSha256Hex(
    serverEnv.ADMIN_EXCHANGE_SECRET,
    `${phone}|${nonce}|${signedAt}`,
  );
  return api("/api/v1/auth/partner/exchange", {
    method: "POST",
    body: JSON.stringify({ phone, signedAt, nonce, signature }),
    // The exchange call runs from inside the NextAuth jwt callback
    // when refreshing a soon-to-expire service token. A 401 here
    // means the HMAC envelope was rejected (rare — usually means
    // env mismatch, not a stale session); the jwt callback's own
    // catch falls back to the stale token, and the next data call
    // surfaces the failure to the user. Either way, we don't want
    // a redirect firing from inside the JWT lifecycle hook —
    // that's a recipe for redirect loops.
    bypassAuthRedirect: true,
  });
}
