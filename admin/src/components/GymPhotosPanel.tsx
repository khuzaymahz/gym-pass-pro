"use client";

import Image from "next/image";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useRef, useState, useTransition } from "react";

import type { GymPhotoRead, GymPhotoUpdate } from "@/lib/gyms";

type Result<T> =
  | { ok: true; value: T }
  | { ok: false; error: string };

type Props = {
  photos: GymPhotoRead[];
  uploadAction: (formData: FormData) => Promise<Result<GymPhotoRead>>;
  updateAction: (
    photoId: string,
    data: GymPhotoUpdate,
  ) => Promise<Result<GymPhotoRead>>;
  deleteAction: (photoId: string) => Promise<Result<null>>;
};

export default function GymPhotosPanel({
  photos,
  uploadAction,
  updateAction,
  deleteAction,
}: Props) {
  const router = useRouter();
  const t = useTranslations("gyms.photos");
  const [pending, startTransition] = useTransition();
  const [file, setFile] = useState<File | null>(null);
  const [altEn, setAltEn] = useState("");
  const [altAr, setAltAr] = useState("");
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const sorted = [...photos].sort((a, b) => a.sortOrder - b.sortOrder);

  function refresh() {
    startTransition(() => router.refresh());
  }

  async function onUpload(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    if (!file) {
      setError(t("errorPickFirst"));
      return;
    }
    const formData = new FormData();
    formData.set("file", file);
    if (altEn.trim()) formData.set("altTextEn", altEn.trim());
    if (altAr.trim()) formData.set("altTextAr", altAr.trim());
    setUploading(true);
    const result = await uploadAction(formData);
    setUploading(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setFile(null);
    setAltEn("");
    setAltAr("");
    if (fileInputRef.current) fileInputRef.current.value = "";
    refresh();
  }

  async function onDelete(photoId: string) {
    setError(null);
    const result = await deleteAction(photoId);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    refresh();
  }

  async function onMove(idx: number, dir: -1 | 1) {
    const target = sorted[idx];
    const neighbour = sorted[idx + dir];
    if (!target || !neighbour) return;
    setError(null);
    const r1 = await updateAction(target.id, { sortOrder: neighbour.sortOrder });
    if (!r1.ok) {
      setError(r1.error);
      return;
    }
    const r2 = await updateAction(neighbour.id, { sortOrder: target.sortOrder });
    if (!r2.ok) {
      setError(r2.error);
      return;
    }
    refresh();
  }

  async function onAltSave(photo: GymPhotoRead, en: string, ar: string) {
    setError(null);
    const result = await updateAction(photo.id, {
      altTextEn: en.trim() || null,
      altTextAr: ar.trim() || null,
    });
    if (!result.ok) {
      setError(result.error);
      return;
    }
    refresh();
  }

  const busy = pending || uploading;

  return (
    <section className="panel flex flex-col gap-3 p-4">
      <header className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold">{t("title")}</h2>
          <p className="text-[11px] text-muted">{t("description")}</p>
        </div>
        <span className="text-[11px] text-muted">
          {t("uploaded", { count: sorted.length })}
        </span>
      </header>

      <form
        onSubmit={onUpload}
        className="grid grid-cols-1 gap-2 md:grid-cols-4"
      >
        <label className="field md:col-span-2">
          <span className="field-label">{t("imageFile")}</span>
          <input
            ref={fileInputRef}
            className="input input-sm"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("altEn")}</span>
          <input
            className="input input-sm"
            value={altEn}
            onChange={(e) => setAltEn(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("altAr")}</span>
          <input
            className="input input-sm"
            dir="rtl"
            value={altAr}
            onChange={(e) => setAltAr(e.target.value)}
          />
        </label>
        <div className="md:col-span-4 flex items-center justify-between">
          <span className="text-[11px] text-muted">
            {file
              ? t("fileSummary", {
                  name: file.name,
                  kb: Math.round(file.size / 1024),
                })
              : t("noFile")}
          </span>
          <button className="btn-primary btn-sm" disabled={busy || !file}>
            {uploading ? t("uploading") : t("uploadPhoto")}
          </button>
        </div>
      </form>

      {error ? (
        <p className="text-[12px] text-red-300">{error}</p>
      ) : null}

      {sorted.length === 0 ? (
        <p className="rounded border border-dashed border-line px-3 py-6 text-center text-[12px] text-muted">
          {t("noPhotosYet")}
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {sorted.map((photo, idx) => (
            <PhotoRow
              key={photo.id}
              photo={photo}
              canMoveUp={idx > 0}
              canMoveDown={idx < sorted.length - 1}
              onMoveUp={() => onMove(idx, -1)}
              onMoveDown={() => onMove(idx, 1)}
              onDelete={() => onDelete(photo.id)}
              onAltSave={(en, ar) => onAltSave(photo, en, ar)}
              pending={busy}
            />
          ))}
        </ul>
      )}
    </section>
  );
}

function PhotoRow({
  photo,
  canMoveUp,
  canMoveDown,
  onMoveUp,
  onMoveDown,
  onDelete,
  onAltSave,
  pending,
}: {
  photo: GymPhotoRead;
  canMoveUp: boolean;
  canMoveDown: boolean;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onDelete: () => void;
  onAltSave: (en: string, ar: string) => void;
  pending: boolean;
}) {
  const t = useTranslations("gyms.photos");
  const [editing, setEditing] = useState(false);
  const [altEn, setAltEn] = useState(photo.altTextEn ?? "");
  const [altAr, setAltAr] = useState(photo.altTextAr ?? "");

  return (
    <li className="flex items-start gap-3 rounded border border-line bg-surface-1 p-2">
      <div className="relative h-16 w-24 shrink-0 overflow-hidden rounded bg-surface-2">
        <Image
          src={photo.url}
          alt={photo.altTextEn ?? ""}
          fill
          sizes="96px"
          className="object-cover"
          unoptimized
        />
      </div>

      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <div className="flex items-center gap-2">
          <span className="text-[11px] text-muted">#{photo.sortOrder}</span>
          <a
            href={photo.url}
            target="_blank"
            rel="noreferrer"
            className="truncate text-[12px] underline decoration-dotted"
          >
            {photo.url}
          </a>
        </div>
        {editing ? (
          <div className="grid grid-cols-1 gap-1 md:grid-cols-2">
            <input
              className="input input-sm"
              placeholder={t("altPlaceholderEn")}
              value={altEn}
              onChange={(e) => setAltEn(e.target.value)}
            />
            <input
              className="input input-sm"
              placeholder={t("altPlaceholderAr")}
              dir="rtl"
              value={altAr}
              onChange={(e) => setAltAr(e.target.value)}
            />
            <div className="md:col-span-2 flex gap-2">
              <button
                type="button"
                className="btn-primary btn-sm"
                disabled={pending}
                onClick={() => {
                  onAltSave(altEn, altAr);
                  setEditing(false);
                }}
              >
                {t("altSave")}
              </button>
              <button
                type="button"
                className="btn-ghost btn-sm"
                onClick={() => {
                  setAltEn(photo.altTextEn ?? "");
                  setAltAr(photo.altTextAr ?? "");
                  setEditing(false);
                }}
              >
                {t("cancel")}
              </button>
            </div>
          </div>
        ) : (
          <div className="flex flex-wrap gap-x-3 gap-y-1 text-[11px] text-muted">
            <span>EN: {photo.altTextEn ?? "—"}</span>
            <span dir="rtl">AR: {photo.altTextAr ?? "—"}</span>
          </div>
        )}
      </div>

      <div className="flex shrink-0 flex-col gap-1">
        <div className="flex gap-1">
          <button
            type="button"
            className="btn-ghost btn-sm"
            disabled={!canMoveUp || pending}
            onClick={onMoveUp}
            title={t("moveUp")}
          >
            ↑
          </button>
          <button
            type="button"
            className="btn-ghost btn-sm"
            disabled={!canMoveDown || pending}
            onClick={onMoveDown}
            title={t("moveDown")}
          >
            ↓
          </button>
        </div>
        <div className="flex gap-1">
          <button
            type="button"
            className="btn-ghost btn-sm"
            onClick={() => setEditing((v) => !v)}
          >
            {editing ? t("altPending") : t("editAlt")}
          </button>
          <button
            type="button"
            className="btn-danger btn-sm"
            disabled={pending}
            onClick={onDelete}
          >
            {t("delete")}
          </button>
        </div>
      </div>
    </li>
  );
}
