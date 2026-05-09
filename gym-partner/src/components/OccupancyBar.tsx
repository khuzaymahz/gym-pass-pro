"use client";

import { useTranslations } from "next-intl";

/**
 * Top status strip — "how full is the floor right now". Fills from
 * the inline-start to the right; passes 70% the fill flips amber as
 * a warning that the gym is approaching capacity.
 *
 * Capacity is computed locally as `today / max(last 30 days)`. We
 * don't have a literal headcount sensor, so this is "today vs
 * busiest comparable day in the last month" — the closest honest
 * proxy. When the data is too thin to make a comparison (no
 * meaningful peak yet), the strip shows an idle state instead of
 * a misleading 0%.
 */
export function OccupancyBar({
  today,
  peakLast30,
}: {
  /** Check-in count today. */
  today: number;
  /** Largest single-day count seen in the last 30 days. */
  peakLast30: number;
}) {
  const t = useTranslations("dashboard");

  const hasBaseline = peakLast30 > 0;
  const ratio = hasBaseline ? Math.min(1, today / peakLast30) : 0;
  const pct = ratio * 100;
  const overWarn = ratio >= 0.7;

  return (
    <div className="flex items-center gap-3.5">
      <span className="tracked text-[11.5px] text-muted">
        {t("occupancy")}
      </span>
      <div
        className="relative h-[4px] flex-1 overflow-hidden rounded-full bg-line/70"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(pct)}
        aria-label={t("occupancyAria")}
      >
        <div
          className={`absolute inset-y-0 left-0 rounded-full transition-[width,background-color] duration-700 ease-out ${
            overWarn ? "bg-accent" : "bg-paper/55"
          }`}
          style={{ width: `${pct.toFixed(1)}%` }}
        />
      </div>
      <div className="num flex shrink-0 items-baseline gap-1.5">
        <span
          className={`gauge text-[22px] ${overWarn ? "text-accent" : "text-paper"}`}
        >
          {today}
        </span>
        <span className="tracked text-[11px] text-muted">
          / {hasBaseline ? peakLast30 : "—"}
        </span>
      </div>
    </div>
  );
}
