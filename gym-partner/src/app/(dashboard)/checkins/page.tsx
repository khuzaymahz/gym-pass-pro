import { getTranslations } from "next-intl/server";
import Link from "next/link";

import { StatusPill } from "@/components/StatusPill";
import { Toolbar } from "@/components/Toolbar";
import {
  PartnerSDK,
  type CheckinStatus,
  type PartnerCheckin,
} from "@/lib/sdk";

const STATUS_FILTERS: (CheckinStatus | "all")[] = [
  "all",
  "success",
  "tier_locked",
  "no_visits",
  "expired",
];

const TONE: Record<CheckinStatus, "ok" | "warn" | "bad"> = {
  success: "ok",
  tier_locked: "warn",
  no_visits: "warn",
  expired: "bad",
  invalid_qr: "bad",
  rate_limited: "bad",
};

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

export const dynamic = "force-dynamic";

export default async function CheckinsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; page?: string }>;
}) {
  const t = await getTranslations("checkins");
  const sp = await searchParams;
  const status = (sp.status === "all" ? undefined : sp.status) as
    | CheckinStatus
    | undefined;
  const page = Number.parseInt(sp.page ?? "1", 10) || 1;

  const result = await PartnerSDK.listCheckins({
    status,
    page,
    pageSize: 25,
  });

  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />

      <nav className="seg">
        {STATUS_FILTERS.map((s) => {
          const isActive =
            (s === "all" && !status) || (s !== "all" && s === status);
          return (
            <Link
              key={s}
              href={s === "all" ? "/checkins" : `/checkins?status=${s}`}
              className={isActive ? "is-active" : ""}
            >
              {t(s)}
            </Link>
          );
        })}
      </nav>

      <div className="panel overflow-hidden">
        {result.items.length === 0 ? (
          <p className="p-8 text-center text-[12.5px] text-muted">
            {t("noResults")}
          </p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>{t("member")}</th>
                <th>{t("status")}</th>
                <th>{t("scannedAt")}</th>
              </tr>
            </thead>
            <tbody>
              {result.items.map((c: PartnerCheckin) => (
                <tr key={c.id}>
                  <td>
                    <div className="flex flex-col gap-0.5">
                      <span className="text-[13px] text-paper">
                        {c.userName ?? c.userId.slice(0, 8)}
                      </span>
                      {c.userPhone ? (
                        <span
                          className="num text-[11px] text-muted"
                          dir="ltr"
                        >
                          {c.userPhone}
                        </span>
                      ) : null}
                    </div>
                  </td>
                  <td>
                    <StatusPill tone={TONE[c.status]}>
                      {t(c.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-[12.5px] text-muted">
                    {formatTime(c.scannedAt)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <Pager
        page={page}
        pageSize={25}
        total={result.total}
        baseHref={status ? `/checkins?status=${status}` : "/checkins"}
        prev={t("prev")}
        next={t("next")}
      />
    </section>
  );
}

function Pager({
  page,
  pageSize,
  total,
  baseHref,
  prev,
  next,
}: {
  page: number;
  pageSize: number;
  total: number;
  baseHref: string;
  prev: string;
  next: string;
}) {
  if (total <= pageSize) return null;
  const totalPages = Math.ceil(total / pageSize);
  const sep = baseHref.includes("?") ? "&" : "?";
  return (
    <div className="flex items-center justify-between text-[12px] text-muted">
      <span className="num">
        {page}/{totalPages}
      </span>
      <div className="flex gap-2">
        {page > 1 ? (
          <Link
            href={`${baseHref}${sep}page=${page - 1}`}
            className="btn-secondary btn-sm"
          >
            {prev}
          </Link>
        ) : null}
        {page < totalPages ? (
          <Link
            href={`${baseHref}${sep}page=${page + 1}`}
            className="btn-secondary btn-sm"
          >
            {next}
          </Link>
        ) : null}
      </div>
    </div>
  );
}
