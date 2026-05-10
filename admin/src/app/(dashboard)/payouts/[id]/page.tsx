import Link from "next/link";
import { notFound } from "next/navigation";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import MarkPayoutPaid from "@/components/MarkPayoutPaid";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import { AdminSDK } from "@/lib/sdk";

type Props = { params: Promise<{ id: string }> };

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
    return { date: iso.slice(0, 10), time: "" };
  }
}

export default async function PayoutDetailPage({ params }: Props) {
  const { id } = await params;
  const t = await getTranslations("payouts");
  const tDetail = await getTranslations("payouts.detail");
  const tTable = await getTranslations("payouts.table");

  let detail;
  try {
    detail = await AdminSDK.getPayout(id);
  } catch {
    notFound();
  }

  const { payout, entries } = detail;

  async function markPaid(notes?: string) {
    "use server";
    return runAction(() => AdminSDK.markPayoutPaid(id, notes));
  }

  const total = Number(payout.totalAmountJod);
  const computed = entries.reduce((sum, e) => sum + Number(e.amountJod), 0);
  // Sanity diff between header total and the sum of constituent
  // entries — exposes any reconciliation drift if the ledger has
  // been mutated post-aggregation. Should always be zero for a
  // healthy payout. Show as a quiet warning chip when it isn't.
  const drift = total - computed;
  const driftAbs = Math.abs(drift);

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={payout.gymNameEn}
        description={`${formatDate(payout.periodStart)} → ${formatDate(payout.periodEnd)}`}
        actions={
          <>
            <Link href="/payouts" className="btn-ghost btn-sm">
              ← {t("back")}
            </Link>
            {payout.status === "pending" ? (
              <MarkPayoutPaid action={markPaid} />
            ) : null}
          </>
        }
      />

      {/* Summary card */}
      <div className="panel grid grid-cols-2 gap-4 p-4 sm:grid-cols-4">
        <SummaryStat
          label={tDetail("total")}
          value={`${total.toFixed(2)} JOD`}
        />
        <SummaryStat
          label={tDetail("entries")}
          value={String(payout.entryCount)}
        />
        <div className="flex flex-col gap-1">
          <span className="field-label">{tDetail("status")}</span>
          <div>
            <StatusPill tone={payout.status === "paid" ? "ok" : "warn"}>
              {payout.status === "paid"
                ? tTable("paid")
                : tTable("pending")}
            </StatusPill>
          </div>
        </div>
        <SummaryStat
          label={tDetail("paidAt")}
          value={payout.paidAt ? formatDate(payout.paidAt) : "—"}
        />
        {payout.notes ? (
          <div className="col-span-2 sm:col-span-4 border-t border-line pt-3">
            <span className="field-label">{tDetail("notes")}</span>
            <p className="text-[13px] text-paper">{payout.notes}</p>
          </div>
        ) : null}
        {driftAbs > 0.005 ? (
          <div className="col-span-2 sm:col-span-4 rounded-md border border-amber-400/40 bg-amber-400/10 px-3 py-2 text-[12px] text-amber-200">
            {tDetail("driftWarning", {
              header: total.toFixed(2),
              computed: computed.toFixed(2),
              diff: drift.toFixed(2),
            })}
          </div>
        ) : null}
      </div>

      {/* Entries table */}
      {entries.length === 0 ? (
        <EmptyState
          title={tDetail("emptyTitle")}
          hint={tDetail("emptyBody")}
        />
      ) : (
        <div className="panel overflow-hidden">
          <header className="flex items-center justify-between border-b border-line px-4 py-2.5">
            <h2 className="text-[13px] font-semibold text-paper">
              {tDetail("entriesTitle")}
            </h2>
            <span className="text-[11.5px] text-muted">
              {tDetail("entriesCount", { count: entries.length })}
            </span>
          </header>
          <table className="table">
            <thead>
              <tr>
                <th>{tDetail("col.member")}</th>
                <th>{tDetail("col.scannedAt")}</th>
                <th className="num">{tDetail("col.rate")}</th>
                <th className="num">{tDetail("col.amount")}</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((e) => {
                const ts = formatTime(e.scannedAt);
                return (
                  <tr key={e.ledgerId}>
                    <td className="min-w-0">
                      <Link
                        href={`/users/${e.userId}`}
                        className="link-ghost flex min-w-0 flex-col leading-tight"
                      >
                        <span className="truncate text-paper">
                          {e.userName?.trim() || e.userPhone || "—"}
                        </span>
                        {e.userPhone ? (
                          <span className="truncate text-[11px] text-muted num">
                            {e.userPhone}
                          </span>
                        ) : null}
                      </Link>
                    </td>
                    <td>
                      <div className="flex flex-col gap-0.5">
                        <span className="text-[12.5px]">{ts.date}</span>
                        <span className="num text-[11px] text-muted">
                          {ts.time}
                        </span>
                      </div>
                    </td>
                    <td className="num text-[12.5px] text-muted">
                      {Number(e.rateApplied).toFixed(2)}
                    </td>
                    <td className="num">
                      <span className="font-semibold text-paper">
                        {Number(e.amountJod).toFixed(2)}
                      </span>
                      <span className="ml-1 text-[10.5px] text-muted">JOD</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function SummaryStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="field-label">{label}</span>
      <span className="text-[16px] font-semibold text-paper num">{value}</span>
    </div>
  );
}
