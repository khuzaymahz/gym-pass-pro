"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useTranslations } from "next-intl";

import LocaleToggle from "./LocaleToggle";
import ThemeToggle from "./ThemeToggle";

type NavItem = {
  href: string;
  labelKey: string;
  mark?: { count: number; urgent?: boolean };
};

type NavGroup = {
  titleKey: string;
  items: NavItem[];
};

export default function Sidebar({
  email,
  openTicketCount = 0,
  urgentTicketCount = 0,
}: {
  email: string;
  openTicketCount?: number;
  urgentTicketCount?: number;
}) {
  const pathname = usePathname();
  const tBrand = useTranslations("brand");
  const tGroups = useTranslations("nav.groups");
  const tItems = useTranslations("nav.items");
  const tAccount = useTranslations("account");

  const groups: NavGroup[] = [
    {
      titleKey: "overview",
      items: [
        { href: "/", labelKey: "dashboard" },
        {
          href: "/support",
          labelKey: "support",
          mark:
            openTicketCount > 0
              ? { count: openTicketCount, urgent: urgentTicketCount > 0 }
              : undefined,
        },
      ],
    },
    {
      titleKey: "network",
      items: [
        { href: "/gyms", labelKey: "gyms" },
        { href: "/users", labelKey: "users" },
      ],
    },
    {
      titleKey: "revenue",
      items: [
        { href: "/subscriptions", labelKey: "subscriptions" },
        { href: "/plans", labelKey: "plans" },
        { href: "/payouts", labelKey: "payouts" },
      ],
    },
    {
      titleKey: "activity",
      items: [{ href: "/checkins", labelKey: "checkins" }],
    },
    {
      titleKey: "system",
      items: [
        { href: "/notifications", labelKey: "notifications" },
        { href: "/audit", labelKey: "audit" },
        { href: "/admins", labelKey: "admins" },
        { href: "/settings", labelKey: "settings" },
      ],
    },
  ];

  return (
    <aside className="sticky top-0 flex h-screen w-[220px] shrink-0 flex-col border-r border-line bg-ink">
      {/* Workspace header */}
      <div className="flex h-14 items-center gap-2.5 border-b border-line px-4">
        <div className="flex h-7 w-7 items-center justify-center rounded-md bg-lime text-[13px] font-bold text-ink">
          G
        </div>
        <div className="flex min-w-0 flex-col leading-tight">
          <span className="truncate text-[13px] font-semibold text-paper">
            {tBrand("name")}
          </span>
          <span className="truncate text-[10.5px] text-muted">
            {tBrand("tagline")}
          </span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {groups.map((group) => (
          <div key={group.titleKey} className="mb-5 last:mb-0">
            <div className="px-2">
              <span className="nav-group-label">{tGroups(group.titleKey)}</span>
            </div>
            <ul className="flex flex-col gap-px">
              {group.items.map((item) => {
                const active =
                  item.href === "/"
                    ? pathname === "/"
                    : pathname.startsWith(item.href);
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href as never}
                      className={`flex h-7 items-center justify-between rounded-md px-2 text-[13px] transition-colors ${
                        active
                          ? "bg-line text-paper"
                          : "text-muted hover:bg-surface hover:text-paper"
                      }`}
                    >
                      <span>{tItems(item.labelKey)}</span>
                      {item.mark ? (
                        <span
                          className={`inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full px-1.5 text-[10.5px] font-medium ${
                            item.mark.urgent
                              ? "bg-red-500/15 text-red-300"
                              : "bg-amber-400/15 text-amber-300"
                          }`}
                          style={{ fontVariantNumeric: "tabular-nums" }}
                        >
                          {item.mark.count}
                        </span>
                      ) : null}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      {/* Account footer */}
      <div className="border-t border-line px-3 py-3">
        <div className="flex items-center gap-2.5 rounded-md px-2 py-1.5">
          <div className="flex h-7 w-7 items-center justify-center rounded-full bg-surface text-[11px] font-semibold uppercase text-muted">
            {email.slice(0, 2).toUpperCase()}
          </div>
          <div className="flex min-w-0 flex-col leading-tight">
            <span className="truncate text-[12.5px] font-medium text-paper">
              {email}
            </span>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={async () => {
                  await signOut({ redirect: false });
                  window.location.href = "/login";
                }}
                className="text-left text-[11px] text-muted transition-colors hover:text-accent"
              >
                {tAccount("signOut")}
              </button>
              <LocaleToggle />
              <ThemeToggle />
            </div>
          </div>
        </div>
      </div>
    </aside>
  );
}
