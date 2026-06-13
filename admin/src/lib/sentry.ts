// Sentry init for the admin Next.js runtime. Mirrors the backend
// pattern: no-op when `SENTRY_DSN` is unset (default everywhere
// except operators who flip it on in staging/prod env vars), so
// the SDK ships in the bundle but contributes zero runtime
// overhead until activated.
//
// Per CLAUDE.md §15 Sentry is "deferred until a real provider is
// chosen" — this module exists so flipping it on later is one
// env-var change on the VM, not a code change + rebuild.
//
// The `@sentry/nextjs` import is dynamic (and wrapped in
// try/catch) because the package isn't yet in `package.json` — the
// Sentry-wiring commit landed before the dependency. A static
// `import * as Sentry from "@sentry/nextjs"` blows up the Next.js
// dev server with a hard 500 on EVERY page render, not just
// instrumentation init. The dynamic guard turns this back into a
// quiet no-op until either the dep is installed or the file is
// removed. Same shape as gym-partner/src/lib/sentry.ts.

let initialised = false;

export async function initSentry(): Promise<boolean> {
  if (initialised) return true;
  const dsn = (process.env.SENTRY_DSN ?? "").trim();
  if (!dsn) return false;

  let Sentry: typeof import("@sentry/nextjs");
  try {
    Sentry = (await import("@sentry/nextjs")) as typeof import("@sentry/nextjs");
  } catch {
    // Package not installed — same outcome as "no DSN". Caller
    // (instrumentation.ts) treats `false` as "Sentry is off".
    return false;
  }

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
