"use client";

import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";

import {
  CropperDialog,
  CropperViewport,
  SegmentedControl,
  SnapPresets,
  ZoomSlider,
  type CropEngine,
  useCropEngine,
} from "@/components/cropper";
import {
  DEFAULT_LOGO_ALIGNMENT,
  type LogoAlignment,
} from "@/lib/sdk";

/// Output target for a saved logo. The largest surface that renders
/// the logo today is the gym detail page (~200pt round); 512×512
/// stays comfortably above any device pixel-density at that size
/// without bloating storage.
const OUTPUT_SIZE = 512;

const POSITIONS = ["top", "center", "bottom"] as const;
const FITS = ["cover", "contain"] as const;

/**
 * Logo cropper. Square viewport with two output paths:
 *
 *   FILL — partner drags + zooms to compose. On Apply we render a
 *   fresh 512×512 JPEG of the visible region. Saved alignment is
 *   `{fit: "cover", position: "center"}` — the file already IS the
 *   crop, so renderers don't need any alignment logic.
 *
 *   CONTAIN — for transparent-background marks where any crop
 *   would clip meaningful pixels. The original file is uploaded
 *   unchanged and `{fit: "contain", position: "center"}` is stored
 *   so renderers letterbox it inside the chip.
 *
 * The drag/zoom math, pointer handling, canvas export, and modal
 * scaffolding all come from the shared `cropper` bundle —
 * `LogoCropper` is just the logo-specific control wiring.
 */
export function LogoCropper({
  open,
  imageFile,
  imageUrl,
  initialAlignment,
  pending,
  onApply,
  onCancel,
}: {
  open: boolean;
  imageFile: File | null;
  imageUrl: string | null;
  initialAlignment: LogoAlignment | null;
  pending?: boolean;
  /** Receives the file to upload (a fresh canvas-derived JPEG in
   *  Fill mode, the original file in Contain mode) plus the
   *  alignment record to persist alongside it. */
  onApply: (file: File, alignment: LogoAlignment) => void;
  onCancel: () => void;
}) {
  const t = useTranslations("profile");
  const [fit, setFit] = useState<LogoAlignment["fit"]>("cover");
  const [exporting, setExporting] = useState(false);

  const engine = useCropEngine({ imageUrl, enabled: fit === "cover" });

  useEffect(() => {
    if (open) {
      setFit(initialAlignment?.fit ?? DEFAULT_LOGO_ALIGNMENT.fit);
    }
  }, [open, initialAlignment]);

  const isContain = fit === "contain";
  const busy = Boolean(pending) || exporting;

  async function handleApply() {
    if (!imageFile || !imageUrl) return;
    if (isContain) {
      onApply(imageFile, { fit: "contain", position: "center" });
      return;
    }
    setExporting(true);
    try {
      const cropped = await engine.exportToFile({
        sourceUrl: imageUrl,
        sourceFileName: imageFile.name,
        outputWidth: OUTPUT_SIZE,
        outputHeight: OUTPUT_SIZE,
      });
      onApply(cropped ?? imageFile, { fit: "cover", position: "center" });
    } finally {
      setExporting(false);
    }
  }

  if (!open || !imageUrl || !imageFile) return null;

  const applyLabel = exporting
    ? t("logoCropProcessing")
    : pending
      ? t("logoUploading")
      : t("logoApply");

  return (
    <CropperDialog
      open={open}
      titleId="logo-crop-title"
      title={t("logoCropTitle")}
      busy={busy}
      closeLabel={t("logoCancel")}
      onClose={onCancel}
      footer={
        <>
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="btn-ghost btn-sm"
          >
            {t("logoCancel")}
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
      <p className="text-[12.5px] text-muted">
        {isContain ? t("logoCropContainHint") : t("logoCropFillHint")}
      </p>

      <div className="mx-auto w-full max-w-[min(72vh,360px)]">
        <CropperViewport
          engine={engine}
          imageUrl={imageUrl}
          aspectClass="aspect-square"
          disabled={isContain}
        />
        {!isContain ? (
          <div className="mt-3">
            <ZoomSlider
              value={engine.crop.scale}
              onChange={engine.setZoom}
              zoomInLabel={t("logoZoomIn")}
              zoomOutLabel={t("logoZoomOut")}
              zoomLabel={t("logoZoom")}
            />
          </div>
        ) : null}
      </div>

      <LogoControls
        engine={engine}
        fit={fit}
        onFitChange={(next) => {
          setFit(next);
          if (next === "contain") engine.resetCrop();
        }}
        t={t}
      />
    </CropperDialog>
  );
}

function LogoControls({
  engine,
  fit,
  onFitChange,
  t,
}: {
  engine: CropEngine;
  fit: LogoAlignment["fit"];
  onFitChange: (next: LogoAlignment["fit"]) => void;
  t: ReturnType<typeof useTranslations>;
}) {
  const isContain = fit === "contain";
  const isPristine =
    engine.crop.offsetX === 0 &&
    engine.crop.offsetY === 0 &&
    engine.crop.scale === 1;
  return (
    <div className="flex flex-wrap items-end gap-4">
      <div className="flex flex-col gap-1.5">
        <span className="tracked text-[10.5px] text-muted">{t("logoFit")}</span>
        <SegmentedControl
          value={fit}
          options={FITS.map((f) => ({
            value: f,
            label: t(`logoFitOption.${f}`),
          }))}
          onChange={onFitChange}
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <span className="tracked text-[10.5px] text-muted">
          {t("logoCropSnap")}
        </span>
        <SnapPresets
          onSnap={engine.snapVertical}
          labelTop={t("logoPositionOption.top")}
          labelCenter={t("logoPositionOption.center")}
          labelBottom={t("logoPositionOption.bottom")}
          disabled={isContain}
        />
      </div>
      <button
        type="button"
        onClick={engine.resetCrop}
        disabled={isContain || isPristine}
        className="btn-ghost btn-sm self-end"
      >
        {t("logoCropReset")}
      </button>
    </div>
  );
}

// `POSITIONS` is exported indirectly via translation keys —
// re-export here for consumers that want the source-of-truth list.
export { POSITIONS as LOGO_POSITIONS };
