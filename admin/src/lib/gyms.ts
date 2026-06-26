import "server-only";

import { api, ApiError } from "@/lib/api";
import { serverEnv } from "@/lib/env.server";
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
  audienceGender: "mixed" | "female_only" | "male_only";
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

/// Multipart upload helper. The shared `api()` client forces a JSON
/// content-type and body, so the two file-upload endpoints (photo /
/// logo) bypass it and post `FormData` directly. This factors out the
/// otherwise byte-for-byte response parsing + `ApiError` mapping they
/// both repeated. Throws the same `ApiError` shape as `api()` on
/// non-2xx so callers / error boundaries handle it identically.
async function uploadFormData<T>(path: string, formData: FormData): Promise<T> {
  const bearer = await serviceToken();
  const response = await fetch(`${serverEnv.API_BASE_URL}${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${bearer}` },
    body: formData,
    cache: "no-store",
  });
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
  return body as T;
}

export type GymListFilters = {
  page?: number;
  pageSize?: number;
  category?: string;
  tier?: string;
  audience?: string;
  q?: string;
};

export async function listGyms(
  filtersOrPage: GymListFilters | number = 1,
  pageSize = 20,
): Promise<Page<GymRead>> {
  // Back-compat: callers passing positional (page, pageSize) still
  // work. New callers pass a filter bag so server-side pagination +
  // filtering compose cleanly without a 100-row client-side dance.
  const filters: GymListFilters =
    typeof filtersOrPage === "number"
      ? { page: filtersOrPage, pageSize }
      : filtersOrPage;
  const qs = new URLSearchParams();
  qs.set("page", String(filters.page ?? 1));
  qs.set("pageSize", String(filters.pageSize ?? 20));
  if (filters.category) qs.set("category", filters.category);
  if (filters.tier) qs.set("tier", filters.tier);
  if (filters.audience) qs.set("audience", filters.audience);
  if (filters.q) qs.set("q", filters.q);
  return api(`/api/v1/admin/gyms?${qs.toString()}`, {
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
  return uploadFormData(`/api/v1/admin/gyms/${gymId}/photos`, formData);
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
  return `${serverEnv.API_BASE_URL}${url}`;
}

export async function uploadGymLogo(
  gymId: string,
  formData: FormData,
): Promise<GymRead> {
  return uploadFormData(`/api/v1/admin/gyms/${gymId}/logo`, formData);
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
