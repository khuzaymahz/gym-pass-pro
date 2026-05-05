import AdminCreateForm from "@/components/AdminCreateForm";
import AdminResetPassword from "@/components/AdminResetPassword";
import EmptyState from "@/components/EmptyState";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type AdminCreateBody } from "@/lib/sdk";

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  } catch {
    return iso.slice(0, 10);
  }
}

export default async function AdminsPage() {
  const result = await AdminSDK.listUsers({
    role: "admin",
    pageSize: 100,
  });

  async function createAdmin(body: AdminCreateBody) {
    "use server";
    return runAction(() => AdminSDK.createAdmin(body));
  }
  async function resetPassword(id: string, password: string) {
    "use server";
    return runAction(() => AdminSDK.resetAdminPassword(id, password));
  }

  const activeCount = result.items.filter((a) => !a.deletedAt).length;
  const inactiveCount = result.items.length - activeCount;

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title="Admins"
        description="Everyone with a seat at this console. Creation and resets are audit-logged."
        count={{ label: "total", value: result.items.length }}
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        <StatTile label="Active" value={activeCount} tone="ok" />
        <StatTile
          label="Deactivated"
          value={inactiveCount}
          tone={inactiveCount > 0 ? "warn" : "default"}
        />
        <StatTile label="Total seats" value={result.items.length} />
        <StatTile label="Added this month" value={monthAdds(result.items)} />
      </div>

      <AdminCreateForm action={createAdmin} />

      {result.items.length === 0 ? (
        <EmptyState
          title="No admins yet"
          hint="Provision yourself or a colleague above."
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>Admin</th>
                <th>Email</th>
                <th>Joined</th>
                <th>Status</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {result.items.map((a) => {
                const reset = resetPassword.bind(null, a.id);
                return (
                  <tr key={a.id}>
                    <td className="min-w-0">
                      <div className="flex min-w-0 flex-col leading-tight">
                        <span className="truncate font-medium text-paper">
                          {a.name ?? "Unnamed admin"}
                        </span>
                        <span className="truncate text-[11px] text-muted num">
                          {a.id.slice(0, 8)}
                        </span>
                      </div>
                    </td>
                    <td className="text-paper/90">{a.email ?? "—"}</td>
                    <td className="num text-muted">
                      {formatDate(a.createdAt)}
                    </td>
                    <td>
                      <StatusPill tone={a.deletedAt ? "bad" : "ok"}>
                        {a.deletedAt ? "Disabled" : "Active"}
                      </StatusPill>
                    </td>
                    <td className="text-right">
                      <AdminResetPassword action={reset} />
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

function monthAdds(items: { createdAt: string }[]): number {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  return items.filter((a) => {
    const d = new Date(a.createdAt);
    return d.getUTCFullYear() === year && d.getUTCMonth() === month;
  }).length;
}
