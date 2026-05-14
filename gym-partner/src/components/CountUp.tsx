"use client";

import { useEffect, useRef, useState } from "react";

const DURATION_MS = 600;

function easeOutCubic(t: number): number {
  return 1 - Math.pow(1 - t, 3);
}

/**
 * Tween a number toward `value` over ~600ms whenever `value` changes
 * post-mount. The **first** render emits `value` directly — both on
 * the server (SSR) and on the client's first paint — so the
 * hydration tree matches. Without that, the previous implementation
 * SSR'd the final value and then ran a `0 → value` tween from the
 * client's first frame, producing a React hydration mismatch error.
 *
 * Subsequent value updates (poll-driven dashboard refreshes) animate
 * from the previous displayed value to the new one. Reduced-motion
 * users get the snap-to-final behaviour throughout.
 */
export function CountUp({
  value,
  format = (n) => n.toLocaleString("en-US"),
  className,
}: {
  value: number;
  format?: (n: number) => string;
  className?: string;
}) {
  const [display, setDisplay] = useState<number>(value);
  const targetRef = useRef<number>(value);
  const mountedRef = useRef<boolean>(false);

  useEffect(() => {
    const previousTarget = targetRef.current;
    targetRef.current = value;

    if (!mountedRef.current) {
      mountedRef.current = true;
      return;
    }

    const reducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reducedMotion) {
      setDisplay(value);
      return;
    }

    const start = performance.now();
    const from = previousTarget;
    let raf = 0;
    const tick = (now: number) => {
      const elapsed = now - start;
      const t = Math.min(1, elapsed / DURATION_MS);
      const eased = easeOutCubic(t);
      const current = from + (targetRef.current - from) * eased;
      setDisplay(current);
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value]);

  return (
    <span className={className} aria-label={format(value)}>
      {format(Math.round(display))}
    </span>
  );
}
