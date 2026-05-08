import type { DefaultSession } from "next-auth";

declare module "next-auth" {
  interface Session {
    serviceToken?: string;
    serviceExpiresAt?: string;
    partnerId?: string;
    phone?: string;
    gymId?: string;
    user?: DefaultSession["user"];
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    serviceToken?: string;
    serviceExpiresAt?: string;
    partnerId?: string;
    phone?: string;
    gymId?: string;
    /** True when the operator ticked "remember me" at sign-in. Drives
     *  per-session cookie/token lifetime — short (8 h) when false,
     *  long (30 d) when true. Stored on the token, not the session,
     *  so the jwt callback can gate the manually-set `exp`. */
    rememberMe?: boolean;
  }
}
