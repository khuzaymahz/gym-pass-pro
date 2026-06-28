import Link from "next/link";
import { getTranslations } from "next-intl/server";

import NewGymForm from "@/components/NewGymForm";
import Toolbar from "@/components/Toolbar";
import { GymUpsertBodySchema, parseAction } from "@/lib/action-schemas";
import {
  createGym,
  createGymOwner,
  uploadGymPhoto,
  type GymRead,
} from "@/lib/gyms";

async function createGymAction(data: Partial<GymRead>) {
  "use server";
  const validated = parseAction(GymUpsertBodySchema, data);
  if (!validated.ok) {
    return { ok: false as const, error: validated.message };
  }
  try {
    const gym = await createGym(validated.data as Partial<GymRead>);
    return { ok: true as const, gymId: gym.id };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to create gym.",
    };
  }
}

async function createOwnerAction(
  gymId: string,
  owner: { phone: string; name: string; password: string },
) {
  "use server";
  try {
    await createGymOwner(gymId, {
      phone: owner.phone,
      password: owner.password,
      name: owner.name || null,
    });
    return { ok: true as const };
  } catch (error) {
    return {
      ok: false as const,
      error:
        error instanceof Error
          ? error.message
          : "Failed to create partner login.",
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
        createGymAction={createGymAction}
        createOwnerAction={createOwnerAction}
        uploadPhotoAction={uploadPhotoAction}
      />
    </section>
  );
}
