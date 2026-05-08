import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

import { api, exchangePartnerToken } from "@/lib/api";
import { env } from "@/lib/env";

type LoginResp = {
  id: string;
  phone: string;
  name: string | null;
  role: string;
  gymId: string;
};

const SHORT_SESSION_SECONDS = 60 * 60 * 8; // 8 hours
const LONG_SESSION_SECONDS = 60 * 60 * 24 * 30; // 30 days

export const authOptions: NextAuthOptions = {
  // `session.maxAge` is the *upper bound* — the actual lifetime per
  // sign-in is gated by `token.exp` we set in the jwt callback,
  // which honours the rememberMe checkbox. Setting maxAge to the
  // long bound here lets us extend sessions when the operator opts
  // in; short-session signins still expire on schedule because we
  // override `token.exp` to a closer timestamp.
  session: { strategy: "jwt", maxAge: LONG_SESSION_SECONDS },
  secret: env.NEXTAUTH_SECRET,
  providers: [
    CredentialsProvider({
      name: "Partner Credentials",
      credentials: {
        phone: { label: "Phone", type: "tel" },
        password: { label: "Password", type: "password" },
        // Carried as a string because NextAuth's credentials shape
        // is string-only; we coerce to boolean in `authorize`.
        rememberMe: { label: "Remember me", type: "text" },
      },
      async authorize(credentials) {
        if (!credentials?.phone || !credentials?.password) return null;
        try {
          const u = await api<LoginResp>("/api/v1/auth/partner/login", {
            method: "POST",
            body: JSON.stringify({
              phone: credentials.phone,
              password: credentials.password,
            }),
            // Login endpoint can legitimately return 401 (wrong
            // password). NextAuth handles that path by returning
            // null — we don't want the api helper to redirect to
            // /login from inside /login.
            bypassAuthRedirect: true,
          });
          // Pre-flight the service-token exchange. If it fails here,
          // NextAuth treats credentials as invalid so the user lands
          // back on /login instead of a session that 401s on every
          // request.
          await exchangePartnerToken(u.phone);
          // We attach phone + gymId + the remember-me choice to the
          // User object so the jwt callback can persist them onto
          // the JWT below. Cast as unknown to satisfy NextAuth's
          // narrow User type; our module augmentation in
          // `types/next-auth.d.ts` declares them as first-class
          // fields.
          const rememberMe = credentials.rememberMe === "true";
          return {
            id: u.id,
            name: u.name ?? "Gym partner",
            phone: u.phone,
            gymId: u.gymId,
            rememberMe,
          } as unknown as { id: string; name: string };
        } catch {
          return null;
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        // First leg of sign-in. Persist identity onto the JWT then
        // mint the first service token in the same step so the
        // dashboard's first request has a token to call with.
        const u = user as unknown as {
          id: string;
          phone: string;
          gymId: string;
          rememberMe?: boolean;
        };
        token.partnerId = u.id;
        token.phone = u.phone;
        token.gymId = u.gymId;
        token.rememberMe = !!u.rememberMe;
        // Stamp the per-session expiry. NextAuth checks `token.exp`
        // on every request and invalidates the session when it
        // passes — short-lived (8 h) when the operator left the
        // checkbox off, long-lived (30 d) when they ticked it.
        const lifetimeSec = u.rememberMe
          ? LONG_SESSION_SECONDS
          : SHORT_SESSION_SECONDS;
        token.exp = Math.floor(Date.now() / 1000) + lifetimeSec;
        try {
          const svc = await exchangePartnerToken(u.phone);
          token.serviceToken = svc.token;
          token.serviceExpiresAt = svc.expiresAt;
          return token;
        } catch {
          // Backend got worse between authorize() and here. Drop
          // identity bits so the dashboard's session-check redirects
          // to /login rather than mounting with a half-built session.
          return {} as typeof token;
        }
      }
      // Subsequent calls: refresh the *backend* service token when
      // it's about to expire (≤60 s window) so requests don't fail
      // mid-render. Note this is the 5-min backend hop token, not
      // the NextAuth session — those expire on different clocks.
      if (token.phone && token.serviceExpiresAt) {
        const expiresAtMs = Date.parse(token.serviceExpiresAt);
        if (Number.isFinite(expiresAtMs) && expiresAtMs - Date.now() < 60_000) {
          try {
            const svc = await exchangePartnerToken(token.phone);
            token.serviceToken = svc.token;
            token.serviceExpiresAt = svc.expiresAt;
          } catch {
            // Refresh failed (rate-limit, network, backend hiccup).
            // The previous behaviour was "leave the stale token and
            // let the next request 401" — that produced a phantom
            // "session expired" banner immediately after a fresh
            // sign-in when the rate-limiter happened to be hot.
            // Clear the service token instead so the dashboard
            // layout's `!session.serviceToken` guard fires a clean
            // /login redirect (no banner, no 401 cascade), and the
            // re-login goes through full credentials flow again.
            token.serviceToken = undefined;
            token.serviceExpiresAt = undefined;
          }
        }
      }
      return token;
    },
    async session({ session, token }) {
      session.serviceToken = token.serviceToken;
      session.serviceExpiresAt = token.serviceExpiresAt;
      session.partnerId = token.partnerId;
      session.phone = token.phone;
      session.gymId = token.gymId;
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
};
