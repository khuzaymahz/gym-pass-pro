"use server";

import { revalidatePath } from "next/cache";
import { cookies } from "next/headers";

import { BRANCH_COOKIE } from "@/lib/branch";

/// Switch the active branch. Sets the cookie then revalidates the whole
/// dashboard layout so every server component re-fetches scoped to the new
/// branch. Validation of *access* lives in the backend (`selected_gym`);
/// here we only persist the choice.
export async function selectBranch(formData: FormData): Promise<void> {
  const gymId = String(formData.get("gymId") ?? "").trim();
  const jar = await cookies();
  if (gymId) {
    jar.set(BRANCH_COOKIE, gymId, {
      httpOnly: true,
      sameSite: "lax",
      path: "/",
      maxAge: 60 * 60 * 24 * 30,
    });
  } else {
    jar.delete(BRANCH_COOKIE);
  }
  revalidatePath("/", "layout");
}
