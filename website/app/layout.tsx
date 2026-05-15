import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';

// All real chrome lives inside `public/register-flow.html` — the page
// renders as a self-contained HTML document complete with its own
// fonts, styles, and scripts. This Next.js layout exists only so the
// route segment that catches direct hits to anything other than
// `/` (e.g. `/foo`) doesn't blow up with a missing-layout error.
export const metadata: Metadata = {
  title: 'GymPass — One subscription. Every gym.',
  description:
    'One subscription, every partner gym in Jordan. Sign in by phone, pick a tier, scan a static QR at the door. No card. No contract. No kiosk.',
  metadataBase: new URL('https://gym-pass.net'),
  openGraph: {
    title: 'GymPass — One subscription. Every gym.',
    description:
      'One subscription, every partner gym in Jordan. Sign in by phone, pick a tier, scan a static QR at the door.',
    url: 'https://gym-pass.net',
    siteName: 'GymPass',
    locale: 'en_JO',
    type: 'website',
  },
  icons: {
    icon: '/favicon.svg',
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: dark)', color: '#0A0B0A' },
    { media: '(prefers-color-scheme: light)', color: '#FAFAF9' },
  ],
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
