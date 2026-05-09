import { z } from "zod";

// **Client-safe env.** Only validates values that are legitimately
// exposed to the browser bundle — the API base URL the browser
// fetches images / SSE / WS from. Anything secret (NextAuth, HMAC
// keys) lives in `lib/env.server.ts` so an accidental import from a
// Client Component fails at build time, not at runtime in the
// browser as a crashed Zod parse.
//
// Reading order in dev: `process.env.NEXT_PUBLIC_API_URL` is set by
// docker-compose; the next two fallbacks cover devs running outside
// docker (`API_BASE_URL` from `.env`, then a sane localhost default
// so tests / Storybook never crash on a missing var).
const schema = z.object({
  PUBLIC_API_URL: z.string().url().default("http://localhost:8000"),
});

export const env = schema.parse({
  PUBLIC_API_URL:
    process.env.NEXT_PUBLIC_API_URL ??
    process.env.API_BASE_URL ??
    "http://localhost:8000",
});
