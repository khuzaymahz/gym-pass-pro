"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useTranslations } from "next-intl";

import { LocaleToggle } from "./LocaleToggle";

export function Sidebar({ gymName, phone }: { gymName: string; phone: string }) {
  const t = useTranslations("nav");
  const tApp = useTranslations("app");
  const pathname = usePathname();

  const items: { href: string; key: keyof typeof labels }[] = [
    { href: "/", key: "dashboard" },
    { href: "/profile", key: "profile" },
    { href: "/photos", key: "photos" },
    { href: "/checkins", key: "checkins" },
    { href: "/payouts", key: "payouts" },
  ];
  const labels = {
    dashboard: t("dashboard"),
    profile: t("profile"),
    photos: t("photos"),
    checkins: t("checkins"),
    payouts: t("payouts"),
  };

  return (
    <aside className="sticky top-0 flex h-screen w-[240px] shrink-0 flex-col border-e border-line bg-ink">
      <div className="flex flex-col gap-1 px-5 py-6">
        <span className="nav-group-label">{tApp("subtitle")}</span>
        <p className="h2 truncate" title={gymName}>
          {gymName}
        </p>
        <p className="text-[11.5px] text-muted num" dir="ltr">
          {phone}
        </p>
      </div>

      <nav className="flex-1 px-3">
        <ul className="flex flex-col gap-0.5">
          {items.map((it) => {
            const active =
              it.href === "/"
                ? pathname === "/"
                : pathname.startsWith(it.href);
            return (
              <li key={it.href}>
                <Link
                  href={it.href}
                  className={`flex items-center justify-between rounded-md px-3 py-1.5 text-[13px] transition-colors ${
                    active
                      ? "bg-line text-paper"
                      : "text-muted hover:bg-surface hover:text-paper"
                  }`}
                >
                  <span>{labels[it.key]}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="flex flex-col gap-2 border-t border-line p-3">
        <LocaleToggle />
        <button
          type="button"
          className="btn-ghost btn-sm w-full justify-start"
          onClick={() => signOut({ callbackUrl: "/login" })}
        >
          {tApp("signOut")}
        </button>
      </div>
    </aside>
  );
}
