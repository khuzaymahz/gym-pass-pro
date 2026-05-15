import { getTranslations } from "next-intl/server";

import { QrPanel } from "@/components/QrPanel";
import { Toolbar } from "@/components/Toolbar";
import { PartnerSDK } from "@/lib/sdk";

/// QR page — the static QR every member scans to check in at this
/// gym. Renders the QR client-side from the gym's UUID (the backend
/// already has all the data we need; no new endpoint required), and
/// offers PNG / SVG / print exports.
///
/// `dynamic = "force-dynamic"` is owned by the dashboard layout so
/// the gym lookup always sees fresh data after a rename / slug
/// change. The QR is keyed on `gym.id`, not the slug, so cosmetic
/// renames don't invalidate the printed code.
export default async function QrPage() {
  const t = await getTranslations("qr");
  const gym = await PartnerSDK.getGym();
  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />
      <QrPanel
        gym={{
          id: gym.id,
          slug: gym.slug,
          nameEn: gym.nameEn,
          nameAr: gym.nameAr,
        }}
      />
    </section>
  );
}
