import Link from "next/link";

import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { AdminSDK, type CheckinStatus, type DashboardMetrics } from "@/lib/sdk";

const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;

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

function deltaPct(current: string, previous: string): number | null {
  const c = Number.parseFloat(current);
  const p = Number.parseFloat(previous);
  if (!Number.isFinite(c) || !Number.isFinite(p) || p === 0) return null;
  return ((c - p) / p) * 100;
}

const CHECKIN_TONE: Record<CheckinStatus, "ok" | "warn" | "bad" | "mute"> = {
  success: "ok",
  tier_locked: "warn",
  no_visits: "warn",
  expired: "bad",
  invalid_qr: "bad",
  rate_limited: "bad",
};

export default async function DashboardPage() {
  const m = await AdminSDK.dashboard();
  const revenueDelta = deltaPct(m.revenueMtdJod, m.revenuePreviousMonthJod);

  return (
    <section className="flex flex-col gap-6">
      <Toolbar
        title="Dashboard"
        description="Operations overview for the current workspace."
        actions={<HealthRow health={m.systemHealth} />}
      />

      {(m.urgentTicketCount > 0 ||
        m.openTicketCount > 0 ||
        m.expiringSubscriptionsCount > 0) && <AttentionStrip m={m} />}

      {/* Stat grid ------------------------------------------------ */}
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        <StatTile
          label="Members"
          value={m.memberCount.toLocaleString()}
          sub={`${m.signupsLast30Days.reduce((a, b) => a + b.count, 0)} in 30d`}
        />
        <StatTile
          label="Active subs"
          value={m.activeSubscriptions.toLocaleString()}
          sub={`${m.expiringSubscriptionsCount} expiring ≤7d`}
          tone={m.expiringSubscriptionsCount > 0 ? "warn" : "default"}
        />
        <StatTile label="Gyms" value={m.gymCount.toLocaleString()} />
        <StatTile
          label="Check-ins · today"
          value={m.checkinsToday.toLocaleString()}
          sub={`${m.checkinsThisMonth.toLocaleString()} MTD`}
        />
        <StatTile
          label="Pending payouts"
          value={formatJod(m.pendingPayoutTotalJod, { compact: true })}
          unit="JOD"
        />
        <StatTile
          label="Revenue · MTD"
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
              ? "No prior month"
              : `${revenueDelta >= 0 ? "+" : ""}${revenueDelta.toFixed(1)}% vs prev`
          }
        />
      </div>

      {/* Charts row ----------------------------------------------- */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-3">
        <ChartPanel
          className="lg:col-span-2"
          title="Check-ins"
          subtitle="Last 30 days"
          total={m.checkinsLast30Days.reduce((a, b) => a + b.count, 0)}
        >
          <AreaChart
            points={m.checkinsLast30Days.map((d) => d.count)}
            labels={m.checkinsLast30Days.map((d) => d.day)}
          />
        </ChartPanel>
        <ChartPanel
          title="Revenue"
          subtitle="Last 30 days"
          total={formatJod(
            m.revenueLast30Days.reduce(
              (a, b) => a + Number.parseFloat(b.total || "0"),
              0,
            ),
            { compact: true },
          )}
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
        <Panel title="Signups" subtitle="Last 30 days">
          <BarStrip points={m.signupsLast30Days.map((d) => d.count)} />
          <div className="mt-3 flex items-baseline justify-between text-[11.5px] text-muted num">
            <span>
              Σ{" "}
              <span className="text-paper">
                {m.signupsLast30Days.reduce((a, b) => a + b.count, 0)}
              </span>
            </span>
            <Link href="/users" className="hover:text-lime">
              View all →
            </Link>
          </div>
        </Panel>

        <Panel title="Active subs · tier split">
          <TierBreakdown
            tiers={m.subscriptionsByTier}
            total={m.activeSubscriptions}
          />
        </Panel>

        <Panel title="Top gyms" subtitle="MTD check-ins">
          <TopGyms gyms={m.topGymsByCheckins} />
        </Panel>
      </div>

      {/* Feed row ------------------------------------------------- */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <Panel title="Recent signups" linkHref="/users" linkLabel="All users">
          <RecentSignups users={m.recentSignups} />
        </Panel>
        <Panel
          title="Recent check-ins"
          linkHref="/checkins"
          linkLabel="All check-ins"
        >
          <RecentCheckins checkins={m.recentCheckins} />
        </Panel>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------- */
/* Components                                                           */
/* -------------------------------------------------------------------- */

function HealthRow({
  health,
}: {
  health: { db: string; redis: string; api: string };
}) {
  const entries = Object.entries(health);
  const allOk = entries.every(([, v]) => v === "ok");
  return (
    <div className="flex items-center gap-1.5">
      <StatusPill tone={allOk ? "ok" : "bad"}>
        {allOk ? "All systems" : "Degraded"}
      </StatusPill>
      <div className="hidden items-center gap-2 px-2 text-[11px] text-muted md:flex">
        {entries.map(([k, v]) => {
          const ok = v === "ok";
          return (
            <span key={k} className="flex items-center gap-1">
              <span
                className={`dot ${ok ? "bg-lime" : "bg-red-400"}`}
              />
              <span className="uppercase tracking-wide">{k}</span>
            </span>
          );
        })}
      </div>
    </div>
  );
}

function AttentionStrip({ m }: { m: DashboardMetrics }) {
  const items: {
    label: string;
    value: number;
    tone: "ok" | "warn" | "bad";
    href: string;
  }[] = [];
  if (m.urgentTicketCount > 0)
    items.push({
      label: "urgent tickets",
      value: m.urgentTicketCount,
      tone: "bad",
      href: "/support?priority=urgent",
    });
  if (m.openTicketCount > 0)
    items.push({
      label: "open tickets",
      value: m.openTicketCount,
      tone: "warn",
      href: "/support?status=open",
    });
  if (m.expiringSubscriptionsCount > 0)
    items.push({
      label: "subs expiring ≤7d",
      value: m.expiringSubscriptionsCount,
      tone: "warn",
      href: "/subscriptions",
    });

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-amber-400/20 bg-amber-400/[0.04] px-4 py-2.5">
      <div className="flex flex-wrap items-center gap-2">
        <span className="label text-amber-300/90">Needs attention</span>
        {items.map((it) => (
          <Link
            key={it.label}
            href={it.href}
            className="inline-flex items-center gap-1.5 text-[12.5px] text-paper hover:underline"
          >
            <StatusPill tone={it.tone} withDot={false}>
              <span className="num font-semibold">{it.value}</span>
              <span className="ml-1 opacity-80">{it.label}</span>
            </StatusPill>
          </Link>
        ))}
      </div>
      <Link
        href="/support"
        className="btn-secondary btn-sm"
      >
        Open queue →
      </Link>
    </div>
  );
}

function Panel({
  title,
  subtitle,
  linkHref,
  linkLabel,
  children,
  className = "",
}: {
  title: string;
  subtitle?: string;
  linkHref?: string;
  linkLabel?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={`panel p-4 ${className}`}>
      <header className="mb-3 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="h2">{title}</h2>
          {subtitle ? (
            <p className="mt-0.5 text-[11.5px] text-muted">{subtitle}</p>
          ) : null}
        </div>
        {linkHref ? (
          <Link
            href={linkHref}
            className="text-[11.5px] text-muted hover:text-lime"
          >
            {linkLabel ?? "View all"} →
          </Link>
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
  children,
  className = "",
}: {
  title: string;
  subtitle?: string;
  total: number | string;
  unit?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={`panel p-4 ${className}`}>
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
}: {
  points: number[];
  labels: string[];
}) {
  if (points.length === 0) {
    return (
      <div className="flex h-36 items-center justify-center rounded-md border border-dashed border-line">
        <p className="label">No data</p>
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
          <linearGradient id="areaFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#BBFB46" stopOpacity="0.22" />
            <stop offset="100%" stopColor="#BBFB46" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={0}
            x2={w}
            y1={h * f}
            y2={h * f}
            stroke="#1F1F23"
            strokeWidth="1"
          />
        ))}
        <path d={area} fill="url(#areaFill)" />
        <path
          d={line}
          fill="none"
          stroke="#BBFB46"
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

function BarStrip({ points }: { points: number[] }) {
  const slots = 30;
  const series = points.length >= slots
    ? points.slice(-slots)
    : [...Array(slots - points.length).fill(0), ...points];
  const total = series.reduce((a, b) => a + b, 0);
  if (total === 0) {
    return (
      <div className="flex h-16 items-center justify-center rounded-md border border-dashed border-line">
        <p className="label">No signups in window</p>
      </div>
    );
  }
  const max = Math.max(...series, 1);
  return (
    <div className="flex h-16 items-end gap-[2px]">
      {series.map((p, i) => (
        <div
          key={i}
          className={`flex-1 rounded-sm ${p === 0 ? "bg-line" : "bg-lime/80"}`}
          style={{ height: `${Math.max(6, (p / max) * 100)}%` }}
          title={`${p}`}
        />
      ))}
    </div>
  );
}

function TierBreakdown({
  tiers,
  total,
}: {
  tiers: Record<string, number>;
  total: number;
}) {
  return (
    <ul className="flex flex-col gap-2.5">
      {TIER_ORDER.map((tier) => {
        const count = tiers[tier] ?? 0;
        const pct = total > 0 ? (count / total) * 100 : 0;
        return (
          <li key={tier} className="flex items-center gap-3 text-[12px]">
            <span className="w-14 capitalize text-muted">{tier}</span>
            <div className="relative h-1 flex-1 overflow-hidden rounded-full bg-line">
              <div
                className="absolute inset-y-0 left-0 rounded-full bg-lime"
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

function TopGyms({
  gyms,
}: {
  gyms: { gymId: string; nameEn: string; count: number }[];
}) {
  if (gyms.length === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">
        Check-ins will rank gyms here.
      </p>
    );
  }
  const max = Math.max(...gyms.map((g) => g.count), 1);
  return (
    <ul className="flex flex-col gap-2">
      {gyms.slice(0, 6).map((g, i) => {
        const pct = (g.count / max) * 100;
        return (
          <li key={g.gymId}>
            <Link
              href={`/gyms/${g.gymId}`}
              className="group flex items-center gap-2.5 text-[12.5px]"
            >
              <span className="num w-5 text-right text-[11px] text-muted">
                {i + 1}
              </span>
              <span className="min-w-0 flex-1 truncate text-paper group-hover:text-lime">
                {g.nameEn}
              </span>
              <span className="relative hidden h-1 w-16 overflow-hidden rounded-full bg-line md:block">
                <span
                  className="absolute inset-y-0 left-0 rounded-full bg-lime/80"
                  style={{ width: `${pct}%` }}
                />
              </span>
              <span className="num w-8 text-right text-paper">{g.count}</span>
            </Link>
          </li>
        );
      })}
    </ul>
  );
}

function RecentSignups({
  users,
}: {
  users: {
    id: string;
    name: string | null;
    email: string | null;
    phone: string | null;
    createdAt: string;
  }[];
}) {
  if (users.length === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">No members yet.</p>
    );
  }
  return (
    <ul className="-mx-1 flex flex-col">
      {users.map((u) => (
        <li key={u.id}>
          <Link
            href={`/users/${u.id}`}
            className="flex items-center gap-3 rounded-md px-1 py-2 hover:bg-line/40"
          >
            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-surface text-[11px] font-semibold uppercase text-muted">
              {(u.name ?? u.email ?? u.phone ?? u.id).slice(0, 2).toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] text-paper">
                {u.name ?? u.email ?? u.phone ?? u.id.slice(0, 8)}
              </p>
              <p className="truncate text-[11.5px] text-muted">
                {u.email ?? u.phone ?? "—"}
              </p>
            </div>
            <span className="num shrink-0 text-[11px] text-muted">
              {formatTime(u.createdAt)}
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}

function RecentCheckins({
  checkins,
}: {
  checkins: {
    id: string;
    userId: string;
    userName: string | null;
    gymNameEn: string;
    status: CheckinStatus;
    scannedAt: string;
  }[];
}) {
  if (checkins.length === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">
        No scans recorded.
      </p>
    );
  }
  return (
    <ul className="-mx-1 flex flex-col">
      {checkins.map((c) => {
        const tone = CHECKIN_TONE[c.status] ?? "mute";
        return (
          <li
            key={c.id}
            className="flex items-center gap-3 rounded-md px-1 py-2 hover:bg-line/40"
          >
            <span className={`dot ${toneToDot(tone)}`} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] text-paper">
                {c.userName ?? c.userId.slice(0, 8)}
              </p>
              <p className="truncate text-[11.5px] text-muted">
                {c.gymNameEn}
              </p>
            </div>
            <span className="shrink-0">
              <StatusPill tone={tone} withDot={false}>
                {c.status.replace("_", " ")}
              </StatusPill>
            </span>
            <span className="num shrink-0 text-[11px] text-muted">
              {formatTime(c.scannedAt)}
            </span>
          </li>
        );
      })}
    </ul>
  );
}

function toneToDot(tone: "ok" | "warn" | "bad" | "info" | "mute") {
  switch (tone) {
    case "ok":
      return "bg-lime";
    case "warn":
      return "bg-amber-300";
    case "bad":
      return "bg-red-400";
    case "info":
      return "bg-sky-400";
    default:
      return "bg-muted";
  }
}
