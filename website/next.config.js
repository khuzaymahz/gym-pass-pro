/**
 * Marketing site — serves the Claude-Design `RegisterFlow` prototype
 * verbatim from `public/register-flow.html`. The page is fully
 * self-contained (inline CSS + JS, fonts from Google CDN, scroll
 * behaviour from a single IIFE), so there is no benefit to
 * decomposing it into React components — match the visual output
 * pixel-for-pixel by serving the source HTML.
 *
 * The rewrite below is what makes `/` resolve to the prototype.
 * `public/register-flow.html` would otherwise only be reachable at
 * `/register-flow.html`, which is ugly and breaks share links. By
 * rewriting at the framework level (not redirecting), the URL stays
 * `https://gym-pass.net/` while the served bytes come from the
 * static asset. Hits to `/register-flow.html` directly still work
 * for cache-busting and previews.
 *
 * The APK download lives at `/downloads/gympass.apk` and is dropped
 * into `public/downloads/` by `scripts/build-apk.sh`. Next.js
 * serves it as a static asset; nginx then adds the
 * Content-Disposition: attachment header in front of it so mobile
 * browsers offer "Install" instead of trying to render bytes.
 *
 * Security headers are duplicated here for belt-and-braces; nginx
 * also adds them at the edge. Doing both means the headers survive
 * a direct hit to the Next.js container during dev / debugging.
 */
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=()',
  },
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Speed up production image: bundles the runtime so the runner
  // stage can drop node_modules entirely. See Dockerfile.
  output: 'standalone',
  async rewrites() {
    return [
      { source: '/', destination: '/register-flow.html' },
    ];
  },
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders,
      },
    ];
  },
};

module.exports = nextConfig;
