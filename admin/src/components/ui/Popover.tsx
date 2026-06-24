"use client";

import { useTranslations } from "next-intl";
import { useState, type ReactNode } from "react";

/**
 * Anchored popover shell — trigger button, click-away backdrop, and an
 * elevated `.pop` panel with a titled header. Extracted from the
 * Manage-subscription and Configure-offering menus, which had
 * identical open/close + backdrop + panel scaffolding.
 *
 * `children` may be a render-prop receiving `close` so an action inside
 * can dismiss the panel after it completes.
 */
export default function Popover({
  trigger,
  title,
  children,
  width = "w-72",
  triggerClassName = "btn btn-sm",
}: {
  trigger: ReactNode;
  title: string;
  children: ReactNode | ((close: () => void) => ReactNode);
  width?: string;
  triggerClassName?: string;
}) {
  const tCommon = useTranslations("common");
  const [open, setOpen] = useState(false);
  const close = () => setOpen(false);

  if (!open) {
    return (
      <button
        type="button"
        className={triggerClassName}
        onClick={() => setOpen(true)}
      >
        {trigger}
      </button>
    );
  }

  return (
    <>
      <button
        type="button"
        aria-label={tCommon("close")}
        className="fixed inset-0 z-40 cursor-default"
        onClick={close}
      />
      <div className="relative z-50 inline-block text-left">
        <div
          className={`pop fade-in absolute right-0 top-0 z-50 flex ${width} flex-col gap-3 p-3`}
        >
          <div className="flex items-center justify-between">
            <span className="field-label">{title}</span>
            <button
              type="button"
              className="text-[11px] text-muted transition-colors hover:text-paper"
              onClick={close}
            >
              {tCommon("close")}
            </button>
          </div>
          {typeof children === "function" ? children(close) : children}
        </div>
      </div>
    </>
  );
}
