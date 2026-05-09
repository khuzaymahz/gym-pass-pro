"use client";

import * as React from "react";

/**
 * Brand-themed loading indicator — a dumbbell that *builds itself*
 * each cycle: plates drop in from above and grow from a sliver to
 * full height, sequenced outer → inner. Once fully assembled it
 * holds for a beat, then resets.
 *
 * Use anywhere the partner portal needs an indeterminate "we're
 * working" indicator — replaces generic browser spinners with a
 * recognisably GymPass mark. Same animation as the mobile app and
 * the admin dashboard, so the brand reads consistent across all
 * three surfaces.
 *
 * Reads accent (the plates) from `--c-accent`, neutrals (grip + caps
 * + knurl) from `--c-line-2` / `--c-bg`, so a future palette tweak
 * propagates without touching this file.
 *
 * Sizes follow the mobile contract:
 *   - `sm` (24×16) — single plate per side, fits inside a button.
 *   - `md` (32×22) — two plates per side, default for inline content.
 *   - `lg` (48×32) — full three-plate composition for hero spots.
 */
export type GymLoaderSize = "sm" | "md" | "lg";

export interface GymLoaderProps {
  size?: GymLoaderSize;
  /** Override the plate colour for tier-tinted loaders. Defaults to `--c-accent`. */
  color?: string;
  /** Accessible label announced to screen readers while the loader is mounted. */
  ariaLabel?: string;
  className?: string;
}

const SIZE_TABLE: Record<
  GymLoaderSize,
  { width: number; height: number; plates: number }
> = {
  sm: { width: 24, height: 16, plates: 1 },
  md: { width: 32, height: 22, plates: 2 },
  lg: { width: 48, height: 32, plates: 3 },
};

/** Plate geometry in unit-fractions, outer → inner. Sliced by plate count. */
const PLATE_SPECS: Array<{ w: number; h: number }> = [
  { w: 0.16, h: 0.96 },
  { w: 0.14, h: 0.82 },
  { w: 0.12, h: 0.66 },
];

const clamp01 = (v: number) => Math.max(0, Math.min(1, v));
const easeOutCubic = (t: number) => 1 - Math.pow(1 - t, 3);

/** rAF clock that yields seconds-since-mount. Pauses on unmount. */
function useTime(active: boolean): number {
  const [t, setT] = React.useState(0);
  React.useEffect(() => {
    if (!active) return;
    let raf = 0;
    const start = performance.now();
    const loop = (now: number) => {
      setT((now - start) / 1000);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [active]);
  return t;
}

export function GymLoader({
  size = "md",
  color,
  ariaLabel = "Loading",
  className,
}: GymLoaderProps) {
  // Honour the OS reduced-motion preference — show the assembled
  // dumbbell statically rather than burn frames repainting plates
  // for users who've asked the browser to stop animating things.
  const reducedMotion = usePrefersReducedMotion();
  const t = useTime(!reducedMotion);

  const { width, height, plates: plateCount } = SIZE_TABLE[size];
  const plates = PLATE_SPECS.slice(0, plateCount);

  // Cycle: plates finish dropping at the 80 % mark (`progress`
  // hits 1.0), then the dumbbell holds for the remaining 320 ms
  // before resetting. Was 2.4 s originally — read as sluggish on
  // quick form submits where the network round-trip beat the
  // animation to "fully built". 1.6 s is brisk enough that a
  // fast submit sees most of a cycle, slow enough that the eye
  // still registers the assembled shape during the hold.
  const cycle = 1.6;
  const progress = reducedMotion
    ? 1
    : clamp01(((t % cycle) / cycle) * 1.25);

  // Total dumbbell width in unit-fractions: grip + 2 × (cap + spacer)
  // + 2 × Σ(plate widths). Pick the unit so the dumbbell scales to
  // the smaller of the two axes — preserves aspect across the three
  // box sizes without distortion.
  const totalPlateW = plates.reduce((a, p) => a + p.w, 0);
  const widthUnits = 0.9 + 2 * (0.1 + 0.06) + 2 * totalPlateW;
  const heightUnits = 1.2;
  const unit = Math.min(width / widthUnits, height / heightUnits);

  const cx = width / 2;
  const cy = height / 2;
  const gripW = unit * 0.9;
  const gripH = unit * 0.18;
  const capW = unit * 0.1;
  const capH = unit * 0.55;
  const gripLeft = cx - gripW / 2;
  const gripTop = cy - gripH / 2;

  const plateColor = color ?? "rgb(var(--c-accent))";
  const gripColor = "rgb(var(--c-line-2))";
  const knurlColor = "rgb(var(--c-bg))";
  const capColor = "rgb(var(--c-line-2) / 0.92)";

  const knurlVisible = unit >= 16;
  const knurlMarks: number[] = [];
  if (knurlVisible) {
    for (let i = 0; i < 7; i++) {
      const x = gripLeft + unit * 0.15 + i * unit * 0.1;
      if (x > gripLeft + gripW - unit * 0.05) break;
      knurlMarks.push(x);
    }
  }

  return (
    <span
      role="status"
      aria-label={ariaLabel}
      className={className}
      style={{ display: "inline-flex", lineHeight: 0 }}
    >
      <svg
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        aria-hidden="true"
        focusable="false"
      >
        {/* GRIP — solid bar, single colour, soft top highlight. */}
        <rect
          x={gripLeft}
          y={gripTop}
          width={gripW}
          height={gripH}
          rx={gripH * 0.35}
          fill={gripColor}
        />

        {/* KNURL — light tick marks across the grip face. */}
        {knurlMarks.map((x, i) => (
          <line
            key={i}
            x1={x}
            y1={cy - gripH * 0.3}
            x2={x}
            y2={cy + gripH * 0.3}
            stroke={knurlColor}
            strokeWidth={1.2}
            strokeLinecap="round"
            opacity={0.55}
          />
        ))}

        {/* END CAPS — clean rounded rectangles flanking the grip. */}
        {[-1, 1].map((side) => {
          const capX =
            cx + (side * gripW) / 2 + (side < 0 ? -capW : 0);
          return (
            <rect
              key={`cap-${side}`}
              x={capX}
              y={cy - capH / 2}
              width={capW}
              height={capH}
              rx={unit * 0.05}
              fill={capColor}
            />
          );
        })}

        {/* PLATES — drop in sequentially per side, outer → inner. */}
        {[-1, 1].map((side) => {
          let runner = cx + (side * gripW) / 2 + side * capW;
          return (
            <g key={`plates-${side}`}>
              {plates.map((p, i) => {
                const start = i / plates.length;
                const local = clamp01(
                  (progress - start) * plates.length * 1.15,
                );
                const e = easeOutCubic(local);
                const pw = p.w * unit;
                const ph = p.h * unit * e;
                const xPos = side < 0 ? runner - pw : runner;
                runner += side * pw;
                if (e <= 0) return null;
                const dropOffset = (1 - e) * unit * 0.25;
                const yPos = cy - ph / 2 + dropOffset;
                // Glow snap once the plate is essentially fully formed
                // — mirrors the React reference's drop-shadow appearing
                // at e > 0.92, marking the moment the plate "lands".
                const glow =
                  e > 0.92 && unit >= 12
                    ? `drop-shadow(0 0 ${unit * 0.1}px rgb(var(--c-accent) / 0.45))`
                    : "none";
                // Plate alpha floors at 0.55 so each plate is
                // already legibly visible the moment its drop
                // starts, then ramps to full opacity as it lands.
                // The earlier "0 → 1 with `e`" curve made plates
                // ghost in from invisible — read as washed-out
                // during the build. Floor + ramp keeps the
                // sequencing legible while making the dumbbell
                // read as *solid* throughout.
                const plateOpacity = 0.55 + 0.45 * e;
                return (
                  <rect
                    key={i}
                    x={xPos}
                    y={yPos}
                    width={pw}
                    height={ph}
                    rx={unit * 0.04}
                    fill={plateColor}
                    opacity={plateOpacity}
                    style={{ filter: glow }}
                  />
                );
              })}
            </g>
          );
        })}
      </svg>
    </span>
  );
}

function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = React.useState(false);
  React.useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);
  return reduced;
}

export default GymLoader;
