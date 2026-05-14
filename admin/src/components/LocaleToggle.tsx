"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";

import { LOCALE_COOKIE, type Locale } from "@/i18n/config";

/**
 * Locale-flip pill. Writes the cookie client-side then refreshes —
 * avoids the Server Action + `revalidatePath('/', 'layout')` route
 * because in dev mode that rotates the page's Server Action IDs,
 * which then 404s every form on the page that was loaded before
 * the toggle (logo upload, profile save, etc.).
 */
export default function LocaleToggle() {
  const locale = useLocale() as Locale;
  const t = useTranslations("locale");
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const next: Locale = locale === "ar" ? "en" : "ar";

  function flip() {
    if (pending) return;
    const maxAge = 60 * 60 * 24 * 365;
    document.cookie =
      `${LOCALE_COOKIE}=${next}; path=/; max-age=${maxAge}; samesite=lax`;
    startTransition(() => {
      router.refresh();
    });
  }

  return (
    <button
      type="button"
      aria-label={t("label")}
      disabled={pending}
      onClick={flip}
      className="rounded-md border border-line px-2 py-0.5 text-[10.5px] font-medium text-muted transition-colors hover:border-lime hover:text-lime disabled:opacity-50"
    >
      {t(`toggleTo.${next}`)}
    </button>
  );
}
