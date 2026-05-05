import type { DefaultSession } from "next-auth";

declare module "next-auth" {
  interface Session {
    serviceToken?: string;
    serviceExpiresAt?: string;
    adminId?: string;
    user?: DefaultSession["user"];
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    serviceToken?: string;
    serviceExpiresAt?: string;
    adminId?: string;
  }
}
