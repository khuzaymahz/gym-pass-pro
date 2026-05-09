"use client";

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type Dispatch,
  type PointerEvent as ReactPointerEvent,
  type RefObject,
  type SetStateAction,
  type WheelEvent as ReactWheelEvent,
} from "react";

/**
 * Shared cropper engine.
 *
 * Both `LogoCropper` (1:1 + alignment metadata) and `PhotoCropper`
 * (4:5 portrait, no metadata) need the same fundamentals:
 *
 *   1. A draggable, zoomable viewport that always keeps the source
 *      image fully covering the frame (cover-baseline math).
 *   2. Clamped offsets so the user can never reveal a transparent
 *      edge.
 *   3. Pointer Events for mouse/touch/pen unified.
 *   4. Wheel zoom with `preventDefault`.
 *   5. Vertical snap presets (top / center / bottom).
 *   6. A canvas-based export that produces a fresh JPEG of the
 *      visible region, parameterized by output dimensions.
 *   7. Modal scaffolding (Esc to close, body scroll lock, focus
 *      trap entry, backdrop click).
 *
 * Putting these in one place removes ~400 lines of duplication and
 * gives both components a single contract to test against.
 */

export type CropState = {
  offsetX: number;
  offsetY: number;
  /** Zoom multiplier on top of the cover-baseline scale. 1.0 = the
   *  image just covers the viewport; 4.0 = 4× tighter crop. */
  scale: number;
};

export type ImageNaturalSize = { width: number; height: number };

export const INITIAL_CROP: CropState = { offsetX: 0, offsetY: 0, scale: 1 };

export const CROP_LIMITS = {
  minScale: 1.0,
  maxScale: 4.0,
} as const;

export type SnapDirection = "top" | "center" | "bottom";

export type ExportOptions = {
  /** Source image URL — usually a blob: URL from a staged File. */
  sourceUrl: string;
  /** File name we want to give the exported file (extension is
   *  forced to `.jpg` since we always re-encode as JPEG). */
  sourceFileName: string;
  outputWidth: number;
  outputHeight: number;
  /** JPEG quality 0..1. Default 0.9 — visually transparent and
   *  ~70% smaller than lossless. */
  quality?: number;
};

export type CropEngine = {
  crop: CropState;
  setCrop: Dispatch<SetStateAction<CropState>>;
  resetCrop: () => void;
  naturalSize: ImageNaturalSize | null;
  /** Attach to the viewport `<div>`. Used both as the pointer
   *  capture target and as the source for runtime dimensions. */
  viewportRef: RefObject<HTMLDivElement>;
  pointerHandlers: {
    onPointerDown: (e: ReactPointerEvent<HTMLDivElement>) => void;
    onPointerMove: (e: ReactPointerEvent<HTMLDivElement>) => void;
    onPointerUp: (e: ReactPointerEvent<HTMLDivElement>) => void;
    onPointerCancel: (e: ReactPointerEvent<HTMLDivElement>) => void;
  };
  onWheel: (e: ReactWheelEvent<HTMLDivElement>) => void;
  setZoom: (next: number) => void;
  snapVertical: (direction: SnapDirection) => void;
  /** Renders the visible region to an offscreen canvas at the
   *  given output dimensions and returns a JPEG `File`. Returns
   *  `null` when the image hasn't loaded yet or the canvas API
   *  can't produce a blob. */
  exportToFile: (opts: ExportOptions) => Promise<File | null>;
  /** Total scale = cover-baseline × user zoom, computed from
   *  whatever the viewport currently measures. Useful for
   *  positioning the displayed image. */
  computeTotalScale: () => number;
};

const DEFAULT_QUALITY = 0.9;

export function useCropEngine(opts: {
  imageUrl: string | null;
  /** When false (e.g. logo "contain" mode), drag/zoom/snap become
   *  no-ops. The engine is still mounted so the UI can read state. */
  enabled?: boolean;
}): CropEngine {
  const { imageUrl, enabled = true } = opts;

  const [crop, setCrop] = useState<CropState>(INITIAL_CROP);
  const [naturalSize, setNaturalSize] = useState<ImageNaturalSize | null>(null);

  // `useRef<HTMLDivElement>(null)` — generic stays unioned with
  // null in the runtime ref but the public `RefObject<HTMLDivElement>`
  // type matches what `<div ref>` expects from JSX without the
  // `LegacyRef` widening complaint.
  const viewportRef = useRef<HTMLDivElement>(null) as RefObject<HTMLDivElement>;
  const dragRef = useRef<{
    pointerId: number;
    startClientX: number;
    startClientY: number;
    startOffsetX: number;
    startOffsetY: number;
  } | null>(null);

  // Reset state when the source image swaps. Keep the effect
  // narrowly scoped — independent state updates so React batches
  // them on a single render.
  useEffect(() => {
    setCrop(INITIAL_CROP);
    setNaturalSize(null);
    if (!imageUrl) return;
    const img = new Image();
    img.onload = (): void => {
      setNaturalSize({ width: img.naturalWidth, height: img.naturalHeight });
    };
    img.src = imageUrl;
  }, [imageUrl]);

  const viewportDims = useCallback((): { width: number; height: number } => {
    const el = viewportRef.current;
    if (!el) return { width: 0, height: 0 };
    return { width: el.clientWidth, height: el.clientHeight };
  }, []);

  const coverScale = useCallback(
    (vw: number, vh: number): number => {
      if (!naturalSize || vw === 0 || vh === 0) return 1;
      return Math.max(vw / naturalSize.width, vh / naturalSize.height);
    },
    [naturalSize],
  );

  const clamp = useCallback(
    (state: CropState, vw: number, vh: number): CropState => {
      if (!naturalSize) return state;
      const total = coverScale(vw, vh) * state.scale;
      const scaledW = naturalSize.width * total;
      const scaledH = naturalSize.height * total;
      const maxX = Math.max(0, (scaledW - vw) / 2);
      const maxY = Math.max(0, (scaledH - vh) / 2);
      return {
        ...state,
        offsetX: Math.max(-maxX, Math.min(maxX, state.offsetX)),
        offsetY: Math.max(-maxY, Math.min(maxY, state.offsetY)),
      };
    },
    [naturalSize, coverScale],
  );

  const onPointerDown = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>): void => {
      if (!enabled || !viewportRef.current) return;
      e.preventDefault();
      viewportRef.current.setPointerCapture(e.pointerId);
      dragRef.current = {
        pointerId: e.pointerId,
        startClientX: e.clientX,
        startClientY: e.clientY,
        startOffsetX: crop.offsetX,
        startOffsetY: crop.offsetY,
      };
    },
    [enabled, crop.offsetX, crop.offsetY],
  );

  const onPointerMove = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>): void => {
      const drag = dragRef.current;
      if (!drag || drag.pointerId !== e.pointerId) return;
      const { width, height } = viewportDims();
      setCrop((c) =>
        clamp(
          {
            ...c,
            offsetX: drag.startOffsetX + (e.clientX - drag.startClientX),
            offsetY: drag.startOffsetY + (e.clientY - drag.startClientY),
          },
          width,
          height,
        ),
      );
    },
    [viewportDims, clamp],
  );

  const releaseDrag = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>): void => {
      if (!dragRef.current) return;
      if (viewportRef.current?.hasPointerCapture(e.pointerId)) {
        viewportRef.current.releasePointerCapture(e.pointerId);
      }
      dragRef.current = null;
    },
    [],
  );

  const onWheel = useCallback(
    (e: ReactWheelEvent<HTMLDivElement>): void => {
      if (!enabled) return;
      e.preventDefault();
      const { width, height } = viewportDims();
      const delta = -e.deltaY * 0.002;
      setCrop((c) =>
        clamp(
          {
            ...c,
            scale: clampScale(c.scale + delta),
          },
          width,
          height,
        ),
      );
    },
    [enabled, viewportDims, clamp],
  );

  const setZoom = useCallback(
    (next: number): void => {
      if (!enabled) return;
      const { width, height } = viewportDims();
      setCrop((c) => clamp({ ...c, scale: clampScale(next) }, width, height));
    },
    [enabled, viewportDims, clamp],
  );

  const snapVertical = useCallback(
    (direction: SnapDirection): void => {
      if (!enabled || !naturalSize) return;
      const { width, height } = viewportDims();
      const total = coverScale(width, height) * crop.scale;
      const scaledH = naturalSize.height * total;
      const halfOver = (scaledH - height) / 2;
      const offsetY =
        direction === "top"
          ? halfOver
          : direction === "bottom"
            ? -halfOver
            : 0;
      setCrop((c) => clamp({ ...c, offsetY, offsetX: 0 }, width, height));
    },
    [enabled, naturalSize, viewportDims, coverScale, clamp, crop.scale],
  );

  const resetCrop = useCallback((): void => {
    setCrop(INITIAL_CROP);
  }, []);

  const computeTotalScale = useCallback((): number => {
    const { width, height } = viewportDims();
    return coverScale(width, height) * crop.scale;
  }, [viewportDims, coverScale, crop.scale]);

  const exportToFile = useCallback(
    async (exportOpts: ExportOptions): Promise<File | null> => {
      if (!naturalSize) return null;
      const img = await loadImage(exportOpts.sourceUrl);
      const canvas = document.createElement("canvas");
      canvas.width = exportOpts.outputWidth;
      canvas.height = exportOpts.outputHeight;
      const ctx = canvas.getContext("2d");
      if (!ctx) return null;

      // Translate viewport-pixel offsets back into source-image
      // pixel space so the export is independent of how big the
      // viewport happened to be at apply time.
      const { width: vw, height: vh } = viewportDims();
      const total = coverScale(vw, vh) * crop.scale;
      const sourceCropW = vw / total;
      const sourceCropH = vh / total;
      const cx = naturalSize.width / 2 - crop.offsetX / total;
      const cy = naturalSize.height / 2 - crop.offsetY / total;

      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = "high";
      ctx.drawImage(
        img,
        cx - sourceCropW / 2,
        cy - sourceCropH / 2,
        sourceCropW,
        sourceCropH,
        0,
        0,
        exportOpts.outputWidth,
        exportOpts.outputHeight,
      );

      const blob = await canvasToJpegBlob(canvas, exportOpts.quality);
      if (!blob) return null;
      const baseName = exportOpts.sourceFileName.replace(/\.[^/.]+$/, "");
      return new File([blob], `${baseName}.jpg`, { type: "image/jpeg" });
    },
    [naturalSize, viewportDims, coverScale, crop],
  );

  return {
    crop,
    setCrop,
    resetCrop,
    naturalSize,
    viewportRef,
    pointerHandlers: {
      onPointerDown,
      onPointerMove,
      onPointerUp: releaseDrag,
      onPointerCancel: releaseDrag,
    },
    onWheel,
    setZoom,
    snapVertical,
    exportToFile,
    computeTotalScale,
  };
}

function clampScale(n: number): number {
  return Math.max(CROP_LIMITS.minScale, Math.min(CROP_LIMITS.maxScale, n));
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = (): void => resolve(img);
    img.onerror = (): void => reject(new Error("Image failed to load"));
    img.src = src;
  });
}

function canvasToJpegBlob(
  canvas: HTMLCanvasElement,
  quality: number = DEFAULT_QUALITY,
): Promise<Blob | null> {
  return new Promise((resolve) => {
    canvas.toBlob(resolve, "image/jpeg", quality);
  });
}
