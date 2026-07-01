import Link from "next/link";
import { getTranslations } from "next-intl/server";

import NewGymForm from "@/components/NewGymForm";
import Toolbar from "@/components/Toolbar";
import { GymUpsertBodySchema, parseAction } from "@/lib/action-schemas";
import {
  createGymWithOwner,
  uploadGymPhoto,
  type GymRead,
  type OwnerProvision,
} from "@/lib/gyms";

async function createGymWithOwnerAction(
  data: Partial<GymRead>,
  owner: OwnerProvision | null,
) {
  "use server";
  const validated = parseAction(GymUpsertBodySchema, data);
  if (!validated.ok) {
    return { ok: false as const, error: validated.message };
  }
  try {
    // Atomic on the backend: a failed owner step rolls the gym back, so
    // we never strand an orphan gym. No edit-page recovery needed here.
    const res = await createGymWithOwner({
      gym: validated.data as Partial<GymRead>,
      owner,
    });
    return { ok: true as const, gymId: res.gym.id };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to create gym.",
    };
  }
}

async function uploadPhotoAction(gymId: string, formData: FormData) {
  "use server";
  try {
    await uploadGymPhoto(gymId, formData);
    return { ok: true as const };
  } catch (error) {
    return {
      ok: false as const,
      error:
        error instanceof Error ? error.message : "Failed to upload photo.",
    };
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
      <NewGymForm
        submitLabel={tForm("create")}
        createGymWithOwnerAction={createGymWithOwnerAction}
        uploadPhotoAction={uploadPhotoAction}
      />
    </section>
  );
}
