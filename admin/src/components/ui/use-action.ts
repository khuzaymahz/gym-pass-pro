"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import { useToast } from "@/components/ui/Toast";
import type { ActionResult } from "@/lib/action-result";

/**
 * Shared client-action runner. Encapsulates the pending / error /
 * success-then-refresh dance that every admin mutation control was
 * re-implementing by hand (cancel, refund, manage-subscription,
 * configure-offering, force-logout, …).
 *
 *   const { pending, error, ok, run } = useAction();
 *   run(() => action(payload));
 *
 * On success it calls `router.refresh()` so the server component
 * re-renders with fresh data; `ok` flips true for an inline "Saved."
 * acknowledgement. Errors from `runAction` surface as `error`.
 */
export function useAction() {
  const router = useRouter();
  const { toast } = useToast();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  function run(
    fn: () => Promise<ActionResult<unknown>>,
    opts?: { onSuccess?: () => void; refresh?: boolean; success?: string },
  ) {
    setError(null);
    setOk(false);
    startTransition(async () => {
      const result = await fn();
      if (result.ok) {
        setOk(true);
        // Confirmation toast on success when the caller supplies a
        // message; the inline `ok` flag stays for in-place hints.
        if (opts?.success) toast(opts.success, "success");
        opts?.onSuccess?.();
        if (opts?.refresh !== false) router.refresh();
      } else {
        setError(result.message);
        // Failures always surface as a toast — no silent errors.
        toast(result.message, "error");
      }
    });
  }

  return {
    pending,
    error,
    ok,
    run,
    reset: () => {
      setError(null);
      setOk(false);
    },
  };
}
