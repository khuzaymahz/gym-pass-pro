"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, useTransition } from "react";

import {
  deleteLogoAction,
  uploadLogoAction,
} from "@/app/(dashboard)/profile/actions";
import { resolveMediaUrl } from "@/lib/media";
import {
  DEFAULT_LOGO_ALIGNMENT,
  type LogoAlignment,
} from "@/lib/sdk";
import {
  ACCEPTED_IMAGE_TYPES_ATTR,
  MAX_UPLOAD_MB,
  validateImageFile,
} from "@/lib/upload";

import { LogoCropper } from "./LogoCropper";

/**
 * Logo manager. Resting view shows the current logo at its real
 * sidebar + card sizes; picking a file opens the LogoCropper modal
 * where the partner aligns / crops the image before committing.
 *
 * The cropper handles the preview UI; this panel handles the file
 * lifecycle (object URL creation/revocation, server upload, error
 * surfacing) and stays as a simple summary card.
 */
export function LogoPanel({
  initialLogoUrl,
  initialAlignment,
  gymName,
}: {
  initialLogoUrl: string | null;
  initialAlignment: LogoAlignment | null;
  gymName: string;
}) {
  const t = useTranslations("profile");
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  // Staged file held while the cropper modal is open. The blob URL
  // is created on file pick and released on cancel / success.
  const [staged, setStaged] = useState<{ url: string; file: File } | null>(
    null,
  );

  useEffect(() => {
    return () => {
      if (staged) URL.revokeObjectURL(staged.url);
    };
  }, [staged]);

  const restingUrl = resolveMediaUrl(initialLogoUrl);
  const initials = makeInitials(gymName);
  const alignment = initialAlignment ?? DEFAULT_LOGO_ALIGNMENT;

  function onPickFile(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError(null);

    const validation = validateImageFile(file);
    if (validation === "unsupported_type") {
      setError(t("logoErrorUnsupportedType"));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    if (validation === "too_large") {
      setError(t("logoErrorTooLarge", { limit: MAX_UPLOAD_MB }));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }

    if (staged) URL.revokeObjectURL(staged.url);
    const url = URL.createObjectURL(file);
    setStaged({ url, file });
    if (fileRef.current) fileRef.current.value = "";
  }

  function cancelStaging() {
    if (!staged) return;
    URL.revokeObjectURL(staged.url);
    setStaged(null);
    setError(null);
  }

  function applyStaged(file: File, nextAlignment: LogoAlignment) {
    if (!staged) return;
    setError(null);
    const data = new FormData();
    // The cropper hands back either a freshly-cropped JPEG (Fill
    // mode) or the original file (Contain mode). Either way the
    // backend's `sniff_image` validates magic bytes, so we just
    // forward whatever the cropper produced.
    data.append("file", file);
    data.append("fit", nextAlignment.fit);
    data.append("position", nextAlignment.position);
    startTransition(async () => {
      const res = await uploadLogoAction(data);
      if (!res.ok) {
        setError(res.error ?? t("logoErrorUploadGeneric"));
        return;
      }
      URL.revokeObjectURL(staged.url);
      setStaged(null);
      router.refresh();
    });
  }

  function onDelete() {
    setError(null);
    startTransition(async () => {
      const res = await deleteLogoAction();
      if (!res.ok) {
        setError(res.error ?? t("logoErrorDeleteGeneric"));
        return;
      }
      router.refresh();
    });
  }

  return (
    <>
      <section className="panel p-5">
        <header className="mb-4 flex items-baseline justify-between gap-2">
          <div>
            <h2 className="h2">{t("logoTitle")}</h2>
            <p className="mt-0.5 text-[12px] text-muted">{t("logoSubtitle")}</p>
          </div>
        </header>

        <div className="flex flex-wrap items-center gap-5">
          <div
            className="relative h-24 w-24 shrink-0 overflow-hidden rounded-full border border-line bg-surface"
            aria-label={t("logoPreviewSidebar")}
          >
            {restingUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={restingUrl}
                alt=""
                className="h-full w-full"
                style={{
                  objectFit: alignment.fit,
                  objectPosition: `center ${alignment.position}`,
                }}
              />
            ) : (
              <span className="flex h-full w-full items-center justify-center text-[28px] font-semibold tracking-wide text-muted">
                {initials}
              </span>
            )}
            {pending ? (
              <span
                className="absolute inset-0 flex items-center justify-center bg-ink/55 text-[10px] font-medium uppercase tracking-wider text-paper"
                aria-busy
              >
                {t("logoUploading")}
              </span>
            ) : null}
          </div>

          <div className="flex min-w-0 flex-1 flex-col gap-2">
            <div className="flex flex-wrap gap-2">
              <input
                ref={fileRef}
                type="file"
                accept={ACCEPTED_IMAGE_TYPES_ATTR}
                onChange={onPickFile}
                className="hidden"
                id="logo-upload"
                disabled={pending}
              />
              <label
                htmlFor="logo-upload"
                className={`btn-primary btn-sm inline-flex items-center gap-2 ${
                  pending ? "pointer-events-none opacity-60" : "cursor-pointer"
                }`}
                aria-busy={pending}
              >
                <UploadIcon />
                <span>
                  {initialLogoUrl ? t("logoReplace") : t("logoUpload")}
                </span>
              </label>
              {initialLogoUrl ? (
                <button
                  type="button"
                  onClick={onDelete}
                  disabled={pending}
                  className="btn-ghost btn-sm"
                >
                  {t("logoRemove")}
                </button>
              ) : null}
            </div>
            <p className="text-[12px] text-muted">
              {t("logoHint", { limit: MAX_UPLOAD_MB })}
            </p>
            {error ? (
              <span
                role="alert"
                className="rounded-md border border-red-500/40 bg-red-500/10 px-3 py-1.5 text-[12px] text-red-300"
              >
                {error}
              </span>
            ) : null}
          </div>
        </div>
      </section>

      {/* Cropper modal — opens whenever a file is staged. The
       *  cropper owns its own alignment state; on Apply it hands
       *  back the chosen alignment and we commit the upload. */}
      <LogoCropper
        open={staged !== null}
        imageFile={staged?.file ?? null}
        imageUrl={staged?.url ?? null}
        initialAlignment={initialAlignment}
        pending={pending}
        onApply={applyStaged}
        onCancel={cancelStaging}
      />
    </>
  );
}

function UploadIcon() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="17 8 12 3 7 8" />
      <line x1="12" y1="3" x2="12" y2="15" />
    </svg>
  );
}

function makeInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
