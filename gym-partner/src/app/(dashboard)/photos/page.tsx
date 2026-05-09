import { getTranslations } from "next-intl/server";

import { Toolbar } from "@/components/Toolbar";
import { PhotosPanel } from "@/components/PhotosPanel";
import { PartnerSDK } from "@/lib/sdk";

// `dynamic = "force-dynamic"` is owned by the dashboard layout.
export default async function PhotosPage() {
  const t = await getTranslations("photos");
  const photos = await PartnerSDK.listPhotos();
  return (
    <section className="flex flex-col gap-6">
      <Toolbar title={t("title")} description={t("subtitle")} />
      <PhotosPanel initial={photos} />
    </section>
  );
}
