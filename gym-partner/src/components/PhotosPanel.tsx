"use client";

import { useTranslations } from "next-intl";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useRef, useState, useTransition } from "react";

import { deletePhotoAction, uploadPhotoAction } from "@/app/(dashboard)/photos/actions";
import type { GymPhoto } from "@/lib/sdk";

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
    const data = new FormData();
    data.append("file", file);
    startTransition(async () => {
      const res = await uploadPhotoAction(data);
      if (!res.ok) setError(res.error ?? "Upload failed.");
      router.refresh();
      if (fileRef.current) fileRef.current.value = "";
    });
  }

  function onDelete(id: string) {
    startTransition(async () => {
      const res = await deletePhotoAction(id);
      if (!res.ok) setError(res.error ?? "Delete failed.");
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <input
          ref={fileRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          onChange={onUpload}
          className="hidden"
          id="photo-upload"
        />
        <label
          htmlFor="photo-upload"
          className="btn-primary btn-sm cursor-pointer"
        >
          {pending ? "…" : t("upload")}
        </label>
        {error ? (
          <span className="text-[12px] text-red-400">{error}</span>
        ) : null}
      </div>

      {initial.length === 0 ? (
        <div className="panel p-8 text-center">
          <p className="text-[12.5px] text-muted">{t("noPhotos")}</p>
        </div>
      ) : (
        <ul className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
          {initial.map((p) => (
            <li
              key={p.id}
              className="panel relative aspect-[4/3] overflow-hidden"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={p.url}
                alt={p.altTextEn ?? ""}
                className="h-full w-full object-cover"
              />
              <button
                type="button"
                onClick={() => onDelete(p.id)}
                className="absolute top-2 end-2 btn-danger btn-sm"
                disabled={pending}
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
