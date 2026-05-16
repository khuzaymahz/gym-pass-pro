import { getTranslations } from "next-intl/server";

import PlanEditor from "@/components/PlanEditor";
import Toolbar from "@/components/Toolbar";
import { PlanUpdateBodySchema, parseAction } from "@/lib/action-schemas";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type PlanUpdate } from "@/lib/sdk";

const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;
type KnownTier = (typeof TIER_ORDER)[number];

// Unknown tiers (backend drift — e.g. someone adds "elite") sort
// to the END so the next reviewer sees the misfit at the bottom of
// the list rather than masquerading as silver (indexOf returns -1).
function tierIndex(tier: string): number {
  const idx = TIER_ORDER.indexOf(tier as KnownTier);
  return idx >= 0 ? idx : TIER_ORDER.length;
}

export default async function PlansPage() {
  const plans = await AdminSDK.listPlans();
  const t = await getTranslations("plans");

  const sorted = [...plans].sort((a, b) => {
    const tierDelta = tierIndex(a.tier) - tierIndex(b.tier);
    if (tierDelta !== 0) return tierDelta;
    return a.durationMonths - b.durationMonths;
  });

  async function update(id: string, data: PlanUpdate) {
    "use server";
    const validated = parseAction(PlanUpdateBodySchema, data);
    if (!validated.ok) return validated;
    return runAction(() => AdminSDK.updatePlan(id, validated.data));
  }

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: t("count"), value: plans.length }}
      />

      <div className="grid grid-cols-1 gap-3 xl:grid-cols-2">
        {sorted.map((plan) => (
          <PlanEditor
            key={plan.id}
            plan={plan}
            action={update.bind(null, plan.id)}
          />
        ))}
      </div>
    </section>
  );
}
