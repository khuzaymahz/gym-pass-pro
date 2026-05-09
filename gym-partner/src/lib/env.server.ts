import "server-only";

import { z } from "zod";

// **Server-only env.** Validates the secrets that must never reach
// the browser bundle (NextAuth signing key, the HMAC shared with
// FastAPI for the partner-exchange envelope) plus server-side URLs
// like `API_BASE_URL` (`http://backend:8000` inside docker — not
// reachable from the browser). The `import "server-only"` directive
// at the top of this file makes Next.js refuse to bundle it into
// any Client Component; if an accidental import shows up, the
// build fails with a clear message instead of crashing in the
// browser.
//
// Required secrets have NO in-code fallback — Zod's `.min(16)` will
// fail-fast with a clear error if the env var is unset, instead of
// silently parsing a hardcoded sentinel that ships to production.
// Dev defaults live in `.env` / `docker-compose.yml`, NOT here.
const schema = z.object({
  // Server-side base URL — used by Server Components / Server
  // Actions to talk to the backend. Inside docker this is
  // `http://backend:8000` (service name) which is unreachable from
  // the browser; the browser uses `PUBLIC_API_URL` from the
  // client-safe `env.ts` instead.
  API_BASE_URL: z.string().url().default("http://localhost:8000"),
  NEXTAUTH_SECRET: z
    .string({
      required_error:
        "NEXTAUTH_SECRET is required. Generate with `openssl rand -base64 32` and set it in .env.",
    })
    .min(
      16,
      "NEXTAUTH_SECRET must be at least 16 characters. Generate with `openssl rand -base64 32`.",
    ),
  NEXTAUTH_URL: z.string().url().default("http://localhost:3003"),
  // Shared HMAC secret for the NextAuth → FastAPI partner exchange.
  // Backend recomputes the HMAC and rejects mismatched signatures,
  // so this MUST match `ADMIN_EXCHANGE_SECRET` in the backend env
  // exactly (the partner endpoint reuses the same shared secret —
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

export const serverEnv = schema.parse({
  API_BASE_URL: process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL,
  NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET,
  NEXTAUTH_URL: process.env.NEXTAUTH_URL,
  ADMIN_EXCHANGE_SECRET: process.env.ADMIN_EXCHANGE_SECRET,
});
