import { z } from "zod";

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
  NEXTAUTH_SECRET: z.string().min(16),
  NEXTAUTH_URL: z.string().url().default("http://localhost:3003"),
  // Shared HMAC secret for the NextAuth → FastAPI partner exchange.
  // Backend recomputes the HMAC and rejects mismatched signatures, so
  // this MUST match `ADMIN_EXCHANGE_SECRET` in the backend env exactly
  // (the partner endpoint reuses the same shared secret because the
  // skew/replay machinery is identical to admin's).
  ADMIN_EXCHANGE_SECRET: z.string().min(16),
});

export const env = schema.parse({
  API_BASE_URL: process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL,
  PUBLIC_API_URL:
    process.env.NEXT_PUBLIC_API_URL ??
    process.env.API_BASE_URL ??
    "http://localhost:8000",
  NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET ?? "change-me-in-dev-only-please",
  NEXTAUTH_URL: process.env.NEXTAUTH_URL,
  ADMIN_EXCHANGE_SECRET:
    process.env.ADMIN_EXCHANGE_SECRET ?? "changeme-admin-exchange-secret",
});

