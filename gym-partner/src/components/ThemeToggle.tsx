"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";

type Theme = "light" | "dark";

const STORAGE_KEY = "gp.theme";

/**
 * Two-state theme switch (light / dark) wired to the same `data-theme`
 * attribute the design tokens read in `globals.css`. Changes are
 * persisted to `localStorage` so the choice survives a refresh, and
 * the head-script in the root layout hydrates from the same key
 * before first paint to avoid the dark-to-light flash on reload.
 *
 * Renders nothing on the server / first client tick — the actual
 * <html data-theme> attribute is what determines the mode at SSR
 * time, and we only know the *current* mode after the head script
 * has run. A short skeleton during that window is uglier than no
 * button; the toggle just appears once we've read the live state.
 */
export function ThemeToggle() {
  const t = useTranslations("nav");
  const [theme, setTheme] = useState<Theme | null>(null);

  useEffect(() => {
    const current = (document.documentElement.getAttribute("data-theme") ??
      "dark") as Theme;
    setTheme(current);
  }, []);

  function toggle() {
    const next: Theme = theme === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // localStorage can throw in private mode / locked-down
      // browsers — failing silently keeps the toggle responsive.
      // The choice just won't survive the next reload.
    }
    setTheme(next);
  }

  if (theme === null) {
    // Reserve a footprint roughly matching the resolved chip so
    // there's no layout jolt at first paint.
    return <div className="h-9 w-[72px]" aria-hidden />;
  }

  const targetIsLight = theme === "dark";
  const targetLabel = targetIsLight ? t("themeLight") : t("themeDark");
  return (
    <button
      type="button"
      onClick={toggle}
      // Same shape + tonal register as LocaleToggle (icon + label,
      // h-9 surface chip with line border) so the two read as a
      // single control cluster, not two competing affordances.
      // Visible icon + label both reflect the *target* state, so
      // the chip answers "what does tapping this give me" rather
      // than "what mode am I in" — same convention as iOS
      // Settings.
      className="inline-flex h-9 items-center gap-1.5 rounded-md border border-line bg-surface px-2.5 text-paper transition-colors duration-150 hover:bg-surface-1 hover:border-line-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
      aria-label={
        targetIsLight ? t("themeSwitchToLight") : t("themeSwitchToDark")
      }
      title={
        targetIsLight ? t("themeSwitchToLight") : t("themeSwitchToDark")
      }
    >
      {targetIsLight ? (
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
        >
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
        </svg>
      ) : (
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
        >
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
        </svg>
      )}
      <span className="text-[11px] font-medium tracking-wide">
        {targetLabel}
      </span>
    </button>
  );
}
