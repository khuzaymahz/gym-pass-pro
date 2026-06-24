"use client";

import { useTranslations } from "next-intl";
import { useState } from "react";

import PendingButton from "@/components/PendingButton";
import Popover from "@/components/ui/Popover";
import { useAction } from "@/components/ui/use-action";
import type { ActionResult } from "@/lib/action-result";
import type {
  AdminDayPassOffering,
  AdminDayPassOfferingConfigure,
} from "@/lib/sdk";

type Props = {
  offering: AdminDayPassOffering;
  action: (
    body: AdminDayPassOfferingConfigure,
  ) => Promise<ActionResult<unknown>>;
};

export default function ConfigureDayPassOffering({ offering, action }: Props) {
  const t = useTranslations("dayPasses.configure");
  const tCommon = useTranslations("common");
  const { pending, error, ok, run } = useAction();

  const [isEnabled, setIsEnabled] = useState(offering.isEnabled);
  const [price, setPrice] = useState(offering.priceJod);
  const [feePct, setFeePct] = useState(offering.platformFeePct);
  const [validity, setValidity] = useState(String(offering.validityHours));
  const [cap, setCap] = useState(
    offering.dailyCap === null ? "" : String(offering.dailyCap),
  );

  function onSave() {
    const body: AdminDayPassOfferingConfigure = {
      isEnabled,
      priceJod: price,
      platformFeePct: feePct,
      validityHours: Number.parseInt(validity || "0", 10),
      dailyCap: cap.trim() === "" ? null : Number.parseInt(cap, 10),
      audienceGenderOverride: offering.audienceGenderOverride,
    };
    run(() => action(body), { success: tCommon("savedDot") });
  }

  return (
    <Popover trigger={t("configure")} title={t("title")}>
      <label className="flex items-center gap-2 text-[12.5px] text-paper">
        <input
          type="checkbox"
          className="h-3.5 w-3.5 accent-lime"
          checked={isEnabled}
          onChange={(e) => setIsEnabled(e.target.checked)}
        />
        {t("enabled")}
      </label>

      <div className="grid grid-cols-2 gap-2">
        <label className="field">
          <span className="field-label">{t("price")}</span>
          <input
            type="number"
            step="0.01"
            min={0}
            className="input input-sm num"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("feePct")}</span>
          <input
            type="number"
            step="0.01"
            min={0}
            max={99.99}
            className="input input-sm num"
            value={feePct}
            onChange={(e) => setFeePct(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("validity")}</span>
          <input
            type="number"
            min={1}
            max={168}
            className="input input-sm num"
            value={validity}
            onChange={(e) => setValidity(e.target.value)}
          />
        </label>
        <label className="field">
          <span className="field-label">{t("dailyCap")}</span>
          <input
            type="number"
            min={1}
            placeholder={t("unlimited")}
            className="input input-sm num"
            value={cap}
            onChange={(e) => setCap(e.target.value)}
          />
        </label>
      </div>

      <div className="flex items-center justify-between border-t border-line pt-2">
        {error ? (
          <span className="text-[11px] text-red-300">{error}</span>
        ) : ok ? (
          <span className="text-[11px] text-lime">{tCommon("savedDot")}</span>
        ) : (
          <span className="text-[11px] text-muted">{t("hint")}</span>
        )}
        <PendingButton
          type="button"
          pending={pending}
          pendingLabel={tCommon("saving")}
          idleLabel={t("save")}
          className="btn btn-sm"
          onClick={onSave}
        />
      </div>
    </Popover>
  );
}
