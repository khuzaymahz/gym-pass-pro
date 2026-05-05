import PlanEditor from "@/components/PlanEditor";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type PlanUpdate } from "@/lib/sdk";

const TIER_ORDER = ["silver", "gold", "platinum", "diamond"] as const;

export default async function PlansPage() {
  const plans = await AdminSDK.listPlans();

  const sorted = [...plans].sort((a, b) => {
    const tierDelta =
      TIER_ORDER.indexOf(a.tier as (typeof TIER_ORDER)[number]) -
      TIER_ORDER.indexOf(b.tier as (typeof TIER_ORDER)[number]);
    if (tierDelta !== 0) return tierDelta;
    return a.durationMonths - b.durationMonths;
  });

  async function update(id: string, data: PlanUpdate) {
    "use server";
    return runAction(() => AdminSDK.updatePlan(id, data));
  }

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title="Plans"
        description="Tier and pricing for member subscriptions. Edits apply to future renewals."
        count={{ label: "plans", value: plans.length }}
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
