import { z } from "zod";

const schema = z.object({
  API_BASE_URL: z.string().url().default("http://localhost:8000"),
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
  NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET ?? "change-me-in-dev-only-please",
  NEXTAUTH_URL: process.env.NEXTAUTH_URL,
  ADMIN_EXCHANGE_SECRET:
    process.env.ADMIN_EXCHANGE_SECRET ?? "changeme-admin-exchange-secret",
});
