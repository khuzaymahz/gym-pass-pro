import "server-only";

import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

import { api, exchangePartnerToken } from "@/lib/api";
import { serverEnv } from "@/lib/env.server";

type LoginResp = {
  id: string;
  phone: string;
  name: string | null;
  role: string;
  gymId: string;
};

const SHORT_SESSION_SECONDS = 60 * 60 * 8; // 8 hours
const LONG_SESSION_SECONDS = 60 * 60 * 24 * 30; // 30 days

// Module-level coalescer for in-flight service-token exchanges.
// A single dashboard render typically triggers `getServerSession`
// multiple times (server component + nested layout + each child
// route segment) — without coalescing, all of those see the same
// soon-expired token and each fires its own `/auth/partner/exchange`
// call, which used to instantly burn the rate-limit budget and
// surface as "Credentials not recognised" on the next /login.
//
// Keyed by phone so two operators on the same machine don't share
// each other's mint; the value is the in-flight Promise so callers
// converge onto the same fetch and resolve together. Cleared as soon
// as the promise settles (success or failure) — we never want to
// cache a failed mint.
const exchangeInFlight = new Map<
  string,
  Promise<{ token: string; expiresAt: string }>
>();

async function coalescedExchange(
  phone: string,
): Promise<{ token: string; expiresAt: string }> {
  const existing = exchangeInFlight.get(phone);
  if (existing) return existing;
  const p = exchangePartnerToken(phone).finally(() => {
    exchangeInFlight.delete(phone);
  });
  exchangeInFlight.set(phone, p);
  return p;
}

export const authOptions: NextAuthOptions = {
  // `session.maxAge` is the *upper bound* — the actual lifetime per
  // sign-in is gated by `token.exp` we set in the jwt callback,
  // which honours the rememberMe checkbox. Setting maxAge to the
  // long bound here lets us extend sessions when the operator opts
  // in; short-session signins still expire on schedule because we
  // override `token.exp` to a closer timestamp.
  session: { strategy: "jwt", maxAge: LONG_SESSION_SECONDS },
  secret: serverEnv.NEXTAUTH_SECRET,
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
          // The earlier version pre-flighted the service-token exchange
          // here, intending to fail-fast on a misconfigured backend. In
          // practice it doubled the exchange-call cost of every sign-in
          // (this call + the JWT callback's first-leg mint) and made
          // legitimate retries trip the per-phone rate-limit, surfacing
          // as the wildly misleading "Credentials not recognised" on
          // the very next attempt. The JWT callback's first-leg mint
          // catches the same backend failure modes and falls back to a
          // clean /login redirect, so the pre-flight is pure cost.
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
          const svc = await coalescedExchange(u.phone);
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
        const now = Date.now();
        if (Number.isFinite(expiresAtMs) && expiresAtMs - now < 60_000) {
          try {
            const svc = await coalescedExchange(token.phone);
            token.serviceToken = svc.token;
            token.serviceExpiresAt = svc.expiresAt;
          } catch {
            // Refresh failed (rate-limit, network, backend hiccup).
            // Two prior strategies both broke:
            //   (a) "leave the stale token" → next API call 401s
            //       → api.ts redirects to /login?reason=session_expired
            //       → user re-logs in → exchange still rate-limited
            //       → "Credentials not recognised" banner.
            //   (b) "blank the token here" → dashboard layout's
            //       `!session.serviceToken` guard fires /login on the
            //       very next render, same loop as (a) but faster.
            //
            // Correct behaviour: keep whatever token we have if it's
            // still within its actual TTL. The window check above
            // fires at expiresAt-60s; the token is *not yet* expired,
            // just expiring soon. Letting the request use it gives
            // the page a fighting chance, and if the backend really
            // does start 401-ing we'll redirect cleanly via api.ts
            // — but typically the next render after the rate-limit
            // window rolls forward will succeed instead.
            if (Number.isFinite(expiresAtMs) && expiresAtMs <= now) {
              // Already past TTL — only here is blanking the right
              // call (no chance of the existing token working).
              token.serviceToken = undefined;
              token.serviceExpiresAt = undefined;
            }
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
