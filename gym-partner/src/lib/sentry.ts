// Sentry init for the gym-partner Next.js runtime. Same pattern
// as admin/lib/sentry.ts — no-op when `SENTRY_DSN` is unset, so
// the SDK ships baked-in and operators flip it on later via env
// var. Per CLAUDE.md §15 Sentry is deferred until a real provider
// is chosen.

import * as Sentry from "@sentry/nextjs";

let initialised = false;

export function initSentry(): boolean {
  if (initialised) return true;
  const dsn = (process.env.SENTRY_DSN ?? "").trim();
  if (!dsn) return false;

  const env = process.env.APP_ENV ?? "development";
  const defaultRate = env === "production" ? 0.05 : env === "staging" ? 0.1 : 0;
  const rateOverride = Number(process.env.SENTRY_TRACES_SAMPLE_RATE);
  const tracesSampleRate = Number.isFinite(rateOverride)
    ? rateOverride
    : defaultRate;

  Sentry.init({
    dsn,
    environment: env,
    release: process.env.APP_RELEASE ?? "gympass-partner@0.1.0",
    tracesSampleRate,
    sendDefaultPii: false,
    ignoreErrors: [/CredentialsSignin/],
  });
  initialised = true;
  return true;
}
