"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";

import { isLocale, type Locale } from "./config";
import { LOCALE_COOKIE } from "./request";

export async function setLocale(next: Locale): Promise<void> {
  if (!isLocale(next)) return;
  const store = await cookies();
  store.set(LOCALE_COOKIE, next, {
    path: "/",
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 365,
  });
  revalidatePath("/", "layout");
}
