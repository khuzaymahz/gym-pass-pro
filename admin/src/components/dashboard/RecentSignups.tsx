import Link from "next/link";
import { useTranslations } from "next-intl";

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

/// Recent signup list used in the dashboard feed row. Each row links
/// to /users/[id] so ops can hop straight into the new member.
export default function RecentSignups({
  users,
}: {
  users: {
    id: string;
    name: string | null;
    email: string | null;
    phone: string | null;
    createdAt: string;
  }[];
}) {
  const t = useTranslations("dashboard.feeds");
  if (users.length === 0) {
    return (
      <p className="py-4 text-center text-[12px] text-muted">
        {t("noMembersYet")}
      </p>
    );
  }
  return (
    <ul className="-mx-1 flex flex-col">
      {users.map((u) => (
        <li key={u.id}>
          <Link
            href={`/users/${u.id}`}
            className="flex items-center gap-3 rounded-md px-1 py-2 hover:bg-line/40"
          >
            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-surface text-[11px] font-semibold uppercase text-muted">
              {(u.name ?? u.email ?? u.phone ?? u.id).slice(0, 2).toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] text-paper">
                {u.name ?? u.email ?? u.phone ?? u.id.slice(0, 8)}
              </p>
              <p className="truncate text-[11.5px] text-muted">
                {u.email ?? u.phone ?? "—"}
              </p>
            </div>
            <span className="num shrink-0 text-[11px] text-muted">
              {formatTime(u.createdAt)}
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}
