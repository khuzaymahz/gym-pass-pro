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

/// Three-way result so the page can distinguish a genuine 404 ("this
/// gym slug doesn't exist") from a transient network failure ("we
/// couldn't reach the backend"). The previous implementation
/// collapsed both into `null`, which meant a brief backend hiccup
/// sent the receiver to a 404 page that falsely claimed their
/// freshly-shared gym link didn't exist.
type GymFetchResult =
  | { kind: "ok"; gym: GymSummary }
  | { kind: "not-found" }
  | { kind: "unavailable" };

async function fetchGym(slug: string): Promise<GymFetchResult> {
  // 8-second cap. Server-rendered pages without a timeout pin a
  // Next.js worker waiting on a stuck upstream — Next won't kill the
  // fetch on its own and a slow backend can quietly take the host
  // out of rotation.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8_000);
  try {
    const res = await fetch(
      `${API_BASE}/api/v1/gyms/by-slug/${encodeURIComponent(slug)}`,
      {
        next: { revalidate: 600 },
        signal: controller.signal,
      },
    );
    if (res.status === 404) return { kind: "not-found" };
    if (!res.ok) return { kind: "unavailable" };
    const gym = (await res.json()) as GymSummary;
    return { kind: "ok", gym };
  } catch {
    // AbortError (timeout) and TypeError ("fetch failed", DNS, etc.)
    // both land here. Treat as transient — render the "couldn't
    // load" panel with a retry, not a 404.
    return { kind: "unavailable" };
  } finally {
    clearTimeout(timer);
  }
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const result = await fetchGym(slug);
  const gym = result.kind === "ok" ? result.gym : null;
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
  const result = await fetchGym(slug);
  if (result.kind === "not-found") {
    notFound();
  }
  if (result.kind === "unavailable") {
    return <Unavailable slug={slug} />;
  }
  const gym = result.gym;

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

/// Rendered when the backend was unreachable. We deliberately do NOT
/// 404 here — falsely telling the receiver that a fresh share link
/// is broken is worse than admitting we're momentarily down. The
/// page still offers the APK download (which is served by the same
/// Next.js host, not the API) so a member who already has the app
/// can hand the receiver a working install path while we recover.
function Unavailable({ slug }: { slug: string }) {
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
          GymPass
        </div>
        <h1
          style={{
            fontSize: 32,
            fontWeight: 800,
            margin: 0,
            letterSpacing: -0.5,
          }}
        >
          Can&apos;t load this gym right now
        </h1>
        <p
          style={{
            fontSize: 15,
            lineHeight: 1.55,
            color: "rgba(245,243,236,0.72)",
            margin: 0,
          }}
        >
          We couldn&apos;t reach the GymPass server. Check your connection
          and try again — the link is still valid.
        </p>
        {/* Plain anchor (no client JS) so the page works even with
            JS disabled. `gyms/<slug>` re-enters the same server
            component, which re-fetches and either succeeds this
            time or re-renders this surface. */}
        <a
          href={`/gyms/${slug}`}
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
          TRY AGAIN
        </a>
        <a
          href={APK_URL}
          style={{
            fontSize: 13,
            color: "rgba(245,243,236,0.6)",
            textDecoration: "none",
            borderBottom: "1px solid rgba(245,243,236,0.25)",
            paddingBottom: 2,
          }}
        >
          Get the app
        </a>
      </div>
    </main>
  );
}
