import { createHmac, randomBytes } from "node:crypto";

import { env } from "@/lib/env";

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
  const nonce = randomBytes(16).toString("hex");
  const signature = createHmac("sha256", env.ADMIN_EXCHANGE_SECRET)
    .update(`${email}|${nonce}|${signedAt}`)
    .digest("hex");
  return api("/api/v1/auth/admin/exchange", {
    method: "POST",
    body: JSON.stringify({ email, signedAt, nonce, signature }),
  });
}
