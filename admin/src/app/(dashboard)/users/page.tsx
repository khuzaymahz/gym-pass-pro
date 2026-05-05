import Link from "next/link";

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
        title="Users"
        description="Members and admins across the workspace."
        count={{ label: "found", value: result.total.toLocaleString() }}
        actions={
          <Link href="/admins" className="btn-secondary btn-sm">
            Manage admins
          </Link>
        }
      />

      <FilterBar>
        <Segmented
          value={role}
          options={ROLES}
          labelFor={(r) => r.charAt(0).toUpperCase() + r.slice(1)}
          hrefFor={(r) => hrefFor({ role: r, page: undefined })}
        />
        <Segmented
          value={includeDeleted ? "all" : undefined}
          options={["all"] as const}
          labelFor={() => "Include deleted"}
          hrefFor={(v) =>
            hrefFor({
              includeDeleted: v === "all" ? "1" : undefined,
              page: undefined,
            })
          }
          allLabel="Active only"
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={q}
            placeholder="Name, email, phone…"
            action="/users"
            hidden={{
              role: params.role,
              includeDeleted: params.includeDeleted,
            }}
          />
        </div>
      </FilterBar>

      {result.items.length === 0 ? (
        <EmptyState
          title="No users match"
          hint="Widen the search or clear role filter."
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>Member</th>
                <th>Email</th>
                <th>Phone</th>
                <th>Role</th>
                <th>Locale</th>
                <th>Joined</th>
                <th>Status</th>
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
                        {u.name ?? "Unnamed"}
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
                  <td className="num text-muted">{formatDate(u.createdAt)}</td>
                  <td>
                    <StatusPill tone={u.deletedAt ? "bad" : "ok"}>
                      {u.deletedAt ? "Deleted" : "Active"}
                    </StatusPill>
                  </td>
                  <td className="text-right">
                    <Link
                      href={`/users/${u.id}`}
                      className="btn-ghost btn-sm"
                    >
                      Open →
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
