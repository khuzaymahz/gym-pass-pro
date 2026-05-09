import Link from "next/link";
import { getTranslations } from "next-intl/server";

import GymForm from "@/components/GymForm";
import Toolbar from "@/components/Toolbar";
import { GymUpsertBodySchema, parseAction } from "@/lib/action-schemas";
import { createGym, type GymRead } from "@/lib/gyms";

async function action(data: Partial<GymRead>) {
  "use server";
  const validated = parseAction(GymUpsertBodySchema, data);
  if (!validated.ok) {
    return { ok: false, error: validated.message };
  }
  try {
    await createGym(validated.data as Partial<GymRead>);
    return { ok: true };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to create gym.";
    return { ok: false, error: message };
  }
}

export default async function NewGymPage() {
  const t = await getTranslations("gyms");
  const tForm = await getTranslations("gyms.form");
  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("newTitle")}
        description={t("newDescription")}
        actions={
          <Link href="/gyms" className="btn-ghost btn-sm">
            ← {t("back")}
          </Link>
        }
      />
      <GymForm action={action} submitLabel={tForm("create")} />
    </section>
  );
}
