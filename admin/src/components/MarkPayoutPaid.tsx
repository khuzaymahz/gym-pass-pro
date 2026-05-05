"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";
import type { AdminPayout } from "@/lib/sdk";

type Props = {
  action: (notes?: string) => Promise<ActionResult<AdminPayout>>;
};

export default function MarkPayoutPaid({ action }: Props) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [notes, setNotes] = useState("");
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    startTransition(async () => {
      const result = await action(notes.trim() || undefined);
      if (result.ok) {
        setOpen(false);
        setNotes("");
        router.refresh();
      } else {
        setError(result.message);
      }
    });
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="btn-primary btn-sm"
      >
        Mark paid
      </button>
    );
  }

  return (
    <form onSubmit={onSubmit} className="flex items-center justify-end gap-1.5">
      <input
        className="input input-sm w-44"
        placeholder="Notes (optional)"
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
      />
      <button
        type="submit"
        disabled={pending}
        className="btn-primary btn-sm"
      >
        {pending ? "…" : "Confirm"}
      </button>
      <button
        type="button"
        onClick={() => {
          setOpen(false);
          setNotes("");
          setError(null);
        }}
        className="btn-ghost btn-sm"
      >
        Cancel
      </button>
      {error ? <span className="text-[11px] text-red-300">{error}</span> : null}
    </form>
  );
}
