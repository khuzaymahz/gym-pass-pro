import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { NextIntlClientProvider } from "next-intl";
import { getLocale, getMessages } from "next-intl/server";
import { cookies } from "next/headers";
import type { ReactNode } from "react";

import { themeBootScript } from "@/components/ThemeToggle";
import "@/styles/globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "GymPass · Admin",
  description: "Internal console for GymPass.",
};

export default async function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  const locale = await getLocale();
  const messages = await getMessages();
  const dir = locale === "ar" ? "rtl" : "ltr";
  // Read the theme cookie server-side so the SSR'd `<html>` already
  // has the right `data-theme` attribute. The inline script below
  // is the second line of defense for soft navigations and
  // first-time visitors who haven't set the cookie yet.
  const cookieStore = await cookies();
  const theme = cookieStore.get("theme")?.value === "light" ? "light" : "dark";

  return (
    <html
      lang={locale}
      dir={dir}
      className={inter.variable}
      data-theme={theme}
      suppressHydrationWarning
    >
      <head>
        {/* FOUC blocker: re-applies the cookie value before any
            stylesheet is parsed, in case a CDN cached the page
            with a stale `data-theme`. */}
        <script
          dangerouslySetInnerHTML={{ __html: themeBootScript }}
        />
      </head>
      <body className="font-sans antialiased">
        <NextIntlClientProvider locale={locale} messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
