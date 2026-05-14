import { cookies, headers } from "next/headers";
import { getRequestConfig } from "next-intl/server";

import { LOCALE_COOKIE, defaultLocale, isLocale, type Locale } from "./config";

// Re-export so callers importing from this module keep working.
export { LOCALE_COOKIE };

async function resolveLocale(): Promise<Locale> {
  const cookie = (await cookies()).get(LOCALE_COOKIE)?.value;
  if (isLocale(cookie)) return cookie;

  const accept = (await headers()).get("accept-language") ?? "";
  if (/^\s*ar\b/i.test(accept)) return "ar";
  if (/^\s*en\b/i.test(accept)) return "en";
  return defaultLocale;
}

export default getRequestConfig(async () => {
  const locale = await resolveLocale();
  const messages = (await import(`../../messages/${locale}.json`)).default;
  return { locale, messages };
});
