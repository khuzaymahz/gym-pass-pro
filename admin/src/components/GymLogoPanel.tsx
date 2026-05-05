"use client";

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
      setError("Pick an image first.");
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
    <section className="panel flex flex-col gap-3 p-4">
      <header className="flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold">Logo</h2>
          <p className="text-[11px] text-muted">
            Square mark used wherever this gym is referenced — gym list, detail,
            and plan network sheets. Stored on the backend.
          </p>
        </div>
      </header>

      <div className="flex items-center gap-4">
        <div className="h-20 w-20 shrink-0 overflow-hidden rounded-lg border border-line bg-surface-2">
          {logoUrl ? (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img
              src={logoUrl}
              alt="Gym logo"
              className="h-full w-full object-cover"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-[10px] uppercase tracking-widest text-muted">
              No logo
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
                ? `${file.name} · ${Math.round(file.size / 1024)} KB`
                : "JPEG / PNG / WebP — square images work best."}
            </span>
            <div className="flex gap-2">
              {logoUrl ? (
                <button
                  type="button"
                  className="btn-danger btn-sm"
                  disabled={blocking}
                  onClick={onDelete}
                >
                  Remove
                </button>
              ) : null}
              <button className="btn-primary btn-sm" disabled={blocking || !file}>
                {busy ? "Uploading…" : logoUrl ? "Replace logo" : "Upload logo"}
              </button>
            </div>
          </div>
        </form>
      </div>

      {error ? <p className="text-[12px] text-red-300">{error}</p> : null}
    </section>
  );
}
