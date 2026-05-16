"use client";

import { useEffect } from "react";

/// Best-effort auto-redirect into the GymPass app on page load.
///
/// Strategy: fire the custom-scheme URL via `window.location` so the
/// OS attempts to resolve it. If the app is installed, Android /
/// iOS will swap apps and our page becomes a brief flash; if not,
/// the scheme silently fails (modern mobile browsers swallow
/// unknown-scheme errors) and the user is left on the page below,
/// which shows the install CTA. We avoid the popular "iframe trick"
/// because it triggers full-screen download warnings on iOS Safari.
///
/// The effect runs once per slug. We delay 100 ms so the page has
/// time to paint the install CTA before the OS prompt fires —
/// otherwise the user lands on a blank flash if the scheme bounces.
export default function OpenInApp({ slug }: { slug: string }) {
  useEffect(() => {
    const isMobile = /Android|iPhone|iPad/i.test(navigator.userAgent);
    if (!isMobile) return;
    const url = `gympass://gyms/${encodeURIComponent(slug)}`;
    const timer = window.setTimeout(() => {
      window.location.href = url;
    }, 100);
    return () => window.clearTimeout(timer);
  }, [slug]);
  return null;
}
