import "server-only";

import { serverEnv } from "@/lib/env.server";

// Web Crypto API — works in both Node 20+ and the browser, no
// `node:crypto` import. The previous `node:`-prefixed import was
// blowing up the production webpack bundle with
// `UnhandledSchemeError: Reading from "node:crypto" is not handled
// by plugins`. Web Crypto sidesteps the `node:` scheme entirely.
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
/// or the runtime's `fetch` throwing a `TypeError("fetch failed")`.
/// Distinct from [ApiError] because the UI / error boundary surfaces
/// it differently: "check your connection" instead of a generic
/// "something went wrong" panel.
export class NetworkError extends Error {
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = "NetworkError";
  }
}

type Init = RequestInit & {
  token?: string;
  /** Per-request timeout in ms. Default 15s — long enough for a
   *  cold-start API container to spin up, short enough that a stuck
   *  upstream doesn't pin a Next.js server worker indefinitely. */
  timeoutMs?: number;
  /** Set to 0 to disable retries. Default 1 retry on transient
   *  errors (5xx / network) for safe methods only. */
  maxRetries?: number;
};

/// HTTP methods we can safely retry without risk of duplicate side
/// effects. POST/PATCH are excluded unless the caller opts in — the
/// backend would happily create two gyms / two ban rows / two payouts
/// if a slow 502 lured us into a second attempt.
const IDEMPOTENT_METHODS = new Set(["GET", "HEAD", "OPTIONS", "DELETE"]);

const TRANSIENT_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

export async function api<T>(path: string, init: Init = {}): Promise<T> {
  const {
    token,
    headers,
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
      // Backoff before the second swing: 500ms with ±20% jitter so
      // we don't synchronize a thundering herd of admin tabs all
      // retrying the same dashboard at once.
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
        // Transient 5xx + 408/429: retry the request once. Anything
        // else is a permanent failure (4xx auth, validation, not
        // found) — surface immediately.
        if (canRetry && TRANSIENT_STATUS.has(response.status) && attempt < attempts - 1) {
          lastError = new ApiError(
            err?.code ?? "UNKNOWN",
            err?.message ?? response.statusText,
            response.status,
            err?.details,
          );
          continue;
        }
        throw new ApiError(
          err?.code ?? "UNKNOWN",
          err?.message ?? response.statusText,
          response.status,
          err?.details,
        );
      }
      return body as T;
    } catch (fetchErr) {
      // AbortError (timeout) and TypeError ("fetch failed" / "Failed
      // to fetch") are both "we never got an HTTP response" failures.
      // Treat them uniformly as NetworkError. Retry once for
      // idempotent methods; bail otherwise so a typed NetworkError
      // surfaces to the caller / error boundary.
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
      // Anything else (including the ApiError we threw above for a
      // non-transient HTTP failure) bubbles up unchanged.
      throw fetchErr;
    } finally {
      clearTimeout(abortTimer);
    }
  }
  // Unreachable in practice — the loop either returns, throws, or
  // continues. Kept as a guard so a future refactor doesn't leak a
  // silent undefined.
  throw lastError ?? new NetworkError("Request failed without diagnosis");
}

export async function exchangeAdminToken(email: string): Promise<{
  token: string;
  expiresAt: string;
}> {
  // Sign the envelope with the shared secret so the backend can
  // verify this request actually came from the admin app and isn't
  // being replayed. Backend rejects on any mismatch.
  const signedAt = Math.floor(Date.now() / 1000);
  const nonce = bytesToHex(cryptoApi.getRandomValues(new Uint8Array(16)));
  const signature = await hmacSha256Hex(
    serverEnv.ADMIN_EXCHANGE_SECRET,
    `${email}|${nonce}|${signedAt}`,
  );
  return api("/api/v1/auth/admin/exchange", {
    method: "POST",
    body: JSON.stringify({ email, signedAt, nonce, signature }),
  });
}
