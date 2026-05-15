import "server-only";

import { api, ApiError } from "@/lib/api";
import { env } from "@/lib/env";
import { serviceToken } from "@/lib/sdk";

export type GymRead = {
  id: string;
  slug: string;
  nameEn: string;
  nameAr: string;
  addressEn: string;
  addressAr: string;
  area: string;
  phone?: string | null;
  category: string;
  requiredTier: string;
  perVisitRateJod: string;
  lat: string;
  lng: string;
  isActive: boolean;
  amenities: string[];
  openingHours: Record<string, unknown>;
  coverImageUrl?: string | null;
  logoUrl?: string | null;
  rating?: string | null;
  reviewCount: number;
  photoCount: number;
};

export type Page<T> = { items: T[]; total: number; page: number; pageSize: number };

export async function listGyms(page = 1, pageSize = 20): Promise<Page<GymRead>> {
  return api(`/api/v1/admin/gyms?page=${page}&pageSize=${pageSize}`, {
    token: await serviceToken(),
  });
}

export async function getGym(id: string): Promise<GymRead> {
  return api(`/api/v1/admin/gyms/${id}`, { token: await serviceToken() });
}

export async function createGym(body: Partial<GymRead>): Promise<GymRead> {
  return api(`/api/v1/admin/gyms`, {
    method: "POST",
    body: JSON.stringify(body),
    token: await serviceToken(),
  });
}

export async function updateGym(
  id: string,
  body: Partial<GymRead>,
): Promise<GymRead> {
  return api(`/api/v1/admin/gyms/${id}`, {
    method: "PATCH",
    body: JSON.stringify(body),
    token: await serviceToken(),
  });
}

export async function deleteGym(id: string): Promise<void> {
  return api(`/api/v1/admin/gyms/${id}`, {
    method: "DELETE",
    token: await serviceToken(),
  });
}

export type GymPhotoRead = {
  id: string;
  url: string;
  sortOrder: number;
  altTextEn?: string | null;
  altTextAr?: string | null;
};

export type GymPhotoUpdate = {
  sortOrder?: number;
  altTextEn?: string | null;
  altTextAr?: string | null;
};

export async function listGymPhotos(gymId: string): Promise<GymPhotoRead[]> {
  return api(`/api/v1/admin/gyms/${gymId}/photos`, { token: await serviceToken() });
}

export async function uploadGymPhoto(
  gymId: string,
  formData: FormData,
): Promise<GymPhotoRead> {
  const bearer = await serviceToken();
  const response = await fetch(
    `${env.API_BASE_URL}/api/v1/admin/gyms/${gymId}/photos`,
    {
      method: "POST",
      headers: { authorization: `Bearer ${bearer}` },
      body: formData,
      cache: "no-store",
    },
  );
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = body?.error;
    throw new ApiError(
      err?.code ?? "UNKNOWN",
      err?.message ?? response.statusText,
      response.status,
      err?.details,
    );
  }
  return body as GymPhotoRead;
}

export async function updateGymPhoto(
  gymId: string,
  photoId: string,
  body: GymPhotoUpdate,
): Promise<GymPhotoRead> {
  return api(`/api/v1/admin/gyms/${gymId}/photos/${photoId}`, {
    method: "PATCH",
    body: JSON.stringify(body),
    token: await serviceToken(),
  });
}

export async function deleteGymPhoto(
  gymId: string,
  photoId: string,
): Promise<void> {
  return api(`/api/v1/admin/gyms/${gymId}/photos/${photoId}`, {
    method: "DELETE",
    token: await serviceToken(),
  });
}

export function resolvePhotoUrl(url: string): string {
  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  return `${env.API_BASE_URL}${url}`;
}

export async function uploadGymLogo(
  gymId: string,
  formData: FormData,
): Promise<GymRead> {
  const bearer = await serviceToken();
  const response = await fetch(
    `${env.API_BASE_URL}/api/v1/admin/gyms/${gymId}/logo`,
    {
      method: "POST",
      headers: { authorization: `Bearer ${bearer}` },
      body: formData,
      cache: "no-store",
    },
  );
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = body?.error;
    throw new ApiError(
      err?.code ?? "UNKNOWN",
      err?.message ?? response.statusText,
      response.status,
      err?.details,
    );
  }
  return body as GymRead;
}

export async function deleteGymLogo(gymId: string): Promise<GymRead> {
  return api(`/api/v1/admin/gyms/${gymId}/logo`, {
    method: "DELETE",
    token: await serviceToken(),
  });
}

/// Partner-portal login bound 1:1 to a gym. The DB enforces the
/// uniqueness constraint via the partial unique index
/// `uq_users_gym_owner_gym_id`, so attempting to create a second
/// owner on a gym that already has one comes back as a clean 409
/// from the backend.
export type GymOwnerRead = {
  id: string;
  phone: string;
  name: string | null;
  gymId: string;
};

export async function getGymOwner(
  gymId: string,
): Promise<GymOwnerRead | null> {
  return api<GymOwnerRead | null>(
    `/api/v1/admin/gyms/${gymId}/owner`,
    { token: await serviceToken() },
  );
}

export async function createGymOwner(
  gymId: string,
  body: { phone: string; password: string; name?: string | null },
): Promise<GymOwnerRead> {
  return api(`/api/v1/admin/gyms/${gymId}/owner`, {
    method: "POST",
    body: JSON.stringify(body),
    token: await serviceToken(),
  });
}

export async function deleteGymOwner(gymId: string): Promise<void> {
  return api(`/api/v1/admin/gyms/${gymId}/owner`, {
    method: "DELETE",
    token: await serviceToken(),
  });
}
