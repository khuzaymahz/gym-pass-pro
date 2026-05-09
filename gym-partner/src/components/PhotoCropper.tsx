"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

import {
  CropperDialog,
  CropperViewport,
  SnapPresets,
  ZoomSlider,
  useCropEngine,
} from "@/components/cropper";

/// Output target. The mobile gym-detail hero renders gallery
/// photos at 400 px height across the device width — a 4:5 portrait
/// roughly matches what a member sees. 1024 × 1280 is comfortably
/// above any device pixel-density at that size, and JPEG quality
/// 0.9 keeps a typical interior shot in the 200–500 KB range.
const OUTPUT_WIDTH = 1024;
const OUTPUT_HEIGHT = 1280;

/**
 * Gallery-photo cropper. 4:5 portrait viewport matching the mobile
 * hero's `BoxFit.cover` rendering. On Apply we render a fresh
 * 1024×1280 JPEG of the visible region and hand it back to the
 * caller — no alignment metadata, the file IS the crop.
 */
export function PhotoCropper({
  open,
  imageFile,
  imageUrl,
  pending,
  onApply,
  onCancel,
}: {
  open: boolean;
  imageFile: File | null;
  imageUrl: string | null;
  pending?: boolean;
  onApply: (file: File) => void;
  onCancel: () => void;
}) {
  const t = useTranslations("photos");
  const tCrop = useTranslations("profile");
  const [exporting, setExporting] = useState(false);

  const engine = useCropEngine({ imageUrl });

  const busy = Boolean(pending) || exporting;

  async function handleApply() {
    if (!imageFile || !imageUrl) return;
    setExporting(true);
    try {
      const cropped = await engine.exportToFile({
        sourceUrl: imageUrl,
        sourceFileName: imageFile.name,
        outputWidth: OUTPUT_WIDTH,
        outputHeight: OUTPUT_HEIGHT,
      });
      onApply(cropped ?? imageFile);
    } finally {
      setExporting(false);
    }
  }

  if (!open || !imageUrl || !imageFile) return null;

  const isPristine =
    engine.crop.offsetX === 0 &&
    engine.crop.offsetY === 0 &&
    engine.crop.scale === 1;
  const applyLabel = exporting
    ? tCrop("logoCropProcessing")
    : pending
      ? t("uploading")
      : tCrop("logoApply");

  return (
    <CropperDialog
      open={open}
      titleId="photo-crop-title"
      title={t("cropTitle")}
      busy={busy}
      closeLabel={tCrop("logoCancel")}
      onClose={onCancel}
      footer={
        <>
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="btn-ghost btn-sm"
          >
            {tCrop("logoCancel")}
          </button>
          <button
            type="button"
            onClick={handleApply}
            disabled={busy || !engine.naturalSize}
            className="btn-primary btn-sm"
          >
            {applyLabel}
          </button>
        </>
      }
    >
      <p className="text-[12.5px] text-muted">{t("cropSubtitle")}</p>

      <div className="mx-auto w-full max-w-[min(70vh,320px)]">
        <CropperViewport
          engine={engine}
          imageUrl={imageUrl}
          aspectClass="aspect-[4/5]"
        />
        <div className="mt-3">
          <ZoomSlider
            value={engine.crop.scale}
            onChange={engine.setZoom}
            zoomInLabel={tCrop("logoZoomIn")}
            zoomOutLabel={tCrop("logoZoomOut")}
            zoomLabel={tCrop("logoZoom")}
          />
        </div>
      </div>

      <div className="flex flex-wrap items-end gap-4">
        <div className="flex flex-col gap-1.5">
          <span className="tracked text-[10.5px] text-muted">
            {tCrop("logoCropSnap")}
          </span>
          <SnapPresets
            onSnap={engine.snapVertical}
            labelTop={tCrop("logoPositionOption.top")}
            labelCenter={tCrop("logoPositionOption.center")}
            labelBottom={tCrop("logoPositionOption.bottom")}
          />
        </div>
        <button
          type="button"
          onClick={engine.resetCrop}
          disabled={isPristine}
          className="btn-ghost btn-sm self-end"
        >
          {tCrop("logoCropReset")}
        </button>
      </div>
    </CropperDialog>
  );
}
