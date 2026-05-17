// Sentry init for the admin Next.js runtime. Mirrors the backend
// pattern: no-op when `SENTRY_DSN` is unset (default everywhere
// except operators who flip it on in staging/prod env vars), so
// the SDK ships in the bundle but contributes zero runtime
// overhead until activated.
//
// Per CLAUDE.md §15 Sentry is "deferred until a real provider is
// chosen" — this module exists so flipping it on later is one
// env-var change on the VM, not a code change + rebuild.

import * as Sentry from "@sentry/nextjs";

let initialised = false;

export function initSentry(): boolean {
  if (initialised) return true;
  const dsn = (process.env.SENTRY_DSN ?? "").trim();
  if (!dsn) return false;

  const env = process.env.APP_ENV ?? "development";
  // Same staircase as the backend: don't sample dev (would noise
  // a personal DSN), gradually sample staging + prod.
  const defaultRate = env === "production" ? 0.05 : env === "staging" ? 0.1 : 0;
  const rateOverride = Number(process.env.SENTRY_TRACES_SAMPLE_RATE);
  const tracesSampleRate = Number.isFinite(rateOverride)
    ? rateOverride
    : defaultRate;

  Sentry.init({
    dsn,
    environment: env,
    release: process.env.APP_RELEASE ?? "gympass-admin@0.1.0",
    tracesSampleRate,
    // PII off by default — admin handles real user emails.
    sendDefaultPii: false,
    // Match the backend's logging integration semantics: warnings
    // are breadcrumbs, errors are events.
    ignoreErrors: [
      // NextAuth bubbles a benign CredentialsSignin on bad password.
      // Don't flood the dashboard with these — they're user error,
      // not app error.
      /CredentialsSignin/,
    ],
  });
  initialised = true;
  return true;
}
