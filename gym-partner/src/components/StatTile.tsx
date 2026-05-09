"use client";

import { CountUp } from "./CountUp";

type Tone = "default" | "ok" | "warn" | "bad";

export type Trend = {
  /** Most recent N data points (oldest → newest). */
  points: readonly number[];
  /** ARIA label describing what the sparkline represents. */
  ariaLabel?: string;
};

/**
 * Training-floor stat card. Reads like a gauge readout:
 *
 *   ┌────────────────────────────────┐
 *   │ CHECK-INS  TODAY               │  ← tracked-out caps label
 *   │ ┌──┐                           │
 *   │ │47│              +12% ▲       │  ← gauge numeral + delta
 *   │ └──┘                           │
 *   │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━    │  ← progress rail (vs prev period)
 *   │      hover → reveal sparkline  │
 *   └────────────────────────────────┘
 *
 * Surface is brushed-steel (`.steel`) with a subtle noise texture.
 * Hover lifts 2px with a warm amber-tinted shadow and reveals the
 * 14-day sparkline overlay along the bottom edge.
 *
 * `delta` drives both the inline percent label and the progress
 * rail's fill ratio — a +50% week gets a near-full rail, a flat
 * week gets a half-fill. Negative deltas render the rail in the
 * "warn" colour, capped at 100% width so a one-off 200% spike
 * doesn't blow the layout.
 */
export function StatTile({
  label,
  value,
  unit,
  delta,
  trend,
  tone = "default",
}: {
  label: string;
  /** Final numeric value. Strings are accepted for pre-formatted
   *  outputs (e.g. compact JOD totals "12k") and skip the count-up. */
  value: string | number;
  unit?: string;
  delta?: number | null;
  trend?: Trend;
  tone?: Tone;
}) {
  const numeric = typeof value === "number" ? value : null;
  const valueClass =
    tone === "ok"
      ? "text-accent"
      : tone === "warn"
        ? "text-accent"
        : tone === "bad"
          ? "text-red-400"
          : "text-paper";

  return (
    <div className="steel lift-on-hover group relative flex flex-col gap-2.5 overflow-hidden rounded-lg p-5">
      <span className="tracked text-[11.5px] text-muted">{label}</span>

      <div className="flex items-end justify-between gap-3">
        <div className="flex items-end gap-1.5">
          {numeric != null ? (
            <CountUp
              value={numeric}
              className={`gauge text-[40px] ${valueClass}`}
            />
          ) : (
            <span className={`gauge text-[40px] ${valueClass}`}>{value}</span>
          )}
          {unit ? (
            <span className="tracked mb-1.5 text-[11px] text-muted">
              {unit}
            </span>
          ) : null}
        </div>
        {delta != null ? <DeltaBadge delta={delta} /> : null}
      </div>

      <ProgressRail delta={delta ?? null} />

      {trend && trend.points.length >= 2 ? (
        <SparklineOverlay trend={trend} tone={tone} />
      ) : null}
    </div>
  );
}

function DeltaBadge({ delta }: { delta: number }) {
  const abs = Math.abs(delta);
  // <1% reads as flat — don't treat noise as movement.
  const flat = abs < 1;
  const sign = flat ? "" : delta > 0 ? "▲" : "▼";
  const color = flat
    ? "text-muted"
    : delta > 0
      ? "text-accent"
      : "text-red-400";
  return (
    <span
      className={`num inline-flex items-center gap-1 text-[12.5px] font-semibold ${color}`}
    >
      <span>{sign}</span>
      <span>{flat ? "—" : `${abs.toFixed(abs < 10 ? 1 : 0)}%`}</span>
    </span>
  );
}

/**
 * Thin progress rail under the number. Maps the WoW delta onto a
 * 0–100% fill so the eye reads "this metric moved by THIS much"
 * without needing to read the percent label. Centered at 50% so
 * negative deltas render as a half-empty rail; positive deltas
 * push past it.
 *
 * Rail height stays at 2px so it never competes with the gauge
 * numeral for attention — it's a supporting cue, not a chart.
 */
function ProgressRail({ delta }: { delta: number | null }) {
  if (delta == null) {
    return (
      <div className="h-[2px] w-full rounded-full bg-line/60" aria-hidden />
    );
  }
  // Map (-100%, +100%) → (0%, 100%) with a soft floor/ceiling so a
  // flat week shows a centered tick.
  const clamped = Math.max(-100, Math.min(100, delta));
  const fill = 50 + clamped / 2;
  const negative = delta < -1;
  return (
    <div
      className="relative h-[2px] w-full overflow-hidden rounded-full bg-line/60"
      aria-hidden
    >
      <div
        className={`absolute inset-y-0 left-0 rounded-full transition-[width] duration-700 ease-out ${
          negative ? "bg-red-400/70" : "bg-accent"
        }`}
        style={{ width: `${fill.toFixed(1)}%` }}
      />
    </div>
  );
}

/**
 * Hover-revealed sparkline. Sits absolute along the bottom edge so
 * the resting state is unchanged — the line only appears once the
 * partner inspects the card. Single luminous stroke, no fill.
 */
function SparklineOverlay({ trend, tone }: { trend: Trend; tone: Tone }) {
  const { points, ariaLabel } = trend;
  const w = 100;
  const h = 22;
  const max = Math.max(...points, 1);
  const min = Math.min(...points, 0);
  const range = Math.max(max - min, 1);
  const stepX = w / Math.max(1, points.length - 1);
  const coords = points.map((p, i) => {
    const x = i * stepX;
    const y = h - ((p - min) / range) * (h - 4) - 2;
    return { x, y };
  });
  const line = coords
    .map((c, i) => `${i === 0 ? "M" : "L"}${c.x.toFixed(1)},${c.y.toFixed(1)}`)
    .join(" ");
  const stroke =
    tone === "bad" ? "rgb(248 113 113)" : "rgb(var(--c-accent))";
  return (
    <svg
      viewBox={`0 0 ${w} ${h}`}
      className="pointer-events-none absolute inset-x-3 bottom-2 h-5 opacity-0 transition-opacity duration-200 group-hover:opacity-100"
      preserveAspectRatio="none"
      role={ariaLabel ? "img" : "presentation"}
      aria-label={ariaLabel}
      style={{ width: "calc(100% - 1.5rem)" }}
    >
      <path
        d={line}
        fill="none"
        stroke={stroke}
        strokeWidth="1.25"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
    </svg>
  );
}
