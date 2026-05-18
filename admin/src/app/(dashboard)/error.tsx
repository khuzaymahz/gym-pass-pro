"use client";

import { useTranslations } from "next-intl";
import { useEffect } from "react";

/// Catches anything thrown by a server component below this segment
/// that isn't a `NEXT_REDIRECT` (those are handled by Next.js
/// itself). Real failures land here: backend 5xx, network dropped,
/// schema mismatch, anything unexpected. Shows a quiet, blame-free
/// panel with a retry button instead of a stack trace.
///
/// Network failures (`lib/api.ts` throws `NetworkError`) get a
/// distinct copy so the operator knows to check their connection
/// rather than chasing a ghost. Detection is by `name` instead of
/// `instanceof` because the error crosses the
/// server-component → error-boundary serialization boundary and
/// only carries `message`, `name`, and `digest`.
export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const t = useTranslations("error");

  const isNetwork = error.name === "NetworkError";

  useEffect(() => {
    if (process.env.NODE_ENV !== "production") {
      // eslint-disable-next-line no-console
      console.error("[admin] unhandled:", error);
    }
  }, [error]);

  return (
    <div className="mx-auto flex max-w-md flex-col gap-4 py-16">
      <p className="label text-muted">{t("eyebrow")}</p>
      <h1 className="h2">{isNetwork ? t("networkTitle") : t("title")}</h1>
      <p className="text-[13px] leading-relaxed text-muted">
        {isNetwork ? t("networkBody") : t("body")}
      </p>
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
