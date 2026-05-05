"use client";

import { useEffect, useState } from "react";

/**
 * Sun/moon theme toggle. Reads + writes the `theme` cookie + the
 * `data-theme` attribute on `<html>`. The cookie is what survives
 * across reloads; the attribute is what CSS variables flip on.
 *
 * Why a cookie instead of localStorage: the inline FOUC script in
 * the root layout has to choose dark vs. light *before* React
 * hydrates, which means it can only read sources available
 * synchronously at HTML parse time — cookies are; localStorage in
 * an SSR-rendered Next.js page is racy. Cookie also flows to the
 * server so future SSR work can pick the right theme on first
 * render and skip the FOUC entirely.
 */
type Theme = "dark" | "light";

const COOKIE = "theme";
const ONE_YEAR = 60 * 60 * 24 * 365;

function readTheme(): Theme {
  if (typeof document === "undefined") return "dark";
  const m = document.cookie.match(/(?:^|; )theme=(dark|light)/);
  return (m?.[1] as Theme | undefined) ?? "dark";
}

function applyTheme(t: Theme) {
  if (typeof document === "undefined") return;
  document.documentElement.setAttribute("data-theme", t);
  document.cookie = `${COOKIE}=${t}; path=/; max-age=${ONE_YEAR}; samesite=lax`;
}

export default function ThemeToggle() {
  // Hydrate from the cookie (which the inline FOUC script has
  // already applied to <html>) so server-rendered markup matches
  // client expectations on first paint.
  const [theme, setTheme] = useState<Theme>("dark");

  useEffect(() => {
    setTheme(readTheme());
  }, []);

  const toggle = () => {
    const next: Theme = theme === "dark" ? "light" : "dark";
    setTheme(next);
    applyTheme(next);
  };

  // Show the icon for the *target* state (the locale toggle in the
  // mobile app does the same thing — labels show where a tap takes
  // you, not where you are right now).
  const goingToLight = theme === "dark";

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={goingToLight ? "Switch to light theme" : "Switch to dark theme"}
      title={goingToLight ? "Switch to light" : "Switch to dark"}
      className="btn-icon"
    >
      {goingToLight ? (
        // Sun (going to light)
        <svg
          width="14"
          height="14"
          viewBox="0 0 16 16"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
        >
          <circle cx="8" cy="8" r="3" />
          <path d="M8 1.5v1.7M8 12.8v1.7M1.5 8h1.7M12.8 8h1.7M3.4 3.4l1.2 1.2M11.4 11.4l1.2 1.2M3.4 12.6l1.2-1.2M11.4 4.6l1.2-1.2" />
        </svg>
      ) : (
        // Moon (going to dark)
        <svg
          width="14"
          height="14"
          viewBox="0 0 16 16"
          fill="currentColor"
        >
          <path d="M13.5 11.2A6 6 0 1 1 4.8 2.5a5 5 0 0 0 8.7 8.7Z" />
        </svg>
      )}
    </button>
  );
}

/**
 * Synchronous, blocking script string injected into `<head>` before
 * any styles render. Reads the `theme` cookie and applies it to
 * `<html>` so the first paint already has the correct CSS variables.
 * Without this, a light-mode user would see a black flash on every
 * navigation while the React hydrate runs.
 *
 * Kept as a literal string so it can be passed to `<script
 * dangerouslySetInnerHTML>` from a server component without bundling
 * a client-side import.
 */
export const themeBootScript = `
(function(){try{
  var m=document.cookie.match(/(?:^|; )theme=(dark|light)/);
  var t=(m&&m[1])||'dark';
  document.documentElement.setAttribute('data-theme', t);
}catch(_){document.documentElement.setAttribute('data-theme','dark');}})();
`.trim();
