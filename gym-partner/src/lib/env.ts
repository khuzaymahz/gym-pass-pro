import { z } from "zod";

// Schema is the single source of truth. Required secrets have NO
// in-code fallback — Zod's `.min(16)` will fail-fast with a clear
// error if the env var is unset, instead of silently parsing a
// hardcoded sentinel that ships to production. Dev defaults live in
// `.env.example` and `docker-compose.yml`, NOT here.
const schema = z.object({
  // Server-side base URL — used by server components / actions to
  // talk to the backend. Inside Docker this is `http://backend:8000`
  // (service name) which is unreachable from the browser, so we
  // can't reuse it for `<img src>`.
  API_BASE_URL: z.string().url().default("http://localhost:8000"),
  // Browser-facing base URL — used to resolve media URLs that the
  // browser will fetch directly (gym photos, logos). In dev this is
  // `http://localhost:8000`; in prod it's whatever public hostname
  // serves the FastAPI media route. When unset, falls back to
  // API_BASE_URL so single-host setups still work.
  PUBLIC_API_URL: z.string().url().default("http://localhost:8000"),
  NEXTAUTH_SECRET: z
    .string({
      required_error:
        "NEXTAUTH_SECRET is required. Generate one with `openssl rand -base64 32` and set it in .env.",
    })
    .min(
      16,
      "NEXTAUTH_SECRET must be at least 16 characters. Generate with `openssl rand -base64 32`.",
    ),
  NEXTAUTH_URL: z.string().url().default("http://localhost:3003"),
  // Shared HMAC secret for the NextAuth → FastAPI partner exchange.
  // Backend recomputes the HMAC and rejects mismatched signatures, so
  // this MUST match `ADMIN_EXCHANGE_SECRET` in the backend env exactly
  // (the partner endpoint reuses the same shared secret because the
  // skew/replay machinery is identical to admin's).
  ADMIN_EXCHANGE_SECRET: z
    .string({
      required_error:
        "ADMIN_EXCHANGE_SECRET is required. Must match backend env exactly. Generate with `openssl rand -hex 32`.",
    })
    .min(
      16,
      "ADMIN_EXCHANGE_SECRET must be at least 16 characters. Must match backend env exactly.",
    ),
});

// Both `NEXTAUTH_SECRET` and `ADMIN_EXCHANGE_SECRET` are deliberately
// passed through *without* a code-level fallback. A code default would
// silently let a misconfigured deploy boot with a known-public secret
// — which means anyone can mint partner-exchange envelopes or forge
// session JWTs. Failing fast at module-init via `z.string().min(16)` is
// the correct behaviour: the dev fallbacks belong in `.env` /
// `docker-compose.yml`, never here.
export const env = schema.parse({
  API_BASE_URL: process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL,
  PUBLIC_API_URL:
    process.env.NEXT_PUBLIC_API_URL ??
    process.env.API_BASE_URL ??
    "http://localhost:8000",
  NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET,
  NEXTAUTH_URL: process.env.NEXTAUTH_URL,
  ADMIN_EXCHANGE_SECRET: process.env.ADMIN_EXCHANGE_SECRET,
});

