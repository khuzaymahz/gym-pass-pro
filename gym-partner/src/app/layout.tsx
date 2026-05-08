import type { Metadata } from "next";
import { Archivo, Inter } from "next/font/google";
import { NextIntlClientProvider } from "next-intl";
import { getLocale, getMessages, getTranslations } from "next-intl/server";
import type { ReactNode } from "react";

import "@/styles/globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

// Archivo Black Italic for the GYMPASS wordmark only — mirrors the
// mobile app's brand mark (`mobile/lib/core/widgets/wordmark.dart`).
// The operator-tool register is "one font for body" (CLAUDE.md
// memory) but the brand wordmark is a logo, not body copy, so a
// distinct face is correct here. Loaded once via next/font so the
// FOUT is bounded and the file is self-hosted (no runtime
// google-fonts call from the browser at request time).
const archivo = Archivo({
  subsets: ["latin"],
  weight: ["900"],
  style: ["italic"],
  variable: "--font-display",
  display: "swap",
});

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("app");
  return {
    title: t("title"),
    description: t("subtitle"),
  };
}

export default async function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  const locale = await getLocale();
  const messages = await getMessages();
  const dir = locale === "ar" ? "rtl" : "ltr";

  return (
    <html
      lang={locale}
      dir={dir}
      className={`${inter.variable} ${archivo.variable}`}
      // `data-theme` defaults to "dark" for first paint so the page
      // never flashes the wrong mode. The blocking inline script in
      // <head> below replaces it with the user's saved choice
      // *before* hydration so a returning member who picked light
      // mode never sees a dark-then-light flash.
      data-theme="dark"
      suppressHydrationWarning
    >
      <head>
        {/*
          Theme-flash guard. Read the saved preference (or the OS
          one) synchronously and apply it to <html> before the body
          paints. Has to be a string-literal `<script>` because
          Next/RSC otherwise defers it past the first paint, which
          re-introduces the flash. Falls back to "dark" silently if
          localStorage / matchMedia throws (private modes, server
          environments, etc.).
        */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(()=>{try{var s=localStorage.getItem("gp.theme");if(s==="light"||s==="dark"){document.documentElement.setAttribute("data-theme",s);return;}var m=window.matchMedia&&window.matchMedia("(prefers-color-scheme: light)").matches;document.documentElement.setAttribute("data-theme",m?"light":"dark");}catch(_){/* keep ssr default */}})();`,
          }}
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
