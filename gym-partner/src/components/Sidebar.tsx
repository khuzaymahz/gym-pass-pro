"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useTranslations } from "next-intl";

import { resolveMediaUrl } from "@/lib/media";

import { Wordmark } from "./Wordmark";

export function Sidebar({
  gymName,
  logoUrl,
  phone,
}: {
  gymName: string;
  logoUrl?: string | null;
  phone: string;
}) {
  const t = useTranslations("nav");
  const tApp = useTranslations("app");
  const pathname = usePathname();
  const resolvedLogo = resolveMediaUrl(logoUrl);
  const initials = makeInitials(gymName);

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
      <div className="flex flex-col gap-3 px-5 py-6">
        {/* Brand wordmark — same shape as the mobile app's
            header, anchored visually-left in both LTR and RTL so
            the logo never reads as "PASSGYM" in Arabic. */}
        <Wordmark size={22} />
        {/* Gym identity row: the partner's brand mark sits next
            to their gym name so a glance at the sidebar says
            "this is your gym" instead of "this is GymPass for
            partners, generic". Falls back to initials on a
            surface chip when no logo has been uploaded — the
            profile page's LogoPanel is one click away. */}
        <div className="mt-1 flex items-center gap-3">
          {resolvedLogo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={resolvedLogo}
              alt={gymName}
              className="h-10 w-10 shrink-0 rounded-full border border-line object-cover"
            />
          ) : (
            <span
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-line bg-surface text-[11px] font-semibold uppercase tracking-wide text-muted"
              aria-hidden
            >
              {initials}
            </span>
          )}
          <div className="flex min-w-0 flex-1 flex-col">
            <span className="nav-group-label">{tApp("subtitle")}</span>
            <p className="h2 truncate" title={gymName}>
              {gymName}
            </p>
            <p className="num text-[11.5px] text-muted" dir="ltr">
              {phone}
            </p>
          </div>
        </div>
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
        {/* Locale + theme controls live in the page-level chrome
            cluster (dashboard layout / login). Sidebar footer
            keeps a single sign-out affordance — no duplicates. */}
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

/// Two-letter monogram for the no-logo fallback in the sidebar
/// avatar. Matches the convention the mobile app uses in
/// `gym_logo.dart` — first letter of each of the first two words
/// (or first two letters of a single-word name) so "Iron Forge"
/// becomes "IF" and "Gym" becomes "GY".
function makeInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
