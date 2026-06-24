"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import PendingButton from "@/components/PendingButton";
import StatusPill from "@/components/StatusPill";
import { useToast } from "@/components/ui/Toast";
import EmptyRow from "@/components/users/EmptyRow";
import { formatDateTime } from "@/components/users/format";
import type { ActionResult } from "@/lib/action-result";
import type { AdminSession } from "@/lib/sdk";

type Props = {
  sessions: AdminSession[];
  revoke: () => Promise<ActionResult<unknown>>;
};

function sessionState(s: AdminSession): {
  key: "active" | "revoked" | "expired";
  tone: "ok" | "bad" | "mute";
} {
  if (s.revokedAt) return { key: "revoked", tone: "bad" };
  if (new Date(s.expiresAt).getTime() < Date.now())
    return { key: "expired", tone: "mute" };
  return { key: "active", tone: "ok" };
}

export default function UserSessionsPanel({ sessions, revoke }: Props) {
  const router = useRouter();
  const t = useTranslations("users.sessions");
  const tCommon = useTranslations("common");
  const { toast } = useToast();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const activeCount = sessions.filter(
    (s) => sessionState(s).key === "active",
  ).length;

  function onRevoke() {
    if (!confirm(t("revokeConfirm"))) return;
    setError(null);
    startTransition(async () => {
      const result = await revoke();
      if (result.ok) {
        toast(tCommon("done"), "success");
        router.refresh();
      } else {
        setError(result.message);
        toast(result.message, "error");
      }
    });
  }

  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">{t("title")}</h2>
        <PendingButton
          type="button"
          onClick={onRevoke}
          pending={pending}
          pendingLabel={tCommon("loading")}
          idleLabel={t("forceLogout")}
          className="btn-danger btn-sm disabled:opacity-50"
          disabled={activeCount === 0}
        />
      </div>
      {error ? <p className="text-[11px] text-red-300">{error}</p> : null}

      <div className="panel overflow-hidden">
        {sessions.length === 0 ? (
          <EmptyRow label={t("none")} />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>{t("device")}</th>
                <th>{t("status")}</th>
                <th>{t("lastUsed")}</th>
                <th>{t("created")}</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((s) => {
                const state = sessionState(s);
                return (
                  <tr key={s.id}>
                    <td className="text-paper">
                      {s.deviceInfo ?? (
                        <span className="text-muted">{t("unknownDevice")}</span>
                      )}
                    </td>
                    <td>
                      <StatusPill tone={state.tone}>
                        {t(`states.${state.key}`)}
                      </StatusPill>
                    </td>
                    <td className="num text-muted">
                      {s.lastUsedAt ? formatDateTime(s.lastUsedAt) : "—"}
                    </td>
                    <td className="num text-muted">
                      {formatDateTime(s.createdAt)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
