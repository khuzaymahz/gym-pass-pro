// Sentry init for the gym-partner Next.js runtime. Same pattern
// as admin/lib/sentry.ts — no-op when `SENTRY_DSN` is unset, so
// the SDK ships baked-in and operators flip it on later via env
// var. Per CLAUDE.md §15 Sentry is deferred until a real provider
// is chosen.
//
// The `@sentry/nextjs` import is dynamic (and wrapped in try/catch)
// because the package isn't yet in `package.json` — commit 8314dfd
// added the wiring ahead of the dependency landing. A static
// `import * as Sentry from "@sentry/nextjs"` blows up the Next.js
// dev server with a hard 500 on EVERY page render, not just
// instrumentation init. The dynamic guard turns this back into a
// quiet no-op until either the dep is installed or the file is
// removed.

let initialised = false;

export async function initSentry(): Promise<boolean> {
  if (initialised) return true;
  const dsn = (process.env.SENTRY_DSN ?? "").trim();
  if (!dsn) return false;

  let Sentry: typeof import("@sentry/nextjs");
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    Sentry = (await import("@sentry/nextjs")) as typeof import("@sentry/nextjs");
  } catch {
    // Package not installed — same outcome as "no DSN". Caller
    // (instrumentation.ts) treats `false` as "Sentry is off".
    return false;
  }

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
