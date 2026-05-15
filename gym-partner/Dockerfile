FROM node:20-alpine AS base
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

FROM base AS deps
COPY package.json ./
RUN npm install --no-audit --no-fund --loglevel=error

FROM deps AS dev
COPY . .
EXPOSE 3003
CMD ["npm", "run", "dev"]

FROM deps AS builder
# Build-time env. gym-partner's env.server.ts uses Zod to validate
# required envs at module load; Next.js's "Collecting page data"
# pass imports `/api/auth/[...nextauth]/route.ts`, which loads
# env.server.ts, which throws if these are unset. We accept ARGs so
# `docker-compose.prod.yml` can pass real values from `.env.prod` —
# fall back to dummies long enough to satisfy Zod, since the real
# secrets are re-read from the runtime env in the runner stage.
ARG NEXTAUTH_SECRET=build-only-placeholder-not-shipped-xxxxxxxxxx
ARG ADMIN_EXCHANGE_SECRET=build-only-placeholder-not-shipped-xxxxxxxxxx
ENV NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
ENV ADMIN_EXCHANGE_SECRET=${ADMIN_EXCHANGE_SECRET}
COPY . .
RUN npm run build

FROM base AS runner
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3003
CMD ["node", "server.js"]
