"use client";

import { useEffect } from "react";

export default function OpenInApp({ code }: { code: string }) {
  useEffect(() => {
    const isMobile = /Android|iPhone|iPad/i.test(navigator.userAgent);
    if (!isMobile) return;
    const url = `gympass://invite/${encodeURIComponent(code)}`;
    const timer = window.setTimeout(() => {
      window.location.href = url;
    }, 100);
    return () => window.clearTimeout(timer);
  }, [code]);
  return null;
}
