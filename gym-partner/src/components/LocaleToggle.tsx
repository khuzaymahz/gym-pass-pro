"use client";

import { useLocale, useTranslations } from "next-intl";
import { useTransition } from "react";

import { setLocale } from "@/i18n/actions";
import type { Locale } from "@/i18n/config";

/**
 * Compact locale-flip pill — globe icon + a two-letter label of the
 * locale you'll switch *to* (matches `project_language_toggle_shows_target.md`
 * memory: "EN/AR labels itself with where-a-tap-takes-you, not the
 * current locale"). Sized to live next to `ThemeToggle` at the top-end
 * of every page; the shared icon + label format makes both chips
 * recognisable at a glance instead of "what's this random letter".
 */
export function LocaleToggle() {
  const t = useTranslations("nav");
  const current = useLocale() as Locale;
  const [pending, startTransition] = useTransition();
  const target: Locale = current === "ar" ? "en" : "ar";
  const targetLabel = target === "ar" ? "AR" : "EN";

  function flip() {
    if (pending) return;
    startTransition(() => {
      void setLocale(target);
    });
  }

  return (
    <button
      type="button"
      onClick={flip}
      disabled={pending}
      // Same tonal register as ThemeToggle (surface + line border,
      // hover bumps to surface-1) so the two chips read as one
      // control cluster. Slightly wider than 36×36 because the
      // label needs room — fixed `h-9` keeps vertical alignment
      // identical to the theme chip beside it.
      className="inline-flex h-9 items-center gap-1.5 rounded-md border border-line bg-surface px-2.5 text-paper transition-colors duration-150 hover:bg-surface-1 hover:border-line-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 disabled:opacity-60"
      aria-label={
        target === "ar" ? t("localeSwitchToAr") : t("localeSwitchToEn")
      }
      title={target === "ar" ? t("localeSwitchToAr") : t("localeSwitchToEn")}
      // Lock direction to LTR so glyph + label always render left-to-right,
      // regardless of the page's text-direction.
      dir="ltr"
    >
      <svg
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden
      >
        <circle cx="12" cy="12" r="9" />
        <path d="M3 12h18" />
        <path d="M12 3a14 14 0 0 1 0 18" />
        <path d="M12 3a14 14 0 0 0 0 18" />
      </svg>
      <span className="text-[11px] font-semibold uppercase tracking-wider">
        {targetLabel}
      </span>
    </button>
  );
}
