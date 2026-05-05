import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Gym Pass — one pass, every gym in Jordan",
  description:
    "A single subscription. Four tiers. Thousands of check-ins. Gym Pass stitches Jordan's gyms into one network so you never pay two gyms again.",
  metadataBase: new URL("https://gym-pass.net"),
  openGraph: {
    title: "Gym Pass — one pass, every gym",
    description:
      "One subscription, every gym in Jordan. Scan, lift, leave.",
    type: "website",
    locale: "en_US",
    siteName: "Gym Pass",
  },
  twitter: { card: "summary_large_image" },
  icons: { icon: "/favicon.svg" },
};

export const viewport: Viewport = {
  themeColor: "#0A0B0A",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="font-body bg-ink text-paper overflow-x-hidden">
        {children}
      </body>
    </html>
  );
}
