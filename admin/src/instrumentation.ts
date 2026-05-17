// Next.js server-side init hook. Runs exactly once when the Node runtime
// boots, before any request is served. We use it as a prod boot-fence:
// refuse to start when secrets or domain knobs are still on the
// development sentinels that would silently weaken the production deploy.
//
// Mirrors backend/app/config.py::validate_production_safety so both halves
// of the stack fail fast at boot rather than degrade quietly under load.

const DEV_SENTINELS = new Set([
  "changeme",
  "changeme-dev",
  "changeme-long-random-string",
  "dev-nextauth-secret-change-me",
  "change-me-in-dev-only-please",
  "admin123",
]);

export async function register(): Promise<void> {
  if (process.env.NEXT_RUNTIME !== "nodejs") return;

  // Sentry first — runs in every env (no-op without SENTRY_DSN),
  // so error-tracking is live before any further boot checks can
  // throw. Lazy import keeps the dependency out of the dev runtime
  // bundle when DSN is unset.
  try {
    const { initSentry } = await import("./lib/sentry");
    initSentry();
  } catch {
    // Sentry SDK missing or init failed — non-fatal, the rest of
    // boot continues.
  }

  if (process.env.NODE_ENV !== "production") return;
  if (process.env.APP_ENV !== "production") return;

  const problems: string[] = [];

  const nextAuthSecret = process.env.NEXTAUTH_SECRET ?? "";
  if (DEV_SENTINELS.has(nextAuthSecret) || nextAuthSecret.length < 32) {
    problems.push(
      "NEXTAUTH_SECRET must be a random string >= 32 chars (use `openssl rand -base64 32`)",
    );
  }

  const nextAuthUrl = process.env.NEXTAUTH_URL ?? "";
  if (!nextAuthUrl.startsWith("https://")) {
    problems.push("NEXTAUTH_URL must be an https:// URL in production");
  }

  const apiBase = process.env.API_BASE_URL ?? process.env.BACKEND_API_URL ?? "";
  if (!apiBase) {
    problems.push("API_BASE_URL (or BACKEND_API_URL) must be set");
  }

  const bootstrapPwd = process.env.ADMIN_BOOTSTRAP_PASSWORD ?? "";
  if (
    bootstrapPwd &&
    (DEV_SENTINELS.has(bootstrapPwd) || bootstrapPwd.length < 12)
  ) {
    problems.push(
      "ADMIN_BOOTSTRAP_PASSWORD must be unset OR >= 12 chars and not a dev default",
    );
  }

  if (problems.length === 0) return;

  const message =
    "Refusing to start admin in production with insecure defaults:\n  - " +
    problems.join("\n  - ");

  // Throwing inside `register()` aborts the Next bootstrap with a clear
  // log; the container exits non-zero so docker / k8s surfaces the failure.
  throw new Error(message);
}
