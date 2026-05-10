import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { listReferrals } from "@/lib/referrals";

type SearchParams = {
  status?: string;
  page?: string;
};

const PAGE_SIZE = 50;

const STATUSES = ["pending", "converted"] as const;
type ReferralStatus = (typeof STATUSES)[number];

const STATUS_TONE: Record<ReferralStatus, "ok" | "warn" | "mute"> = {
  pending: "warn",
  converted: "ok",
};

function parseStatus(value: string | undefined): ReferralStatus | undefined {
  return STATUSES.includes(value as ReferralStatus)
    ? (value as ReferralStatus)
    : undefined;
}

function parsePage(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? "1", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
}

function formatDate(iso: string): { date: string; time: string } {
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
    return { date: iso, time: "" };
  }
}

function personLabel(p: {
  name?: string | null;
  email?: string | null;
  phone?: string | null;
}): string {
  const name = p.name?.trim();
  if (name) return name;
  return p.email?.trim() || p.phone?.trim() || "—";
}

export default async function ReferralsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const t = await getTranslations("referrals");
  const status = parseStatus(params.status);
  const page = parsePage(params.page);

  const result = await listReferrals({
    status,
    page,
    pageSize: PAGE_SIZE,
  });

  const totalPages = Math.max(1, Math.ceil(result.total / PAGE_SIZE));

  // Build query strings for filter chips so a click preserves all
  // other filters but resets the page back to 1.
  function chipHref(nextStatus: ReferralStatus | undefined): string {
    const next = new URLSearchParams();
    if (nextStatus) next.set("status", nextStatus);
    return `/referrals${next.size ? `?${next.toString()}` : ""}`;
  }

  function pageHref(nextPage: number): string {
    const next = new URLSearchParams();
    if (status) next.set("status", status);
    if (nextPage > 1) next.set("page", String(nextPage));
    return `/referrals${next.size ? `?${next.toString()}` : ""}`;
  }

  return (
    <section className="flex flex-col gap-5">
      <Toolbar title={t("title")} description={t("subtitle")} />

      <FilterBar>
        <Segmented<ReferralStatus>
          value={status}
          options={STATUSES}
          labelFor={(s) => t(`filter.${s}`)}
          hrefFor={(s) => chipHref(s)}
          allLabel={t("filter.all")}
        />
      </FilterBar>

      {result.items.length === 0 ? (
        <EmptyState
          title={t("emptyTitle")}
          hint={t("emptyBody")}
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="data-table">
            <thead>
              <tr>
                <th>{t("col.referrer")}</th>
                <th>{t("col.invited")}</th>
                <th>{t("col.code")}</th>
                <th>{t("col.status")}</th>
                <th>{t("col.created")}</th>
                <th>{t("col.converted")}</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((row) => {
                const created = formatDate(row.createdAt);
                const converted = row.convertedAt
                  ? formatDate(row.convertedAt)
                  : null;
                return (
                  <tr key={row.id}>
                    <td>
                      <Link
                        href={`/users/${row.referrer.id}`}
                        className="link-ghost"
                      >
                        {personLabel(row.referrer)}
                      </Link>
                    </td>
                    <td>
                      <Link
                        href={`/users/${row.invited.id}`}
                        className="link-ghost"
                      >
                        {personLabel(row.invited)}
                      </Link>
                    </td>
                    <td>
                      <span className="num text-[12px] text-muted" dir="ltr">
                        {row.referralCode}
                      </span>
                    </td>
                    <td>
                      <StatusPill tone={STATUS_TONE[row.status]}>
                        {t(`status.${row.status}`)}
                      </StatusPill>
                    </td>
                    <td>
                      <div className="flex flex-col gap-0.5">
                        <span className="text-[12.5px]">{created.date}</span>
                        <span className="num text-[11px] text-muted">
                          {created.time}
                        </span>
                      </div>
                    </td>
                    <td>
                      {converted ? (
                        <div className="flex flex-col gap-0.5">
                          <span className="text-[12.5px]">{converted.date}</span>
                          <span className="num text-[11px] text-muted">
                            {converted.time}
                          </span>
                        </div>
                      ) : (
                        <span className="text-[12.5px] text-muted">—</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <Pager
        page={result.page}
        totalPages={totalPages}
        total={result.total}
        hrefFor={pageHref}
      />
    </section>
  );
}
