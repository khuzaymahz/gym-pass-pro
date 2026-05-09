import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import Pager from "@/components/Pager";
import Toolbar from "@/components/Toolbar";
import { AdminSDK } from "@/lib/sdk";

type SearchParams = {
  entityType?: string;
  action?: string;
  actorUserId?: string;
  page?: string;
};

const PAGE_SIZE = 50;

function parsePage(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? "1", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
}

function formatTimestamp(iso: string): { date: string; time: string } {
  try {
    const d = new Date(iso);
    return {
      date: d.toISOString().slice(0, 10),
      time: d.toISOString().slice(11, 19),
    };
  } catch {
    return { date: iso.slice(0, 10), time: iso.slice(11, 19) };
  }
}

function actionTone(action: string): string {
  if (action.endsWith(".delete") || action.endsWith(".cancel"))
    return "text-red-300";
  if (action.endsWith(".create")) return "text-lime";
  if (action.endsWith(".update") || action.endsWith(".reset"))
    return "text-amber-300";
  return "text-sky-300";
}

function prettyDiff(diff: unknown): string {
  if (!diff || typeof diff !== "object") return "—";
  try {
    const str = JSON.stringify(diff);
    return str.length > 240 ? str.slice(0, 237) + "…" : str;
  } catch {
    return String(diff);
  }
}

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const t = await getTranslations("audit");
  const tTable = await getTranslations("audit.table");
  const tEmpty = await getTranslations("audit.empty");
  const tFilters = await getTranslations("audit.filters");
  const tCommon = await getTranslations("common");
  const entityType = params.entityType?.trim() || undefined;
  const action = params.action?.trim() || undefined;
  const actorUserId = params.actorUserId?.trim() || undefined;
  const page = parsePage(params.page);

  const result = await AdminSDK.listAudit({
    entityType,
    action,
    actorUserId,
    page,
    pageSize: PAGE_SIZE,
  });

  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = { ...params, ...overrides };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/audit?${s}` : "/audit";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: t("found"), value: result.total.toLocaleString() }}
      />

      <form
        action="/audit"
        method="get"
        autoComplete="off"
        className="flex flex-wrap items-end gap-2 rounded-lg border border-line bg-surface p-3"
      >
        <label className="field">
          <span className="field-label">{tFilters("entity")}</span>
          <input
            name="entityType"
            defaultValue={entityType ?? ""}
            placeholder={tFilters("entityPlaceholder")}
            className="input input-sm w-40"
          />
        </label>
        <label className="field">
          <span className="field-label">{tFilters("actionPrefix")}</span>
          <input
            name="action"
            defaultValue={action ?? ""}
            placeholder={tFilters("actionPlaceholder")}
            className="input input-sm w-56"
          />
        </label>
        <label className="field">
          <span className="field-label">{tFilters("actorUuid")}</span>
          <input
            name="actorUserId"
            defaultValue={actorUserId ?? ""}
            placeholder={tFilters("uuidPlaceholder")}
            className="input input-sm w-60"
          />
        </label>
        <div className="ml-auto flex items-center gap-1">
          {(entityType || action || actorUserId) && (
            <Link href="/audit" className="btn-ghost btn-sm">
              {tCommon("close")}
            </Link>
          )}
          <button type="submit" className="btn-primary btn-sm">
            {tCommon("filter")}
          </button>
        </div>
      </form>

      {result.items.length === 0 ? (
        <EmptyState title={tEmpty("title")} hint={tEmpty("hint")} />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table table-compact">
            <thead>
              <tr>
                <th>{tTable("when")}</th>
                <th>{tTable("actor")}</th>
                <th>{tTable("action")}</th>
                <th>{tTable("entity")}</th>
                <th>{tTable("diff")}</th>
                <th>{tTable("ip")}</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((e) => {
                const { date, time } = formatTimestamp(e.createdAt);
                return (
                  <tr key={e.id}>
                    <td className="num whitespace-nowrap text-muted">
                      <span className="text-paper">{time}</span>
                      <span className="ml-2 text-[11px]">{date}</span>
                    </td>
                    <td className="num">
                      {e.actorUserId ? (
                        <Link
                          href={`/users/${e.actorUserId}`}
                          className="text-paper hover:text-lime"
                        >
                          {e.actorUserId.slice(0, 8)}
                        </Link>
                      ) : (
                        <span className="text-muted">system</span>
                      )}
                      {e.actorRole ? (
                        <span className="ml-1 text-[10.5px] uppercase text-muted">
                          {e.actorRole}
                        </span>
                      ) : null}
                    </td>
                    <td className={`${actionTone(e.action)} font-medium`}>
                      {e.action}
                    </td>
                    <td className="num">
                      <span className="text-paper/90">{e.entityType}</span>
                      {e.entityId ? (
                        <span className="ml-1 text-muted">
                          · {e.entityId.slice(0, 8)}
                        </span>
                      ) : null}
                    </td>
                    <td>
                      <pre className="max-w-xl overflow-hidden whitespace-pre-wrap break-all text-[11px] text-muted">
                        {prettyDiff(e.diff)}
                      </pre>
                    </td>
                    <td className="num text-[11px] text-muted">
                      {e.ipAddress ?? "—"}
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
