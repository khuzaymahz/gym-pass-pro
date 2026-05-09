"use client";

import type { SnapDirection } from "./cropper-core";

/// Three-button group for vertical alignment quick-snap (top /
/// center / bottom). Used by both croppers; same `seg` styling as
/// the rest of the partner portal segmented controls.
export function SnapPresets({
  onSnap,
  labelTop,
  labelCenter,
  labelBottom,
  disabled,
}: {
  onSnap: (direction: SnapDirection) => void;
  labelTop: string;
  labelCenter: string;
  labelBottom: string;
  disabled?: boolean;
}) {
  return (
    <div
      className={`seg ${disabled ? "pointer-events-none opacity-50" : ""}`}
      role="group"
      aria-disabled={disabled}
    >
      <button type="button" onClick={() => onSnap("top")} disabled={disabled}>
        {labelTop}
      </button>
      <button type="button" onClick={() => onSnap("center")} disabled={disabled}>
        {labelCenter}
      </button>
      <button type="button" onClick={() => onSnap("bottom")} disabled={disabled}>
        {labelBottom}
      </button>
    </div>
  );
}
