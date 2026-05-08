import { getTranslations } from "next-intl/server";

import { StatTile } from "@/components/StatTile";
import { Toolbar } from "@/components/Toolbar";
import { PartnerSDK, type PartnerDashboardMetrics } from "@/lib/sdk";

const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;
const TIER_DOT: Record<string, string> = {
  silver: "rgb(180 180 180)",
  gold: "rgb(234 179 8)", // matches --c-accent
  platinum: "rgb(184 212 255)",
  diamond: "rgb(100 210 255)",
};

function formatJod(value: string | number, opts?: { compact?: boolean }) {
  const num = typeof value === "string" ? Number.parseFloat(value) : value;
  if (!Number.isFinite(num)) return `${value}`;
  if (opts?.compact && Math.abs(num) >= 1000) {
    return `${(num / 1000).toFixed(num >= 10000 ? 0 : 1)}k`;
  }
  return num.toLocaleString("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  });
}

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

/// Week-over-week percent change, comparing the most recent 7 days
/// in `series` against the 7 days immediately before. Returns null
/// when we don't have at least 14 points or when the prior window
/// summed to zero (division undefined). Caller treats null as "no
/// comparison data yet" — the StatTile renders no delta in that
/// case rather than a misleading 0% or +∞%.
function weekOverWeek(series: readonly number[]): number | null {
  if (series.length < 14) return null;
  const recent = series.slice(-7).reduce((a, b) => a + b, 0);
  const prior = series.slice(-14, -7).reduce((a, b) => a + b, 0);
  if (prior === 0) return null;
  return ((recent - prior) / prior) * 100;
}

export default async function PartnerDashboardPage() {
  const t = await getTranslations("dashboard");
  const m = await PartnerSDK.metrics();

  // Pre-compute the per-day series once so each tile + chart can
  // reach for the same arrays. The backend already returns
  // last-30-days arrays via `/partner/gym/metrics/overview`.
  const checkinsSeries = m.checkinsPerDay.map((d) => d.count);
  const revenueSeries = m.revenuePerDay.map((d) =>
    Number.parseFloat(d.total || "0"),
  );
  const checkinsWoW = weekOverWeek(checkinsSeries);
  const revenueWoW = weekOverWeek(revenueSeries);
  // Today's check-ins live in `m.checkinsToday`; for the tile's
  // delta we compare today to the *median* of the last 7 days so a
  // single outlier (slow Sunday) doesn't pin every Monday at "huge
  // jump". For the rest, weekly aggregates are the right window.
  const last7 = checkinsSeries.slice(-7).filter((_, i, a) => i < a.length - 1);
  const medianLast7 =
    last7.length === 0
      ? 0
      : (() => {
          const sorted = [...last7].sort((a, b) => a - b);
          const mid = Math.floor(sorted.length / 2);
          return sorted.length % 2
            ? sorted[mid]
            : (sorted[mid - 1] + sorted[mid]) / 2;
        })();
  const todayDelta =
    medianLast7 > 0
      ? ((m.checkinsToday - medianLast7) / medianLast7) * 100
      : null;

  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />

      {/* KPI grid — last-14-day sparklines + WoW deltas added to
          the four "movement" tiles. Static / cumulative tiles
          (uniqueMembers, payouts) skip the sparkline since their
          shape isn't a meaningful trend. */}
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-7">
        <StatTile
          label={t("checkinsToday")}
          value={m.checkinsToday.toLocaleString()}
          delta={todayDelta}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("checkinsThisMonth")}
          value={m.checkinsThisMonth.toLocaleString()}
          delta={checkinsWoW}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("checkinsLast30")}
          value={m.checkinsLast30Days.toLocaleString()}
          delta={checkinsWoW}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("uniqueMembers")}
          value={m.uniqueMembersLast30Days.toLocaleString()}
        />
        <StatTile
          label={t("revenueMtd")}
          value={formatJod(m.revenueMtdJod, { compact: true })}
          unit={t("jod")}
          tone="ok"
          delta={revenueWoW}
          trend={{
            points: revenueSeries.slice(-14),
            ariaLabel: t("trendRevenueAria"),
          }}
        />
        <StatTile
          label={t("pendingPayout")}
          value={formatJod(m.pendingPayoutTotalJod, { compact: true })}
          unit={t("jod")}
          tone="warn"
        />
        <StatTile
          label={t("paidPayoutMtd")}
          value={formatJod(m.paidPayoutMtdJod, { compact: true })}
          unit={t("jod")}
        />
      </div>

      {/* Trend charts */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <ChartPanel
          title={t("checkinsTrend")}
          subtitle={t("checkinsLast30")}
          total={m.checkinsLast30Days.toLocaleString()}
          delta={checkinsWoW}
        >
          <AreaChart
            points={checkinsSeries}
            labels={m.checkinsPerDay.map((d) => d.day)}
            empty={t("noData")}
            ariaLabel={t("trendCheckinsAria")}
          />
        </ChartPanel>
        <ChartPanel
          title={t("revenueTrend")}
          subtitle={t("checkinsLast30")}
          total={formatJod(
            revenueSeries.reduce((a, b) => a + b, 0),
            { compact: true },
          )}
          unit={t("jod")}
          delta={revenueWoW}
        >
          <AreaChart
            points={revenueSeries}
            labels={m.revenuePerDay.map((d) => d.day)}
            empty={t("noData")}
            ariaLabel={t("trendRevenueAria")}
          />
        </ChartPanel>
      </div>

      {/* Distributions */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
        <Panel title={t("tierMix")}>
          <TierBreakdown
            tiers={m.tierBreakdown}
            total={m.checkinsLast30Days}
            empty={t("noData")}
          />
        </Panel>
        <Panel title={t("hourMix")} subtitle={t("hourMixSubtitle")}>
          <HourStrip hours={m.hourBreakdown} empty={t("noData")} />
        </Panel>
        <Panel title={t("recentCheckins")}>
          {m.recentCheckins.length === 0 ? (
            <p className="py-4 text-center text-[12px] text-muted">
              {t("noCheckinsYet")}
            </p>
          ) : (
            <ul className="-mx-1 flex flex-col">
              {m.recentCheckins.map((c) => (
                <li
                  key={c.id}
                  className="flex items-center gap-3 rounded-md px-1 py-2 transition-colors hover:bg-line/40"
                >
                  <RecencyDot scannedAt={c.scannedAt} />
                  <span className="min-w-0 flex-1 truncate text-[13px] text-paper">
                    {c.userName ?? c.userId.slice(0, 8)}
                  </span>
                  <span className="num shrink-0 text-[11px] text-muted">
                    {formatTime(c.scannedAt)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>
    </section>
  );
}

function Panel({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="panel p-4">
      <header className="mb-3">
        <h2 className="h2">{title}</h2>
        {subtitle ? (
          <p className="mt-0.5 text-[11px] text-muted">{subtitle}</p>
        ) : null}
      </header>
      {children}
    </section>
  );
}

function ChartPanel({
  title,
  subtitle,
  total,
  unit,
  delta,
  children,
}: {
  title: string;
  subtitle?: string;
  total: number | string;
  unit?: string;
  delta?: number | null;
  children: React.ReactNode;
}) {
  return (
    <section className="panel p-4">
      <header className="mb-3 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="h2">{title}</h2>
          {subtitle ? (
            <p className="mt-0.5 text-[11.5px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        <div className="flex items-baseline gap-2">
          {delta != null ? <ChartDelta delta={delta} /> : null}
          <div className="flex items-baseline gap-1">
            <span className="num text-[18px] font-semibold text-paper">
              {total}
            </span>
            {unit ? (
              <span className="text-[10.5px] font-medium uppercase text-muted">
                {unit}
              </span>
            ) : null}
          </div>
        </div>
      </header>
      {children}
    </section>
  );
}

function ChartDelta({ delta }: { delta: number }) {
  const abs = Math.abs(delta);
  const colorClass =
    abs < 1
      ? "text-muted"
      : delta > 0
        ? "text-emerald-400"
        : "text-red-400";
  const sign = delta > 0 ? "+" : delta < 0 ? "−" : "";
  return (
    <span className={`num text-[10.5px] font-medium ${colorClass}`}>
      {sign}
      {abs.toFixed(abs < 10 ? 1 : 0)}%
    </span>
  );
}

/// Bigger area chart with axis labels, a min/max band, and a
/// hover-able value row. Kept as raw SVG (no chart lib) — the
/// dashboard renders three of these per page, and shipping a chart
/// runtime per panel would dwarf the data they show.
function AreaChart({
  points,
  labels,
  empty,
  ariaLabel,
}: {
  points: number[];
  labels: string[];
  empty: string;
  ariaLabel?: string;
}) {
  if (points.length === 0) {
    return (
      <div className="flex h-36 items-center justify-center rounded-md border border-dashed border-line">
        <p className="label">{empty}</p>
      </div>
    );
  }
  const max = Math.max(...points, 1);
  const min = Math.min(...points, 0);
  const w = 600;
  const h = 130;
  const pad = 6;
  const stepX = (w - pad * 2) / Math.max(1, points.length - 1);
  const coords = points.map((p, i) => {
    const x = pad + i * stepX;
    const y =
      h -
      pad -
      ((p - min) / Math.max(max - min, 1)) * (h - pad * 2);
    return { x, y };
  });
  const line = coords
    .map((c, i) => `${i === 0 ? "M" : "L"}${c.x.toFixed(1)},${c.y.toFixed(1)}`)
    .join(" ");
  const area = `${line} L${w - pad},${h - pad} L${pad},${h - pad} Z`;
  const peakIdx = points.indexOf(max);
  const peak = coords[peakIdx];
  return (
    <div>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="h-32 w-full"
        preserveAspectRatio="none"
        role={ariaLabel ? "img" : "presentation"}
        aria-label={ariaLabel}
      >
        <defs>
          <linearGradient id="partnerAreaFill" x1="0" y1="0" x2="0" y2="1">
            <stop
              offset="0%"
              stopColor="rgb(var(--c-accent))"
              stopOpacity="0.28"
            />
            <stop
              offset="100%"
              stopColor="rgb(var(--c-accent))"
              stopOpacity="0"
            />
          </linearGradient>
        </defs>
        {/* Subtle gridlines at quarter, half, three-quarter heights. */}
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={pad}
            x2={w - pad}
            y1={h * f}
            y2={h * f}
            stroke="rgb(var(--c-line))"
            strokeWidth="1"
            strokeDasharray="2 4"
            opacity="0.55"
          />
        ))}
        <path d={area} fill="url(#partnerAreaFill)" />
        <path
          d={line}
          fill="none"
          stroke="rgb(var(--c-accent))"
          strokeWidth="1.75"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {/* Peak marker — gives the eye an anchor point on what
            otherwise reads as a continuous wave. */}
        {Number.isFinite(peak.x) && peak.x > 0 ? (
          <>
            <line
              x1={peak.x}
              x2={peak.x}
              y1={peak.y}
              y2={h - pad}
              stroke="rgb(var(--c-accent))"
              strokeWidth="1"
              strokeDasharray="1 3"
              opacity="0.5"
            />
            <circle
              cx={peak.x}
              cy={peak.y}
              r="2.5"
              fill="rgb(var(--c-accent))"
              stroke="rgb(var(--c-ink))"
              strokeWidth="1.5"
            />
          </>
        ) : null}
      </svg>
      {/* Three-tick axis: first day, midpoint, last day. Kept
          monospace so the digit columns line up across panels. */}
      <div className="num mt-2 flex justify-between text-[10.5px] text-muted">
        <span>{labels[0]?.slice(5)}</span>
        <span>{labels[Math.floor(labels.length / 2)]?.slice(5)}</span>
        <span>{labels[labels.length - 1]?.slice(5)}</span>
      </div>
    </div>
  );
}

function TierBreakdown({
  tiers,
  total,
  empty,
}: {
  tiers: Record<string, number>;
  total: number;
  empty: string;
}) {
  const sum = Object.values(tiers).reduce((a, b) => a + b, 0);
  if (sum === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">{empty}</p>
    );
  }
  const denom = total > 0 ? total : sum;
  return (
    <ul className="flex flex-col gap-2.5">
      {TIER_ORDER.map((tier) => {
        const count = tiers[tier] ?? 0;
        const pct = denom > 0 ? (count / denom) * 100 : 0;
        return (
          <li key={tier} className="flex items-center gap-3 text-[12px]">
            <span className="flex w-16 items-center gap-1.5">
              <span
                className="h-2 w-2 rounded-full"
                style={{ backgroundColor: TIER_DOT[tier] }}
                aria-hidden
              />
              <span className="capitalize text-muted">{tier}</span>
            </span>
            <div className="relative h-1.5 flex-1 overflow-hidden rounded-full bg-line">
              <div
                className="absolute inset-y-0 left-0 rounded-full transition-[width] duration-500 ease-out"
                style={{
                  width: `${pct}%`,
                  backgroundColor: TIER_DOT[tier],
                }}
              />
            </div>
            <span className="num w-10 text-right text-paper">{count}</span>
            <span className="num w-10 text-right text-[11px] text-muted">
              {pct.toFixed(0)}%
            </span>
          </li>
        );
      })}
    </ul>
  );
}

/// Hour-of-day strip styled as a heat row: each cell is a fixed
/// 24th of the width, the saturation of the accent colour scales
/// with the bucket count, and the active hour (current local time)
/// gets a thin marker. Replaces the previous bar-histogram which
/// read as a chart but was actually a 24-cell legend in disguise —
/// this version makes the "look at this hour vs that hour"
/// affordance literal.
///
/// Backend returns UTC hours; Jordan sits at UTC+3 year-round (no
/// DST), so a single +3 shift gives the partner a local-clock view.
function HourStrip({
  hours,
  empty,
}: {
  hours: PartnerDashboardMetrics["hourBreakdown"];
  empty: string;
}) {
  if (hours.length === 0) {
    return <p className="py-4 text-center text-[12px] text-muted">{empty}</p>;
  }
  const buckets = new Array<number>(24).fill(0);
  for (const { hour, count } of hours) {
    const local = (hour + 3) % 24;
    buckets[local] += count;
  }
  const max = Math.max(...buckets, 1);
  return (
    <div className="flex flex-col gap-2">
      <div className="flex h-9 items-stretch overflow-hidden rounded-md border border-line">
        {buckets.map((v, i) => {
          const intensity = v === 0 ? 0 : 0.15 + (v / max) * 0.85;
          return (
            <div
              key={i}
              className="flex-1 transition-colors duration-200"
              style={{
                backgroundColor: `rgba(var(--c-accent) / ${intensity.toFixed(2)})`,
              }}
              title={`${i.toString().padStart(2, "0")}:00 — ${v} check-ins`}
            />
          );
        })}
      </div>
      <div className="num flex justify-between text-[10px] text-muted">
        <span>00</span>
        <span>06</span>
        <span>12</span>
        <span>18</span>
        <span>23</span>
      </div>
    </div>
  );
}

/// Live indicator dot on the recent-check-ins list. Pulses gently
/// while the scan is genuinely fresh (≤ 60 s), goes solid for
/// "today" rows, fades for older. Gives a partner glancing at the
/// list a second-channel cue beyond the timestamp.
function RecencyDot({ scannedAt }: { scannedAt: string }) {
  const ageMs = Date.now() - new Date(scannedAt).getTime();
  if (!Number.isFinite(ageMs)) {
    return <span className="dot bg-line" aria-hidden />;
  }
  if (ageMs < 60_000) {
    return (
      <span
        className="relative inline-flex h-2 w-2 shrink-0"
        aria-label="just now"
      >
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-60" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
      </span>
    );
  }
  if (ageMs < 24 * 60 * 60_000) {
    return <span className="dot bg-accent" aria-hidden />;
  }
  return <span className="dot bg-line-2" aria-hidden />;
}
