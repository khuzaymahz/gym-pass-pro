// Next.js server-side boot hook. Wires Sentry (no-op without
// SENTRY_DSN env var — flip on per env, no rebuild).
//
// Per CLAUDE.md §15 Sentry is "deferred until a real provider is
// chosen"; this module is the wiring so flipping it on is one
// env var change at deploy time.

export async function register(): Promise<void> {
  if (process.env.NEXT_RUNTIME !== "nodejs") return;
  try {
    const { initSentry } = await import("./lib/sentry");
    initSentry();
  } catch {
    // SDK missing or init failed — non-fatal; partner shell
    // continues booting.
  }
}
