"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";

import LocaleToggle from "./LocaleToggle";
import NavIcon from "./NavIcon";
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
  pendingApplicationCount = 0,
}: {
  email: string;
  openTicketCount?: number;
  urgentTicketCount?: number;
  pendingApplicationCount?: number;
}) {
  const pathname = usePathname();
  const tBrand = useTranslations("brand");
  const tGroups = useTranslations("nav.groups");
  const tItems = useTranslations("nav.items");
  const tAccount = useTranslations("account");
  const [open, setOpen] = useState(false);

  // Close the mobile drawer on navigation and lock body scroll while open.
  useEffect(() => setOpen(false), [pathname]);
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [open]);

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
        {
          href: "/partner-applications",
          labelKey: "partnerApplications",
          mark:
            pendingApplicationCount > 0
              ? { count: pendingApplicationCount, urgent: true }
              : undefined,
        },
        { href: "/users", labelKey: "users" },
      ],
    },
    {
      titleKey: "revenue",
      items: [
        { href: "/subscriptions", labelKey: "subscriptions" },
        { href: "/plans", labelKey: "plans" },
        { href: "/day-passes", labelKey: "dayPasses" },
        { href: "/payouts", labelKey: "payouts" },
      ],
    },
    {
      titleKey: "activity",
      items: [
        { href: "/checkins", labelKey: "checkins" },
        { href: "/referrals", labelKey: "referrals" },
      ],
    },
    {
      titleKey: "system",
      items: [
        { href: "/notifications", labelKey: "notifications" },
        { href: "/admins", labelKey: "admins" },
        { href: "/settings", labelKey: "settings" },
      ],
    },
  ];

  const brandMark = (
    <div className="flex h-7 w-7 items-center justify-center rounded-md bg-accent text-[13px] font-bold text-accent-ink shadow-[0_2px_8px_rgba(234,179,8,0.35),inset_0_1px_0_rgba(255,255,255,0.25)]">
      G
    </div>
  );

  const nav = (
    <nav className="flex-1 overflow-y-auto px-3 py-4">
      {groups.map((group) => (
        <div key={group.titleKey} className="mb-5 last:mb-0">
          <div className="px-2">
            <span className="nav-group-label">{tGroups(group.titleKey)}</span>
          </div>
          <ul className="flex flex-col gap-0.5">
            {group.items.map((item) => {
              const active =
                item.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(item.href);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href as never}
                    aria-current={active ? "page" : undefined}
                    className={`nav-item ${active ? "is-active" : ""}`}
                  >
                    <span className="flex min-w-0 items-center gap-2.5">
                      <span
                        className={active ? "text-accent" : "text-muted"}
                      >
                        <NavIcon name={item.labelKey} />
                      </span>
                      <span className="truncate">{tItems(item.labelKey)}</span>
                    </span>
                    {item.mark ? (
                      <span
                        className={`num inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full px-1.5 text-[10.5px] font-medium ${
                          item.mark.urgent
                            ? "bg-red-500/15 text-red-300"
                            : "bg-amber-400/15 text-amber-300"
                        }`}
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
  );

  const footer = (
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
  );

  const brandHeader = (
    <div className="flex h-14 items-center gap-2.5 border-b border-line px-4">
      {brandMark}
      <div className="flex min-w-0 flex-col leading-tight">
        <span className="truncate text-[13px] font-semibold text-paper">
          {tBrand("name")}
        </span>
        <span className="truncate text-[10.5px] text-muted">
          {tBrand("tagline")}
        </span>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop: persistent rail (lg and up) */}
      <aside className="sticky top-0 hidden h-screen w-[230px] shrink-0 flex-col border-r border-line bg-ink/60 backdrop-blur-xl lg:flex">
        {brandHeader}
        {nav}
        {footer}
      </aside>

      {/* Mobile/tablet: fixed top bar with a menu trigger */}
      <header className="fixed inset-x-0 top-0 z-30 flex h-14 items-center gap-3 border-b border-line bg-ink/80 px-4 backdrop-blur-xl lg:hidden">
        <button
          type="button"
          onClick={() => setOpen(true)}
          aria-label={tAccount("openMenu")}
          aria-expanded={open}
          className="btn-icon"
        >
          <svg
            viewBox="0 0 24 24"
            className="h-5 w-5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            aria-hidden
          >
            <path d="M3 6h18M3 12h18M3 18h18" />
          </svg>
        </button>
        <div className="flex items-center gap-2">
          {brandMark}
          <span className="text-[13px] font-semibold text-paper">
            {tBrand("name")}
          </span>
        </div>
        <div className="ml-auto flex items-center gap-1">
          <ThemeToggle />
        </div>
      </header>

      {/* Mobile/tablet: slide-in drawer */}
      {open ? (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            type="button"
            aria-label={tAccount("closeMenu")}
            onClick={() => setOpen(false)}
            className="absolute inset-0 bg-ink/70 backdrop-blur-sm"
            style={{ animation: "fade-up 160ms ease both" }}
          />
          <aside
            className="pop absolute left-0 top-0 flex h-full w-[264px] flex-col rounded-none border-y-0 border-l-0"
            style={{ animation: "slide-in 220ms cubic-bezier(0.2,0.7,0.2,1) both" }}
          >
            {brandHeader}
            {nav}
            {footer}
          </aside>
        </div>
      ) : null}
    </>
  );
}
