import { z } from "zod";

// Schema is the single source of truth. Required secrets have NO
// in-code fallback — Zod's `.min(16)` will fail-fast with a clear
// error if the env var is unset, instead of silently parsing a
// hardcoded sentinel that ships to production. Dev defaults live in
// `.env.example` and `docker-compose.yml`, NOT here.
const schema = z.object({
  API_BASE_URL: z.string().url().default("http://localhost:8000"),
  NEXTAUTH_SECRET: z
    .string({
      required_error:
        "NEXTAUTH_SECRET is required. Generate one with `openssl rand -base64 32` and set it in .env.",
    })
    .min(
      16,
      "NEXTAUTH_SECRET must be at least 16 characters. Generate with `openssl rand -base64 32`.",
    ),
  NEXTAUTH_URL: z.string().url().default("http://localhost:3001"),
  ADMIN_BOOTSTRAP_EMAIL: z.string().email().optional(),
  ADMIN_BOOTSTRAP_PASSWORD: z.string().min(8).optional(),
  // Shared HMAC secret for the NextAuth → FastAPI exchange. The
  // backend recomputes the HMAC and rejects mismatched signatures,
  // so this MUST match `ADMIN_EXCHANGE_SECRET` in the backend env
  // exactly. No in-code default — set it explicitly.
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

export const env = schema.parse({
  API_BASE_URL: process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL,
  NEXTAUTH_SECRET: process.env.NEXTAUTH_SECRET,
  NEXTAUTH_URL: process.env.NEXTAUTH_URL,
  ADMIN_BOOTSTRAP_EMAIL: process.env.ADMIN_BOOTSTRAP_EMAIL,
  ADMIN_BOOTSTRAP_PASSWORD: process.env.ADMIN_BOOTSTRAP_PASSWORD,
  ADMIN_EXCHANGE_SECRET: process.env.ADMIN_EXCHANGE_SECRET,
});
