"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { useState } from "react";

import { PERIOD_PRESETS, type PeriodPreset } from "@/lib/period";

/// Period selector that drives all dashboard tiles, charts, and the
/// recent-on-the-floor list. State is held in the URL as `?period=`
/// (or `?from=YYYY-MM-DD&to=YYYY-MM-DD` for Custom), so refreshes and
/// back/forward navigation keep the partner's pick. The dashboard
/// page is a server component that reads these params and forwards
/// resolved (since, until) timestamps to the backend.

export function PeriodSelector({
  current,
  from,
  to,
}: {
  current: PeriodPreset;
  from?: string;
  to?: string;
}) {
  const t = useTranslations("dashboard.period");
  const router = useRouter();
  const params = useSearchParams();
  // Local state for the date inputs in custom mode. Initialise from
  // URL so the inputs reflect what's currently active.
  const [customFrom, setCustomFrom] = useState<string>(from ?? "");
  const [customTo, setCustomTo] = useState<string>(to ?? "");

  function setPreset(next: PeriodPreset) {
    const url = new URLSearchParams(params.toString());
    if (next === "30d") {
      // 30d is the default — drop the param to keep URLs clean
      url.delete("period");
    } else {
      url.set("period", next);
    }
    if (next !== "custom") {
      url.delete("from");
      url.delete("to");
    }
    const qs = url.toString();
    router.push(qs ? `/?${qs}` : "/");
  }

  function applyCustom() {
    if (!customFrom || !customTo) return;
    if (customFrom > customTo) return;
    const url = new URLSearchParams(params.toString());
    url.set("period", "custom");
    url.set("from", customFrom);
    url.set("to", customTo);
    router.push(`/?${url.toString()}`);
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="seg" role="radiogroup" aria-label={t("ariaLabel")}>
        {PERIOD_PRESETS.map((p) => (
          <button
            key={p}
            type="button"
            role="radio"
            aria-checked={current === p}
            className={current === p ? "is-active" : ""}
            onClick={() => setPreset(p)}
          >
            {t(p)}
          </button>
        ))}
      </div>

      {current === "custom" ? (
        <div className="flex items-end gap-2">
          <label className="field">
            <span className="field-label">{t("from")}</span>
            <input
              type="date"
              className="input input-sm"
              value={customFrom}
              max={customTo || undefined}
              onChange={(e) => setCustomFrom(e.target.value)}
            />
          </label>
          <span className="pb-2 text-[13px] text-muted">→</span>
          <label className="field">
            <span className="field-label">{t("to")}</span>
            <input
              type="date"
              className="input input-sm"
              value={customTo}
              min={customFrom || undefined}
              onChange={(e) => setCustomTo(e.target.value)}
            />
          </label>
          <button
            type="button"
            className="btn-secondary btn-sm"
            onClick={applyCustom}
            disabled={!customFrom || !customTo || customFrom > customTo}
          >
            {t("apply")}
          </button>
        </div>
      ) : null}
    </div>
  );
}
