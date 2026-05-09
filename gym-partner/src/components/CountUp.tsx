"use client";

import { useEffect, useRef, useState } from "react";

const DURATION_MS = 600;
// cubic ease-out — settles a hair under 1.0 so the final frame
// snaps to the precise number rather than asymptotically approaching it.
function easeOutCubic(t: number): number {
  return 1 - Math.pow(1 - t, 3);
}

/**
 * Tween a number from 0 → `value` over ~600ms on mount. The
 * displayed number tracks the partner's prefers-reduced-motion
 * setting: when set, the count-up is skipped and the final value
 * is shown immediately — animations are decorative here, not
 * meaning-bearing.
 *
 * The tween is render-driven (re-render per RAF tick), which is
 * fine at the volume on the dashboard (≤ 8 stat cards) but should
 * not be reused in tight lists. For chart axes / row counts, render
 * the static value directly.
 */
export function CountUp({
  value,
  format = (n) => n.toLocaleString("en-US"),
  className,
}: {
  value: number;
  /** Optional formatter so the same component can render integers,
   *  decimals, currency, etc. without internal switches. */
  format?: (n: number) => string;
  className?: string;
}) {
  const [display, setDisplay] = useState<number>(() => {
    if (typeof window === "undefined") return value;
    if (
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      return value;
    }
    return 0;
  });
  // Track the current target so a value change mid-tween doesn't
  // race the previous animation. Using a ref instead of state
  // avoids re-running the effect on every re-render.
  const targetRef = useRef<number>(value);

  useEffect(() => {
    targetRef.current = value;
    if (
      typeof window !== "undefined" &&
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      setDisplay(value);
      return;
    }
    const start = performance.now();
    const from = 0;
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

  // Round during the tween so the eye doesn't see fractional decimals
  // ticking up — hand the rounded number to the formatter unchanged.
  return (
    <span className={className} aria-label={format(value)}>
      {format(Math.round(display))}
    </span>
  );
}
