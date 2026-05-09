import { getTranslations } from "next-intl/server";

import { OccupancyBar } from "@/components/OccupancyBar";
import { QuietFloor } from "@/components/QuietFloor";
import { StatTile } from "@/components/StatTile";
import { PartnerSDK, type PartnerDashboardMetrics } from "@/lib/sdk";

const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;

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

/// Week-over-week percent change. Returns null when there's not
/// enough data to compare (caller renders no delta).
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

  const checkinsSeries = m.checkinsPerDay.map((d) => d.count);
  const revenueSeries = m.revenuePerDay.map((d) =>
    Number.parseFloat(d.total || "0"),
  );
  const checkinsWoW = weekOverWeek(checkinsSeries);
  const revenueWoW = weekOverWeek(revenueSeries);
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

  const peakLast30 = checkinsSeries.length === 0 ? 0 : Math.max(...checkinsSeries);

  return (
    <section className="flex flex-col gap-6">
      {/* Top status strip — page title on the start, live occupancy
       *  bar on the end. The bar fills toward the 30-day peak and
       *  flips amber past 70% so a quick glance answers "are we
       *  busy right now?". */}
      <header className="flex flex-col gap-4 border-b border-line pb-5">
        <div className="flex items-baseline justify-between gap-4">
          <div>
            <h1 className="gauge text-[36px] text-paper">{t("title")}</h1>
            <p className="text-[13px] text-muted">{t("subtitle")}</p>
          </div>
        </div>
        <OccupancyBar today={m.checkinsToday} peakLast30={peakLast30} />
      </header>

      {/* KPI grid — gauge readouts. Static / cumulative tiles skip
       *  the sparkline and progress rail since their shape isn't a
       *  meaningful trend. */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-7">
        <StatTile
          label={t("checkinsToday")}
          value={m.checkinsToday}
          delta={todayDelta}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("checkinsThisMonth")}
          value={m.checkinsThisMonth}
          delta={checkinsWoW}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("checkinsLast30")}
          value={m.checkinsLast30Days}
          delta={checkinsWoW}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("uniqueMembers")}
          value={m.uniqueMembersLast30Days}
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

      {/* Trend charts — oscilloscope-style: lane-grid background +
       *  single luminous accent stroke, no gradient fill. */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <ChartPanel
          title={t("checkinsTrend")}
          subtitle={t("checkinsLast30")}
          total={m.checkinsLast30Days.toLocaleString()}
          delta={checkinsWoW}
        >
          <LaneChart
            points={checkinsSeries}
            labels={m.checkinsPerDay.map((d) => d.day)}
            empty={t("noDataCheckins")}
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
          <LaneChart
            points={revenueSeries}
            labels={m.revenuePerDay.map((d) => d.day)}
            empty={t("noDataRevenue")}
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
            empty={t("noDataTiers")}
          />
        </Panel>
        <Panel title={t("hourMix")} subtitle={t("hourMixSubtitle")}>
          <HourStrip hours={m.hourBreakdown} empty={t("noDataHours")} />
        </Panel>
        <Panel title={t("recentCheckins")}>
          {m.recentCheckins.length === 0 ? (
            <QuietFloor message={t("noCheckinsYet")} small />
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
                  <span className="num shrink-0 text-[10.5px] text-muted">
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
    <section className="steel rounded-lg p-5">
      <header className="mb-4">
        <h2 className="tracked text-[11.5px] text-muted">{title}</h2>
        {subtitle ? (
          <p className="mt-1 text-[12px] text-muted">{subtitle}</p>
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
    <section className="steel rounded-lg p-5">
      <header className="mb-4 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="tracked text-[11.5px] text-muted">{title}</h2>
          {subtitle ? (
            <p className="mt-1 text-[12px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        <div className="flex items-baseline gap-3">
          {delta != null ? <ChartDelta delta={delta} /> : null}
          <div className="flex items-baseline gap-1">
            <span className="gauge text-[28px] text-paper">{total}</span>
            {unit ? (
              <span className="tracked text-[11px] text-muted">{unit}</span>
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
  const flat = abs < 1;
  const color = flat
    ? "text-muted"
    : delta > 0
      ? "text-accent"
      : "text-red-400";
  const arrow = flat ? "—" : delta > 0 ? "▲" : "▼";
  return (
    <span className={`num text-[11px] font-medium ${color}`}>
      {arrow} {flat ? "—" : `${abs.toFixed(abs < 10 ? 1 : 0)}%`}
    </span>
  );
}

/// Oscilloscope-style chart. Lane-grid background, single luminous
/// accent stroke, no gradient fill. A thin "now" tick on the last
/// data point gives the eye an anchor without competing with the
/// stroke for attention.
function LaneChart({
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
        <QuietFloor message={empty} small />
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
  const last = coords[coords.length - 1];
  return (
    <div>
      <div className="lane-grid h-32 w-full overflow-hidden rounded-md border border-line/60">
        <svg
          viewBox={`0 0 ${w} ${h}`}
          className="h-full w-full"
          preserveAspectRatio="none"
          role={ariaLabel ? "img" : "presentation"}
          aria-label={ariaLabel}
        >
          <path
            d={line}
            fill="none"
            stroke="rgb(var(--c-accent))"
            strokeWidth="1.75"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
          {/* Now-tick on the most recent point. */}
          {Number.isFinite(last.x) ? (
            <>
              <line
                x1={last.x}
                x2={last.x}
                y1={pad}
                y2={h - pad}
                stroke="rgb(var(--c-accent))"
                strokeWidth="1"
                strokeDasharray="1 3"
                opacity="0.4"
              />
              <circle
                cx={last.x}
                cy={last.y}
                r="2.5"
                fill="rgb(var(--c-accent))"
                stroke="rgb(var(--c-ink))"
                strokeWidth="1.5"
              />
            </>
          ) : null}
        </svg>
      </div>
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
    return <QuietFloor message={empty} small />;
  }
  const denom = total > 0 ? total : sum;
  return (
    <ul className="flex flex-col gap-2.5">
      {TIER_ORDER.map((tier) => {
        const count = tiers[tier] ?? 0;
        const pct = denom > 0 ? (count / denom) * 100 : 0;
        return (
          <li key={tier} className="flex items-center gap-3 text-[12px]">
            <span className="tracked w-16 text-[10px] text-muted">{tier}</span>
            <div className="relative h-1.5 flex-1 overflow-hidden rounded-full bg-line">
              <div
                className="absolute inset-y-0 left-0 rounded-full bg-paper/45 transition-[width] duration-700 ease-out"
                style={{ width: `${pct}%` }}
              />
            </div>
            <span className="num w-10 text-right text-paper">{count}</span>
            <span className="num w-10 text-right text-[10.5px] text-muted">
              {pct.toFixed(0)}%
            </span>
          </li>
        );
      })}
    </ul>
  );
}

/// Hour-of-day strip styled as a heat row.
function HourStrip({
  hours,
  empty,
}: {
  hours: PartnerDashboardMetrics["hourBreakdown"];
  empty: string;
}) {
  if (hours.length === 0) {
    return <QuietFloor message={empty} small />;
  }
  const buckets = new Array<number>(24).fill(0);
  for (const { hour, count } of hours) {
    const local = (hour + 3) % 24;
    buckets[local] += count;
  }
  const max = Math.max(...buckets, 1);
  return (
    <div className="flex flex-col gap-2">
      <div className="flex h-9 items-stretch overflow-hidden rounded-md border border-line/60">
        {buckets.map((v, i) => {
          const intensity = v === 0 ? 0 : 0.18 + (v / max) * 0.82;
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
