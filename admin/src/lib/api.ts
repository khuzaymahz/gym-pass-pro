import { env } from "@/lib/env";

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

type Init = RequestInit & { token?: string };

export async function api<T>(path: string, init: Init = {}): Promise<T> {
  const { token, headers, ...rest } = init;
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
    throw new ApiError(
      err?.code ?? "UNKNOWN",
      err?.message ?? response.statusText,
      response.status,
      err?.details,
    );
  }
  return body as T;
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
    env.ADMIN_EXCHANGE_SECRET,
    `${email}|${nonce}|${signedAt}`,
  );
  return api("/api/v1/auth/admin/exchange", {
    method: "POST",
    body: JSON.stringify({ email, signedAt, nonce, signature }),
  });
}
