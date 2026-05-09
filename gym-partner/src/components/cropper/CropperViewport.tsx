"use client";

import type { CropEngine } from "./cropper-core";
import { ThirdsOverlay } from "./ThirdsOverlay";

/// Draggable, zoomable viewport bound to a `CropEngine`. The
/// caller picks the aspect via `aspectClass` (e.g. `aspect-square`,
/// `aspect-[4/5]`) and provides the source URL — everything else
/// is wired through the engine's pointer/wheel handlers.
///
/// Renders the rule-of-thirds overlay by default since both
/// croppers want it. Pass `disabled` to render the source image at
/// `object-fit: contain` and skip the drag affordance — used by
/// the logo cropper's "Contain" mode.
export function CropperViewport({
  engine,
  imageUrl,
  aspectClass,
  disabled,
}: {
  engine: CropEngine;
  imageUrl: string;
  aspectClass: string;
  disabled?: boolean;
}) {
  const { naturalSize, viewportRef, pointerHandlers, onWheel, computeTotalScale, crop } =
    engine;

  if (disabled) {
    return (
      <div
        className={`relative ${aspectClass} w-full overflow-hidden rounded-md border border-line bg-ink`}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={imageUrl}
          alt=""
          className="h-full w-full object-contain"
          draggable={false}
        />
      </div>
    );
  }

  const totalScale = computeTotalScale();

  return (
    <div
      ref={viewportRef}
      className={`relative ${aspectClass} w-full cursor-grab touch-none overflow-hidden rounded-md border border-line bg-ink active:cursor-grabbing`}
      {...pointerHandlers}
      onWheel={onWheel}
    >
      {naturalSize ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={imageUrl}
          alt=""
          draggable={false}
          className="absolute left-1/2 top-1/2 max-w-none select-none"
          style={{
            width: naturalSize.width,
            height: naturalSize.height,
            transform: `translate(calc(-50% + ${crop.offsetX}px), calc(-50% + ${crop.offsetY}px)) scale(${totalScale})`,
            transformOrigin: "center",
          }}
        />
      ) : null}
      <ThirdsOverlay />
    </div>
  );
}
