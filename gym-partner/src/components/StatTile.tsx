type Tone = "default" | "ok" | "warn" | "bad";

/**
 * Dense KPI tile. Honours the operator-tool register from CLAUDE.md
 * memory ("Linear/Vercel/Stripe, no editorial chrome"): tight
 * padding, monospace numerals, neutral surfaces. The optional
 * `trend` mini-chart sits at the bottom-right of the tile so the
 * primary number reads at a glance and the trend reinforces it
 * without competing for attention.
 *
 * `delta` is rendered as `+12.3%` / `-4.1%` with the appropriate
 * accent (green up, red down) so a partner can spot week-over-week
 * movement without leaving the tile. `null` delta means "not enough
 * data to compare" — we show nothing rather than a misleading 0%.
 */

export type Trend = {
  /** Most recent N data points (oldest → newest). The last point
   *  is rendered as the active dot; everything before it is the
   *  fading line tail. */
  points: readonly number[];
  /** ARIA label describing what the sparkline represents
   *  (e.g. "Daily check-ins, last 14 days"). */
  ariaLabel?: string;
};

export function StatTile({
  label,
  value,
  unit,
  sub,
  delta,
  trend,
  tone = "default",
}: {
  label: string;
  value: string | number;
  unit?: string;
  sub?: string;
  /** Percent change relative to a prior window. Pass `null` to skip
   *  rendering — the empty slot collapses cleanly. */
  delta?: number | null;
  trend?: Trend;
  tone?: Tone;
}) {
  const valueClass =
    tone === "ok"
      ? "text-accent"
      : tone === "warn"
        ? "text-amber-400"
        : tone === "bad"
          ? "text-red-400"
          : "text-paper";

  return (
    <div className="stat group relative">
      <span className="stat-label">{label}</span>
      <div className="flex items-baseline gap-1">
        <span className={`stat-value ${valueClass}`}>{value}</span>
        {unit ? (
          <span className="text-[10.5px] font-medium uppercase text-muted">
            {unit}
          </span>
        ) : null}
      </div>
      {/* Bottom row: optional WoW delta on the start, optional
          sparkline on the end. Both are dim chrome — the tile's
          primary message is the big number above. */}
      {sub || delta != null || trend ? (
        <div className="mt-1 flex items-end justify-between gap-2">
          <div className="flex flex-col gap-0.5">
            {delta != null ? <DeltaPill delta={delta} /> : null}
            {sub ? <span className="stat-delta">{sub}</span> : null}
          </div>
          {trend ? <Sparkline trend={trend} tone={tone} /> : null}
        </div>
      ) : null}
    </div>
  );
}

function DeltaPill({ delta }: { delta: number }) {
  const sign = delta > 0 ? "+" : delta < 0 ? "−" : "";
  const abs = Math.abs(delta);
  // Suppress sub-1% noise — random daily wiggle isn't a signal.
  const colorClass =
    abs < 1
      ? "text-muted"
      : delta > 0
        ? "text-emerald-400"
        : "text-red-400";
  return (
    <span className={`num text-[10.5px] font-medium ${colorClass}`}>
      {sign}
      {abs.toFixed(abs < 10 ? 1 : 0)}%
    </span>
  );
}

/**
 * Compact 14-day-ish sparkline. Pure SVG, no chart library — the
 * tile only needs a 60×20 visual cue, not interactive chrome.
 *
 * Per `nextjs-best-practices` (skill: data-dense dashboard): keep
 * dependencies minimal, prefer hand-rolled SVG for primitives that
 * don't need interactivity. The full charts at the bottom of the
 * dashboard already use a heavier renderer; this one stays
 * featherweight so a row of seven tiles doesn't ship seven canvas
 * contexts.
 */
function Sparkline({ trend, tone }: { trend: Trend; tone: Tone }) {
  const { points, ariaLabel } = trend;
  if (points.length < 2) {
    // Single point or empty → render nothing rather than a flat
    // line that reads as "no movement" (which is misleading when
    // the truth is "no comparison data yet").
    return <span className="block h-5 w-[60px]" aria-hidden />;
  }
  const w = 60;
  const h = 20;
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
  const last = coords[coords.length - 1];
  const stroke =
    tone === "warn"
      ? "rgb(251 191 36)" // amber-400
      : tone === "bad"
        ? "rgb(248 113 113)" // red-400
        : "rgb(var(--c-accent))";
  return (
    <svg
      viewBox={`0 0 ${w} ${h}`}
      className="h-5 w-[60px] shrink-0 opacity-80 transition-opacity duration-150 group-hover:opacity-100"
      preserveAspectRatio="none"
      role={ariaLabel ? "img" : "presentation"}
      aria-label={ariaLabel}
    >
      <path
        d={line}
        fill="none"
        stroke={stroke}
        strokeWidth="1.25"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      {/* Active dot — same colour as the line, slightly heavier so
          the eye can find "now" on a 14-day series. */}
      <circle cx={last.x} cy={last.y} r={1.6} fill={stroke} />
    </svg>
  );
}
