import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { AdminSDK, type CheckinStatus } from "@/lib/sdk";

type SearchParams = {
  gymId?: string;
  userId?: string;
  status?: string;
  since?: string;
  until?: string;
  page?: string;
};

const PAGE_SIZE = 50;
const STATUSES: readonly CheckinStatus[] = [
  "success",
  "tier_locked",
  "no_visits",
  "expired",
  "invalid_qr",
  "rate_limited",
] as const;

const STATUS_TONE: Record<CheckinStatus, "ok" | "warn" | "bad" | "mute"> = {
  success: "ok",
  tier_locked: "warn",
  no_visits: "warn",
  expired: "mute",
  invalid_qr: "bad",
  rate_limited: "bad",
};

function parseStatus(value: string | undefined): CheckinStatus | undefined {
  return STATUSES.includes(value as CheckinStatus)
    ? (value as CheckinStatus)
    : undefined;
}
function parsePage(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? "1", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
}

function formatTime(iso: string): { date: string; time: string } {
  try {
    const d = new Date(iso);
    return {
      date: d.toLocaleDateString("en-GB", { day: "2-digit", month: "short" }),
      time: d.toLocaleTimeString("en-GB", {
        hour: "2-digit",
        minute: "2-digit",
      }),
    };
  } catch {
    return { date: iso.slice(0, 10), time: iso.slice(11, 16) };
  }
}

export default async function CheckinsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const t = await getTranslations("checkins");
  const tStats = await getTranslations("checkins.stats");
  const tTable = await getTranslations("checkins.table");
  const tEmpty = await getTranslations("checkins.empty");
  const tFilters = await getTranslations("checkins.filters");
  const tStatuses = await getTranslations("checkinStatuses");
  const tCommon = await getTranslations("common");
  const status = parseStatus(params.status);
  const gymId = params.gymId?.trim() || undefined;
  const userId = params.userId?.trim() || undefined;
  const since = params.since?.trim() || undefined;
  const until = params.until?.trim() || undefined;
  const page = parsePage(params.page);

  const result = await AdminSDK.listCheckins({
    gymId,
    userId,
    status,
    since,
    until,
    page,
    pageSize: PAGE_SIZE,
  });
  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  const successCount = result.items.filter((c) => c.status === "success").length;
  const deniedCount = result.items.length - successCount;

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = { ...params, ...overrides };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/checkins?${s}` : "/checkins";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: t("found"), value: result.total.toLocaleString() }}
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        <StatTile label={tStats("total")} value={result.items.length} />
        <StatTile
          label={tStats("successful")}
          value={successCount}
          tone="ok"
        />
        <StatTile
          label={tStats("denied")}
          value={deniedCount}
          tone={deniedCount > 0 ? "bad" : "default"}
        />
        <StatTile
          label={tStats("successRate")}
          value={
            result.items.length === 0
              ? "—"
              : `${((successCount / result.items.length) * 100).toFixed(0)}%`
          }
          tone={
            result.items.length === 0
              ? "default"
              : successCount / result.items.length >= 0.8
                ? "ok"
                : successCount / result.items.length >= 0.5
                  ? "warn"
                  : "bad"
          }
        />
      </div>

      <FilterBar>
        <Segmented
          value={status}
          options={STATUSES}
          labelFor={(s) => tStatuses(s)}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
        />
        <div className="ml-auto">
          <SearchInput
            name="gymId"
            defaultValue={gymId}
            placeholder={tFilters("search")}
            action="/checkins"
            hidden={{ userId, status: params.status, since, until }}
          />
        </div>
      </FilterBar>

      <form
        action="/checkins"
        method="get"
        autoComplete="off"
        className="flex flex-wrap items-end gap-2 rounded-lg border border-line bg-surface p-3"
      >
        <label className="field">
          <span className="field-label">{tFilters("userId")}</span>
          <input
            name="userId"
            defaultValue={userId ?? ""}
            placeholder={tFilters("uuidPlaceholder")}
            className="input input-sm w-56"
          />
        </label>
        <label className="field">
          <span className="field-label">{tFilters("since")}</span>
          <input
            name="since"
            type="date"
            defaultValue={since ?? ""}
            className="input input-sm w-40"
          />
        </label>
        <label className="field">
          <span className="field-label">{tFilters("until")}</span>
          <input
            name="until"
            type="date"
            defaultValue={until ?? ""}
            className="input input-sm w-40"
          />
        </label>
        {gymId ? <input type="hidden" name="gymId" value={gymId} /> : null}
        {status ? <input type="hidden" name="status" value={status} /> : null}
        <button type="submit" className="btn-primary btn-sm ml-auto">
          {tCommon("filter")}
        </button>
      </form>

      {result.items.length === 0 ? (
        <EmptyState title={tEmpty("title")} hint={tEmpty("hint")} />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table table-compact">
            <thead>
              <tr>
                <th>{tTable("when")}</th>
                <th>{tTable("member")}</th>
                <th>{tTable("gym")}</th>
                <th>{tTable("status")}</th>
                <th>{tTable("reason")}</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((c) => {
                const { date, time } = formatTime(c.scannedAt);
                return (
                  <tr key={c.id}>
                    <td className="num text-muted whitespace-nowrap">
                      <span className="text-paper">{time}</span>
                      <span className="ml-2 text-[11px]">{date}</span>
                    </td>
                    <td className="min-w-0">
                      <Link
                        href={`/users/${c.userId}`}
                        className="flex min-w-0 flex-col leading-tight hover:text-lime"
                      >
                        <span className="truncate text-paper">
                          {c.userName ??
                            c.userPhone ??
                            c.userId.slice(0, 8)}
                        </span>
                        <span className="truncate text-[11px] text-muted num">
                          {c.userPhone ?? c.userId.slice(0, 8)}
                        </span>
                      </Link>
                    </td>
                    <td className="text-paper/90 truncate">{c.gymNameEn}</td>
                    <td>
                      <StatusPill tone={STATUS_TONE[c.status]}>
                        {tStatuses(c.status)}
                      </StatusPill>
                    </td>
                    <td className="text-[11.5px] text-muted">
                      {c.failureReason ?? "—"}
                    </td>
                  </tr>
                );
              })}
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
