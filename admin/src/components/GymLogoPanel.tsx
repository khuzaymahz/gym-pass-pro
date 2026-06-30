"use client";

import Image from "next/image";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useRef, useState, useTransition } from "react";

type Result<T> = { ok: true; value: T } | { ok: false; error: string };

type Props = {
  logoUrl: string | null;
  uploadAction: (formData: FormData) => Promise<Result<{ logoUrl: string | null }>>;
  deleteAction: () => Promise<Result<{ logoUrl: string | null }>>;
};

export default function GymLogoPanel({ logoUrl, uploadAction, deleteAction }: Props) {
  const router = useRouter();
  const t = useTranslations("gyms.logo");
  const [pending, startTransition] = useTransition();
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  function refresh() {
    startTransition(() => router.refresh());
  }

  async function onUpload(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    if (!file) {
      setError(t("pickImage"));
      return;
    }
    const formData = new FormData();
    formData.set("file", file);
    setBusy(true);
    const result = await uploadAction(formData);
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setFile(null);
    if (fileInputRef.current) fileInputRef.current.value = "";
    refresh();
  }

  async function onDelete() {
    setError(null);
    setBusy(true);
    const result = await deleteAction();
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    refresh();
  }

  const blocking = busy || pending;

  return (
    <div className="flex flex-col gap-3">
      <p className="text-[11px] text-muted">{t("description")}</p>

      <div className="flex items-center gap-4">
        <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-lg border border-line bg-surface-2">
          {logoUrl ? (
            <Image
              src={logoUrl}
              alt={t("alt")}
              fill
              sizes="80px"
              className="object-cover"
              unoptimized
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-[10px] uppercase tracking-widest text-muted">
              {t("noLogo")}
            </div>
          )}
        </div>

        <form onSubmit={onUpload} className="flex flex-1 flex-col gap-2">
          <input
            ref={fileInputRef}
            className="input input-sm"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            required
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
          <div className="flex items-center justify-between">
            <span className="text-[11px] text-muted">
              {file
                ? t("fileSummary", {
                    name: file.name,
                    kb: Math.round(file.size / 1024),
                  })
                : t("hint")}
            </span>
            <div className="flex gap-2">
              {logoUrl ? (
                <button
                  type="button"
                  className="btn-danger btn-sm"
                  disabled={blocking}
                  onClick={onDelete}
                >
                  {t("remove")}
                </button>
              ) : null}
              <button className="btn-primary btn-sm" disabled={blocking || !file}>
                {busy
                  ? t("uploading")
                  : logoUrl
                    ? t("replace")
                    : t("upload")}
              </button>
            </div>
          </div>
        </form>
      </div>

      {error ? <p className="text-[12px] text-red-300">{error}</p> : null}
    </div>
  );
}
