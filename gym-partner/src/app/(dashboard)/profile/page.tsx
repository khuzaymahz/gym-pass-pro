import { getTranslations } from "next-intl/server";

import { DayPassSection } from "@/components/DayPassSection";
import { GymProfileForm } from "@/components/GymProfileForm";
import { LogoPanel } from "@/components/LogoPanel";
import { Toolbar } from "@/components/Toolbar";
import { PartnerSDK } from "@/lib/sdk";

// `dynamic = "force-dynamic"` is owned by the dashboard layout.
export default async function ProfilePage() {
  const t = await getTranslations("profile");
  // Parallel fetch — independent backend calls. Promise.all keeps the
  // shell render at one round-trip latency instead of two.
  const [gym, dayPassOffering] = await Promise.all([
    PartnerSDK.getGym(),
    PartnerSDK.getDayPassOffering(),
  ]);
  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />
      {/* Logo first — it's the asset most likely to be unset on
          first sign-in, so partners shouldn't have to scroll past
          the long profile form to set it. */}
      <LogoPanel
        initialLogoUrl={gym.logoUrl}
        initialAlignment={gym.logoAlignment}
        gymName={gym.nameEn}
      />
      <GymProfileForm gym={gym} />
      {/* Day pass sits below the main profile form. Self-contained:
          its own save action, error pill, and form state — so the
          partner can flip enable + adjust price without touching
          the long gym profile above. */}
      <DayPassSection initial={dayPassOffering} />
    </section>
  );
}
