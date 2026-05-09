"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import PendingButton from "@/components/PendingButton";
import StatusPill from "@/components/StatusPill";
import type { ActionResult } from "@/lib/action-result";
import type { PlanRead, PlanUpdate } from "@/lib/sdk";

type Props = {
  plan: PlanRead;
  action: (data: PlanUpdate) => Promise<ActionResult<PlanRead>>;
};

export default function PlanEditor({ plan, action }: Props) {
  const router = useRouter();
  const t = useTranslations("plans");
  const tCommon = useTranslations("common");
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{
    tone: "ok" | "err";
    text: string;
  } | null>(null);

  const [priceJod, setPriceJod] = useState(plan.priceJod);
  const [monthlyVisits, setMonthlyVisits] = useState(plan.monthlyVisits);
  const [includedGymCount, setIncludedGymCount] = useState(
    plan.includedGymCount,
  );
  const [discountPercent, setDiscountPercent] = useState(plan.discountPercent);
  const [featuresEn, setFeaturesEn] = useState(plan.featuresEn.join("\n"));
  const [featuresAr, setFeaturesAr] = useState(plan.featuresAr.join("\n"));
  const [isActive, setIsActive] = useState(plan.isActive);

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setMessage(null);
    const payload: PlanUpdate = {
      priceJod,
      monthlyVisits,
      includedGymCount,
      discountPercent,
      featuresEn: featuresEn
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean),
      featuresAr: featuresAr
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean),
      isActive,
    };

    startTransition(async () => {
      const result = await action(payload);
      if (result.ok) {
        setMessage({ tone: "ok", text: tCommon("savedDot") });
        router.refresh();
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="panel flex flex-col">
      <header className="flex items-center justify-between border-b border-line px-4 py-3">
        <div className="flex items-center gap-2">
          <h3 className="h2 capitalize">{plan.tier}</h3>
          <span className="kbd">
            {t("duration", { count: plan.durationMonths })}
          </span>
          <StatusPill tone={isActive ? "ok" : "mute"}>
            {isActive ? tCommon("active") : tCommon("inactive")}
          </StatusPill>
        </div>
        <label className="flex items-center gap-1.5 text-[12px] text-muted">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
            className="h-3.5 w-3.5 accent-lime"
          />
          {tCommon("enabled")}
        </label>
      </header>

      <div className="grid grid-cols-2 gap-3 border-b border-line p-4 md:grid-cols-4">
        <Field label={t("fields.price")}>
          <input
            className="input input-sm num"
            required
            inputMode="decimal"
            value={priceJod}
            onChange={(e) => setPriceJod(e.target.value)}
          />
        </Field>
        <Field label={t("fields.monthlyVisits")}>
          <input
            className="input input-sm num"
            required
            type="number"
            min={0}
            value={monthlyVisits}
            onChange={(e) =>
              setMonthlyVisits(Number.parseInt(e.target.value, 10))
            }
          />
        </Field>
        <Field label={t("fields.includedGyms")}>
          <input
            className="input input-sm num"
            required
            type="number"
            min={0}
            value={includedGymCount}
            onChange={(e) =>
              setIncludedGymCount(Number.parseInt(e.target.value, 10))
            }
          />
        </Field>
        <Field label={t("fields.discount")}>
          <input
            className="input input-sm num"
            required
            inputMode="decimal"
            value={discountPercent}
            onChange={(e) => setDiscountPercent(e.target.value)}
          />
        </Field>
      </div>

      <div className="grid grid-cols-1 gap-3 p-4 md:grid-cols-2">
        <Field label={t("fields.featuresEn")}>
          <textarea
            className="input min-h-[7rem]"
            value={featuresEn}
            onChange={(e) => setFeaturesEn(e.target.value)}
          />
        </Field>
        <Field label={t("fields.featuresAr")}>
          <textarea
            className="input min-h-[7rem]"
            dir="rtl"
            value={featuresAr}
            onChange={(e) => setFeaturesAr(e.target.value)}
          />
        </Field>
      </div>

      <footer className="flex items-center justify-between gap-3 border-t border-line px-4 py-3">
        {message ? (
          <p
            className={`text-[12px] ${
              message.tone === "ok" ? "text-lime" : "text-red-300"
            }`}
          >
            {message.text}
          </p>
        ) : (
          <span className="text-[12px] text-muted">{t("footerHint")}</span>
        )}
        <PendingButton
          pending={pending}
          pendingLabel={tCommon("saving")}
          idleLabel={tCommon("save")}
        />
      </footer>
    </form>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
    </label>
  );
}
