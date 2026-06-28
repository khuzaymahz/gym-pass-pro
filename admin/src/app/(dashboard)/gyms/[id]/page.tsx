import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";

import GymForm from "@/components/GymForm";
import { GymDayPassPanel } from "@/components/GymDayPassPanel";
import GymLogoPanel from "@/components/GymLogoPanel";
import { GymOwnerPanel } from "@/components/GymOwnerPanel";
import GymPhotosPanel from "@/components/GymPhotosPanel";
import { GymSecurityPanel } from "@/components/GymSecurityPanel";
import Toolbar from "@/components/Toolbar";
import CollapsibleSection from "@/components/ui/CollapsibleSection";
import { runAction } from "@/lib/action-result";
import { GymUpsertBodySchema, parseAction } from "@/lib/action-schemas";
import { AdminSDK, type AdminDayPassOfferingConfigure } from "@/lib/sdk";
import {
  createGymOwner,
  deleteGym,
  deleteGymLogo,
  deleteGymOwner,
  deleteGymPhoto,
  getGym,
  getGymOwner,
  listGymPhotos,
  resetGymOwnerPassword,
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

async function configureOfferingAction(
  gymId: string,
  body: AdminDayPassOfferingConfigure,
) {
  "use server";
  return runAction(() => AdminSDK.configureDayPassOffering(gymId, body));
}

async function resetOwnerPasswordAction(gymId: string, password: string) {
  "use server";
  try {
    await resetGymOwnerPassword(gymId, password);
    return { ok: true as const };
  } catch (error) {
    return {
      ok: false as const,
      error:
        error instanceof Error ? error.message : "Failed to reset password.",
    };
  }
}

export default async function EditGymPage({ params }: Props) {
  const { id } = await params;
  const t = await getTranslations("gyms");
  const tForm = await getTranslations("gyms.form");
  const tSec = await getTranslations("gyms.sections");
  // Fetch gym + photos + owner concurrently instead of in a 3-deep
  // waterfall — they're independent, so latency drops from the sum of
  // three round-trips to the slowest one. Semantics preserved: gym and
  // photos are required (404 if either fails); owner is optional (a
  // fresh gym isn't bound to a partner login yet) and soft-fails.
  const [gymR, photosR, ownerR, offeringR] = await Promise.allSettled([
    getGym(id),
    listGymPhotos(id),
    getGymOwner(id),
    AdminSDK.getDayPassOffering(id),
  ]);
  if (gymR.status !== "fulfilled" || photosR.status !== "fulfilled") {
    notFound();
  }
  const gym = gymR.value;
  const photos: GymPhotoRead[] = photosR.value;
  const owner: GymOwnerRead | null =
    ownerR.status === "fulfilled" ? ownerR.value : null;
  const offering =
    offeringR.status === "fulfilled" ? offeringR.value : null;

  const bound = updateAction.bind(null, id);
  const boundDelete = deleteAction.bind(null, id);
  const boundUploadPhoto = uploadPhotoAction.bind(null, id);
  const boundUpdatePhoto = updatePhotoAction.bind(null, id);
  const boundDeletePhoto = deletePhotoAction.bind(null, id);
  const boundUploadLogo = uploadLogoAction.bind(null, id);
  const boundDeleteLogo = deleteLogoAction.bind(null, id);
  const boundCreateOwner = createOwnerAction.bind(null, id);
  const boundDeleteOwner = deleteOwnerAction.bind(null, id);
  const boundResetPassword = resetOwnerPasswordAction.bind(null, id);
  const boundConfigureOffering = configureOfferingAction.bind(null, id);

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

      <CollapsibleSection
        title={tSec("partner")}
        subtitle={tSec("partnerSubtitle")}
      >
        <GymOwnerPanel
          initial={owner}
          createAction={boundCreateOwner}
          deleteAction={boundDeleteOwner}
        />
      </CollapsibleSection>

      <CollapsibleSection title={tSec("security")} subtitle={tSec("securitySubtitle")}>
        <GymSecurityPanel
          hasOwner={owner !== null}
          resetAction={boundResetPassword}
        />
      </CollapsibleSection>

      <CollapsibleSection
        title={tSec("dayPass")}
        subtitle={tSec("dayPassSubtitle")}
      >
        <GymDayPassPanel
          offering={offering}
          gymId={id}
          action={boundConfigureOffering}
        />
      </CollapsibleSection>

      <CollapsibleSection title={tSec("logo")}>
        <GymLogoPanel
          logoUrl={resolvedLogo}
          uploadAction={boundUploadLogo}
          deleteAction={boundDeleteLogo}
        />
      </CollapsibleSection>

      <CollapsibleSection title={tSec("photos")}>
        <GymPhotosPanel
          photos={photosForPanel}
          uploadAction={boundUploadPhoto}
          updateAction={boundUpdatePhoto}
          deleteAction={boundDeletePhoto}
        />
      </CollapsibleSection>
    </section>
  );
}
