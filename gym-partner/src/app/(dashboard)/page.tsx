import { getFormatter, getTranslations } from "next-intl/server";

import { ChartPanel } from "@/components/dashboard/ChartPanel";
import { LaneChart } from "@/components/dashboard/LaneChart";
import { Panel } from "@/components/dashboard/Panel";
import { RecencyDot } from "@/components/dashboard/RecencyDot";
import { TierBreakdown } from "@/components/dashboard/TierBreakdown";
import { PeriodSelector } from "@/components/PeriodSelector";
import { QuietFloor } from "@/components/QuietFloor";
import { StatTile } from "@/components/StatTile";
import { isPeriodPreset, type PeriodPreset } from "@/lib/period";
import { PartnerSDK } from "@/lib/sdk";

/// Resolve URL search params into a (since, until) window. `30d` is
/// the default — generous enough to populate the trend chart, short
/// enough that the numbers reflect recent activity rather than
/// lifetime data.
function resolvePeriodWindow(
  preset: PeriodPreset,
  fromParam: string | undefined,
  toParam: string | undefined,
): { since: string; until: string; preset: PeriodPreset } {
  const now = new Date();
  const startOfToday = new Date(now);
  startOfToday.setUTCHours(0, 0, 0, 0);

  if (preset === "today") {
    return {
      since: startOfToday.toISOString(),
      until: now.toISOString(),
      preset,
    };
  }
  if (preset === "week") {
    const since = new Date(startOfToday);
    since.setUTCDate(since.getUTCDate() - 6);
    return { since: since.toISOString(), until: now.toISOString(), preset };
  }
  if (preset === "90d") {
    const since = new Date(startOfToday);
    since.setUTCDate(since.getUTCDate() - 89);
    return { since: since.toISOString(), until: now.toISOString(), preset };
  }
  if (preset === "custom" && fromParam && toParam) {
    // Date inputs return YYYY-MM-DD — anchor to UTC midnight at both
    // ends, then push `until` to end-of-day so the closing date is
    // included rather than truncated at 00:00.
    const since = new Date(`${fromParam}T00:00:00.000Z`);
    const until = new Date(`${toParam}T23:59:59.999Z`);
    if (
      Number.isFinite(since.getTime()) &&
      Number.isFinite(until.getTime()) &&
      since <= until
    ) {
      return { since: since.toISOString(), until: until.toISOString(), preset };
    }
  }
  // Fall-through default: 30d.
  const since = new Date(startOfToday);
  since.setUTCDate(since.getUTCDate() - 29);
  return { since: since.toISOString(), until: now.toISOString(), preset: "30d" };
}

function formatJod(value: string | number, opts?: { compact?: boolean }) {
  const num = typeof value === "string" ? Number.parseFloat(value) : value;
  if (!Number.isFinite(num)) return `${value}`;
  if (opts?.compact && Math.abs(num) >= 1000) {
    return `${(num / 1000).toFixed(num >= 10000 ? 0 : 1)}k`;
  }
  // Currency totals stay in en-US digits — the design spec calls for
  // Western digits in both locales (Jordanian convention for modern
  // apps), and the JOD label sits next to the number anyway.
  return num.toLocaleString("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  });
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

export default async function PartnerDashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string; from?: string; to?: string }>;
}) {
  const t = await getTranslations("dashboard");
  const tPeriod = await getTranslations("dashboard.period");
  const sp = await searchParams;
  const preset: PeriodPreset = isPeriodPreset(sp.period) ? sp.period : "30d";
  const { since, until, preset: resolvedPreset } = resolvePeriodWindow(
    preset,
    sp.from,
    sp.to,
  );
  // Locale-aware date/time formatter. Previously a hardcoded
  // `toLocaleString("en-GB", ...)` call rendered Arabic users a
  // British-English timestamp (`09 May 25, 14:30`) regardless of
  // their UI locale. `getFormatter` honours the request locale so
  // Arabic readers see Arabic month names and the numeric grouping
  // that next-intl is configured to emit.
  const format = await getFormatter();
  const formatRecent = (iso: string): string => {
    try {
      return format.dateTime(new Date(iso), {
        day: "2-digit",
        month: "short",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return iso;
    }
  };
  const m = await PartnerSDK.metrics({ since, until });
  // Label suffix surfaced on the period-scoped tiles ("Reps · MTD",
  // "Reps · 30d", etc.). Driven by the resolved preset so a custom
  // range still gets a meaningful label.
  const periodSuffix = tPeriod(resolvedPreset);

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

  return (
    <section className="flex flex-col gap-6">
      <header className="flex flex-col gap-4 border-b border-line pb-5">
        <div className="flex flex-col gap-2">
          <h1 className="gauge text-[36px] text-paper">{t("title")}</h1>
          <p className="text-[13px] text-muted">{t("subtitle")}</p>
        </div>
        <PeriodSelector
          current={resolvedPreset}
          from={sp.from}
          to={sp.to}
        />
      </header>

      {/* KPI grid. Each tile that depends on the active period uses
       *  the period-suffix substitution so the label always tells
       *  the truth about which window the number reflects.
       *  `checkinsToday` and `pendingPayout` always show "today" /
       *  "right now" — they don't depend on the selector. */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
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
          label={t("checkinsPeriod", { period: periodSuffix })}
          value={m.checkinsThisMonth}
          delta={checkinsWoW}
          trend={{
            points: checkinsSeries.slice(-14),
            ariaLabel: t("trendCheckinsAria"),
          }}
        />
        <StatTile
          label={t("uniqueMembers", { period: periodSuffix })}
          value={m.uniqueMembersLast30Days}
        />
        <StatTile
          label={t("revenuePeriod", { period: periodSuffix })}
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
          label={t("paidPeriod", { period: periodSuffix })}
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

      {/* Distributions — tier mix + recent activity. The "busy hours"
       *  strip was here too but partners said it wasn't actionable
       *  (they already know their busy hours from being on the floor)
       *  so it's gone along with the occupancy bar in the header. */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <Panel title={t("tierMix")}>
          <TierBreakdown
            tiers={m.tierBreakdown}
            total={m.checkinsLast30Days}
            empty={t("noDataTiers")}
          />
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
                    {formatRecent(c.scannedAt)}
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
