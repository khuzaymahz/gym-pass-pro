"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";

import { resolveMediaUrl } from "@/lib/media";
import { DEFAULT_LOGO_ALIGNMENT, type LogoAlignment } from "@/lib/sdk";

import { Wordmark } from "./Wordmark";

type NavKey = "dashboard" | "profile" | "photos" | "checkins" | "payouts";

const NAV_ITEMS: { href: string; key: NavKey }[] = [
  { href: "/", key: "dashboard" },
  { href: "/profile", key: "profile" },
  { href: "/photos", key: "photos" },
  { href: "/checkins", key: "checkins" },
  { href: "/payouts", key: "payouts" },
];

export function Sidebar({
  gymName,
  logoUrl,
  logoAlignment,
  phone,
}: {
  gymName: string;
  logoUrl?: string | null;
  logoAlignment?: LogoAlignment | null;
  phone: string;
}) {
  const t = useTranslations("nav");
  const tApp = useTranslations("app");
  const pathname = usePathname();
  const resolvedLogo = resolveMediaUrl(logoUrl);
  const initials = makeInitials(gymName);
  const alignment = logoAlignment ?? DEFAULT_LOGO_ALIGNMENT;

  const activeIndex = Math.max(
    0,
    NAV_ITEMS.findIndex((it) =>
      it.href === "/" ? pathname === "/" : pathname.startsWith(it.href),
    ),
  );

  return (
    <aside className="sticky top-0 flex h-screen w-[240px] shrink-0 flex-col border-e border-line bg-ink">
      <div className="flex flex-col gap-4 px-5 py-6">
        <div className="flex justify-center">
          <Wordmark size={22} />
        </div>
        <GymStatusCard
          gymName={gymName}
          phone={phone}
          logoUrl={resolvedLogo}
          logoAlignment={alignment}
          initials={initials}
        />
      </div>

      {/* Icon-first nav with a sliding accent rail. Row height,
       *  icon size and label size were bumped so the nav reads at
       *  arm's length on a partner's desk laptop — the previous
       *  10–11px tracked caps registered as instrumentation but
       *  forced the operator to lean in. */}
      <nav className="relative flex-1 px-3" aria-label={t("dashboard")}>
        <span
          className="rail"
          aria-hidden
          style={{
            top: 0,
            height: "40px",
            transform: `translateY(${activeIndex * 44}px)`,
          }}
        />
        <ul className="flex flex-col">
          {NAV_ITEMS.map((it, i) => {
            const active = i === activeIndex;
            return (
              <li key={it.href}>
                <Link
                  href={it.href}
                  className={`group flex h-11 items-center gap-3.5 rounded-md ps-4 pe-3 transition-colors ${
                    active
                      ? "text-paper"
                      : "text-muted hover:text-paper"
                  }`}
                >
                  <NavIcon name={it.key} active={active} />
                  <span
                    className={`text-[14px] font-medium transition-transform ${
                      active ? "translate-x-0" : "group-hover:translate-x-0.5"
                    }`}
                  >
                    {t(it.key)}
                  </span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="flex flex-col gap-2 border-t border-line p-3">
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

/// Status card — reframes the gym identity row as a "this floor is
/// open / closed" readout. Open/Closed dot pulses while open; a
/// thin tracked-out caps label sits above the gym name so the card
/// reads as instrumentation, not a profile chip.
///
/// Open/Closed is computed client-side against the local clock —
/// the partner is at the gym, in the gym's timezone (Jordan UTC+3,
/// no DST), so naive local time is the right answer. A real
/// opening-hours editor would feed this; until then we treat
/// 06:00–24:00 local as open, which matches the typical gym
/// schedule in Amman.
function GymStatusCard({
  gymName,
  phone,
  logoUrl,
  logoAlignment,
  initials,
}: {
  gymName: string;
  phone: string;
  logoUrl: string | null;
  logoAlignment: LogoAlignment;
  initials: string;
}) {
  const tApp = useTranslations("app");
  const isOpen = useIsOpenLocal();
  return (
    <div className="steel flex items-center gap-3 rounded-md p-2.5">
      {logoUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={logoUrl}
          alt={gymName}
          className="h-9 w-9 shrink-0 rounded"
          style={{
            objectFit: logoAlignment.fit,
            objectPosition: `center ${logoAlignment.position}`,
          }}
        />
      ) : (
        <span
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded bg-line text-[11px] font-semibold uppercase tracking-wide text-paper"
          aria-hidden
        >
          {initials}
        </span>
      )}
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="tracked flex items-center gap-1.5 text-[10.5px] text-muted">
          <span
            className={`status-dot ${isOpen ? "is-open" : "is-closed"}`}
            aria-hidden
          />
          {isOpen ? tApp("statusOpen") : tApp("statusClosed")}
        </span>
        <p
          className="truncate text-[14px] font-semibold leading-tight text-paper"
          title={gymName}
        >
          {gymName}
        </p>
        <p className="num text-[11.5px] leading-tight text-muted" dir="ltr">
          {phone}
        </p>
      </div>
    </div>
  );
}

function useIsOpenLocal(): boolean {
  const [open, setOpen] = useState<boolean>(true);
  useEffect(() => {
    const compute = (): void => {
      const h = new Date().getHours();
      // 06:00–23:59 local treated as open. Caller will gain a per-day
      // schedule when the openingHours editor lands.
      setOpen(h >= 6);
    };
    compute();
    // Re-evaluate at the next minute boundary so the dot flips
    // automatically when the clock crosses 06:00 / 24:00.
    const ms = 60_000 - (Date.now() % 60_000);
    const t = setTimeout(compute, ms);
    return () => clearTimeout(t);
  }, []);
  return open;
}

function NavIcon({ name, active }: { name: NavKey; active: boolean }) {
  const cls = `h-[18px] w-[18px] shrink-0 transition-colors ${
    active ? "text-accent" : "text-muted group-hover:text-paper"
  }`;
  switch (name) {
    case "dashboard":
      // Gauge — quarter-arc sweep with a needle.
      return (
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className={cls} aria-hidden>
          <path d="M2 11a6 6 0 0 1 12 0" />
          <path d="M8 11l3-4" />
          <circle cx="8" cy="11" r="1" />
        </svg>
      );
    case "profile":
      // Identity card — a horizontal card with a header bar.
      return (
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className={cls} aria-hidden>
          <rect x="2" y="3" width="12" height="10" rx="1.5" />
          <line x1="2" y1="6.5" x2="14" y2="6.5" />
          <circle cx="6" cy="10" r="1.2" />
          <line x1="9" y1="9.5" x2="12" y2="9.5" />
          <line x1="9" y1="11.5" x2="12" y2="11.5" />
        </svg>
      );
    case "photos":
      // Frame with a single mountain-and-sun shape.
      return (
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className={cls} aria-hidden>
          <rect x="2" y="3" width="12" height="10" rx="1.5" />
          <circle cx="6" cy="6.5" r="1" />
          <path d="M3 12l3-3 3 2 4-4 1 1" />
        </svg>
      );
    case "checkins":
      // QR-ish bracket — corners of a scan target.
      return (
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className={cls} aria-hidden>
          <path d="M3 5V3h2" />
          <path d="M11 3h2v2" />
          <path d="M13 11v2h-2" />
          <path d="M5 13H3v-2" />
          <line x1="6.5" y1="8" x2="9.5" y2="8" />
        </svg>
      );
    case "payouts":
      // Stacked plates — references a weight stack.
      return (
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className={cls} aria-hidden>
          <ellipse cx="8" cy="4" rx="5" ry="1.5" />
          <path d="M3 4v2.5c0 .8 2.2 1.5 5 1.5s5-.7 5-1.5V4" />
          <path d="M3 8.5V11c0 .8 2.2 1.5 5 1.5s5-.7 5-1.5V8.5" />
        </svg>
      );
  }
}

function makeInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
