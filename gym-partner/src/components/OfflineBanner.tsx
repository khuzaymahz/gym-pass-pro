"use client";

import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";

/// Top-of-page banner that surfaces "you're offline" the moment the
/// browser fires its `offline` event. Pairs with the API-client side
/// of W1 — when `lib/api.ts` throws a `NetworkError` because the
/// fetch couldn't reach the backend, the banner gives the gym owner
/// the standing context they need to interpret the failure (gym Wi-Fi
/// flaked out, dashboard 500'd).
///
/// Why client-side only:
///
///   * `navigator.onLine` is browser-only; SSR has no opinion. We
///     default-render `null` and only mount the banner after
///     hydration — no FOUC because nothing renders pre-hydration.
///   * `online` / `offline` events fire on interface state change.
///     More responsive than polling, and free.
///   * `navigator.onLine` is heuristic — it reports the OS
///     interface state, not actual reachability. A captive portal
///     would report online while every fetch hangs. The
///     authoritative signal is the `NetworkError` raised by
///     `lib/api.ts`; this banner is optional pre-emptive context.
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
      className="sticky top-0 z-50 w-full bg-amber-500/90 px-6 py-2 text-center text-[12px] font-medium text-slate-900 shadow-sm backdrop-blur"
    >
      {t("offline")}
    </div>
  );
}
