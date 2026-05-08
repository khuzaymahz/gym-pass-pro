/**
 * Client-safe media URL resolver.
 *
 * Backend stores upload paths as `/media/<bucket>/<gym>/<file>` —
 * relative to the FastAPI host. When rendered inside an `<img>` at
 * the partner portal origin (`:3003`), the browser would otherwise
 * request `localhost:3003/media/...` and 404. This helper prepends
 * the *public* API URL so the browser references the backend's
 * media route directly.
 *
 * Absolute URLs (the seeded Unsplash photos, or any external CDN)
 * pass through unchanged.
 *
 * **Why a separate module from `env.ts`:** `env.ts` reads server-only
 * secrets (`NEXTAUTH_SECRET`, `ADMIN_EXCHANGE_SECRET`) and parses
 * them through zod at module-init. Importing `env.ts` from a
 * `"use client"` component crashes the bundle because those
 * secrets aren't exposed to the browser. This file reads only the
 * `NEXT_PUBLIC_*` prefix that Next.js explicitly exposes
 * client-side, so it's safe to import from any component.
 */
const PUBLIC_API_URL =
  (typeof process !== "undefined" && process.env.NEXT_PUBLIC_API_URL) ||
  "http://localhost:8000";

export function resolveMediaUrl(url: string | null | undefined): string {
  if (!url) return "";
  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  const base = PUBLIC_API_URL.replace(/\/$/, "");
  return `${base}${url.startsWith("/") ? "" : "/"}${url}`;
}
