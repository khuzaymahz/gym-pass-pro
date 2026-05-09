import Link from "next/link";
import { getTranslations } from "next-intl/server";

import AreaChart from "@/components/dashboard/AreaChart";
import AttentionStrip from "@/components/dashboard/AttentionStrip";
import BarStrip from "@/components/dashboard/BarStrip";
import ChartPanel from "@/components/dashboard/ChartPanel";
import HealthRow from "@/components/dashboard/HealthRow";
import Panel from "@/components/dashboard/Panel";
import RecentCheckins from "@/components/dashboard/RecentCheckins";
import RecentSignups from "@/components/dashboard/RecentSignups";
import TierBreakdown from "@/components/dashboard/TierBreakdown";
import TopGyms from "@/components/dashboard/TopGyms";
import StatTile from "@/components/StatTile";
import Toolbar from "@/components/Toolbar";
import { AdminSDK } from "@/lib/sdk";

function formatJod(value: string | number, opts?: { compact?: boolean }): string {
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

function deltaPct(current: string, previous: string): number | null {
  const c = Number.parseFloat(current);
  const p = Number.parseFloat(previous);
  if (!Number.isFinite(c) || !Number.isFinite(p) || p === 0) return null;
  return ((c - p) / p) * 100;
}

export default async function DashboardPage() {
  const m = await AdminSDK.dashboard();
  const t = await getTranslations("dashboard");
  const revenueDelta = deltaPct(m.revenueMtdJod, m.revenuePreviousMonthJod);

  const signups30dTotal = m.signupsLast30Days.reduce((a, b) => a + b.count, 0);
  const checkins30dTotal = m.checkinsLast30Days.reduce(
    (a, b) => a + b.count,
    0,
  );
  const revenue30dTotal = m.revenueLast30Days.reduce(
    (a, b) => a + Number.parseFloat(b.total || "0"),
    0,
  );

  return (
    <section className="flex flex-col gap-6">
      <Toolbar
        title={t("title")}
        description={t("description")}
        actions={<HealthRow health={m.systemHealth} />}
      />

      {(m.urgentTicketCount > 0 ||
        m.openTicketCount > 0 ||
        m.expiringSubscriptionsCount > 0) && <AttentionStrip m={m} />}

      {/* Stat grid ------------------------------------------------ */}
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        <StatTile
          label={t("stats.members")}
          value={m.memberCount.toLocaleString()}
          sub={t("stats.membersSub", { count: signups30dTotal })}
        />
        <StatTile
          label={t("stats.activeSubs")}
          value={m.activeSubscriptions.toLocaleString()}
          sub={t("stats.activeSubsSub", {
            count: m.expiringSubscriptionsCount,
          })}
          tone={m.expiringSubscriptionsCount > 0 ? "warn" : "default"}
        />
        <StatTile label={t("stats.gyms")} value={m.gymCount.toLocaleString()} />
        <StatTile
          label={t("stats.checkinsToday")}
          value={m.checkinsToday.toLocaleString()}
          sub={t("stats.checkinsTodaySub", {
            count: m.checkinsThisMonth.toLocaleString(),
          })}
        />
        <StatTile
          label={t("stats.pendingPayouts")}
          value={formatJod(m.pendingPayoutTotalJod, { compact: true })}
          unit="JOD"
        />
        <StatTile
          label={t("stats.revenueMtd")}
          value={formatJod(m.revenueMtdJod, { compact: true })}
          unit="JOD"
          tone={
            revenueDelta === null
              ? "default"
              : revenueDelta >= 0
                ? "ok"
                : "bad"
          }
          sub={
            revenueDelta === null
              ? t("noPriorMonth")
              : t("stats.revenueDeltaSub", {
                  sign: revenueDelta >= 0 ? "+" : "",
                  delta: revenueDelta.toFixed(1),
                })
          }
        />
      </div>

      {/* Charts row ----------------------------------------------- */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
        <ChartPanel
          className="lg:col-span-2"
          title={t("panels.checkins")}
          subtitle={t("panels.last30Days")}
          total={checkins30dTotal}
        >
          <AreaChart
            points={m.checkinsLast30Days.map((d) => d.count)}
            labels={m.checkinsLast30Days.map((d) => d.day)}
          />
        </ChartPanel>
        <ChartPanel
          title={t("panels.revenue")}
          subtitle={t("panels.last30Days")}
          total={formatJod(revenue30dTotal, { compact: true })}
          unit="JOD"
        >
          <AreaChart
            points={m.revenueLast30Days.map((d) => Number.parseFloat(d.total))}
            labels={m.revenueLast30Days.map((d) => d.day)}
          />
        </ChartPanel>
      </div>

      {/* Secondary row ------------------------------------------- */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
        <Panel title={t("panels.signups")} subtitle={t("panels.last30Days")}>
          <BarStrip points={m.signupsLast30Days.map((d) => d.count)} />
          <div className="mt-3 flex items-baseline justify-between text-[11.5px] text-muted num">
            <span>
              Σ <span className="text-paper">{signups30dTotal}</span>
            </span>
            <Link href="/users" className="hover:text-lime">
              {t("feeds.allUsers")} →
            </Link>
          </div>
        </Panel>

        <Panel title={t("panels.tierSplit")}>
          <TierBreakdown
            tiers={m.subscriptionsByTier}
            total={m.activeSubscriptions}
          />
        </Panel>

        <Panel title={t("panels.topGyms")} subtitle={t("panels.topGymsSub")}>
          <TopGyms gyms={m.topGymsByCheckins} />
        </Panel>
      </div>

      {/* Feed row ------------------------------------------------- */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <Panel
          title={t("panels.recentSignups")}
          linkHref="/users"
          linkLabel={t("feeds.allUsers")}
        >
          <RecentSignups users={m.recentSignups} />
        </Panel>
        <Panel
          title={t("panels.recentCheckins")}
          linkHref="/checkins"
          linkLabel={t("feeds.allCheckins")}
        >
          <RecentCheckins checkins={m.recentCheckins} />
        </Panel>
      </div>
    </section>
  );
}
