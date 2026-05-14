import { getFormatter, getTranslations } from "next-intl/server";

import { ChartPanel } from "@/components/dashboard/ChartPanel";
import { LaneChart } from "@/components/dashboard/LaneChart";
import { Panel } from "@/components/dashboard/Panel";
import { RecencyDot } from "@/components/dashboard/RecencyDot";
import { TierBreakdown } from "@/components/dashboard/TierBreakdown";
import { QuietFloor } from "@/components/QuietFloor";
import { StatTile } from "@/components/StatTile";
import { PartnerSDK } from "@/lib/sdk";

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

export default async function PartnerDashboardPage() {
  const t = await getTranslations("dashboard");
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

  return (
    <section className="flex flex-col gap-6">
      <header className="flex flex-col gap-2 border-b border-line pb-5">
        <h1 className="gauge text-[36px] text-paper">{t("title")}</h1>
        <p className="text-[13px] text-muted">{t("subtitle")}</p>
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
