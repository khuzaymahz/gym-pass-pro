"use client";

import {
  createContext,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from "react";

type Tone = "success" | "error" | "info";
type Toast = { id: number; tone: Tone; message: string; leaving?: boolean };
type ToastCtx = { toast: (message: string, tone?: Tone) => void };

const ToastContext = createContext<ToastCtx | null>(null);

// Module-scoped counter avoids Date.now()/Math.random() for ids.
let seq = 0;

// Exit-animation duration: a dismissed toast lingers this long so the
// `toast-out` fade can play before the node unmounts. Keep in sync with
// the animation in ToastCard.
const TOAST_EXIT_MS = 280;

/**
 * App-wide notification surface. Every modification (edit, create,
 * delete, refund, …) fires a toast so the operator gets unmistakable
 * confirmation or a clear failure — no more silent saves. Mounted once
 * around the dashboard; consumed via `useToast()`.
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const remove = useCallback((id: number) => {
    setToasts((list) => list.filter((t) => t.id !== id));
  }, []);

  const dismiss = useCallback(
    (id: number) => {
      // Two-phase: flag the toast as leaving so it plays `toast-out`,
      // then unmount once the fade finishes. Without this the node is
      // pulled from the DOM instantly and just blinks out.
      setToasts((list) =>
        list.map((t) => (t.id === id ? { ...t, leaving: true } : t)),
      );
      window.setTimeout(() => remove(id), TOAST_EXIT_MS);
    },
    [remove],
  );

  const toast = useCallback(
    (message: string, tone: Tone = "success") => {
      const id = ++seq;
      setToasts((list) => [...list, { id, tone, message }]);
      // Auto-dismiss; errors linger a touch longer so they're read.
      window.setTimeout(() => dismiss(id), tone === "error" ? 5200 : 3600);
    },
    [dismiss],
  );

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div
        className="pointer-events-none fixed bottom-4 right-4 z-[100] flex w-[min(360px,calc(100vw-2rem))] flex-col gap-2"
        aria-live="polite"
        aria-atomic="false"
      >
        {toasts.map((t) => (
          <ToastCard key={t.id} toast={t} onDismiss={() => dismiss(t.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

const TONE_ACCENT: Record<Tone, string> = {
  success: "text-lime",
  error: "text-red-400",
  info: "text-sky-400",
};

function ToastCard({
  toast,
  onDismiss,
}: {
  toast: Toast;
  onDismiss: () => void;
}) {
  return (
    <div
      role="status"
      className="pop pointer-events-auto flex items-start gap-2.5 p-3"
      style={{
        animation: toast.leaving
          ? `toast-out ${TOAST_EXIT_MS}ms cubic-bezier(0.4,0,1,1) forwards`
          : "toast-in 220ms cubic-bezier(0.2,0.7,0.2,1) both",
      }}
    >
      <span className={`mt-px shrink-0 ${TONE_ACCENT[toast.tone]}`}>
        {toast.tone === "error" ? (
          <svg
            viewBox="0 0 24 24"
            className="h-4 w-4"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            aria-hidden
          >
            <circle cx="12" cy="12" r="9" />
            <path d="M12 8v5M12 16h.01" />
          </svg>
        ) : (
          <svg
            viewBox="0 0 24 24"
            className="h-4 w-4"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden
          >
            <circle cx="12" cy="12" r="9" />
            <path d="m8.5 12.5 2.5 2.5 4.5-5" />
          </svg>
        )}
      </span>
      <p className="min-w-0 flex-1 text-[12.5px] leading-snug text-paper">
        {toast.message}
      </p>
      <button
        type="button"
        onClick={onDismiss}
        aria-label="Dismiss"
        className="-mr-1 -mt-1 shrink-0 rounded p-1 text-muted transition-colors hover:text-paper"
      >
        <svg
          viewBox="0 0 24 24"
          className="h-3.5 w-3.5"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          aria-hidden
        >
          <path d="M18 6 6 18M6 6l12 12" />
        </svg>
      </button>
    </div>
  );
}

/** Returns `{ toast }`. No-ops safely if used outside the provider. */
export function useToast(): ToastCtx {
  return useContext(ToastContext) ?? { toast: () => {} };
}
