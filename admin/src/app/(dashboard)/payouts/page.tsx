import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import GeneratePayoutsForm from "@/components/GeneratePayoutsForm";
import MarkPayoutPaid from "@/components/MarkPayoutPaid";
import Pager from "@/components/Pager";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type PayoutStatus } from "@/lib/sdk";

type SearchParams = {
  status?: string;
  gymId?: string;
  page?: string;
};

const PAGE_SIZE = 25;
const STATUSES = ["pending", "paid"] as const;

function parseStatus(value: string | undefined): PayoutStatus | undefined {
  return STATUSES.includes(value as PayoutStatus)
    ? (value as PayoutStatus)
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

export default async function PayoutsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const status = parseStatus(params.status);
  const gymId = params.gymId?.trim() || undefined;
  const page = parsePage(params.page);

  const result = await AdminSDK.listPayouts({
    status,
    gymId,
    page,
    pageSize: PAGE_SIZE,
  });

  async function generate(periodStart: string, periodEnd: string) {
    "use server";
    return runAction(() => AdminSDK.generatePayouts(periodStart, periodEnd));
  }
  async function markPaid(id: string, notes?: string) {
    "use server";
    return runAction(() => AdminSDK.markPayoutPaid(id, notes));
  }

  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  const pendingAmount = result.items
    .filter((p) => p.status === "pending")
    .reduce((sum, p) => sum + Number(p.totalAmountJod), 0);
  const paidAmount = result.items
    .filter((p) => p.status === "paid")
    .reduce((sum, p) => sum + Number(p.totalAmountJod), 0);
  const pendingCount = result.items.filter((p) => p.status === "pending").length;
  const paidCount = result.items.length - pendingCount;

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = { ...params, ...overrides };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/payouts?${s}` : "/payouts";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title="Payouts"
        description="Monthly partner settlement runs. Generate, review, mark paid once transferred."
        count={{ label: "total", value: result.total.toLocaleString() }}
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        <StatTile
          label="Pending amount"
          value={pendingAmount.toFixed(2)}
          unit="JOD"
          tone={pendingAmount > 0 ? "warn" : "default"}
        />
        <StatTile
          label="Paid amount"
          value={paidAmount.toFixed(2)}
          unit="JOD"
          tone="ok"
        />
        <StatTile label="Pending runs" value={pendingCount} />
        <StatTile label="Paid runs" value={paidCount} />
      </div>

      <GeneratePayoutsForm action={generate} />

      <FilterBar>
        <Segmented
          value={status}
          options={STATUSES}
          labelFor={(s) => s.charAt(0).toUpperCase() + s.slice(1)}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
        />
        <div className="ml-auto">
          <SearchInput
            name="gymId"
            defaultValue={gymId}
            placeholder="Filter by gym UUID…"
            action="/payouts"
            hidden={{ status: params.status }}
          />
        </div>
      </FilterBar>

      {result.items.length === 0 ? (
        <EmptyState
          title="No payouts yet"
          hint="Generate a run for a period once partner gyms have logged check-ins."
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>Gym</th>
                <th>Period</th>
                <th className="num">Entries</th>
                <th className="num">Amount</th>
                <th>Status</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {result.items.map((p) => (
                <tr key={p.id}>
                  <td className="min-w-0">
                    <div className="flex min-w-0 flex-col leading-tight">
                      <span className="truncate text-paper">{p.gymNameEn}</span>
                      <span className="truncate text-[11px] text-muted num">
                        {p.gymId.slice(0, 8)}
                      </span>
                    </div>
                  </td>
                  <td className="num text-muted text-[12px] whitespace-nowrap">
                    {formatDate(p.periodStart)} → {formatDate(p.periodEnd)}
                  </td>
                  <td className="num">{p.entryCount}</td>
                  <td className="num">
                    <span className="font-semibold text-paper">
                      {Number(p.totalAmountJod).toFixed(2)}
                    </span>
                    <span className="ml-1 text-[10.5px] text-muted">JOD</span>
                  </td>
                  <td>
                    <StatusPill tone={p.status === "paid" ? "ok" : "warn"}>
                      {p.status}
                    </StatusPill>
                  </td>
                  <td className="text-right">
                    {p.status === "pending" ? (
                      <MarkPayoutPaid action={markPaid.bind(null, p.id)} />
                    ) : (
                      <span className="text-[11.5px] text-muted num">
                        {p.paidAt ? formatDate(p.paidAt) : "—"}
                      </span>
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
        total={result.total}
        hrefFor={(target) => hrefFor({ page: String(target) })}
      />
    </section>
  );
}
