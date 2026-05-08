import { getTranslations } from "next-intl/server";

import { StatTile } from "@/components/StatTile";
import { Toolbar } from "@/components/Toolbar";
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

export default async function PartnerDashboardPage() {
  const t = await getTranslations("dashboard");
  const m = await PartnerSDK.metrics();

  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />

      {/* KPI grid */}
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-7">
        <StatTile
          label={t("checkinsToday")}
          value={m.checkinsToday.toLocaleString()}
        />
        <StatTile
          label={t("checkinsThisMonth")}
          value={m.checkinsThisMonth.toLocaleString()}
        />
        <StatTile
          label={t("checkinsLast30")}
          value={m.checkinsLast30Days.toLocaleString()}
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
        >
          <AreaChart
            points={m.checkinsPerDay.map((d) => d.count)}
            labels={m.checkinsPerDay.map((d) => d.day)}
            empty={t("noData")}
          />
        </ChartPanel>
        <ChartPanel
          title={t("revenueTrend")}
          subtitle={t("checkinsLast30")}
          total={formatJod(
            m.revenuePerDay.reduce(
              (a, b) => a + Number.parseFloat(b.total || "0"),
              0,
            ),
            { compact: true },
          )}
          unit={t("jod")}
        >
          <AreaChart
            points={m.revenuePerDay.map((d) => Number.parseFloat(d.total))}
            labels={m.revenuePerDay.map((d) => d.day)}
            empty={t("noData")}
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
        <Panel title={t("hourMix")}>
          <HourBars hours={m.hourBreakdown} empty={t("noData")} />
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
                  className="flex items-center gap-3 rounded-md px-1 py-2 hover:bg-line/40"
                >
                  <span className="dot bg-accent" />
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
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="panel p-4">
      <header className="mb-3">
        <h2 className="h2">{title}</h2>
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
  children,
}: {
  title: string;
  subtitle?: string;
  total: number | string;
  unit?: string;
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
      </header>
      {children}
    </section>
  );
}

function AreaChart({
  points,
  labels,
  empty,
}: {
  points: number[];
  labels: string[];
  empty: string;
}) {
  if (points.length === 0) {
    return (
      <div className="flex h-36 items-center justify-center rounded-md border border-dashed border-line">
        <p className="label">{empty}</p>
      </div>
    );
  }
  const max = Math.max(...points, 1);
  const w = 600;
  const h = 120;
  const stepX = w / Math.max(1, points.length - 1);
  const coords = points.map((p, i) => {
    const x = i * stepX;
    const y = h - (p / max) * (h - 8) - 4;
    return { x, y };
  });
  const line = coords
    .map((c, i) => `${i === 0 ? "M" : "L"}${c.x.toFixed(1)},${c.y.toFixed(1)}`)
    .join(" ");
  const area = `${line} L${w},${h} L0,${h} Z`;
  return (
    <div>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="h-32 w-full"
        preserveAspectRatio="none"
      >
        <defs>
          <linearGradient id="partnerAreaFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="rgb(var(--c-accent))" stopOpacity="0.22" />
            <stop offset="100%" stopColor="rgb(var(--c-accent))" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={0}
            x2={w}
            y1={h * f}
            y2={h * f}
            stroke="rgb(var(--c-line))"
            strokeWidth="1"
          />
        ))}
        <path d={area} fill="url(#partnerAreaFill)" />
        <path
          d={line}
          fill="none"
          stroke="rgb(var(--c-accent))"
          strokeWidth="1.75"
          strokeLinejoin="round"
        />
      </svg>
      <div className="mt-2 flex justify-between text-[10.5px] text-muted num">
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
            <span className="w-14 capitalize text-muted">{tier}</span>
            <div className="relative h-1 flex-1 overflow-hidden rounded-full bg-line">
              <div
                className="absolute inset-y-0 left-0 rounded-full bg-accent"
                style={{ width: `${pct}%` }}
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

function HourBars({
  hours,
  empty,
}: {
  hours: PartnerDashboardMetrics["hourBreakdown"];
  empty: string;
}) {
  if (hours.length === 0) {
    return <p className="py-4 text-center text-[12px] text-muted">{empty}</p>;
  }
  // Backend returns UTC hours; Jordan sits at UTC+3 year-round (no DST),
  // so a single +3 shift gives the partner a local-clock view.
  const buckets = new Array<number>(24).fill(0);
  for (const { hour, count } of hours) {
    const local = (hour + 3) % 24;
    buckets[local] += count;
  }
  const max = Math.max(...buckets, 1);
  return (
    <div className="flex h-24 items-end gap-[2px]">
      {buckets.map((v, i) => (
        <div
          key={i}
          className="flex-1 rounded-sm bg-accent/80"
          style={{ height: `${Math.max(4, (v / max) * 100)}%` }}
          title={`${i.toString().padStart(2, "0")}:00 — ${v}`}
        />
      ))}
    </div>
  );
}
