"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useRef, useState, useTransition } from "react";

import {
  deletePhotoAction,
  uploadPhotoAction,
} from "@/app/(dashboard)/photos/actions";
import { resolveMediaUrl } from "@/lib/media";
import type { GymPhoto } from "@/lib/sdk";

/// Local mirror of the backend's image-validation rules so the panel
/// can fail early with a clear message before the file ever leaves
/// the browser. Keeps `gym-partner/next.config.js`'s server-action
/// `bodySizeLimit` and `backend.app.config.max_upload_mb` aligned.
const MAX_UPLOAD_MB = 10;
const ACCEPT_TYPES = ["image/jpeg", "image/png", "image/webp"];

export function PhotosPanel({ initial }: { initial: GymPhoto[] }) {
  const t = useTranslations("photos");
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function onUpload(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError(null);

    // Client-side guards for the two failure modes that don't need a
    // round-trip to the server: oversized file (server-action body
    // limit) and unsupported MIME (backend's image sniff). Any other
    // failure (auth, schema, transient) lands as a server-action
    // error and surfaces in the same `error` slot below.
    if (!ACCEPT_TYPES.includes(file.type)) {
      setError(t("errorUnsupportedType"));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    if (file.size > MAX_UPLOAD_MB * 1024 * 1024) {
      setError(t("errorTooLarge", { limit: MAX_UPLOAD_MB }));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }

    const data = new FormData();
    data.append("file", file);
    startTransition(async () => {
      const res = await uploadPhotoAction(data);
      if (!res.ok) {
        setError(res.error ?? t("errorUploadGeneric"));
      }
      router.refresh();
      if (fileRef.current) fileRef.current.value = "";
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
    <div className="flex flex-col gap-4">
      {/* Toolbar: upload button on one side, error slot on the
          other. Hidden file input is the actual control; the
          <label> is just a styled trigger. */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <input
            ref={fileRef}
            type="file"
            accept={ACCEPT_TYPES.join(",")}
            onChange={onUpload}
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
        <ul className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
          {initial.map((p) => (
            <li
              key={p.id}
              className="panel group relative aspect-[4/3] overflow-hidden"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={resolveMediaUrl(p.url)}
                alt={p.altTextEn ?? ""}
                loading="lazy"
                className="h-full w-full object-cover transition-transform duration-200 group-hover:scale-[1.02]"
              />
              {/* Hover overlay carrying the delete affordance —
                  reduces visual noise in the gallery and lets the
                  photos themselves carry the page. Stays
                  permanently visible on touch (no hover state). */}
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
  );
}
