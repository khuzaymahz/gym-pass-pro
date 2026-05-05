import Link from "next/link";

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
        title="Check-ins"
        description="Live QR-scan ledger — authoritative source for payouts and tier enforcement."
        count={{ label: "total", value: result.total.toLocaleString() }}
        actions={
          <span className="inline-flex items-center gap-1.5 text-[11.5px] text-muted">
            <span className="dot bg-lime pulse" />
            Live · refresh to update
          </span>
        }
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        <StatTile label="On page" value={result.items.length} />
        <StatTile label="Granted" value={successCount} tone="ok" />
        <StatTile
          label="Denied"
          value={deniedCount}
          tone={deniedCount > 0 ? "bad" : "default"}
        />
        <StatTile
          label="Denial rate"
          value={
            result.items.length === 0
              ? "—"
              : `${((deniedCount / result.items.length) * 100).toFixed(0)}%`
          }
          tone={deniedCount === 0 ? "ok" : "warn"}
        />
      </div>

      <FilterBar>
        <Segmented
          value={status}
          options={STATUSES}
          labelFor={(s) => s.replace("_", " ")}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
        />
        <div className="ml-auto">
          <SearchInput
            name="gymId"
            defaultValue={gymId}
            placeholder="Filter by gym UUID…"
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
          <span className="field-label">User ID</span>
          <input
            name="userId"
            defaultValue={userId ?? ""}
            placeholder="uuid"
            className="input input-sm w-56"
          />
        </label>
        <label className="field">
          <span className="field-label">Since</span>
          <input
            name="since"
            type="date"
            defaultValue={since ?? ""}
            className="input input-sm w-40"
          />
        </label>
        <label className="field">
          <span className="field-label">Until</span>
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
          Apply
        </button>
      </form>

      {result.items.length === 0 ? (
        <EmptyState
          title="No check-ins recorded"
          hint="Once members scan, every scan lands here — granted or denied."
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table table-compact">
            <thead>
              <tr>
                <th>When</th>
                <th>Member</th>
                <th>Venue</th>
                <th>Status</th>
                <th>Reason</th>
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
                        {c.status.replace("_", " ")}
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
