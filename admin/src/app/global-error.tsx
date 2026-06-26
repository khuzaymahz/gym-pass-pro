"use client";

import { useEffect } from "react";

/// True root boundary. Next.js renders `global-error` ONLY when the
/// root `layout.tsx` itself throws — a regular `error.tsx` can't catch
/// that because it renders *inside* the layout. So this is the last
/// line of defense for a misconfiguration high in the tree: a bad env
/// var, a failed `next/font` load, the NextIntl provider blowing up,
/// the theme/cookie read, etc. Without it those become an unstyled
/// Next.js 500.
///
/// It must render its own <html>/<body> (it replaces the root layout)
/// and must NOT depend on anything that could be the thing that failed
/// — no i18n, no globals.css classes, no providers. Inline styles +
/// plain English only.
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
      console.error("[admin:global] fatal:", error);
    }
  }, [error]);

  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif",
          background: "#09090B",
          color: "#FAFAFA",
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
          <h1 style={{ fontSize: 22, fontWeight: 700, margin: "8px 0 12px" }}>
            The console failed to load.
          </h1>
          <p style={{ fontSize: 13, lineHeight: 1.55, color: "#A1A1AA" }}>
            Something went wrong before the page could render — usually a
            transient problem. Try again, and reach out to ops if it keeps
            happening.
          </p>
          <div style={{ marginTop: 16, display: "flex", gap: 8 }}>
            <button
              type="button"
              onClick={() => reset()}
              style={{
                background: "#EAB308",
                color: "#09090B",
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
                color: "#FAFAFA",
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
              Ref{" "}
              <code style={{ fontFamily: "ui-monospace, monospace" }}>
                {error.digest}
              </code>
            </p>
          ) : null}
        </div>
      </body>
    </html>
  );
}
