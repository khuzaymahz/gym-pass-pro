const createNextIntlPlugin = require("next-intl/plugin");

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

// Security headers applied to every response. Kept minimal — the partner
// portal renders a small set of routes and never embeds third-party
// origins, so a tight CSP is feasible. HSTS is on a 2-year max-age with
// preload eligibility; switch to a shorter window during the first
// production rollout if cert renewals are still being shaken out.
const securityHeaders = [
  // Force browsers onto HTTPS for two years and refuse mixed content.
  // `includeSubDomains` is safe because the partner portal lives on
  // its own subdomain that already serves HTTPS exclusively.
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  // Disallow framing entirely — the portal has no embed surface, so
  // a strict policy is preferable to the looser SAMEORIGIN.
  { key: "X-Frame-Options", value: "DENY" },
  // Stop content-type sniffing attacks.
  { key: "X-Content-Type-Options", value: "nosniff" },
  // Don't leak the full referrer to cross-origin requests (e.g. media
  // CDN, analytics). `strict-origin-when-cross-origin` is the modern
  // sweet spot — same-origin gets the full URL, cross-origin gets the
  // origin only on HTTPS→HTTPS, nothing on HTTPS→HTTP.
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  // Disable browser features the portal never asks for. Keeps a
  // compromised page from accessing geolocation / camera / mic on
  // behalf of the partner.
  {
    key: "Permissions-Policy",
    value: [
      "accelerometer=()",
      "camera=()",
      "geolocation=()",
      "gyroscope=()",
      "magnetometer=()",
      "microphone=()",
      "payment=()",
      "usb=()",
    ].join(", "),
  },
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: "standalone",
  poweredByHeader: false,
  experimental: {
    typedRoutes: false,
    // Next's default server-action body limit is 1 MB. Any photo
    // off a modern phone camera is 3-8 MB, so the upload action
    // was silently 413-ing before the bytes ever reached the
    // backend — partners saw "Upload failed." with no concrete
    // cause. Match the backend's `settings.max_upload_mb` (10 MB)
    // so the canonical rejection surface is the backend's image
    // validation, not Next's transparent body cap.
    serverActions: {
      bodySizeLimit: "10mb",
    },
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: securityHeaders,
      },
    ];
  },
};

module.exports = withNextIntl(nextConfig);
