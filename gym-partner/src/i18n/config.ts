export const locales = ["ar", "en"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "ar";

// Cookie key the server-side i18n loader reads. Exported here (not
// just in `request.ts`) so client-side code can set the cookie
// directly without going through a Server Action — see
// `LocaleToggle` for why that matters in dev mode.
export const LOCALE_COOKIE = "partner_locale";

export function isLocale(value: string | undefined): value is Locale {
  return value === "ar" || value === "en";
}
