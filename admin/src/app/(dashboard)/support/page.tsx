import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import {
  AdminSDK,
  type TicketCategory,
  type TicketPriority,
  type TicketStatus,
} from "@/lib/sdk";

type SearchParams = {
  status?: string;
  priority?: string;
  category?: string;
  q?: string;
  page?: string;
};

const PAGE_SIZE = 25;
const STATUSES = [
  "open",
  "in_progress",
  "waiting_user",
  "resolved",
  "closed",
] as const;
const PRIORITIES = ["low", "normal", "high", "urgent"] as const;
const CATEGORIES = [
  "bug",
  "payment",
  "account",
  "gym_issue",
  "feature",
  "complaint",
  "other",
] as const;

const STATUS_TONE: Record<TicketStatus, "ok" | "warn" | "info" | "mute" | "bad"> = {
  open: "warn",
  in_progress: "info",
  waiting_user: "mute",
  resolved: "ok",
  closed: "mute",
};

const PRIORITY_TONE: Record<TicketPriority, "ok" | "warn" | "bad" | "mute"> = {
  low: "mute",
  normal: "ok",
  high: "warn",
  urgent: "bad",
};

function parseStatus(v: string | undefined): TicketStatus | undefined {
  return STATUSES.includes(v as TicketStatus) ? (v as TicketStatus) : undefined;
}
function parsePriority(v: string | undefined): TicketPriority | undefined {
  return PRIORITIES.includes(v as TicketPriority)
    ? (v as TicketPriority)
    : undefined;
}
function parseCategory(v: string | undefined): TicketCategory | undefined {
  return CATEGORIES.includes(v as TicketCategory)
    ? (v as TicketCategory)
    : undefined;
}
function parsePage(v: string | undefined): number {
  const n = Number.parseInt(v ?? "1", 10);
  return Number.isFinite(n) && n > 0 ? n : 1;
}

function formatDate(value: string): string {
  try {
    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return value.slice(0, 16).replace("T", " ");
  }
}

export default async function SupportPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const t = await getTranslations("support");
  const tStats = await getTranslations("support.stats");
  const tTable = await getTranslations("support.table");
  const tEmpty = await getTranslations("support.empty");
  const tFilters = await getTranslations("support.filters");
  const tStatuses = await getTranslations("support.statuses");
  const tPriorities = await getTranslations("support.priorities");
  const tCategories = await getTranslations("support.categories");
  const status = parseStatus(params.status);
  const priority = parsePriority(params.priority);
  const category = parseCategory(params.category);
  const q = params.q?.trim() || undefined;
  const page = parsePage(params.page);

  const [stats, result] = await Promise.all([
    AdminSDK.ticketStats(),
    AdminSDK.listTickets({
      status,
      priority,
      category,
      q,
      page,
      pageSize: PAGE_SIZE,
    }),
  ]);

  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));
  const openCount = stats.open + stats.inProgress + stats.waitingUser;
  const urgentOnPage = result.items.filter((t) => t.priority === "urgent").length;

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = { ...params, ...overrides };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/support?${s}` : "/support";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: tStats("total"), value: result.total.toLocaleString() }}
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-6">
        <StatTile
          label={tStats("open")}
          value={openCount}
          tone={openCount > 0 ? "warn" : "ok"}
        />
        <StatTile
          label={tPriorities("urgent")}
          value={urgentOnPage}
          tone={urgentOnPage > 0 ? "bad" : "default"}
        />
        <StatTile
          label={tStats("inProgress")}
          value={stats.inProgress}
          tone="info"
        />
        <StatTile label={tStats("waitingUser")} value={stats.waitingUser} />
        <StatTile label={tStats("resolved")} value={stats.resolved} tone="ok" />
        <StatTile label={tStats("closed")} value={stats.closed} />
      </div>

      <FilterBar>
        <Segmented
          value={status}
          options={STATUSES}
          labelFor={(s) => tStatuses(s)}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
        />
        <Segmented
          value={priority}
          options={PRIORITIES}
          labelFor={(p) => tPriorities(p)}
          hrefFor={(p) => hrefFor({ priority: p, page: undefined })}
          allLabel={tFilters("allPriorities")}
        />
        <Segmented
          value={category}
          options={CATEGORIES}
          labelFor={(c) => tCategories(c)}
          hrefFor={(c) => hrefFor({ category: c, page: undefined })}
          allLabel={tFilters("allCategories")}
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={q}
            placeholder={tFilters("search")}
            action="/support"
            hidden={{
              status: params.status,
              priority: params.priority,
              category: params.category,
            }}
          />
        </div>
      </FilterBar>

      {result.items.length === 0 ? (
        <EmptyState
          title={tEmpty("title")}
          hint={tEmpty("hint")}
          action={{ href: "/support", label: tFilters("allStatuses") }}
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>{tTable("subject")}</th>
                <th>{tTable("member")}</th>
                <th>{tTable("category")}</th>
                <th>{tTable("priority")}</th>
                <th>{tTable("status")}</th>
                <th>{tTable("updated")}</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((ticket) => (
                <tr key={ticket.id}>
                  <td className="min-w-0">
                    <Link
                      href={`/support/${ticket.id}`}
                      className="flex min-w-0 flex-col leading-tight hover:text-lime"
                    >
                      <span className="truncate text-paper">
                        {ticket.subject}
                      </span>
                      <span className="truncate text-[11px] text-muted num">
                        {ticket.id.slice(0, 8)}
                      </span>
                    </Link>
                  </td>
                  <td className="min-w-0">
                    <div className="flex min-w-0 flex-col leading-tight">
                      <span className="truncate text-paper/90">
                        {ticket.userName ?? "—"}
                      </span>
                      <span className="truncate text-[11px] text-muted">
                        {ticket.userEmail ?? ticket.userPhone ?? ""}
                      </span>
                    </div>
                  </td>
                  <td className="capitalize text-muted">
                    {tCategories(ticket.category)}
                  </td>
                  <td>
                    <StatusPill tone={PRIORITY_TONE[ticket.priority]}>
                      {tPriorities(ticket.priority)}
                    </StatusPill>
                  </td>
                  <td>
                    <StatusPill tone={STATUS_TONE[ticket.status]}>
                      {tStatuses(ticket.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-[11.5px] text-muted whitespace-nowrap">
                    {formatDate(ticket.updatedAt)}
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
