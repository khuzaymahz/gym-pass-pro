"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";

import { LOCALE_COOKIE, type Locale } from "@/i18n/config";

/**
 * Compact locale-flip pill — globe icon + a two-letter label of the
 * locale you'll switch *to* (matches `project_language_toggle_shows_target.md`
 * memory: "EN/AR labels itself with where-a-tap-takes-you, not the
 * current locale").
 *
 * The cookie is written client-side here and `router.refresh()` re-
 * renders the current route. We deliberately avoid the Server Action
 * + `revalidatePath('/', 'layout')` route because in Next.js 15 dev
 * mode, invalidating the layout cache often rotates the page's
 * Server Action IDs — and the browser DOM still references the
 * pre-flip IDs, so the next click on any form (e.g. the logo
 * uploader on the profile page) 404s with "Failed to find Server
 * Action". Writing the cookie directly + refreshing keeps action
 * hashes stable.
 */
export function LocaleToggle() {
  const t = useTranslations("nav");
  const router = useRouter();
  const current = useLocale() as Locale;
  const [pending, startTransition] = useTransition();
  const target: Locale = current === "ar" ? "en" : "ar";
  const targetLabel = target === "ar" ? "AR" : "EN";

  function flip() {
    if (pending) return;
    // One-year max-age (mirrors the old Server Action). `samesite=lax`
    // keeps it sent on top-level navigations but not on cross-site
    // GETs, which is what we want for an auth-adjacent preference.
    const maxAge = 60 * 60 * 24 * 365;
    document.cookie =
      `${LOCALE_COOKIE}=${target}; path=/; max-age=${maxAge}; samesite=lax`;
    startTransition(() => {
      router.refresh();
    });
  }

  return (
    <button
      type="button"
      onClick={flip}
      disabled={pending}
      className="inline-flex h-9 items-center gap-1.5 rounded-md border border-line bg-surface px-2.5 text-paper transition-colors duration-150 hover:bg-surface-1 hover:border-line-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 disabled:opacity-60"
      aria-label={
        target === "ar" ? t("localeSwitchToAr") : t("localeSwitchToEn")
      }
      title={target === "ar" ? t("localeSwitchToAr") : t("localeSwitchToEn")}
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
