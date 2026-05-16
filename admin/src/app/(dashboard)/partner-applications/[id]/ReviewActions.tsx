"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useState, useTransition } from "react";

import { approveApplicationAction, rejectApplicationAction } from "./actions";

/// Approve/Reject panel shown on a pending application. Each branch
/// has a textarea for admin notes — required on reject (the partner
/// should know why) and optional on approve (free-form audit
/// trail). Both buttons wrap their action in useTransition so the
/// button shows a pending state while the server action is in
/// flight; success triggers a router.refresh() so the parent
/// page re-renders with the new status.
export function ReviewActions({ applicationId }: { applicationId: string }) {
  const t = useTranslations("partnerApplications");
  const router = useRouter();
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function onApprove() {
    setError(null);
    startTransition(async () => {
      try {
        const res = await approveApplicationAction(applicationId, notes);
        if (!res.ok) {
          setError(res.error);
          return;
        }
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  function onReject() {
    setError(null);
    if (!notes.trim()) {
      setError(t("rejectNotesRequired"));
      return;
    }
    if (!confirm(t("rejectConfirm"))) return;
    startTransition(async () => {
      try {
        const res = await rejectApplicationAction(applicationId, notes);
        if (!res.ok) {
          setError(res.error);
          return;
        }
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <div className="panel flex flex-col gap-3 p-5">
      <h2 className="label">{t("reviewActions")}</h2>
      <label className="field">
        <span className="field-label">{t("notesLabel")}</span>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={3}
          maxLength={2000}
          className="input input-sm w-full"
          placeholder={t("notesPlaceholder")}
          disabled={pending}
        />
        <span className="field-hint">{t("notesHint")}</span>
      </label>
      {error ? (
        <p className="rounded-md border border-red-400/40 bg-red-500/10 px-3 py-2 text-[12.5px] text-red-200">
          {error}
        </p>
      ) : null}
      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          className="btn-primary btn-sm"
          onClick={onApprove}
          disabled={pending}
        >
          {pending ? t("working") : t("approveBtn")}
        </button>
        <button
          type="button"
          className="btn-ghost btn-sm text-red-300 hover:text-red-200"
          onClick={onReject}
          disabled={pending}
        >
          {t("rejectBtn")}
        </button>
        <p className="ml-auto text-[11.5px] text-muted">{t("approveHint")}</p>
      </div>
    </div>
  );
}
