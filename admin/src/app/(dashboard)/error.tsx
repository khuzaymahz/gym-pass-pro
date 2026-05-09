"use client";

import { useTranslations } from "next-intl";
import { useEffect } from "react";

/// Catches anything thrown by a server component below this segment
/// that isn't a `NEXT_REDIRECT` (those are handled by Next.js
/// itself). Real failures land here: backend 5xx, network dropped,
/// schema mismatch, anything unexpected. Shows a quiet, blame-free
/// panel with a retry button instead of a stack trace.
///
/// Per `nextjs-best-practices` — use `error.tsx` to recover
/// gracefully, never let an exception cascade to a generic 500
/// HTML page in production.
export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const t = useTranslations("error");

  useEffect(() => {
    // Surface unhandled exceptions in the dev console so we can see
    // them while iterating; production logging would route the
    // `digest` through Sentry/similar.
    if (process.env.NODE_ENV !== "production") {
      // eslint-disable-next-line no-console
      console.error("[admin] unhandled:", error);
    }
  }, [error]);

  return (
    <div className="mx-auto flex max-w-md flex-col gap-4 py-16">
      <p className="label text-muted">{t("eyebrow")}</p>
      <h1 className="h2">{t("title")}</h1>
      <p className="text-[13px] leading-relaxed text-muted">{t("body")}</p>
      <div className="mt-2 flex gap-2">
        <button
          type="button"
          onClick={() => reset()}
          className="btn-primary btn-sm"
        >
          {t("retry")}
        </button>
        <a href="/" className="btn-ghost btn-sm">
          {t("goHome")}
        </a>
      </div>
      {error.digest ? (
        <p className="mt-3 text-[10px] uppercase tracking-wider text-muted">
          {t("ref")} <span className="num">{error.digest}</span>
        </p>
      ) : null}
    </div>
  );
}
