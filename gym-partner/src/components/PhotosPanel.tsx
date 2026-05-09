"use client";

import Image from "next/image";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, useTransition } from "react";

import {
  deletePhotoAction,
  uploadPhotoAction,
} from "@/app/(dashboard)/photos/actions";
import { resolveMediaUrl } from "@/lib/media";
import type { GymPhoto } from "@/lib/sdk";
import {
  ACCEPTED_IMAGE_TYPES_ATTR,
  MAX_UPLOAD_MB,
  validateImageFile,
} from "@/lib/upload";

import { PhotoCropper } from "./PhotoCropper";

export function PhotosPanel({ initial }: { initial: GymPhoto[] }) {
  const t = useTranslations("photos");
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  // Picked file held while the cropper modal is open. Mirrors the
  // logo-upload flow: the partner stages a file, fine-tunes the
  // crop, then commits — no auto-upload on file pick.
  const [staged, setStaged] = useState<{ url: string; file: File } | null>(
    null,
  );

  useEffect(() => {
    return () => {
      if (staged) URL.revokeObjectURL(staged.url);
    };
  }, [staged]);

  function onPickFile(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError(null);

    const validation = validateImageFile(file);
    if (validation === "unsupported_type") {
      setError(t("errorUnsupportedType"));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    if (validation === "too_large") {
      setError(t("errorTooLarge", { limit: MAX_UPLOAD_MB }));
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

  function applyStaged(croppedFile: File) {
    if (!staged) return;
    setError(null);
    const data = new FormData();
    // The cropper hands back a 4:5 JPEG already cropped to the
    // partner's chosen region; backend's `sniff_image` validates
    // the magic bytes and stores it as-is.
    data.append("file", croppedFile);
    startTransition(async () => {
      const res = await uploadPhotoAction(data);
      if (!res.ok) {
        setError(res.error ?? t("errorUploadGeneric"));
        return;
      }
      URL.revokeObjectURL(staged.url);
      setStaged(null);
      router.refresh();
    });
  }

  function onDelete(id: string) {
    startTransition(async () => {
      const res = await deletePhotoAction(id);
      if (!res.ok) setError(res.error ?? t("errorDeleteGeneric"));
      router.refresh();
    });
  }

  return (
    <>
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <input
              ref={fileRef}
              type="file"
              accept={ACCEPTED_IMAGE_TYPES_ATTR}
              onChange={onPickFile}
              className="hidden"
              id="photo-upload"
              disabled={pending}
            />
            <label
              htmlFor="photo-upload"
              className={`btn-primary btn-sm inline-flex items-center gap-2 ${
                pending ? "pointer-events-none opacity-60" : "cursor-pointer"
              }`}
              aria-busy={pending}
            >
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
                <path d="M12 5v14M5 12h14" />
              </svg>
              <span>{pending ? t("uploading") : t("upload")}</span>
            </label>
            <span className="text-[11.5px] text-muted">
              {t("uploadHint", { limit: MAX_UPLOAD_MB })}
            </span>
          </div>
          {error ? (
            <span
              role="alert"
              className="rounded-md border border-red-500/40 bg-red-500/10 px-3 py-1.5 text-[12px] text-red-300"
            >
              {error}
            </span>
          ) : null}
        </div>

        {initial.length === 0 ? (
          <div className="panel flex flex-col items-center gap-2 p-10 text-center">
            <svg
              width="28"
              height="28"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="text-muted"
              aria-hidden
            >
              <rect x="3" y="3" width="18" height="18" rx="2" />
              <circle cx="8.5" cy="8.5" r="1.5" />
              <path d="M21 15l-5-5L5 21" />
            </svg>
            <p className="text-[13px] text-paper">{t("noPhotos")}</p>
            <p className="text-[11.5px] text-muted">
              {t("noPhotosHint", { limit: MAX_UPLOAD_MB })}
            </p>
          </div>
        ) : (
          // Tile grid uses `aspect-[4/5]` to match the mobile hero —
          // partners now see exactly what members see, instead of a
          // landscape preview that misrepresents the rendering.
          <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {initial.map((p) => (
              <li
                key={p.id}
                className="panel group relative aspect-[4/5] overflow-hidden"
              >
                <Image
                  src={resolveMediaUrl(p.url)}
                  alt={p.altTextEn ?? ""}
                  fill
                  sizes="(min-width: 1024px) 25vw, (min-width: 640px) 33vw, 50vw"
                  className="object-cover transition-transform duration-200 group-hover:scale-[1.02]"
                />
                <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/60 via-black/0 to-transparent opacity-0 transition-opacity duration-200 group-hover:opacity-100" />
                <button
                  type="button"
                  onClick={() => onDelete(p.id)}
                  className="absolute end-2 top-2 rounded-md border border-red-500/60 bg-black/65 px-2.5 py-1 text-[11px] font-medium text-red-200 opacity-0 transition-opacity duration-200 hover:bg-red-500/30 group-hover:opacity-100 focus-visible:opacity-100"
                  disabled={pending}
                  aria-label={t("delete")}
                >
                  {t("delete")}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Cropper modal — opens when a file is staged. Hands back a
       *  cropped 4:5 JPEG which we forward to the upload action. */}
      <PhotoCropper
        open={staged !== null}
        imageFile={staged?.file ?? null}
        imageUrl={staged?.url ?? null}
        pending={pending}
        onApply={applyStaged}
        onCancel={cancelStaging}
      />
    </>
  );
}
