import { getTranslations } from "next-intl/server";

import { Toolbar } from "@/components/Toolbar";
import { GymProfileForm } from "@/components/GymProfileForm";
import { PartnerSDK } from "@/lib/sdk";

export const dynamic = "force-dynamic";

export default async function ProfilePage() {
  const t = await getTranslations("profile");
  const gym = await PartnerSDK.getGym();
  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />
      <GymProfileForm gym={gym} />
    </section>
  );
}
