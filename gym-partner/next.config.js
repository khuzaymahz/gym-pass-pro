const createNextIntlPlugin = require("next-intl/plugin");

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: "standalone",
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
};

module.exports = withNextIntl(nextConfig);
