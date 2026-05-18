"use client";

import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";

/// Top-of-page banner that surfaces "you're offline" the moment the
/// browser fires its `offline` event. Pairs with the API-client side
/// of W1 — when `lib/api.ts` throws a `NetworkError` because the
/// fetch couldn't reach the server, this banner gives the operator
/// the standing context they need to interpret the failure ("right,
/// my WiFi dropped — that's why the dashboard 500'd").
///
/// Why client-side only:
///
///   * `navigator.onLine` is browser-only; SSR has no opinion.
///     We default-render `null` and the banner only mounts after
///     hydration. No FOUC because nothing renders pre-hydration.
///   * Listens to both `online` and `offline` so a flap is reflected
///     within the next event loop tick. Browsers fire these
///     immediately on interface state change — more responsive than
///     polling `/api/ping`.
///   * `navigator.onLine` is heuristic: it reports the OS interface
///     state, not actual reachability to api.gym-pass.net. A captive
///     portal would report online while every request times out.
///     That's fine — the `NetworkError` raised by `lib/api.ts` is
///     the authoritative signal; this banner is the optional
///     pre-emptive context.
export function OfflineBanner() {
  const t = useTranslations("connectivity");
  const [mounted, setMounted] = useState(false);
  const [online, setOnline] = useState(true);

  useEffect(() => {
    setMounted(true);
    setOnline(typeof navigator !== "undefined" ? navigator.onLine : true);

    const goOnline = () => setOnline(true);
    const goOffline = () => setOnline(false);

    window.addEventListener("online", goOnline);
    window.addEventListener("offline", goOffline);
    return () => {
      window.removeEventListener("online", goOnline);
      window.removeEventListener("offline", goOffline);
    };
  }, []);

  if (!mounted || online) return null;

  return (
    <div
      role="status"
      aria-live="polite"
      className="sticky top-0 z-50 w-full bg-amber-500/90 px-6 py-2 text-center text-[12px] font-medium text-ink shadow-sm backdrop-blur"
    >
      {t("offline")}
    </div>
  );
}
