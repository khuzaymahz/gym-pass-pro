import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

import { api, exchangeAdminToken } from "@/lib/api";
import { env } from "@/lib/env";

type LoginResp = { id: string; email: string; name: string | null; role: string };

export const authOptions: NextAuthOptions = {
  session: { strategy: "jwt", maxAge: 60 * 60 * 4 },
  secret: env.NEXTAUTH_SECRET,
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
        } catch {
          return null;
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
        } catch {
          // Backend got worse between authorize() and here. Drop identity
          // bits so dashboardLayout's session check redirects to /login.
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
          } catch {
            // leave stale token; request-layer will surface auth error
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
