import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";

import GymForm from "@/components/GymForm";
import GymLogoPanel from "@/components/GymLogoPanel";
import { GymOwnerPanel } from "@/components/GymOwnerPanel";
import GymPhotosPanel from "@/components/GymPhotosPanel";
import Toolbar from "@/components/Toolbar";
import { GymUpsertBodySchema, parseAction } from "@/lib/action-schemas";
import {
  createGymOwner,
  deleteGym,
  deleteGymLogo,
  deleteGymOwner,
  deleteGymPhoto,
  getGym,
  getGymOwner,
  listGymPhotos,
  resolvePhotoUrl,
  updateGym,
  updateGymPhoto,
  uploadGymLogo,
  uploadGymPhoto,
  type GymOwnerRead,
  type GymPhotoRead,
  type GymPhotoUpdate,
  type GymRead,
} from "@/lib/gyms";

type Props = { params: Promise<{ id: string }> };

async function updateAction(id: string, data: Partial<GymRead>) {
  "use server";
  const validated = parseAction(GymUpsertBodySchema, data);
  if (!validated.ok) {
    return { ok: false, error: validated.message };
  }
  try {
    await updateGym(id, validated.data as Partial<GymRead>);
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Failed to update.",
    };
  }
}

async function deleteAction(id: string) {
  "use server";
  await deleteGym(id);
}

async function uploadPhotoAction(gymId: string, formData: FormData) {
  "use server";
  try {
    const value = await uploadGymPhoto(gymId, formData);
    return { ok: true as const, value };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to upload photo.",
    };
  }
}

async function updatePhotoAction(
  gymId: string,
  photoId: string,
  data: GymPhotoUpdate,
) {
  "use server";
  try {
    const value = await updateGymPhoto(gymId, photoId, data);
    return { ok: true as const, value };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to update photo.",
    };
  }
}

async function deletePhotoAction(gymId: string, photoId: string) {
  "use server";
  try {
    await deleteGymPhoto(gymId, photoId);
    return { ok: true as const, value: null };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to delete photo.",
    };
  }
}

async function uploadLogoAction(gymId: string, formData: FormData) {
  "use server";
  try {
    const gym = await uploadGymLogo(gymId, formData);
    return { ok: true as const, value: { logoUrl: gym.logoUrl ?? null } };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to upload logo.",
    };
  }
}

async function deleteLogoAction(gymId: string) {
  "use server";
  try {
    const gym = await deleteGymLogo(gymId);
    return { ok: true as const, value: { logoUrl: gym.logoUrl ?? null } };
  } catch (error) {
    return {
      ok: false as const,
      error: error instanceof Error ? error.message : "Failed to remove logo.",
    };
  }
}

async function createOwnerAction(
  gymId: string,
  input: { phone: string; password: string; name: string },
) {
  "use server";
  try {
    const value = await createGymOwner(gymId, {
      phone: input.phone.trim(),
      password: input.password,
      name: input.name.trim() || null,
    });
    return { ok: true as const, value };
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

async function deleteOwnerAction(gymId: string) {
  "use server";
  try {
    await deleteGymOwner(gymId);
    return { ok: true as const };
  } catch (error) {
    return {
      ok: false as const,
      error:
        error instanceof Error
          ? error.message
          : "Failed to revoke partner login.",
    };
  }
}

export default async function EditGymPage({ params }: Props) {
  const { id } = await params;
  const t = await getTranslations("gyms");
  const tForm = await getTranslations("gyms.form");
  let gym;
  let photos: GymPhotoRead[] = [];
  let owner: GymOwnerRead | null = null;
  try {
    gym = await getGym(id);
    photos = await listGymPhotos(id);
    // Owner is optional — a freshly-created gym hasn't been bound to a
    // partner login yet. Soft-fail: if the owner endpoint errors for
    // any non-404 reason, the rest of the page should still render.
    try {
      owner = await getGymOwner(id);
    } catch {
      owner = null;
    }
  } catch {
    notFound();
  }

  const bound = updateAction.bind(null, id);
  const boundDelete = deleteAction.bind(null, id);
  const boundUploadPhoto = uploadPhotoAction.bind(null, id);
  const boundUpdatePhoto = updatePhotoAction.bind(null, id);
  const boundDeletePhoto = deletePhotoAction.bind(null, id);
  const boundUploadLogo = uploadLogoAction.bind(null, id);
  const boundDeleteLogo = deleteLogoAction.bind(null, id);
  const boundCreateOwner = createOwnerAction.bind(null, id);
  const boundDeleteOwner = deleteOwnerAction.bind(null, id);

  const photosForPanel = photos.map((p) => ({
    ...p,
    url: resolvePhotoUrl(p.url),
  }));
  const resolvedLogo = gym.logoUrl ? resolvePhotoUrl(gym.logoUrl) : null;

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={gym.nameEn}
        description={`${gym.slug} · ${gym.area} · ${gym.category}`}
        actions={
          <>
            <Link href="/gyms" className="btn-ghost btn-sm">
              ← {t("back")}
            </Link>
            <form action={boundDelete}>
              <button className="btn-danger btn-sm">{t("softDelete")}</button>
            </form>
          </>
        }
      />
      <GymForm initial={gym} action={bound} submitLabel={tForm("save")} />
      <GymLogoPanel
        logoUrl={resolvedLogo}
        uploadAction={boundUploadLogo}
        deleteAction={boundDeleteLogo}
      />
      <GymOwnerPanel
        initial={owner}
        createAction={boundCreateOwner}
        deleteAction={boundDeleteOwner}
      />
      <GymPhotosPanel
        photos={photosForPanel}
        uploadAction={boundUploadPhoto}
        updateAction={boundUpdatePhoto}
        deleteAction={boundDeletePhoto}
      />
    </section>
  );
}
