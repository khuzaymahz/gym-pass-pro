"use client";

import { useEffect } from "react";

/// Segment boundary for anything thrown between the root layout and
/// the (dashboard) segment — e.g. the login route or the dashboard
/// layout's own data fetches. Root-layout failures are handled one
/// level up by `global-error.tsx`; failures *inside* the dashboard by
/// `(dashboard)/error.tsx`.
///
/// Renders WITHIN the root layout (which already provides <html>/<body>
/// and globals.css), so it uses design-system classes. Kept i18n-free
/// on purpose: this boundary can fire when the NextIntl provider itself
/// is the failure, and `useTranslations` would re-throw and defeat it.
export default function AdminError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const isNetwork = error.name === "NetworkError";

  useEffect(() => {
    if (process.env.NODE_ENV !== "production") {
      // eslint-disable-next-line no-console
      console.error("[admin] unhandled:", error);
    }
  }, [error]);

  return (
    <div className="mx-auto flex min-h-[60vh] max-w-md flex-col justify-center gap-4 py-16">
      <p className="label">Admin · error</p>
      <h1 className="h2">
        {isNetwork ? "Can't reach the server" : "Something went wrong"}
      </h1>
      <p className="text-[13px] leading-relaxed text-muted">
        {isNetwork
          ? "The console couldn't reach the GymPass server. Check your connection and try again."
          : "This page couldn't load. It's usually a transient hiccup — try again, and reach out to ops if it keeps happening."}
      </p>
      <div className="mt-2 flex gap-2">
        <button
          type="button"
          onClick={() => reset()}
          className="btn-primary btn-sm"
        >
          Retry
        </button>
        <a href="/" className="btn-ghost btn-sm">
          Reload
        </a>
      </div>
      {error.digest ? (
        <p className="label mt-3">
          Ref <span className="num">{error.digest}</span>
        </p>
      ) : null}
    </div>
  );
}
