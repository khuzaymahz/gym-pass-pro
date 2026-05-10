import "server-only";

import { getServerSession } from "next-auth";

import { api } from "@/lib/api";
import { authOptions } from "@/lib/auth";

export type ReferralPerson = {
  id: string;
  name?: string | null;
  email?: string | null;
  phone?: string | null;
};

export type AdminReferralRead = {
  id: string;
  referrer: ReferralPerson;
  invited: ReferralPerson;
  referralCode: string;
  status: "pending" | "converted";
  createdAt: string;
  convertedAt: string | null;
};

export type Page<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
};

async function token(): Promise<string> {
  const session = await getServerSession(authOptions);
  const t = session?.serviceToken;
  if (!t) throw new Error("No service token on session.");
  return t;
}

/// Paginated list across all referrals. `status` narrows to pending
/// vs converted; default is "everything", sorted newest first.
export async function listReferrals({
  status,
  page = 1,
  pageSize = 20,
}: {
  status?: "pending" | "converted";
  page?: number;
  pageSize?: number;
} = {}): Promise<Page<AdminReferralRead>> {
  const params = new URLSearchParams();
  if (status) params.set("status", status);
  params.set("page", String(page));
  params.set("pageSize", String(pageSize));
  return api(`/api/v1/admin/referrals?${params.toString()}`, {
    token: await token(),
  });
}
