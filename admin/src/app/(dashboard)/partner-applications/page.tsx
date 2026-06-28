import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented } from "@/components/FilterBar";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { AdminSDK, type ApplicationStatus } from "@/lib/sdk";

const STATUSES: ApplicationStatus[] = ["pending", "approved", "rejected"];

type SearchParams = {
  status?: string;
  page?: string;
};

export const dynamic = "force-dynamic";

export default async function PartnerApplicationsPage(props: {
  searchParams: Promise<SearchParams>;
}) {
  const searchParams = await props.searchParams;
  const t = await getTranslations("partnerApplications");

  const statusParam = (
    STATUSES.includes(searchParams.status as ApplicationStatus)
      ? searchParams.status
      : undefined
  ) as ApplicationStatus | undefined;
  const page = Math.max(1, Number.parseInt(searchParams.page ?? "1", 10) || 1);

  const data = await AdminSDK.listPartnerApplications({
    status: statusParam,
    page,
    pageSize: 30,
  });

  const hrefFor = (next: { status?: string; page?: string }) => {
    const params = new URLSearchParams();
    const status = next.status ?? statusParam;
    if (status) params.set("status", status);
    const p = next.page ?? String(page);
    if (p && p !== "1") params.set("page", p);
    const qs = params.toString();
    return qs ? `/partner-applications?${qs}` : "/partner-applications";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: t("total"), value: data.total }}
      />

      <FilterBar>
        <Segmented
          value={statusParam}
          options={STATUSES}
          labelFor={(s) => t(`statuses.${s}`)}
          hrefFor={(s) => hrefFor({ status: s, page: undefined })}
          allLabel={t("allStatuses")}
        />
      </FilterBar>

      {data.items.length === 0 ? (
        <EmptyState
          title={t("emptyTitle")}
          hint={t("emptyHint")}
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>{t("table.gym")}</th>
                <th>{t("table.owner")}</th>
                <th>{t("table.area")}</th>
                <th>{t("table.category")}</th>
                <th>{t("table.submitted")}</th>
                <th>{t("table.status")}</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {data.items.map((a) => (
                <tr key={a.id}>
                  <td className="min-w-0">
                    <Link
                      href={`/partner-applications/${a.id}`}
                      className="font-medium text-paper hover:text-lime"
                    >
                      {a.gymNameEn}
                    </Link>
                  </td>
                  <td className="text-paper/80">
                    {a.ownerName}
                    <div className="text-[11.5px] text-muted" dir="ltr">
                      {a.ownerPhone}
                    </div>
                  </td>
                  <td className="text-paper/80">{a.gymArea}</td>
                  <td className="capitalize text-paper/80">{a.gymCategory}</td>
                  <td className="num text-[12px] text-muted">
                    {new Date(a.createdAt).toLocaleDateString("en-GB", {
                      day: "2-digit",
                      month: "short",
                      year: "numeric",
                    })}
                  </td>
                  <td>
                    <StatusPill
                      tone={
                        a.status === "approved"
                          ? "ok"
                          : a.status === "rejected"
                          ? "bad"
                          : "warn"
                      }
                    >
                      {t(`statuses.${a.status}`)}
                    </StatusPill>
                  </td>
                  <td className="num text-right">
                    <Link
                      href={`/partner-applications/${a.id}`}
                      className="btn-ghost btn-sm"
                    >
                      {t("review")} →
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
