"use client";

import { CROP_LIMITS } from "./cropper-core";
import { MinusIcon, PlusIcon } from "./icons";

/// Zoom slider strip — minus button, range input, plus button, value
/// readout. Centralised so both croppers display the zoom control
/// the same way and the +/- step stays in lockstep with the slider
/// granularity.
export function ZoomSlider({
  value,
  onChange,
  zoomInLabel,
  zoomOutLabel,
  zoomLabel,
}: {
  value: number;
  onChange: (next: number) => void;
  zoomInLabel: string;
  zoomOutLabel: string;
  zoomLabel: string;
}) {
  const { minScale, maxScale } = CROP_LIMITS;
  return (
    <div className="flex items-center gap-3">
      <button
        type="button"
        onClick={() => onChange(value - 0.2)}
        disabled={value <= minScale + 0.001}
        className="btn-icon"
        aria-label={zoomOutLabel}
      >
        <MinusIcon />
      </button>
      <input
        type="range"
        min={minScale}
        max={maxScale}
        step={0.01}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        className="zoom-slider flex-1"
        aria-label={zoomLabel}
      />
      <button
        type="button"
        onClick={() => onChange(value + 0.2)}
        disabled={value >= maxScale - 0.001}
        className="btn-icon"
        aria-label={zoomInLabel}
      >
        <PlusIcon />
      </button>
      <span className="num w-10 text-end text-[11px] tabular-nums text-muted">
        {value.toFixed(1)}×
      </span>
    </div>
  );
}
