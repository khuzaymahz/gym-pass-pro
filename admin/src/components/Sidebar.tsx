"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useLocale, useTranslations } from "next-intl";
import { useEffect, useState } from "react";

import { GpMark, GympassWordmark } from "./BrandLogo";
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

const COLLAPSE_KEY = "admin:sidebarCollapsed";

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
  const isRtl = useLocale() === "ar";
  const [open, setOpen] = useState(false);
  // Desktop rail collapse. Server renders expanded; the stored preference is
  // applied after mount (the width transition makes the adjustment smooth).
  const [collapsed, setCollapsed] = useState(false);
  useEffect(() => {
    setCollapsed(localStorage.getItem(COLLAPSE_KEY) === "1");
  }, []);
  const toggleCollapsed = () =>
    setCollapsed((c) => {
      const next = !c;
      localStorage.setItem(COLLAPSE_KEY, next ? "1" : "0");
      return next;
    });

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

  const doSignOut = async () => {
    await signOut({ redirect: false });
    window.location.href = "/login";
  };

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

  // Icon-only collapse toggle. The chevron points toward the inline-start
  // edge to collapse and inline-end to expand — `collapsed !== isRtl` flips
  // it so it reads correctly in both LTR (English) and RTL (Arabic).
  const collapseButton = (
    <button
      type="button"
      onClick={toggleCollapsed}
      title={collapsed ? tAccount("expandSidebar") : tAccount("collapseSidebar")}
      aria-label={
        collapsed ? tAccount("expandSidebar") : tAccount("collapseSidebar")
      }
      className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-muted transition-colors hover:bg-surface hover:text-paper"
    >
      <svg
        viewBox="0 0 24 24"
        className={`h-[18px] w-[18px] transition-transform ${
          collapsed !== isRtl ? "rotate-180" : ""
        }`}
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden
      >
        <path d="M15 18l-6-6 6-6" />
      </svg>
    </button>
  );

  // Brand header: the GYMPASS wordmark + the collapse toggle (top of the
  // rail). When collapsed, only the toggle shows (centered). `withToggle` is
  // off for the mobile drawer, which has no collapse concept.
  const renderBrand = (compact: boolean, withToggle: boolean) => (
    <div
      className={`flex h-14 items-center border-b border-line ${
        compact ? "justify-center px-2" : "justify-between ps-4 pe-2"
      }`}
    >
      {!compact && (
        <GympassWordmark
          title={tBrand("name")}
          className="h-6 w-auto text-paper"
        />
      )}
      {withToggle ? collapseButton : null}
    </div>
  );

  const renderNav = (compact: boolean) => (
    <nav className={`flex-1 overflow-y-auto py-4 ${compact ? "px-2" : "px-3"}`}>
      {groups.map((group, gi) => (
        <div key={group.titleKey} className="mb-5 last:mb-0">
          {compact ? (
            gi > 0 ? (
              <div className="mx-auto mb-3 h-px w-5 bg-line" aria-hidden />
            ) : null
          ) : (
            <div className="px-2">
              <span className="nav-group-label">{tGroups(group.titleKey)}</span>
            </div>
          )}
          <ul className="flex flex-col gap-0.5">
            {group.items.map((item) => {
              const active =
                item.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(item.href);
              const label = tItems(item.labelKey);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href as never}
                    aria-current={active ? "page" : undefined}
                    title={compact ? label : undefined}
                    className={`nav-item ${active ? "is-active" : ""} ${
                      compact ? "justify-center px-0" : ""
                    }`}
                  >
                    <span
                      className={`flex min-w-0 items-center ${
                        compact ? "" : "gap-2.5"
                      }`}
                    >
                      <span className={active ? "text-accent" : "text-muted"}>
                        <NavIcon name={item.labelKey} />
                      </span>
                      {!compact && (
                        <span className="truncate">{label}</span>
                      )}
                    </span>
                    {item.mark && !compact ? (
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
                    {item.mark && compact ? (
                      <span
                        className={`absolute end-1 top-1 h-1.5 w-1.5 rounded-full ${
                          item.mark.urgent ? "bg-red-400" : "bg-amber-400"
                        }`}
                        aria-hidden
                      />
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

  const renderFooter = (compact: boolean) =>
    compact ? (
      <div className="flex flex-col items-center gap-2 border-t border-line px-2 py-3">
        <div
          title={email}
          className="flex h-8 w-8 items-center justify-center rounded-full bg-surface text-[11px] font-semibold uppercase text-muted"
        >
          {email.slice(0, 2).toUpperCase()}
        </div>
        <ThemeToggle />
        <button
          type="button"
          onClick={doSignOut}
          title={tAccount("signOut")}
          aria-label={tAccount("signOut")}
          className="flex h-8 w-8 items-center justify-center rounded-md text-muted transition-colors hover:bg-surface hover:text-paper"
        >
          <svg
            viewBox="0 0 24 24"
            className="h-4 w-4"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden
          >
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
            <path d="M16 17l5-5-5-5" />
            <path d="M21 12H9" />
          </svg>
        </button>
      </div>
    ) : (
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
                onClick={doSignOut}
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

  return (
    <>
      {/* Desktop: persistent rail (lg and up), collapsible */}
      <aside
        className={`sticky top-0 hidden h-screen shrink-0 flex-col border-r border-line bg-ink/60 backdrop-blur-xl transition-[width] duration-200 ease-out lg:flex ${
          collapsed ? "w-[68px]" : "w-[230px]"
        }`}
      >
        {renderBrand(collapsed, true)}
        {renderNav(collapsed)}
        {renderFooter(collapsed)}
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
        <GpMark title={tBrand("name")} className="h-6 w-auto text-paper" />
        <div className="ms-auto flex items-center gap-1">
          <ThemeToggle />
        </div>
      </header>

      {/* Mobile/tablet: slide-in drawer (always expanded) */}
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
            className="pop absolute start-0 top-0 flex h-full w-[264px] flex-col rounded-none border-y-0 border-s-0"
            style={{ animation: "slide-in 220ms cubic-bezier(0.2,0.7,0.2,1) both" }}
          >
            {renderBrand(false, false)}
            {renderNav(false)}
            {renderFooter(false)}
          </aside>
        </div>
      ) : null}
    </>
  );
}
