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

export const authOptions: NextAuthOptions = {
  session: { strategy: "jwt", maxAge: 60 * 60 * 8 },
  secret: env.NEXTAUTH_SECRET,
  providers: [
    CredentialsProvider({
      name: "Partner Credentials",
      credentials: {
        phone: { label: "Phone", type: "tel" },
        password: { label: "Password", type: "password" },
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
          });
          // Pre-flight the service-token exchange. If it fails here,
          // NextAuth treats credentials as invalid so the user lands
          // back on /login instead of a session that 401s on every
          // request.
          await exchangePartnerToken(u.phone);
          // We attach phone + gymId to the User object so the jwt
          // callback can persist them onto the JWT below. Cast as
          // unknown to satisfy NextAuth's narrow User type; our
          // module augmentation in `types/next-auth.d.ts` declares
          // them as first-class fields.
          return {
            id: u.id,
            name: u.name ?? "Gym partner",
            phone: u.phone,
            gymId: u.gymId,
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
        };
        token.partnerId = u.id;
        token.phone = u.phone;
        token.gymId = u.gymId;
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
      // Subsequent calls: refresh service token when it's about to
      // expire (≤60s window) so requests don't fail mid-render.
      if (token.phone && token.serviceExpiresAt) {
        const expiresAtMs = Date.parse(token.serviceExpiresAt);
        if (Number.isFinite(expiresAtMs) && expiresAtMs - Date.now() < 60_000) {
          try {
            const svc = await exchangePartnerToken(token.phone);
            token.serviceToken = svc.token;
            token.serviceExpiresAt = svc.expiresAt;
          } catch {
            // Transient failure — leave stale token; request layer
            // surfaces the auth error.
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
