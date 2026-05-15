# syntax=docker/dockerfile:1.7
#
# Multi-stage build for the GymPass marketing website. The page is
# the Claude-Design `RegisterFlow` prototype served verbatim from
# `public/register-flow.html`, with a Next.js shell so we can keep
# parity with the rest of the stack (admin, gym-partner) and so the
# `/downloads/gympass.apk` static asset rides on the same container.
#
# Stages mirror admin/ and gym-partner/:
#   • base   — node:20-alpine + WORKDIR
#   • deps   — npm-installed dependencies (cacheable layer)
#   • dev    — bind-mounted hot-reload, used by docker-compose.yml
#   • builder — `next build` producing the standalone bundle
#   • runner  — production target (referenced by docker-compose.prod.yml)
#
# `output: 'standalone'` in next.config.js means the runner stage
# only carries the `.next/standalone` bundle + `public/` dir + the
# precomputed static assets — no node_modules, no source tree.
# Image is ~120 MB instead of ~800 MB.

# ---------- base ---------------------------------------------------
FROM node:20-alpine AS base
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# ---------- deps ---------------------------------------------------
FROM base AS deps
COPY package.json package-lock.json ./
# `npm ci` for reproducible builds (matches admin/ and gym-partner/).
# The lockfile is committed; install resolves the exact pinned tree.
RUN npm ci --no-audit --no-fund --loglevel=error

# ---------- dev (referenced by docker-compose.yml, bind-mounted) ----
FROM deps AS dev
COPY . .
EXPOSE 3004
CMD ["npm", "run", "dev"]

# ---------- builder ------------------------------------------------
FROM deps AS builder
COPY . .
RUN npm run build

# ---------- runner (production target referenced by docker-compose.prod.yml) ----
FROM base AS runner
ENV NODE_ENV=production
ENV PORT=3004
ENV HOSTNAME=0.0.0.0

# Drop privileges for the running container — the Next.js process
# doesn't need root, and a compromised renderer process should be
# contained.
RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 nextjs

# `output: 'standalone'` emits a self-contained tree under
# `.next/standalone`. The static asset dir + the public dir need
# to be copied alongside it — they're NOT part of the standalone
# output by design (so a CDN can serve them).
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3004
CMD ["node", "server.js"]
