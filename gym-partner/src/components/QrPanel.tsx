"use client";

import { useTranslations } from "next-intl";
import { useEffect, useRef, useState } from "react";

import { Wordmark } from "./Wordmark";

/// Canonical QR payload — must match the backend's accepted formats
/// in `app/services/checkin_service.py::_resolve_gym`. The mobile
/// app's scanner reads the raw string and forwards it verbatim;
/// the backend strips the URL prefix and resolves the gym by UUID.
///
/// We emit a real HTTPS URL (not the legacy `gympass:` URI scheme)
/// so a member scanning the code with a generic phone camera —
/// before they've installed the app — is taken to the website
/// instead of seeing an unhandled-scheme prompt. The edge (nginx)
/// 302s `/g/*` to the apex landing, which today is a placeholder
/// and will later branch to the platform-specific install path.
const QR_SCAN_BASE_URL = "https://gym-pass.net/g/";

/// `error correction level H` recovers from ~30% damage — slightly
/// larger QR pattern in exchange for resilience against print
/// smudges, tape glare, partial coverage by the camera. The full
/// URL form is ~58 chars (`https://gym-pass.net/g/` + 36-char
/// UUID), still inside the version-4 byte-mode cap at H, so the
/// bump doesn't push us into an uncomfortably dense pattern.
const ERROR_CORRECTION = "H" as const;

/// Pixel sizes for the rendered output. The on-screen preview is
/// fixed at PREVIEW_PX so layout doesn't reflow as the user toggles
/// between dark / print mode. PNG download is the print resolution
/// — 1024px @ ~200dpi prints at ~13cm square, comfortable for a
/// gym door sign.
const PREVIEW_PX = 320;
const PNG_EXPORT_PX = 1024;

/// Brand-amber rendering used in the on-screen preview only. Print
/// downloads use canonical black-on-white because:
///   - Cheap printers blow non-black inks first.
///   - Most QR scanners verify high contrast — black-on-white is
///     the canonical "must work everywhere" pair.
///   - The brand version is for visual demonstration; the print is
///     the artefact that needs to scan.
const BRAND_DARK = "#ffb400";
const BRAND_LIGHT = "#0e0e0f";
const PRINT_DARK = "#000000";
const PRINT_LIGHT = "#ffffff";

type GymHeader = {
  id: string;
  slug: string;
  nameEn: string;
  nameAr: string;
};

export function QrPanel({ gym }: { gym: GymHeader }) {
  const t = useTranslations("qr");
  const previewRef = useRef<HTMLDivElement>(null);
  const [previewSvg, setPreviewSvg] = useState<string | null>(null);
  const [busy, setBusy] = useState<"png" | "svg" | "print" | null>(null);
  const [copied, setCopied] = useState(false);

  const payload = `${QR_SCAN_BASE_URL}${gym.id}`;

  // Build the preview once on mount. SVG path-data lets the same
  // string drive both the on-screen render and the SVG download —
  // and an SVG QR scales cleanly to any size, unlike a fixed-pixel
  // canvas which would alias when zoomed.
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const QRCode = (await import("qrcode")).default;
      const svg = await QRCode.toString(payload, {
        type: "svg",
        errorCorrectionLevel: ERROR_CORRECTION,
        margin: 1,
        color: { dark: BRAND_DARK, light: BRAND_LIGHT },
        width: PREVIEW_PX,
      });
      if (!cancelled) setPreviewSvg(svg);
    })();
    return () => {
      cancelled = true;
    };
  }, [payload]);

  async function downloadPng() {
    setBusy("png");
    try {
      const QRCode = (await import("qrcode")).default;
      // Canvas-mode PNG export at print resolution. Forced
      // black-on-white — see PRINT_DARK / PRINT_LIGHT above for why.
      const dataUrl = await QRCode.toDataURL(payload, {
        errorCorrectionLevel: ERROR_CORRECTION,
        margin: 2,
        color: { dark: PRINT_DARK, light: PRINT_LIGHT },
        width: PNG_EXPORT_PX,
      });
      triggerDownload(dataUrl, fileBase(gym, "png"));
    } finally {
      setBusy(null);
    }
  }

  async function downloadSvg() {
    setBusy("svg");
    try {
      const QRCode = (await import("qrcode")).default;
      const svg = await QRCode.toString(payload, {
        type: "svg",
        errorCorrectionLevel: ERROR_CORRECTION,
        margin: 2,
        color: { dark: PRINT_DARK, light: PRINT_LIGHT },
      });
      const blob = new Blob([svg], { type: "image/svg+xml;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      triggerDownload(url, fileBase(gym, "svg"));
      // Revoke after a tick so the click-triggered download has a
      // chance to read the URL before the browser GCs it.
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } finally {
      setBusy(null);
    }
  }

  function openPrintView() {
    setBusy("print");
    try {
      // `window.print()` on the current document with a print
      // stylesheet that hides the chrome and centres the print
      // card. The QR pattern, gym name, and tagline are already
      // rendered inside `.qr-print-card`; print CSS just unhides
      // it and hides everything else.
      window.print();
    } finally {
      setBusy(null);
    }
  }

  async function copyPayload() {
    try {
      await navigator.clipboard.writeText(payload);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard API gated by permissions / non-HTTPS; ignore.
    }
  }

  return (
    <>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[auto_1fr]">
        {/* Preview tile — brand-amber on charcoal so the on-screen
            read matches the rest of the partner portal. */}
        <div className="flex flex-col items-center gap-3">
          <div
            ref={previewRef}
            className="steel relative flex h-[336px] w-[336px] items-center justify-center rounded-lg p-2"
            aria-label={t("previewAria", { gymName: gym.nameEn })}
          >
            {previewSvg ? (
              <div
                className="h-full w-full [&>svg]:h-full [&>svg]:w-full"
                dangerouslySetInnerHTML={{ __html: previewSvg }}
              />
            ) : (
              <span className="text-[12px] text-muted">{t("loading")}</span>
            )}
          </div>
          <p className="tracked text-[10px] text-muted">{t("brandPreview")}</p>
        </div>

        <div className="flex flex-col gap-5">
          <div>
            <span className="tracked text-[11px] text-muted">
              {t("scanTarget")}
            </span>
            <h2 className="mt-1 font-serif text-[28px] font-light leading-[1.05] text-paper">
              {gym.nameEn}
            </h2>
            <p className="num mt-1 text-[12px] text-muted" dir="ltr">
              {payload}
            </p>
          </div>

          <p className="max-w-[480px] text-[13px] leading-[1.55] text-muted">
            {t("explainer")}
          </p>

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={downloadPng}
              disabled={busy !== null || !previewSvg}
              className="btn-primary btn-sm inline-flex items-center gap-2"
            >
              {busy === "png" ? t("preparing") : t("downloadPng")}
            </button>
            <button
              type="button"
              onClick={downloadSvg}
              disabled={busy !== null || !previewSvg}
              className="btn-secondary btn-sm"
            >
              {busy === "svg" ? t("preparing") : t("downloadSvg")}
            </button>
            <button
              type="button"
              onClick={openPrintView}
              disabled={busy !== null || !previewSvg}
              className="btn-secondary btn-sm"
            >
              {t("openPrint")}
            </button>
            <button
              type="button"
              onClick={copyPayload}
              className="btn-ghost btn-sm"
              aria-live="polite"
            >
              {copied ? t("copied") : t("copyPayload")}
            </button>
          </div>

          <div className="rounded-md border border-line-2 bg-bg-2/40 p-4">
            <p className="tracked mb-2 text-[10.5px] text-muted">
              {t("hangingTips")}
            </p>
            <ul className="flex flex-col gap-1.5 text-[12.5px] text-paper/85">
              <li>• {t("tipEyeLevel")}</li>
              <li>• {t("tipLamination")}</li>
              <li>• {t("tipFlatSurface")}</li>
              <li>• {t("tipNoReprint")}</li>
            </ul>
          </div>
        </div>
      </div>

      {/* ============ PRINT-ONLY CARD ============
          Hidden in normal flow (display:none on screen, visible in
          print). When the partner clicks "Open print view" we
          window.print() the current document and only this block
          renders. Sized for an A4 portrait sheet centred. */}
      <div className="qr-print-card" aria-hidden>
        <div className="qr-print-frame">
          {previewSvg ? (
            <div
              className="qr-print-svg"
              dangerouslySetInnerHTML={{
                __html: previewSvg
                  // Re-tint to black-on-white for print; the on-screen
                  // SVG embeds brand-amber colours which won't read on
                  // most printers.
                  .replaceAll(BRAND_DARK, PRINT_DARK)
                  .replaceAll(BRAND_LIGHT, PRINT_LIGHT),
              }}
            />
          ) : null}
        </div>
        <h1 className="qr-print-gym">{gym.nameEn}</h1>
        <p className="qr-print-tag">{t("printTagline")}</p>
        <div className="qr-print-foot">
          <Wordmark size={20} />
          <span className="qr-print-host">gym-pass.net</span>
        </div>
      </div>

      <style dangerouslySetInnerHTML={{ __html: PRINT_CSS }} />
    </>
  );
}

/// Print stylesheet, kept out of the JSX tree so the TypeScript
/// JSX parser doesn't try to read CSS braces as expression
/// containers. Loaded into a global `<style>` via
/// `dangerouslySetInnerHTML` — the rules are scoped behind
/// `@media print` so they only fire when the OS print dialog is
/// open; outside of print, the `.qr-print-card` itself stays
/// `display: none` so nothing leaks to the on-screen layout.
const PRINT_CSS = `
.qr-print-card { display: none; }

@media print {
  @page {
    size: A4 portrait;
    margin: 16mm;
  }
  /* Hide every other top-level body child while keeping the
     print card visible. \`visibility: hidden\` on siblings (vs
     \`display: none\`) preserves their layout heights so Next.js's
     hydration tree doesn't shift during the print render. */
  body > * { visibility: hidden; }
  .qr-print-card,
  .qr-print-card * { visibility: visible; }
  .qr-print-card {
    display: flex !important;
    position: fixed;
    inset: 0;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 0;
    background: #fff;
    color: #000;
    font-family: var(--font-sans), system-ui, sans-serif;
  }
  .qr-print-frame {
    width: 60vw;
    max-width: 16cm;
    aspect-ratio: 1;
    padding: 0;
  }
  .qr-print-svg svg {
    width: 100%;
    height: 100%;
    display: block;
  }
  .qr-print-gym {
    font-family: var(--font-sans), system-ui, sans-serif;
    font-weight: 600;
    font-size: 28px;
    margin: 18mm 0 6mm;
    letter-spacing: -0.01em;
  }
  .qr-print-tag {
    font-size: 14px;
    color: #444;
    margin: 0 0 12mm;
    letter-spacing: 0.04em;
  }
  .qr-print-foot {
    display: flex;
    align-items: center;
    gap: 14px;
    color: #000;
  }
  /* Force the wordmark's amber half to black on print — coloured
     inks aren't a guarantee on shared printers and the brand split
     loses meaning on a hung-on-the-door artefact anyway. */
  .qr-print-foot .text-accent { color: #000 !important; }
  .qr-print-host {
    font-family: var(--font-mono), monospace;
    font-size: 11px;
    color: #666;
    letter-spacing: 0.12em;
  }
}
`;

function fileBase(gym: GymHeader, ext: string): string {
  const safeSlug = (gym.slug || "gympass-qr").replace(/[^a-z0-9-]/gi, "");
  return `${safeSlug}-qr.${ext}`;
}

function triggerDownload(url: string, filename: string): void {
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
}
