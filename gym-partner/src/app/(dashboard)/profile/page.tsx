import { getTranslations } from "next-intl/server";

import { GymProfileForm } from "@/components/GymProfileForm";
import { LogoPanel } from "@/components/LogoPanel";
import { Toolbar } from "@/components/Toolbar";
import { PartnerSDK } from "@/lib/sdk";

export const dynamic = "force-dynamic";

export default async function ProfilePage() {
  const t = await getTranslations("profile");
  const gym = await PartnerSDK.getGym();
  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />
      {/* Logo first — it's the asset most likely to be unset on
          first sign-in, so partners shouldn't have to scroll past
          the long profile form to set it. */}
      <LogoPanel initialLogoUrl={gym.logoUrl} gymName={gym.nameEn} />
      <GymProfileForm gym={gym} />
    </section>
  );
}
