"use client";

import { useLocale, useTranslations } from "next-intl";
import { useTransition } from "react";

import { setLocale } from "@/i18n/actions";
import type { Locale } from "@/i18n/config";

export default function LocaleToggle() {
  const locale = useLocale() as Locale;
  const t = useTranslations("locale");
  const [pending, startTransition] = useTransition();
  const next: Locale = locale === "ar" ? "en" : "ar";

  return (
    <button
      type="button"
      aria-label={t("label")}
      disabled={pending}
      onClick={() => startTransition(() => setLocale(next))}
      className="rounded-md border border-line px-2 py-0.5 text-[10.5px] font-medium text-muted transition-colors hover:border-lime hover:text-lime disabled:opacity-50"
    >
      {t(`toggleTo.${next}`)}
    </button>
  );
}
