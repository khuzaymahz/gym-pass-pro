import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { AdminSDK, type Role } from "@/lib/sdk";

type SearchParams = {
  q?: string;
  role?: string;
  includeDeleted?: string;
  page?: string;
};

const PAGE_SIZE = 25;
const ROLES = ["member", "admin"] as const;

function parseRole(value: string | undefined): Role | undefined {
  return value === "admin" || value === "member" ? value : undefined;
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

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const role = parseRole(params.role);
  const includeDeleted = params.includeDeleted === "1";
  const page = parsePage(params.page);
  const q = params.q?.trim() || undefined;
  const t = await getTranslations("users");
  const tCommon = await getTranslations("common");
  const tEdit = await getTranslations("users.edit");
  const tNav = await getTranslations("nav.items");

  const result = await AdminSDK.listUsers({
    role,
    q,
    includeDeleted,
    page,
    pageSize: PAGE_SIZE,
  });

  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  const hrefFor = (overrides: Partial<SearchParams>): string => {
    const merged: SearchParams = {
      q: params.q,
      role: params.role,
      includeDeleted: params.includeDeleted,
      page: params.page,
      ...overrides,
    };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) sp.set(k, v);
    }
    const s = sp.toString();
    return s ? `/users?${s}` : "/users";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: tCommon("of"), value: result.total.toLocaleString() }}
        actions={
          <Link href="/admins" className="btn-secondary btn-sm">
            {tNav("admins")}
          </Link>
        }
      />

      <FilterBar>
        <Segmented
          value={role}
          options={ROLES}
          labelFor={(r) =>
            r === "admin" ? tEdit("roleAdmin") : tEdit("roleMember")
          }
          hrefFor={(r) => hrefFor({ role: r, page: undefined })}
        />
        <Segmented
          value={includeDeleted ? "all" : undefined}
          options={["all"] as const}
          labelFor={() => tCommon("all")}
          hrefFor={(v) =>
            hrefFor({
              includeDeleted: v === "all" ? "1" : undefined,
              page: undefined,
            })
          }
          allLabel={tCommon("active")}
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={q}
            placeholder={t("searchPlaceholder")}
            action="/users"
            hidden={{
              role: params.role,
              includeDeleted: params.includeDeleted,
            }}
          />
        </div>
      </FilterBar>

      {result.items.length === 0 ? (
        <EmptyState title={tCommon("empty")} hint={tCommon("empty")} />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>{tEdit("firstName")}</th>
                <th>{tEdit("email")}</th>
                <th>{tEdit("phone")}</th>
                <th>{tEdit("role")}</th>
                <th>{tEdit("locale")}</th>
                <th>{tEdit("status")}</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {result.items.map((u) => (
                <tr key={u.id}>
                  <td className="min-w-0">
                    <Link
                      href={`/users/${u.id}`}
                      className="flex min-w-0 flex-col leading-tight hover:text-lime"
                    >
                      <span className="truncate font-medium text-paper">
                        {u.name ?? "—"}
                      </span>
                      <span className="truncate text-[11px] text-muted num">
                        {u.id.slice(0, 8)}
                      </span>
                    </Link>
                  </td>
                  <td className="text-paper/90">{u.email ?? "—"}</td>
                  <td className="num text-muted">{u.phone ?? "—"}</td>
                  <td>
                    <span className="kbd capitalize">{u.role}</span>
                  </td>
                  <td className="uppercase text-muted">{u.locale}</td>
                  <td>
                    <StatusPill tone={u.deletedAt ? "bad" : "ok"}>
                      {u.deletedAt
                        ? tCommon("disabled")
                        : tCommon("active")}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    <span className="text-[11px]">
                      {formatDate(u.createdAt)}
                    </span>
                  </td>
                  <td className="text-right">
                    <Link
                      href={`/users/${u.id}`}
                      className="btn-ghost btn-sm"
                    >
                      {tCommon("open")} →
                    </Link>
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
