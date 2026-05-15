import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";

import { LegalDocument } from "@/components/LegalDocument";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("legal.privacy");
  return { title: `${t("title")} · GymPass` };
}

export default function PartnerPrivacyPage() {
  return <LegalDocument kind="privacy" />;
}
