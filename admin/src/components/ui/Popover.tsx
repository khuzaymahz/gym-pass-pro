"use client";

import { useTranslations } from "next-intl";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";

/**
 * Anchored popover shell — trigger button, click-away backdrop, and an
 * elevated `.pop` panel with a titled header. Extracted from the
 * Manage-subscription and Configure-offering menus, which had
 * identical open/close + backdrop + panel scaffolding.
 *
 * The panel is rendered in a portal on `document.body` and positioned
 * `fixed` from the trigger's rect. That's deliberate: the triggers live
 * inside `panel overflow-hidden` tables, which would otherwise clip an
 * in-tree `absolute` panel (the popover appeared cut off mid-table).
 * Position is recomputed on scroll/resize so it tracks the trigger.
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
  const [pos, setPos] = useState<{ top: number; right: number } | null>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const close = useCallback(() => setOpen(false), []);

  // Anchor the panel's top-right just under the trigger's right edge, so
  // it opens downward and stays inside the viewport's right gutter.
  const place = useCallback(() => {
    const el = triggerRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    setPos({
      top: r.bottom + 6,
      right: Math.max(8, window.innerWidth - r.right),
    });
  }, []);

  useEffect(() => {
    if (!open) {
      setPos(null);
      return;
    }
    place();
    // `true` → capture phase, so scrolls inside any ancestor reposition too.
    window.addEventListener("scroll", place, true);
    window.addEventListener("resize", place);
    return () => {
      window.removeEventListener("scroll", place, true);
      window.removeEventListener("resize", place);
    };
  }, [open, place]);

  return (
    <>
      <button
        ref={triggerRef}
        type="button"
        className={triggerClassName}
        onClick={() => setOpen(true)}
      >
        {trigger}
      </button>
      {open && pos
        ? createPortal(
            <>
              <button
                type="button"
                aria-label={tCommon("close")}
                className="fixed inset-0 z-50 cursor-default"
                onClick={close}
              />
              <div
                className={`pop fade-in fixed z-[51] flex ${width} flex-col gap-3 p-3`}
                style={{ top: pos.top, right: pos.right }}
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
            </>,
            document.body,
          )
        : null}
    </>
  );
}
