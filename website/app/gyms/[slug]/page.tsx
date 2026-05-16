import { notFound } from "next/navigation";
import type { Metadata } from "next";

import OpenInApp from "./OpenInApp";

// Server-rendered gym landing for shared links.
//
// Why this page exists: a member taps "Share" on a gym profile in
// the app, and the OS share sheet hands the receiver a URL like
// `https://gym-pass.net/gyms/iron-forge`. The receiver may or may
// not have the app installed:
//   - If they do: this page's client component (`OpenInApp`) fires
//     the `gympass://gyms/<slug>` custom-scheme URL on mount, the
//     OS routes them into the GymPass app on the matching gym, and
//     the page they're looking at briefly flashes then goes away.
//   - If they don't: nothing handles the custom scheme, this page
//     stays put, and the receiver sees the gym preview + the APK
//     download CTA + a fallback "view on the web" experience.
//
// The page is server-rendered so the URL has real OG tags (the
// share sheet handoff to WhatsApp / Messages shows a preview card
// with the gym name + photo). The backend fetch uses
// `force-cache` so a single gym page is shared at most once per
// revalidate window — the data isn't time-sensitive.

type GymSummary = {
  slug: string;
  name_en?: string;
  name_ar?: string;
  nameEn?: string;
  nameAr?: string;
  logo_url?: string | null;
  logoUrl?: string | null;
  area?: string | null;
  category?: string | null;
};

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://api.gym-pass.net";
const APK_URL = "/downloads/gympass.apk";

async function fetchGym(slug: string): Promise<GymSummary | null> {
  try {
    const res = await fetch(`${API_BASE}/api/v1/gyms/by-slug/${encodeURIComponent(slug)}`, {
      next: { revalidate: 600 },
    });
    if (!res.ok) return null;
    return (await res.json()) as GymSummary;
  } catch {
    return null;
  }
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const gym = await fetchGym(slug);
  const displayName = gym?.name_en || gym?.nameEn || gym?.name_ar || gym?.nameAr || "Gym";
  const title = `${displayName} · GymPass`;
  const description =
    "Open this gym in GymPass — one subscription, every gym in the network.";
  return {
    title,
    description,
    openGraph: {
      title,
      description,
      url: `https://gym-pass.net/gyms/${slug}`,
      type: "website",
    },
  };
}

export default async function GymLandingPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const gym = await fetchGym(slug);
  if (!gym) {
    notFound();
  }

  const displayName =
    gym.name_en || gym.nameEn || gym.name_ar || gym.nameAr || "Gym";
  const logoUrl = gym.logo_url || gym.logoUrl || null;
  const area = gym.area ?? "";

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        padding: "32px 24px",
        background: "#0A0B0A",
        color: "#F5F3EC",
        fontFamily:
          "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
      }}
    >
      <OpenInApp slug={slug} />
      <div
        style={{
          maxWidth: 420,
          width: "100%",
          textAlign: "center",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 18,
        }}
      >
        {logoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={logoUrl.startsWith("http") ? logoUrl : `${API_BASE}${logoUrl}`}
            alt=""
            width={88}
            height={88}
            style={{
              width: 88,
              height: 88,
              borderRadius: 88,
              objectFit: "cover",
              border: "1px solid rgba(245,243,236,0.18)",
            }}
          />
        ) : null}
        <div
          style={{
            fontSize: 11,
            letterSpacing: 1.6,
            color: "rgba(245,243,236,0.55)",
            fontFamily:
              "'JetBrains Mono', ui-monospace, SFMono-Regular, monospace",
            textTransform: "uppercase",
          }}
        >
          GymPass · {area}
        </div>
        <h1
          style={{
            fontSize: 36,
            fontWeight: 800,
            margin: 0,
            letterSpacing: -0.5,
          }}
        >
          {displayName}
        </h1>
        <p
          style={{
            fontSize: 15,
            lineHeight: 1.55,
            color: "rgba(245,243,236,0.72)",
            margin: 0,
          }}
        >
          To check in here, sign in to GymPass and pick this gym from the
          network. One subscription. Every gym.
        </p>
        <a
          href={APK_URL}
          style={{
            marginTop: 12,
            display: "inline-block",
            padding: "14px 24px",
            borderRadius: 999,
            background: "#D4FF3F",
            color: "#0A0B0A",
            fontWeight: 800,
            fontSize: 14,
            letterSpacing: 0.4,
            textDecoration: "none",
          }}
        >
          GET THE APP
        </a>
        <a
          href={`gympass://gyms/${slug}`}
          style={{
            fontSize: 13,
            color: "rgba(245,243,236,0.6)",
            textDecoration: "none",
            borderBottom: "1px solid rgba(245,243,236,0.25)",
            paddingBottom: 2,
          }}
        >
          I already have the app
        </a>
      </div>
    </main>
  );
}
