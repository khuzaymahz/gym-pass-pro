"use client";

import { useEffect, useRef, type ReactNode } from "react";

import { CloseIcon } from "./icons";

/// Modal shell shared by every cropper dialog. Owns the
/// boring-but-load-bearing concerns:
///
///  - Esc to close (suppressed when `busy`)
///  - Backdrop click to close (suppressed when `busy`)
///  - Body scroll lock while open
///  - Focus moves into the dialog on open so screen readers
///    announce the heading and Tab cycles inside
///  - aria-modal + role="dialog" + aria-labelledby wiring
///
/// Children render the actual cropper content. Footer is a
/// separate slot so callers can keep their primary action ("Apply")
/// styled consistently — `<footer>` is a common shape but children
/// might want to omit it for non-action dialogs.
export function CropperDialog({
  open,
  titleId,
  title,
  busy,
  closeLabel,
  onClose,
  maxWidthClass = "max-w-md",
  children,
  footer,
}: {
  open: boolean;
  titleId: string;
  title: string;
  busy?: boolean;
  closeLabel: string;
  onClose: () => void;
  /** Tailwind max-w-* class so different croppers can size the
   *  dialog differently (logo wants slightly wider for the
   *  multi-size preview row). */
  maxWidthClass?: string;
  children: ReactNode;
  footer: ReactNode;
}) {
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent): void => {
      if (e.key === "Escape" && !busy) onClose();
    };
    document.addEventListener("keydown", onKey);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = previousOverflow;
    };
  }, [open, busy, onClose]);

  useEffect(() => {
    if (open) dialogRef.current?.focus();
  }, [open]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/75 p-4 backdrop-blur-sm"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget && !busy) onClose();
      }}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        onMouseDown={(e) => e.stopPropagation()}
        className={`steel relative w-full ${maxWidthClass} overflow-hidden rounded-xl shadow-2xl focus:outline-none`}
      >
        <header className="flex items-center justify-between gap-2 border-b border-line px-5 py-3">
          <h3 id={titleId} className="h2">
            {title}
          </h3>
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            aria-label={closeLabel}
            className="btn-icon"
          >
            <CloseIcon />
          </button>
        </header>
        <div className="flex flex-col gap-5 px-5 py-5">{children}</div>
        <footer className="flex items-center justify-end gap-2 border-t border-line bg-surface/40 px-5 py-3">
          {footer}
        </footer>
      </div>
    </div>
  );
}
