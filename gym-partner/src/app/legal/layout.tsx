import Link from "next/link";
import { getTranslations } from "next-intl/server";
import type { ReactNode } from "react";

import { LocaleToggle } from "@/components/LocaleToggle";
import { ThemeToggle } from "@/components/ThemeToggle";
import { Wordmark } from "@/components/Wordmark";

export const dynamic = "force-static";

export default async function LegalLayout({
  children,
}: {
  children: ReactNode;
}) {
  const t = await getTranslations("legal");
  return (
    <main className="relative min-h-screen bg-ink text-paper">
      <div className="absolute left-6 top-6 z-10">
        <Link href="/" aria-label="GymPass">
          <Wordmark size={24} />
        </Link>
      </div>
      <div
        dir="ltr"
        className="absolute right-6 top-6 z-10 flex items-center gap-2"
      >
        <LocaleToggle />
        <ThemeToggle />
      </div>
      <div className="mx-auto w-full max-w-[820px] px-6 pt-24 pb-16">
        <nav
          aria-label="legal"
          className="mb-8 flex items-center gap-3 text-[12px]"
        >
          <Link
            href="/legal/terms"
            className="text-muted hover:text-paper transition-colors"
          >
            {t("navTerms")}
          </Link>
          <span className="text-line">·</span>
          <Link
            href="/legal/privacy"
            className="text-muted hover:text-paper transition-colors"
          >
            {t("navPrivacy")}
          </Link>
        </nav>
        {children}
      </div>
    </main>
  );
}
