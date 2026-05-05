"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";
import type { AdminPayout } from "@/lib/sdk";

type Props = {
  action: (
    periodStart: string,
    periodEnd: string,
  ) => Promise<ActionResult<AdminPayout[]>>;
};

function firstOfThisMonth(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

function todayISO(): string {
  const now = new Date();
  return now.toISOString().slice(0, 10);
}

export default function GeneratePayoutsForm({ action }: Props) {
  const router = useRouter();
  const [periodStart, setPeriodStart] = useState(firstOfThisMonth());
  const [periodEnd, setPeriodEnd] = useState(todayISO());
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{
    tone: "ok" | "err";
    text: string;
  } | null>(null);

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setMessage(null);
    startTransition(async () => {
      const result = await action(periodStart, periodEnd);
      if (result.ok) {
        const count = result.data.length;
        setMessage({
          tone: "ok",
          text:
            count === 0
              ? "No unpaid ledger rows in that range."
              : `Generated ${count} payout${count === 1 ? "" : "s"}.`,
        });
        router.refresh();
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  return (
    <form
      onSubmit={onSubmit}
      className="flex flex-wrap items-end gap-2 rounded-lg border border-line bg-surface p-3"
    >
      <label className="field">
        <span className="field-label">Period start</span>
        <input
          type="date"
          className="input input-sm w-40"
          required
          value={periodStart}
          onChange={(e) => setPeriodStart(e.target.value)}
        />
      </label>
      <label className="field">
        <span className="field-label">Period end</span>
        <input
          type="date"
          className="input input-sm w-40"
          required
          value={periodEnd}
          onChange={(e) => setPeriodEnd(e.target.value)}
        />
      </label>
      <button className="btn-primary btn-sm" disabled={pending}>
        {pending ? "Generating…" : "Generate run"}
      </button>
      <span className="ml-auto self-center text-[11.5px] text-muted">
        Creates one payout per active gym for the chosen window.
      </span>
      {message ? (
        <p
          className={`w-full text-[12px] ${
            message.tone === "ok" ? "text-lime" : "text-red-300"
          }`}
        >
          {message.text}
        </p>
      ) : null}
    </form>
  );
}
