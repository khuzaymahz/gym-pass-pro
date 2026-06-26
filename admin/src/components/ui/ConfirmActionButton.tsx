"use client";

import { useTranslations } from "next-intl";

import PendingButton from "@/components/PendingButton";
import { useAction } from "@/components/ui/use-action";
import type { ActionResult } from "@/lib/action-result";

type Variant = "danger" | "secondary";

const CHROME: Record<Variant, string> = {
  danger: "btn-danger btn-sm disabled:opacity-50",
  secondary: "btn-secondary btn-sm disabled:opacity-50",
};

/**
 * Canonical "click → optional confirm → run server action → refresh"
 * control. Replaces the three hand-rolled copies (cancel subscription,
 * refund day pass, refund payment) that were byte-for-byte the same
 * apart from their label/confirm strings. Single place to evolve the
 * destructive-action UX (busy state, error surface, alignment).
 */
export default function ConfirmActionButton({
  action,
  label,
  confirm,
  variant = "danger",
}: {
  action: () => Promise<ActionResult<unknown>>;
  label: string;
  confirm?: string;
  variant?: Variant;
}) {
  const tCommon = useTranslations("common");
  const { pending, error, run } = useAction();

  function onClick() {
    if (confirm && !window.confirm(confirm)) return;
    run(action, { success: tCommon("done") });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <PendingButton
        type="button"
        onClick={onClick}
        pending={pending}
        pendingLabel={tCommon("loading")}
        idleLabel={label}
        className={CHROME[variant]}
      />
      {error ? <span className="text-[11px] text-red-300">{error}</span> : null}
    </div>
  );
}
