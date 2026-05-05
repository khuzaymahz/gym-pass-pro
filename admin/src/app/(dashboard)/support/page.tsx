import Link from "next/link";

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
        title="Support"
        description="Member-submitted tickets from the mobile app. Reply, reassign, resolve."
        count={{ label: "matching", value: result.total.toLocaleString() }}
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-6">
        <StatTile
          label="Open"
          value={openCount}
          tone={openCount > 0 ? "warn" : "ok"}
        />
        <StatTile
          label="Urgent (page)"
          value={urgentOnPage}
          tone={urgentOnPage > 0 ? "bad" : "default"}
        />
        <StatTile label="In progress" value={stats.inProgress} tone="info" />
        <StatTile label="Waiting user" value={stats.waitingUser} />
        <StatTile label="Resolved" value={stats.resolved} tone="ok" />
        <StatTile label="Closed" value={stats.closed} />
      </div>

      <FilterBar>
        <Segmented
          value={status}
          options={STATUSES}
          labelFor={(s) => s.replace("_", " ")}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
        />
        <Segmented
          value={priority}
          options={PRIORITIES}
          labelFor={(p) => p.charAt(0).toUpperCase() + p.slice(1)}
          hrefFor={(p) => hrefFor({ priority: p, page: undefined })}
          allLabel="Any priority"
        />
        <Segmented
          value={category}
          options={CATEGORIES}
          labelFor={(c) => c.replace("_", " ")}
          hrefFor={(c) => hrefFor({ category: c, page: undefined })}
          allLabel="Any category"
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={q}
            placeholder="Subject, body, member…"
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
          title="No tickets match"
          hint="Clear filters to see the full queue."
          action={{ href: "/support", label: "Clear filters" }}
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>Subject</th>
                <th>Member</th>
                <th>Category</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Updated</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((t) => (
                <tr key={t.id}>
                  <td className="min-w-0">
                    <Link
                      href={`/support/${t.id}`}
                      className="flex min-w-0 flex-col leading-tight hover:text-lime"
                    >
                      <span className="truncate text-paper">{t.subject}</span>
                      <span className="truncate text-[11px] text-muted num">
                        {t.id.slice(0, 8)}
                      </span>
                    </Link>
                  </td>
                  <td className="min-w-0">
                    <div className="flex min-w-0 flex-col leading-tight">
                      <span className="truncate text-paper/90">
                        {t.userName ?? "—"}
                      </span>
                      <span className="truncate text-[11px] text-muted">
                        {t.userEmail ?? t.userPhone ?? ""}
                      </span>
                    </div>
                  </td>
                  <td className="capitalize text-muted">
                    {t.category.replace("_", " ")}
                  </td>
                  <td>
                    <StatusPill tone={PRIORITY_TONE[t.priority]}>
                      {t.priority}
                    </StatusPill>
                  </td>
                  <td>
                    <StatusPill tone={STATUS_TONE[t.status]}>
                      {t.status.replace("_", " ")}
                    </StatusPill>
                  </td>
                  <td className="num text-[11.5px] text-muted whitespace-nowrap">
                    {formatDate(t.updatedAt)}
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
