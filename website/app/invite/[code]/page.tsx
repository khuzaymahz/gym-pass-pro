import type { Metadata } from "next";

import OpenInApp from "./OpenInApp";

// Server-rendered referral landing for shared invite links.
//
// Same pattern as `/gyms/[slug]`: a member shares
// `https://gym-pass.net/invite/GP-ABC123`. On open the client
// component fires `gympass://invite/<code>` to hand off into the
// app's claim flow (where the code arrives pre-filled but is NOT
// auto-claimed — the friend still taps Claim consciously). When
// the app isn't installed, the page below shows the install CTA
// + the code so the friend can either install + paste, or just
// note the code for later.

const APK_URL = "/downloads/gympass.apk";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ code: string }>;
}): Promise<Metadata> {
  const { code } = await params;
  const title = "GymPass invite";
  const description =
    "A friend invited you to GymPass. Install the app, sign in, and we'll credit them when you subscribe.";
  return {
    title,
    description,
    openGraph: {
      title,
      description,
      url: `https://gym-pass.net/invite/${code}`,
      type: "website",
    },
  };
}

export default async function InviteLandingPage({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code } = await params;
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
      <OpenInApp code={code} />
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
          GymPass · invite
        </div>
        <h1
          style={{
            fontSize: 36,
            fontWeight: 800,
            margin: 0,
            letterSpacing: -0.5,
          }}
        >
          You&apos;ve been invited.
        </h1>
        <p
          style={{
            fontSize: 15,
            lineHeight: 1.55,
            color: "rgba(245,243,236,0.72)",
            margin: 0,
          }}
        >
          Install GymPass and enter the code below so your friend gets
          credit when you subscribe.
        </p>
        <div
          style={{
            padding: "12px 18px",
            borderRadius: 12,
            border: "1px solid rgba(212,255,63,0.45)",
            background: "rgba(212,255,63,0.10)",
            color: "#D4FF3F",
            fontSize: 18,
            fontWeight: 800,
            letterSpacing: 1.2,
            fontFamily:
              "'JetBrains Mono', ui-monospace, SFMono-Regular, monospace",
          }}
        >
          {code}
        </div>
        <a
          href={APK_URL}
          style={{
            marginTop: 4,
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
          href={`gympass://invite/${encodeURIComponent(code)}`}
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
