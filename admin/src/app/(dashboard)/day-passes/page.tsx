import { getTranslations } from "next-intl/server";

import ConfigureDayPassOffering from "@/components/ConfigureDayPassOffering";
import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import RefundDayPassButton from "@/components/RefundDayPassButton";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import {
  AdminSDK,
  type AdminDayPassOfferingConfigure,
  type DayPassStatus,
} from "@/lib/sdk";

type SearchParams = { status?: string; page?: string };

const PAGE_SIZE = 25;
const STATUSES = [
  "pending",
  "active",
  "used",
  "expired",
  "refunded",
] as const;

const STATUS_TONE: Record<DayPassStatus, "ok" | "warn" | "mute" | "bad"> = {
  pending: "warn",
  active: "ok",
  used: "mute",
  expired: "mute",
  refunded: "bad",
};

function parseStatus(value: string | undefined): DayPassStatus | undefined {
  return STATUSES.includes(value as DayPassStatus)
    ? (value as DayPassStatus)
    : undefined;
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

export default async function DayPassesPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const t = await getTranslations("dayPasses");
  const tStatuses = await getTranslations("dayPassStatuses");
  const status = parseStatus(params.status);
  const page = parsePage(params.page);

  const [offeringsPage, passesPage] = await Promise.all([
    AdminSDK.listDayPassOfferings({ page: 1, pageSize: 100 }),
    AdminSDK.listDayPasses({ status, page, pageSize: PAGE_SIZE }),
  ]);

  async function configureOffering(
    gymId: string,
    body: AdminDayPassOfferingConfigure,
  ) {
    "use server";
    return runAction(() => AdminSDK.configureDayPassOffering(gymId, body));
  }
  async function refundPass(passId: string) {
    "use server";
    return runAction(() => AdminSDK.refundDayPass(passId));
  }

  const totalPages = Math.max(1, Math.ceil(passesPage.total / passesPage.pageSize));
  const enabledOfferings = offeringsPage.items.filter((o) => o.isEnabled).length;

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = { ...params, ...overrides };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/day-passes?${s}` : "/day-passes";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar title={t("title")} description={t("description")} />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        <StatTile label={t("stats.offerings")} value={offeringsPage.total} />
        <StatTile
          label={t("stats.enabled")}
          value={enabledOfferings}
          tone="ok"
        />
        <StatTile label={t("stats.passesSold")} value={passesPage.total} />
      </div>

      {/* Offerings */}
      <div className="flex flex-col gap-2">
        <h2 className="h2">{t("offeringsTitle")}</h2>
        {offeringsPage.items.length === 0 ? (
          <EmptyState
            title={t("offeringsEmpty.title")}
            hint={t("offeringsEmpty.hint")}
          />
        ) : (
          <div className="panel overflow-visible">
            <table className="table">
              <thead>
                <tr>
                  <th>{t("table.gym")}</th>
                  <th>{t("table.status")}</th>
                  <th className="num">{t("table.price")}</th>
                  <th className="num">{t("table.feePct")}</th>
                  <th className="num">{t("table.validity")}</th>
                  <th className="num">{t("table.cap")}</th>
                  <th className="w-0" />
                </tr>
              </thead>
              <tbody>
                {offeringsPage.items.map((o) => (
                  <tr key={o.id}>
                    <td className="min-w-0">
                      <span className="truncate text-paper">{o.gymNameEn}</span>
                    </td>
                    <td>
                      <StatusPill tone={o.isEnabled ? "ok" : "mute"}>
                        {o.isEnabled ? t("on") : t("off")}
                      </StatusPill>
                    </td>
                    <td className="num">{o.priceJod}</td>
                    <td className="num">{o.platformFeePct}%</td>
                    <td className="num">{o.validityHours}h</td>
                    <td className="num">{o.dailyCap ?? "∞"}</td>
                    <td className="text-right">
                      <ConfigureDayPassOffering
                        offering={o}
                        action={configureOffering.bind(null, o.gymId)}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Sold passes */}
      <div className="flex flex-col gap-2">
        <h2 className="h2">{t("passesTitle")}</h2>
        <FilterBar>
          <Segmented
            value={status}
            options={STATUSES}
            labelFor={(s) => tStatuses(s)}
            hrefFor={(s) => hrefFor({ status: s, page: undefined })}
          />
        </FilterBar>

        {passesPage.items.length === 0 ? (
          <EmptyState
            title={t("passesEmpty.title")}
            hint={t("passesEmpty.hint")}
          />
        ) : (
          <div className="panel overflow-hidden">
            <table className="table">
              <thead>
                <tr>
                  <th>{t("table.member")}</th>
                  <th>{t("table.gym")}</th>
                  <th>{t("table.status")}</th>
                  <th className="num">{t("table.price")}</th>
                  <th className="num">{t("table.net")}</th>
                  <th>{t("table.window")}</th>
                  <th className="w-0" />
                </tr>
              </thead>
              <tbody>
                {passesPage.items.map((p) => (
                  <tr key={p.id}>
                    <td className="min-w-0">
                      <span className="truncate text-paper">
                        {p.userName ?? p.userPhone ?? p.userId.slice(0, 8)}
                      </span>
                    </td>
                    <td className="truncate">{p.gymNameEn}</td>
                    <td>
                      <StatusPill tone={STATUS_TONE[p.status]}>
                        {tStatuses(p.status)}
                      </StatusPill>
                    </td>
                    <td className="num">{p.priceJod}</td>
                    <td className="num text-muted">{p.netAmountJod}</td>
                    <td className="num text-muted text-[12px] whitespace-nowrap">
                      {formatDate(p.purchasedAt)} → {formatDate(p.expiresAt)}
                    </td>
                    <td className="text-right">
                      {p.status === "active" ||
                      p.status === "pending" ||
                      p.status === "expired" ? (
                        <RefundDayPassButton
                          action={refundPass.bind(null, p.id)}
                        />
                      ) : (
                        <span className="text-[11px] text-muted">—</span>
                      )}
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
          total={passesPage.total}
          hrefFor={(target) => hrefFor({ page: String(target) })}
        />
      </div>
    </section>
  );
}
