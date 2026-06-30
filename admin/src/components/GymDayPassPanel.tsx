"use client";

import { useTranslations } from "next-intl";

import ConfigureDayPassOffering from "@/components/ConfigureDayPassOffering";
import StatusPill from "@/components/StatusPill";
import type { ActionResult } from "@/lib/action-result";
import type {
  AdminDayPassOffering,
  AdminDayPassOfferingConfigure,
} from "@/lib/sdk";

/**
 * Bare panel (inside a CollapsibleSection) for a single gym's day-pass
 * offering. Shows the current status and reuses ConfigureDayPassOffering
 * to enable/price it. When the gym has no offering yet, a default is
 * synthesised so the configure control can create one on first save
 * (the backend PUT is create-or-update by gym id).
 */
export function GymDayPassPanel({
  offering,
  gymId,
  action,
}: {
  offering: AdminDayPassOffering | null;
  gymId: string;
  action: (
    body: AdminDayPassOfferingConfigure,
  ) => Promise<ActionResult<unknown>>;
}) {
  const t = useTranslations("gyms.dayPass");
  const effective: AdminDayPassOffering = offering ?? {
    id: "",
    gymId,
    gymNameEn: "",
    gymSlug: "",
    isEnabled: false,
    priceJod: "5.00",
    platformFeePct: "10.00",
    validityHours: 24,
    dailyCap: null,
    audienceGenderOverride: null,
  };

  return (
    <div className="flex flex-col gap-3">
      {offering ? (
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[12.5px]">
          <StatusPill tone={offering.isEnabled ? "ok" : "mute"}>
            {offering.isEnabled ? t("on") : t("off")}
          </StatusPill>
          <span className="text-paper">
            {t("price", { price: offering.priceJod })}
          </span>
          <span className="text-muted">
            {t("validity", { hours: offering.validityHours })}
          </span>
          {offering.dailyCap !== null ? (
            <span className="text-muted">
              {t("cap", { cap: offering.dailyCap })}
            </span>
          ) : null}
        </div>
      ) : (
        <p className="text-[12px] text-muted">{t("notSetUp")}</p>
      )}
      <div>
        <ConfigureDayPassOffering offering={effective} action={action} />
      </div>
    </div>
  );
}
