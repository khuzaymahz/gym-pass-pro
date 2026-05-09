import { redirect } from "next/navigation";

import { env } from "@/lib/env";

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

type Init = RequestInit & {
  token?: string;
  /** When true, suppress the auto-redirect on session-expired errors
   *  and just throw `ApiError` like any other failure. Use this on
   *  paths where we want to render a custom auth-failure surface
   *  (e.g. NextAuth's `authorize()` callback already handles auth by
   *  returning null, so it doesn't want a redirect underneath). */
  bypassAuthRedirect?: boolean;
};

export async function api<T>(path: string, init: Init = {}): Promise<T> {
  const { token, headers, bypassAuthRedirect, ...rest } = init;
  const response = await fetch(`${env.API_BASE_URL}${path}`, {
    ...rest,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    cache: "no-store",
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
    // expired, sign in again" banner. Cleaner than a 500 page and
    // also cleaner than re-throwing a typed error every page would
    // otherwise have to remember to handle.
    if (
      !bypassAuthRedirect &&
      response.status === 401 &&
      SESSION_EXPIRED_CODES.has(code)
    ) {
      redirect("/login?reason=session_expired");
    }

    throw new ApiError(
      code,
      err?.message ?? response.statusText,
      response.status,
      err?.details,
    );
  }
  return body as T;
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
    env.ADMIN_EXCHANGE_SECRET,
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
