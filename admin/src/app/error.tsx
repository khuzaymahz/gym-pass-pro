"use client";

import { useEffect } from "react";

/// Root-level error boundary for anything thrown above the
/// dashboard segment (e.g. the root layout, NextIntl provider, etc.)
/// — the (dashboard) error.tsx can't catch failures higher up the
/// tree, so this is the last line of defense before Next.js falls
/// back to its built-in 500.
///
/// No translations on purpose: if the i18n provider itself is the
/// thing that failed, `useTranslations` would throw again and
/// nullify the boundary.
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    if (process.env.NODE_ENV !== "production") {
      // eslint-disable-next-line no-console
      console.error("[admin:root] unhandled:", error);
    }
  }, [error]);

  return (
    <html>
      <body
        style={{
          margin: 0,
          padding: 0,
          fontFamily:
            "ui-sans-serif, system-ui, -apple-system, sans-serif",
          background: "#0B0B0E",
          color: "#E5E7EB",
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <div style={{ maxWidth: 420, padding: 24 }}>
          <p
            style={{
              fontSize: 11,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
              color: "#71717A",
              margin: 0,
            }}
          >
            Admin · fatal error
          </p>
          <h1
            style={{
              fontSize: 22,
              fontWeight: 600,
              margin: "8px 0 12px",
            }}
          >
            Something went wrong loading the console.
          </h1>
          <p style={{ fontSize: 13, lineHeight: 1.55, color: "#A1A1AA" }}>
            The page couldn't render. This is usually a transient
            problem — try again, and reach out to ops if it keeps
            happening.
          </p>
          <div style={{ marginTop: 16, display: "flex", gap: 8 }}>
            <button
              type="button"
              onClick={() => reset()}
              style={{
                background: "#BBFB46",
                color: "#0B0B0E",
                border: 0,
                borderRadius: 6,
                padding: "8px 14px",
                fontSize: 13,
                fontWeight: 600,
                cursor: "pointer",
              }}
            >
              Retry
            </button>
            <a
              href="/"
              style={{
                background: "transparent",
                color: "#E5E7EB",
                border: "1px solid #27272A",
                borderRadius: 6,
                padding: "8px 14px",
                fontSize: 13,
                textDecoration: "none",
              }}
            >
              Reload
            </a>
          </div>
          {error.digest ? (
            <p
              style={{
                marginTop: 16,
                fontSize: 10,
                textTransform: "uppercase",
                letterSpacing: "0.08em",
                color: "#71717A",
              }}
            >
              Ref <code style={{ fontFamily: "ui-monospace, monospace" }}>{error.digest}</code>
            </p>
          ) : null}
        </div>
      </body>
    </html>
  );
}
