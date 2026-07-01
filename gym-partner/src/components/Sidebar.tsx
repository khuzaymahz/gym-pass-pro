"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { useTranslations } from "next-intl";
import { Component, type ReactNode, useEffect, useState } from "react";

import { makeInitials } from "@/lib/initials";
import { resolveMediaUrl } from "@/lib/media";
import {
  DEFAULT_LOGO_ALIGNMENT,
  type LogoAlignment,
  type PartnerGymRef,
} from "@/lib/sdk-types";

import { BranchSwitcher } from "./BranchSwitcher";
import { Wordmark } from "./Wordmark";

/// Defensive boundary around the GymStatusCard. The card consumes a
/// freeform `openingHours` payload from the backend; while
/// `computeIsOpen` is defensive against missing / wrong-shaped data,
/// any client-side render error inside the card would otherwise
/// take down the entire dashboard shell with it (the whole sidebar
/// would unmount). This boundary swaps the card for a minimal
/// status row so a malformed payload never costs the operator
/// their navigation.
class GymStatusBoundary extends Component<
  { children: ReactNode; fallback: ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  componentDidCatch(error: Error) {
    // eslint-disable-next-line no-console
    console.error("[Sidebar.GymStatusBoundary] caught:", error);
  }
  render() {
    return this.state.hasError ? this.props.fallback : this.props.children;
  }
}

type NavKey =
  | "dashboard"
  | "profile"
  | "qr"
  | "photos"
  | "checkins"
  | "payouts";

// Opening-hours payload is opaque on the wire (`Record<string, unknown>`)
// because the editor isn't shipped yet. The seed writes `{24_7: true}`
// for every gym, so we recognise that and a couple of other plausible
// shapes (`{open: "06:00", close: "24:00"}`, per-day buckets) defensively
// — drift here downgrades the dot to "Closed", not a render error.
type DaySpec =
  | { open?: string; close?: string }
  | { closed?: boolean };
type OpeningHoursShape = {
  // Always-on gyms set this; we early-return open without reading the
  // clock when present.
  "24_7"?: boolean;
  // Older shape used in some seeds: a single open/close window.
  open?: string;
  close?: string;
  // Per-day shape — keys are lowercased weekday names ("mon", "tue",
  // ...). Values are either `{open, close}` or `{closed: true}`.
  mon?: DaySpec;
  tue?: DaySpec;
  wed?: DaySpec;
  thu?: DaySpec;
  fri?: DaySpec;
  sat?: DaySpec;
  sun?: DaySpec;
};

// QR sits second in the nav — right after the dashboard and ahead
// of the editing surfaces (profile / photos). Reasoning: it's the
// asset most partners touch first ("print this and tape it at the
// door") and the one they re-open most often (when a printed copy
// gets damaged or someone joins their staff). Below it are the
// edit/admin views; the check-ins + payouts logs come last as the
// readback surfaces.
const NAV_ITEMS: { href: string; key: NavKey }[] = [
  { href: "/", key: "dashboard" },
  { href: "/qr", key: "qr" },
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
  openingHours,
  branches,
  currentBranchId,
}: {
  gymName: string;
  logoUrl?: string | null;
  logoAlignment?: LogoAlignment | null;
  phone: string;
  // Opaque dict from the gym-profile API — see `OpeningHoursShape`
  // above for the shapes we accept. Falsy = treat as "unknown",
  // which the dot renders as Closed (the safer default).
  openingHours?: Record<string, unknown> | null;
  // Branches this partner can operate + the active one. >1 → the
  // switcher renders above the gym card; otherwise it's a no-op.
  branches?: PartnerGymRef[];
  currentBranchId?: string;
}) {
  const t = useTranslations("nav");
  const tApp = useTranslations("app");
  const tLegal = useTranslations("legal");
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
        <BranchSwitcher
          branches={branches ?? []}
          currentId={currentBranchId}
        />
        <GymStatusBoundary
          fallback={
            <div
              className="steel flex items-center gap-3 rounded-md p-2.5"
              role="status"
            >
              <span
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded bg-line text-[11px] font-semibold uppercase tracking-wide text-paper"
                aria-hidden
              >
                {initials}
              </span>
              <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                <p
                  className="truncate text-[14px] font-semibold leading-tight text-paper"
                  title={gymName}
                >
                  {gymName}
                </p>
                <span className="text-[11px] text-muted">{phone}</span>
              </div>
            </div>
          }
        >
          <GymStatusCard
            gymName={gymName}
            phone={phone}
            logoUrl={resolvedLogo}
            logoAlignment={alignment}
            initials={initials}
            openingHours={openingHours ?? null}
          />
        </GymStatusBoundary>
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
        <div className="flex items-center gap-2 px-2 pt-1 text-[11px] text-muted">
          <Link
            href="/legal/terms"
            className="hover:text-paper transition-colors"
          >
            {tLegal("navTerms")}
          </Link>
          <span className="text-line">·</span>
          <Link
            href="/legal/privacy"
            className="hover:text-paper transition-colors"
          >
            {tLegal("navPrivacy")}
          </Link>
        </div>
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
  openingHours,
}: {
  gymName: string;
  phone: string;
  logoUrl: string | null;
  logoAlignment: LogoAlignment;
  initials: string;
  openingHours: Record<string, unknown> | null;
}) {
  const tApp = useTranslations("app");
  const isOpen = useIsOpenLocal(openingHours);
  return (
    <div className="steel flex items-center gap-3 rounded-md p-2.5">
      {logoUrl ? (
        <div
          className="relative h-9 w-9 shrink-0 overflow-hidden rounded"
          aria-label={gymName}
        >
          <Image
            src={logoUrl}
            alt={gymName}
            fill
            sizes="36px"
            // `unoptimized` because Next's image proxy runs server-
            // side and tries to fetch the absolute backend URL from
            // inside the container, where `localhost:8000` is the
            // container's own loopback (nothing listening). With
            // `unoptimized` Next emits a plain <img> and the browser
            // fetches directly via the host's port mapping.
            unoptimized
            style={{
              objectFit: logoAlignment.fit,
              objectPosition: `center ${logoAlignment.position}`,
            }}
          />
        </div>
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

/// Compute "is the gym open right now?" against the gym's
/// `openingHours` payload. SSR-safe: starts at the same value the
/// server would compute (open if 24/7 / no schedule) so hydration
/// doesn't flicker.
///
/// The previous version returned a hardcoded 06:00-24:00 schedule
/// regardless of the gym's actual hours, AND only refreshed once
/// after the next minute boundary — meaning the dot stuck on the
/// minute-2 reading for the rest of the session. Both bugs are
/// fixed by recomputing each tick of a 60s interval.
function useIsOpenLocal(
  openingHours: Record<string, unknown> | null,
): boolean {
  const [open, setOpen] = useState<boolean>(() => computeIsOpen(openingHours));
  useEffect(() => {
    const compute = (): void => setOpen(computeIsOpen(openingHours));
    compute();
    // Re-evaluate every minute, anchored to the next minute boundary
    // so all gyms in the same browser tick at the same moment.
    let interval: ReturnType<typeof setInterval> | null = null;
    const ms = 60_000 - (Date.now() % 60_000);
    const align = setTimeout(() => {
      compute();
      interval = setInterval(compute, 60_000);
    }, ms);
    return () => {
      clearTimeout(align);
      if (interval) clearInterval(interval);
    };
  }, [openingHours]);
  return open;
}

/// True when `minutes` (since midnight) falls inside the `[open, close)`
/// window. A cross-midnight window (`close <= open`, e.g. 18:00 → 02:00)
/// means "open through midnight" — open when past `open` OR before `close`.
function isWithinWindow(minutes: number, open: number, close: number): boolean {
  return close > open
    ? minutes >= open && minutes < close
    : minutes >= open || minutes < close;
}

/// "HH:MM" → minutes-since-midnight. Returns null on garbage input.
function parseHhMm(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!m) return null;
  const h = Number.parseInt(m[1], 10);
  const min = Number.parseInt(m[2], 10);
  if (!Number.isFinite(h) || !Number.isFinite(min)) return null;
  // Allow `24:00` as the end-of-day sentinel (matches the convention
  // most gym scheduling tools use to represent midnight-as-close).
  if (h < 0 || h > 24 || min < 0 || min > 59) return null;
  return h * 60 + min;
}

function computeIsOpen(
  openingHours: Record<string, unknown> | null,
): boolean {
  if (!openingHours || typeof openingHours !== "object") {
    // No data shipped — be optimistic. The dot is informational, not
    // a gate; "Open" is the right default for a partner dashboard
    // because the closed reading would shame an unconfigured profile.
    return true;
  }
  const hours = openingHours as OpeningHoursShape;
  if (hours["24_7"] === true) return true;

  const now = new Date();
  const minutes = now.getHours() * 60 + now.getMinutes();

  // Per-day buckets take priority over the legacy single-window form.
  const dayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] as const;
  const today = hours[dayKeys[now.getDay()]];
  if (today && typeof today === "object") {
    if ("closed" in today && today.closed === true) return false;
    if ("open" in today && "close" in today) {
      const open = parseHhMm(today.open);
      const close = parseHhMm(today.close);
      if (open != null && close != null) {
        return isWithinWindow(minutes, open, close);
      }
    }
  }

  // Legacy global window (`{open, close}` at the top level).
  const open = parseHhMm(hours.open);
  const close = parseHhMm(hours.close);
  if (open != null && close != null) {
    return isWithinWindow(minutes, open, close);
  }

  // Unknown shape — same optimistic fallback as the no-data branch.
  return true;
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
    case "qr":
      // QR pattern — three finder modules in the corners + a few
      // body modules. Stylised, not a real QR; readable as "QR
      // code" at 18px without competing with the `checkins` icon
      // (which uses corner brackets for the scan-target frame).
      return (
        <svg viewBox="0 0 16 16" fill="currentColor" className={cls} aria-hidden>
          <path d="M2 2h4v4H2V2zm1 1v2h2V3H3z" />
          <path d="M10 2h4v4h-4V2zm1 1v2h2V3h-2z" />
          <path d="M2 10h4v4H2v-4zm1 1v2h2v-2H3z" />
          <rect x="8" y="8" width="1.5" height="1.5" />
          <rect x="11" y="8" width="1.5" height="1.5" />
          <rect x="13.5" y="9.5" width="1.5" height="1.5" />
          <rect x="8" y="11" width="1.5" height="1.5" />
          <rect x="10.5" y="11.5" width="1.5" height="1.5" />
          <rect x="13" y="12" width="1.5" height="1.5" />
          <rect x="8" y="13.5" width="1.5" height="1.5" />
          <rect x="11" y="14" width="1.5" height="1.5" />
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
