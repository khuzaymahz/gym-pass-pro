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

  // The GymPass brand mark — one inline vector. The G uses `currentColor`
  // so it inherits the theme text colour (near-white on dark, near-black on
  // light); the P/bars stay brand-amber. One geometry => the dark and light
  // logos are guaranteed identical.
  const brandMark = (
    <svg
      viewBox="90 293 857 433"
      role="img"
      aria-label={tBrand("name")}
      fill="none"
      className="h-9 w-auto text-paper"
    >
      <path
        fill="currentColor"
        fillRule="evenodd"
        d="M 326 317.687 C 296.821 320.745, 270.528 328.240, 245.222 340.711 C 175.544 375.051, 129.931 440.700, 116.318 526.238 C 113.799 542.063, 114.064 573.474, 116.826 586.528 C 129.145 644.754, 168.361 684.219, 227.071 697.472 C 246.633 701.888, 253.990 702.151, 348 701.792 L 436.500 701.455 445.500 698.653 C 468.307 691.552, 487.844 675.208, 497.086 655.500 C 500.728 647.734, 505.561 630.451, 526.029 552 C 531.979 529.195, 540.431 496.350, 543.955 482.334 C 544.592 479.801, 544.426 479.101, 543.126 478.834 C 542.232 478.650, 510.247 478.725, 472.049 479 L 402.599 479.500 401.304 484 C 399.990 488.569, 388.254 533.823, 387.766 536.202 C 387.555 537.230, 392.239 537.556, 410.250 537.769 L 433 538.038 433 540.363 C 433 542.524, 426.346 569.149, 422.532 582.250 C 419.210 593.660, 409.094 602.820, 395 607.180 L 387.500 609.500 328.500 609.336 L 269.500 609.172 259.746 606.643 C 215.121 595.070, 196.747 550.687, 214.500 497.349 C 228.770 454.473, 260.872 424.147, 304 412.799 L 312.500 410.563 437.692 410.252 C 555.076 409.960, 562.916 409.834, 563.404 408.220 C 564.373 405.014, 570.155 383.619, 578.546 352.187 C 583.143 334.966, 587.182 320.003, 587.520 318.937 C 588.126 317.027, 586.326 317.002, 458.817 317.160 C 387.693 317.248, 327.925 317.485, 326 317.687"
      />
      <path
        fill="#F8BB0A"
        fillRule="evenodd"
        d="M 624.150 323.750 C 621.693 332.326, 617.184 349.447, 612.496 368 C 610.482 375.975, 608.216 384.525, 607.463 387 C 605.865 392.245, 602 407.889, 602 409.110 C 602 409.569, 647.337 410.070, 702.750 410.222 C 815.754 410.534, 807.969 410.014, 817.142 417.857 C 836.203 434.155, 822.988 467.451, 794.084 475.950 C 787.827 477.790, 782.433 477.917, 685.526 478.500 C 629.440 478.838, 583.416 479.251, 583.249 479.418 C 582.893 479.773, 571.281 523.214, 556.628 579 C 550.519 602.258, 540.192 640.981, 532.431 669.728 C 527.794 686.903, 524 701.195, 524 701.487 C 524 701.780, 545.471 701.903, 571.713 701.760 L 619.426 701.500 621.630 694 C 624.102 685.589, 635.745 642.742, 643.912 612 C 655.176 569.597, 655.320 569.136, 657.442 568.617 C 658.574 568.339, 689.034 568.073, 725.132 568.025 C 803.290 567.920, 807.181 567.537, 832.542 557.467 C 882.148 537.769, 920.246 481.566, 922.719 424.435 C 924.926 373.423, 896.192 335.787, 844.500 321.986 C 826.890 317.284, 819.788 317, 719.830 317 L 626.085 317 624.150 323.750 M 318.572 451.884 C 318.271 452.371, 317.161 456.308, 316.105 460.634 C 313.538 471.151, 301.169 518.584, 294.426 543.769 C 291.442 554.917, 289 564.942, 289 566.047 C 289 567.976, 289.553 568.045, 302.747 567.778 L 316.494 567.500 317.788 563.546 C 318.500 561.371, 321.512 550.121, 324.482 538.546 C 327.453 526.971, 331.257 512.325, 332.938 506 C 337.212 489.909, 347 451.917, 347 451.416 C 347 450.571, 319.099 451.031, 318.572 451.884 M 363.076 452.857 C 362.530 453.879, 360.301 461.642, 358.124 470.107 C 353.774 487.028, 349.084 504.941, 339.356 541.799 C 335.828 555.163, 333.207 566.526, 333.530 567.049 C 333.853 567.572, 339.886 568, 346.937 568 C 360.523 568, 361.271 567.756, 362.242 563 C 362.882 559.868, 378.304 501.260, 385.565 474.369 C 388.554 463.298, 391 453.510, 391 452.619 C 391 449.984, 364.493 450.210, 363.076 452.857 M 276.005 481.250 C 275.175 483.211, 263.268 527.793, 261.583 535.250 L 260.962 538 270.962 538 L 280.962 538 281.613 535.250 C 281.971 533.737, 285.188 521.475, 288.761 508 C 292.334 494.525, 295.477 482.488, 295.745 481.250 C 296.225 479.039, 296.068 479, 286.595 479 C 277.549 479, 276.899 479.138, 276.005 481.250"
      />
    </svg>
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
      <span className="truncate text-[11px] text-muted">
        {tBrand("tagline")}
      </span>
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
