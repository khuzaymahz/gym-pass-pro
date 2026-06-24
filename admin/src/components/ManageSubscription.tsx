"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

import PendingButton from "@/components/PendingButton";
import Popover from "@/components/ui/Popover";
import { useAction } from "@/components/ui/use-action";
import type { ActionResult } from "@/lib/action-result";
import type { SubscriptionStatus, Tier } from "@/lib/sdk";

const TIERS: Tier[] = ["silver", "gold", "platinum", "diamond"];

type Sub = {
  id: string;
  status: SubscriptionStatus;
  tier: Tier;
  visitsUsed: number;
};

type Props = {
  sub: Sub;
  extend: (days: number) => Promise<ActionResult<unknown>>;
  setVisits: (visitsUsed: number) => Promise<ActionResult<unknown>>;
  changeTier: (tier: Tier) => Promise<ActionResult<unknown>>;
  restore: () => Promise<ActionResult<unknown>>;
  resumePause: () => Promise<ActionResult<unknown>>;
};

export default function ManageSubscription({
  sub,
  extend,
  setVisits,
  changeTier,
  restore,
  resumePause,
}: Props) {
  const t = useTranslations("subscriptions.manage");
  const tCommon = useTranslations("common");
  const { pending, error, ok, run } = useAction();

  const [days, setDays] = useState("7");
  const [visits, setVisits_] = useState(String(sub.visitsUsed));
  const [tier, setTier] = useState<Tier>(sub.tier);

  const canRestore = sub.status === "cancelled" || sub.status === "expired";
  const canResume = sub.status === "active";

  return (
    <Popover trigger={t("manage")} title={t("title")}>
      {/* Extend */}
      <div className="flex items-end gap-2">
        <label className="field flex-1">
          <span className="field-label">{t("extendDays")}</span>
          <input
            type="number"
            className="input input-sm num"
            value={days}
            onChange={(e) => setDays(e.target.value)}
          />
        </label>
        <PendingButton
          type="button"
          pending={pending}
          pendingLabel={tCommon("saving")}
          idleLabel={t("apply")}
          className="btn btn-sm"
          onClick={() =>
            run(() => extend(Number.parseInt(days || "0", 10)), {
              success: tCommon("savedDot"),
            })
          }
        />
      </div>

      {/* Visits */}
      <div className="flex items-end gap-2">
        <label className="field flex-1">
          <span className="field-label">{t("visitsUsed")}</span>
          <input
            type="number"
            min={0}
            className="input input-sm num"
            value={visits}
            onChange={(e) => setVisits_(e.target.value)}
          />
        </label>
        <PendingButton
          type="button"
          pending={pending}
          pendingLabel={tCommon("saving")}
          idleLabel={t("set")}
          className="btn btn-sm"
          onClick={() =>
            run(() => setVisits(Number.parseInt(visits || "0", 10)), {
              success: tCommon("savedDot"),
            })
          }
        />
      </div>

      {/* Tier */}
      <div className="flex items-end gap-2">
        <label className="field flex-1">
          <span className="field-label">{t("tier")}</span>
          <select
            className="select input-sm capitalize"
            value={tier}
            onChange={(e) => setTier(e.target.value as Tier)}
          >
            {TIERS.map((tr) => (
              <option key={tr} value={tr}>
                {tr}
              </option>
            ))}
          </select>
        </label>
        <PendingButton
          type="button"
          pending={pending}
          pendingLabel={tCommon("saving")}
          idleLabel={t("change")}
          className="btn btn-sm"
          onClick={() =>
            run(() => changeTier(tier), { success: tCommon("savedDot") })
          }
        />
      </div>

      {(canRestore || canResume) && (
        <div className="flex flex-wrap gap-2 border-t border-line pt-2">
          {canRestore && (
            <PendingButton
              type="button"
              pending={pending}
              pendingLabel={tCommon("saving")}
              idleLabel={t("restore")}
              className="btn btn-sm"
              onClick={() =>
                run(() => restore(), { success: tCommon("savedDot") })
              }
            />
          )}
          {canResume && (
            <PendingButton
              type="button"
              pending={pending}
              pendingLabel={tCommon("saving")}
              idleLabel={t("resumePause")}
              className="btn btn-sm"
              onClick={() =>
                run(() => resumePause(), { success: tCommon("savedDot") })
              }
            />
          )}
        </div>
      )}

      {error ? (
        <p className="text-[11px] text-red-300">{error}</p>
      ) : ok ? (
        <p className="text-[11px] text-lime">{tCommon("savedDot")}</p>
      ) : (
        <p className="text-[11px] text-muted">{t("hint")}</p>
      )}
    </Popover>
  );
}
