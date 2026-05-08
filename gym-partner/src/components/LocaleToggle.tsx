"use client";

import { useLocale } from "next-intl";
import { useTransition } from "react";

import { setLocale } from "@/i18n/actions";
import type { Locale } from "@/i18n/config";

export function LocaleToggle() {
  const current = useLocale() as Locale;
  const [pending, startTransition] = useTransition();

  function pick(next: Locale) {
    if (next === current) return;
    startTransition(() => {
      void setLocale(next);
    });
  }

  return (
    <div className="seg w-full" role="tablist" aria-label="locale">
      <button
        type="button"
        className={current === "ar" ? "is-active flex-1" : "flex-1"}
        onClick={() => pick("ar")}
        disabled={pending}
      >
        AR
      </button>
      <button
        type="button"
        className={current === "en" ? "is-active flex-1" : "flex-1"}
        onClick={() => pick("en")}
        disabled={pending}
      >
        EN
      </button>
    </div>
  );
}
