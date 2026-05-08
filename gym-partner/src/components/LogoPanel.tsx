"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useRef, useState, useTransition } from "react";

import {
  deleteLogoAction,
  uploadLogoAction,
} from "@/app/(dashboard)/profile/actions";
import { resolveMediaUrl } from "@/lib/media";

const MAX_UPLOAD_MB = 10;
const ACCEPT_TYPES = ["image/jpeg", "image/png", "image/webp"];

/**
 * Single-asset uploader for the gym's brand logo. Mirrors PhotosPanel
 * one-for-one (same upload guards, same disabled-while-pending UX,
 * same toast/error shape) so the operator's mental model is "upload
 * = upload, regardless of which page".
 *
 * Visually the panel reads as "swap this circle": the current logo
 * (or a tier-coloured initial fallback) sits to the start; the
 * upload control + remove affordance sits to the end. The big
 * round preview makes a 200×200 logo file legible at a glance and
 * matches how the same image renders in the mobile gym-detail page.
 */
export function LogoPanel({
  initialLogoUrl,
  gymName,
}: {
  initialLogoUrl: string | null;
  gymName: string;
}) {
  const t = useTranslations("profile");
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  // Local override of the resolved URL while the partner's request
  // is still on the wire — avoids a brief flash of the old logo
  // between server-action success and `router.refresh()` painting
  // the new one. Cleared on failure so the original stays visible.
  const [optimisticUrl, setOptimisticUrl] = useState<string | null>(null);

  const liveUrl =
    optimisticUrl !== null ? optimisticUrl : resolveMediaUrl(initialLogoUrl);
  const initials = makeInitials(gymName);

  function onUpload(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError(null);

    if (!ACCEPT_TYPES.includes(file.type)) {
      setError(t("logoErrorUnsupportedType"));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    if (file.size > MAX_UPLOAD_MB * 1024 * 1024) {
      setError(t("logoErrorTooLarge", { limit: MAX_UPLOAD_MB }));
      if (fileRef.current) fileRef.current.value = "";
      return;
    }

    // Optimistic preview: stamp a local object URL so the partner
    // sees the new logo *before* the round-trip completes. Revoked
    // after `router.refresh()` so the canonical URL takes over.
    const localUrl = URL.createObjectURL(file);
    setOptimisticUrl(localUrl);

    const data = new FormData();
    data.append("file", file);
    startTransition(async () => {
      const res = await uploadLogoAction(data);
      if (!res.ok) {
        setError(res.error ?? t("logoErrorUploadGeneric"));
        URL.revokeObjectURL(localUrl);
        setOptimisticUrl(null);
      } else {
        // Success — refresh the server tree so the layout's
        // sidebar logo, the page's stored URL, and the mobile
        // app (next time it fetches `/gyms/by-slug/...`) all
        // reflect the new asset. The optimistic blob URL is
        // released after a short delay so the browser doesn't
        // flash empty between unmount of the blob <img> and
        // mount of the resolved one.
        setTimeout(() => {
          URL.revokeObjectURL(localUrl);
          setOptimisticUrl(null);
        }, 600);
      }
      router.refresh();
      if (fileRef.current) fileRef.current.value = "";
    });
  }

  function onDelete() {
    setError(null);
    startTransition(async () => {
      const res = await deleteLogoAction();
      if (!res.ok) {
        setError(res.error ?? t("logoErrorDeleteGeneric"));
      } else {
        setOptimisticUrl(null);
      }
      router.refresh();
    });
  }

  return (
    <section className="panel p-5">
      <header className="mb-4 flex items-baseline justify-between gap-2">
        <div>
          <h2 className="h2">{t("logoTitle")}</h2>
          <p className="mt-0.5 text-[11.5px] text-muted">{t("logoSubtitle")}</p>
        </div>
      </header>

      <div className="flex flex-wrap items-center gap-5">
        {/* Logo preview disc — 96 px round, tier-neutral border so
            the brand mark on the inside carries the colour. */}
        <div className="relative h-24 w-24 shrink-0 overflow-hidden rounded-full border border-line bg-surface">
          {liveUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={liveUrl}
              alt={gymName}
              className="h-full w-full object-cover"
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
              accept={ACCEPT_TYPES.join(",")}
              onChange={onUpload}
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
              <span>
                {pending
                  ? t("logoUploading")
                  : initialLogoUrl
                    ? t("logoReplace")
                    : t("logoUpload")}
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
          <p className="text-[11.5px] text-muted">
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
  );
}

function makeInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
