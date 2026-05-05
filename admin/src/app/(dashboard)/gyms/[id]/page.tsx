import Link from "next/link";
import { notFound } from "next/navigation";

import GymForm from "@/components/GymForm";
import GymLogoPanel from "@/components/GymLogoPanel";
import GymPhotosPanel from "@/components/GymPhotosPanel";
import Toolbar from "@/components/Toolbar";
import {
  deleteGym,
  deleteGymLogo,
  deleteGymPhoto,
  getGym,
  listGymPhotos,
  resolvePhotoUrl,
  updateGym,
  updateGymPhoto,
  uploadGymLogo,
  uploadGymPhoto,
  type GymPhotoRead,
  type GymPhotoUpdate,
  type GymRead,
} from "@/lib/gyms";

type Props = { params: Promise<{ id: string }> };

async function updateAction(id: string, data: Partial<GymRead>) {
  "use server";
  try {
    await updateGym(id, data);
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

export default async function EditGymPage({ params }: Props) {
  const { id } = await params;
  let gym;
  let photos: GymPhotoRead[] = [];
  try {
    gym = await getGym(id);
    photos = await listGymPhotos(id);
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
              ← Gyms
            </Link>
            <form action={boundDelete}>
              <button className="btn-danger btn-sm">Soft-delete</button>
            </form>
          </>
        }
      />
      <GymForm initial={gym} action={bound} submitLabel="Save changes" />
      <GymLogoPanel
        logoUrl={resolvedLogo}
        uploadAction={boundUploadLogo}
        deleteAction={boundDeleteLogo}
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
