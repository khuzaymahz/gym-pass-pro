import Link from "next/link";
import { getTranslations } from "next-intl/server";

import CancelSubscriptionButton from "@/components/CancelSubscriptionButton";
import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import ManageSubscription from "@/components/ManageSubscription";
import Pager from "@/components/Pager";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type SubscriptionStatus, type Tier } from "@/lib/sdk";

type SearchParams = {
  status?: string;
  tier?: string;
  q?: string;
  page?: string;
};

const PAGE_SIZE = 25;
const STATUSES = ["pending", "active", "expired", "cancelled"] as const;
const TIERS = ["silver", "gold", "platinum", "diamond"] as const;

const STATUS_TONE: Record<SubscriptionStatus, "ok" | "warn" | "mute" | "bad"> = {
  pending: "warn",
  active: "ok",
  expired: "mute",
  cancelled: "bad",
};

function parseStatus(value: string | undefined): SubscriptionStatus | undefined {
  return STATUSES.includes(value as SubscriptionStatus)
    ? (value as SubscriptionStatus)
    : undefined;
}
function parseTier(value: string | undefined): Tier | undefined {
  return TIERS.includes(value as Tier) ? (value as Tier) : undefined;
}
function parsePage(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? "1", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
}
function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "2-digit",
    });
  } catch {
    return iso.slice(0, 10);
  }
}

export default async function SubscriptionsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const t = await getTranslations("subscriptions");
  const tStats = await getTranslations("subscriptions.stats");
  const tTable = await getTranslations("subscriptions.table");
  const tEmpty = await getTranslations("subscriptions.empty");
  const tFilters = await getTranslations("subscriptions.filters");
  const tStatuses = await getTranslations("subscriptionStatuses");
  const status = parseStatus(params.status);
  const tier = parseTier(params.tier);
  const q = params.q?.trim() || undefined;
  const page = parsePage(params.page);

  const result = await AdminSDK.listSubscriptions({
    status,
    tier,
    q,
    page,
    pageSize: PAGE_SIZE,
  });

  async function cancel(id: string) {
    "use server";
    return runAction(() => AdminSDK.cancelSubscription(id));
  }
  async function extend(id: string, days: number) {
    "use server";
    return runAction(() => AdminSDK.extendSubscription(id, days));
  }
  async function setVisits(id: string, visitsUsed: number) {
    "use server";
    return runAction(() => AdminSDK.setSubscriptionVisits(id, visitsUsed));
  }
  async function changeTier(id: string, tier: Tier) {
    "use server";
    return runAction(() => AdminSDK.changeSubscriptionTier(id, tier));
  }
  async function restore(id: string) {
    "use server";
    return runAction(() => AdminSDK.restoreSubscription(id));
  }
  async function resumePause(id: string) {
    "use server";
    return runAction(() => AdminSDK.resumeSubscriptionPause(id));
  }

  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));
  const activeCount = result.items.filter((s) => s.status === "active").length;
  const pendingCount = result.items.filter((s) => s.status === "pending").length;
  const expiredCount = result.items.filter((s) => s.status === "expired").length;
  const cancelledCount = result.items.filter(
    (s) => s.status === "cancelled",
  ).length;

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = { ...params, ...overrides };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/subscriptions?${s}` : "/subscriptions";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: t("found"), value: result.total.toLocaleString() }}
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        <StatTile label={tStats("active")} value={activeCount} tone="ok" />
        <StatTile
          label={tStats("pending")}
          value={pendingCount}
          tone={pendingCount > 0 ? "warn" : "default"}
        />
        <StatTile label={tStats("expired")} value={expiredCount} />
        <StatTile
          label={tStats("cancelled")}
          value={cancelledCount}
          tone={cancelledCount > 0 ? "bad" : "default"}
        />
      </div>

      <FilterBar>
        <Segmented
          value={status}
          options={STATUSES}
          labelFor={(s) => tStatuses(s)}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
        />
        <Segmented
          value={tier}
          options={TIERS}
          labelFor={(t) => t.charAt(0).toUpperCase() + t.slice(1)}
          hrefFor={(t) => hrefFor({ tier: t, page: undefined })}
          allLabel={tFilters("allTiers")}
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={q}
            placeholder={tFilters("search")}
            action="/subscriptions"
            hidden={{ status: params.status, tier: params.tier }}
          />
        </div>
      </FilterBar>

      {result.items.length === 0 ? (
        <EmptyState title={tEmpty("title")} hint={tEmpty("hint")} />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>{tTable("member")}</th>
                <th>{tTable("tier")}</th>
                <th>{tTable("status")}</th>
                <th>{tTable("window")}</th>
                <th className="num">{tTable("visits")}</th>
                <th>{tTable("renew")}</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {result.items.map((s) => (
                <tr key={s.id}>
                  <td className="min-w-0">
                    <Link
                      href={`/users/${s.userId}`}
                      className="flex min-w-0 flex-col leading-tight hover:text-lime"
                    >
                      <span className="truncate text-paper">
                        {s.userName ??
                          s.userEmail ??
                          s.userPhone ??
                          s.userId.slice(0, 8)}
                      </span>
                      <span className="truncate text-[11px] text-muted">
                        {s.userEmail ?? s.userPhone ?? s.id.slice(0, 8)}
                      </span>
                    </Link>
                  </td>
                  <td>
                    <span className="kbd capitalize">{s.tier}</span>
                  </td>
                  <td>
                    <StatusPill tone={STATUS_TONE[s.status]}>
                      {tStatuses(s.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-muted text-[12px] whitespace-nowrap">
                    {formatDate(s.startsAt)} → {formatDate(s.expiresAt)}
                  </td>
                  <td className="num">{s.visitsUsed}</td>
                  <td>
                    <span
                      className={`kbd ${s.autoRenew ? "text-lime" : "text-muted"}`}
                    >
                      {s.autoRenew ? tTable("on") : tTable("off")}
                    </span>
                  </td>
                  <td className="text-right">
                    <div className="flex items-center justify-end gap-2">
                      <ManageSubscription
                        sub={{
                          id: s.id,
                          status: s.status,
                          tier: s.tier,
                          visitsUsed: s.visitsUsed,
                        }}
                        extend={extend.bind(null, s.id)}
                        setVisits={setVisits.bind(null, s.id)}
                        changeTier={changeTier.bind(null, s.id)}
                        restore={restore.bind(null, s.id)}
                        resumePause={resumePause.bind(null, s.id)}
                      />
                      {s.status === "active" || s.status === "pending" ? (
                        <CancelSubscriptionButton
                          action={cancel.bind(null, s.id)}
                        />
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Pager
        page={page}
        totalPages={totalPages}
        total={result.total}
        hrefFor={(target) => hrefFor({ page: String(target) })}
      />
    </section>
  );
}
