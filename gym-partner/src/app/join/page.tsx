import type { Metadata } from "next";
import Link from "next/link";
import { getTranslations } from "next-intl/server";

import { LocaleToggle } from "@/components/LocaleToggle";
import { ThemeToggle } from "@/components/ThemeToggle";
import { Wordmark } from "@/components/Wordmark";

import { JoinForm } from "./JoinForm";

export const dynamic = "force-dynamic";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("join");
  return { title: `${t("title")} · GymPass` };
}

/// Public partner-onboarding page. No auth required — a gym owner
/// who has never logged in arrives here from the marketing site or
/// from the login page's "Join Us" link, fills the form, and the
/// submission lands in the admin's review queue.
export default async function JoinPage() {
  const t = await getTranslations("join");
  return (
    <main className="relative flex min-h-screen items-start justify-center bg-ink p-6 text-paper">
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
      <div className="mt-16 w-full max-w-2xl">
        <div className="mb-6 flex flex-col gap-2">
          <p className="label">{t("eyebrow")}</p>
          <h1 className="h2">{t("title")}</h1>
          <p className="text-[13px] leading-relaxed text-muted">
            {t("subtitle")}
          </p>
        </div>
        <JoinForm />
        <p className="mt-4 text-[12px] text-muted">
          {t("alreadyMember")}{" "}
          <Link
            href="/login"
            className="font-semibold text-accent hover:text-paper"
          >
            {t("signIn")}
          </Link>
        </p>
      </div>
    </main>
  );
}
