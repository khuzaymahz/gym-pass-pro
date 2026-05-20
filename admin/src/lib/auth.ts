import "server-only";

import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

import { api, ApiError, exchangeAdminToken } from "@/lib/api";
import { serverEnv } from "@/lib/env.server";

type LoginResp = { id: string; email: string; name: string | null; role: string };

export const authOptions: NextAuthOptions = {
  session: { strategy: "jwt", maxAge: 60 * 60 * 4 },
  secret: serverEnv.NEXTAUTH_SECRET,
  providers: [
    CredentialsProvider({
      name: "Admin Credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null;
        try {
          const u = await api<LoginResp>("/api/v1/auth/admin/login", {
            method: "POST",
            body: JSON.stringify({
              email: credentials.email,
              password: credentials.password,
            }),
          });
          // Pre-flight the service-token exchange before completing sign-in.
          // If exchange fails here, NextAuth treats the credentials as
          // invalid and the user lands back on `/login` instead of a
          // session that 401s every page load.
          await exchangeAdminToken(u.email);
          return { id: u.id, email: u.email, name: u.name ?? "Admin" };
        } catch (error) {
          // Bare catch was swallowing 5xx responses and returning the
          // same null as wrong-password — ops couldn't tell the
          // difference. Log the actual error so it shows up in
          // container logs (greppable prefix), and re-throw on 5xx
          // so NextAuth distinguishes infra failure from credentials.
          if (error instanceof ApiError) {
            // 4xx = legitimate auth failure (bad credentials / locked
            // / etc.) — surface as null so the user sees "credentials
            // not recognised" on /login. Still log it so we can
            // correlate with rate-limiter trips.
            // eslint-disable-next-line no-console
            console.error(
              `[admin:auth] login rejected (${error.status} ${error.code}): ${error.message}`,
            );
            if (error.status >= 500) {
              // Backend dead / 500ing. Re-throw so NextAuth surfaces
              // a CallbackRouteError instead of pretending the
              // password was wrong.
              throw error;
            }
            return null;
          }
          // Unknown error class (network reset, JSON parse, etc.) —
          // log and re-throw so it doesn't masquerade as bad creds.
          // eslint-disable-next-line no-console
          console.error("[admin:auth] login failed (unexpected):", error);
          throw error;
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user?.email) {
        try {
          const svc = await exchangeAdminToken(user.email);
          token.serviceToken = svc.token;
          token.serviceExpiresAt = svc.expiresAt;
          token.email = user.email;
          token.adminId = user.id;
          return token;
        } catch (error) {
          // Backend got worse between authorize() and here. Drop identity
          // bits so dashboardLayout's session check redirects to /login.
          // eslint-disable-next-line no-console
          console.error("[admin:auth] jwt exchange failed (initial):", error);
          return {} as typeof token;
        }
      }
      if (token.email && token.serviceExpiresAt) {
        const expiresAtMs = Date.parse(token.serviceExpiresAt);
        if (Number.isFinite(expiresAtMs) && expiresAtMs - Date.now() < 60_000) {
          try {
            const svc = await exchangeAdminToken(token.email);
            token.serviceToken = svc.token;
            token.serviceExpiresAt = svc.expiresAt;
          } catch (error) {
            // leave stale token; request-layer will surface auth error
            // eslint-disable-next-line no-console
            console.error("[admin:auth] jwt exchange failed (refresh):", error);
          }
        }
      }
      return token;
    },
    async session({ session, token }) {
      session.user = {
        ...(session.user ?? {}),
        email: token.email ?? undefined,
      };
      session.serviceToken = token.serviceToken;
      session.serviceExpiresAt = token.serviceExpiresAt;
      session.adminId = token.adminId;
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
};
