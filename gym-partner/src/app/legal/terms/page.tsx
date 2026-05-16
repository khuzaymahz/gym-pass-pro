import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";

import { LegalDocument } from "@/components/LegalDocument";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("legal.terms");
  return { title: `${t("title")} · GymPass` };
}

export default function PartnerTermsPage() {
  return <LegalDocument kind="terms" />;
}
