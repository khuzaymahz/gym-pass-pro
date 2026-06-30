import "server-only";

import { cookies } from "next/headers";

/// Which branch a multi-branch partner is currently viewing. Stored in a
/// cookie so every server component + SDK call scopes to the same branch
/// without threading it through props. Absent cookie = single-gym partner
/// (or "not chosen yet") → the backend falls back to their primary gym, so
/// nothing breaks for the common one-gym case.
export const BRANCH_COOKIE = "gp_branch";

export async function selectedBranchId(): Promise<string | undefined> {
  return (await cookies()).get(BRANCH_COOKIE)?.value || undefined;
}

/// Header the SDK adds to gym-scoped calls. The backend's `selected_gym`
/// dependency reads `X-Gym-Id`, verifies the caller's membership, and 403s
/// if they don't have access — so a stale cookie can't reach another gym.
export async function branchHeaders(): Promise<Record<string, string>> {
  const id = await selectedBranchId();
  return id ? { "X-Gym-Id": id } : {};
}
