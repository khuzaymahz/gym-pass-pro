"use client";

import * as React from "react";

import GymLoader, { type GymLoaderSize } from "@/components/GymLoader";

/**
 * `<button>` wrapper that swaps in a `GymLoader` and a pending label
 * while a server action is in flight. Single Responsibility — this is
 * the only place admin form buttons should know about loader sizing,
 * busy-state ARIA, and the inline-flex layout that hosts the loader
 * next to the label.
 *
 * Layout vs. chrome are deliberately separated:
 *   - **Layout** owned here: `inline-flex items-center gap-2` so the
 *     loader sits inline with the label without per-call boilerplate.
 *   - **Chrome** owned by the caller via `className`: `btn-primary
 *     btn-sm` for the standard submit, `btn-danger btn-sm` for the
 *     destructive cancel, `btn-ghost` for low-pressure actions.
 *
 * `aria-busy` mirrors `pending` so screen readers announce the
 * transition. The pending and idle labels are passed in by the
 * caller (typically via `next-intl`) — this component never
 * localises itself.
 */
export interface PendingButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  pending: boolean;
  pendingLabel: React.ReactNode;
  idleLabel: React.ReactNode;
  /** Loader size — defaults to `sm` for inline button use. */
  loaderSize?: GymLoaderSize;
}

const LAYOUT_CLASSES = "inline-flex items-center gap-2";
const DEFAULT_CHROME = "btn-primary btn-sm";

export default function PendingButton({
  pending,
  pendingLabel,
  idleLabel,
  loaderSize = "sm",
  className,
  disabled,
  type = "submit",
  ...rest
}: PendingButtonProps) {
  // When the caller passes `className`, treat it as the full chrome
  // override (so a danger button doesn't carry a stale btn-primary).
  // When omitted, fall through to the default `btn-primary btn-sm`
  // so a vanilla submit doesn't need to repeat the canonical chrome.
  const chrome = className ?? DEFAULT_CHROME;
  return (
    <button
      type={type}
      disabled={disabled || pending}
      aria-busy={pending}
      className={`${chrome} ${LAYOUT_CLASSES}`}
      {...rest}
    >
      {pending ? <GymLoader size={loaderSize} /> : null}
      {pending ? pendingLabel : idleLabel}
    </button>
  );
}
