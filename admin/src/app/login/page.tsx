"use client";

import { signIn } from "next-auth/react";
import { useTranslations } from "next-intl";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

function LoginForm() {
  const router = useRouter();
  const search = useSearchParams();
  const t = useTranslations("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    const result = await signIn("credentials", {
      email,
      password,
      redirect: false,
    });
    setLoading(false);
    if (result?.ok) {
      const callback = search.get("callbackUrl") ?? "/";
      router.push(callback);
    } else {
      // `authorize` throws "TOO_MANY_ATTEMPTS" on a 429 (login limiter or
      // service-token exchange); everything else is a real credential
      // failure. Don't blame the password when the user is just throttled.
      setError(
        result?.error === "TOO_MANY_ATTEMPTS"
          ? t("tooManyAttempts")
          : t("invalid"),
      );
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3">
      <label className="field">
        <span className="field-label">{t("email")}</span>
        <input
          className="input input-sm"
          type="email"
          required
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
      </label>
      <label className="field">
        <span className="field-label">{t("password")}</span>
        <input
          className="input input-sm"
          type="password"
          required
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>

      {error ? <p className="text-[12px] text-red-300">{error}</p> : null}

      <button
        type="submit"
        className="btn-primary btn-sm mt-1 w-full justify-center"
        disabled={loading}
      >
        {loading ? t("submitting") : t("submit")}
      </button>
    </form>
  );
}

export default function LoginPage() {
  // Server component would be ideal but next-intl `getTranslations`
  // forces async + the form needs onSubmit; keeping the page as a
  // small client wrapper keeps the boundary tight.
  return (
    <LoginShell>
      <Suspense fallback={null}>
        <LoginForm />
      </Suspense>
    </LoginShell>
  );
}

function LoginShell({ children }: { children: React.ReactNode }) {
  const t = useTranslations("login");
  const tBrand = useTranslations("brand");
  return (
    <main className="flex min-h-screen items-center justify-center bg-ink p-6 text-paper">
      <div className="w-full max-w-sm">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <p className="label">{tBrand("name")} · Console</p>
            <h1 className="mt-1 h2">{t("title")}</h1>
          </div>
          <span className="kbd">{t("subtitle")}</span>
        </div>
        <div className="panel p-5">{children}</div>
        <p className="mt-3 text-[11px] text-muted">{t("footer")}</p>
      </div>
    </main>
  );
}
