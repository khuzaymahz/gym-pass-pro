import { z } from "zod";

const schema = z.object({
  API_BASE_URL: z.string().url().default("http://localhost:8000"),
  NEXTAUTH_SECRET: z.string().min(16),
  NEXTAUTH_URL: z.string().url().default("http://localhost:3001"),
  ADMIN_BOOTSTRAP_EMAIL: z.string().email().optional(),
  ADMIN_BOOTSTRAP_PASSWORD: z.string().min(8).optional(),
  // Shared HMAC secret for the NextAuth → FastAPI exchange. The
  // backend recomputes the HMAC and rejects mismatched signatures,
  // so this MUST match `ADMIN_EXCHANGE_SECRET` in the backend env
  // exactly. Dev sentinel is only valid in development.
  ADMIN_EXCHANGE_SECRET: z.string().min(16),
});

export const env = schema.parse({
  API_BASE_URL: process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL,
  NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET ?? "change-me-in-dev-only-please",
  NEXTAUTH_URL: process.env.NEXTAUTH_URL,
  ADMIN_BOOTSTRAP_EMAIL: process.env.ADMIN_BOOTSTRAP_EMAIL,
  ADMIN_BOOTSTRAP_PASSWORD: process.env.ADMIN_BOOTSTRAP_PASSWORD,
  ADMIN_EXCHANGE_SECRET:
    process.env.ADMIN_EXCHANGE_SECRET ?? "changeme-admin-exchange-secret",
});
