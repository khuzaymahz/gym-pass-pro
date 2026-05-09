const createNextIntlPlugin = require("next-intl/plugin");

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

// Security headers applied to every response. Mirror of the
// gym-partner config — admin runs on its own subdomain with the
// same browser-side defenses. CSP is deliberately *not* set here
// because Next emits inline scripts at runtime and a non-nonce
// CSP would break server components; that goes in a follow-up
// PR with proper nonce plumbing through the layout.
const securityHeaders = [
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  // The admin dashboard has zero embed surface — DENY is correct.
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
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

// next/image needs an explicit allowlist of remote hosts the
// optimizer is allowed to fetch from. Backend serves /media/* under
// these hosts in our environments:
//   - localhost:8000      — host-machine dev
//   - backend:8000        — admin container in docker compose
//   - api.gym-pass.net    — production
// The wildcard line matches the prod domain plus any preview
// subdomains we spin up for staging.
const remoteImagePatterns = [
  { protocol: "http", hostname: "localhost", port: "8000", pathname: "/**" },
  { protocol: "http", hostname: "backend", port: "8000", pathname: "/**" },
  { protocol: "https", hostname: "api.gym-pass.net", pathname: "/**" },
  { protocol: "https", hostname: "*.gym-pass.net", pathname: "/**" },
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: "standalone",
  poweredByHeader: false,
  experimental: {
    typedRoutes: false,
  },
  images: {
    remotePatterns: remoteImagePatterns,
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
