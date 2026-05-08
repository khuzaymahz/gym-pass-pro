"use client";

import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Suspense, useState } from "react";

function normalizePhone(input: string): string {
  // Tolerant inbound shape: members and partners alike commonly type
  // their number as `0791234567` or `791234567`. We canonicalize to
  // E.164 (+9627XXXXXXXX) before sending so the backend regex
  // matches without surprise.
  const digits = input.replace(/\D/g, "");
  if (digits.startsWith("962")) return `+${digits}`;
  if (digits.startsWith("0")) return `+962${digits.slice(1)}`;
  if (digits.length === 9 && digits.startsWith("7")) return `+962${digits}`;
  return input.startsWith("+") ? input : `+${digits}`;
}

function LoginForm() {
  const t = useTranslations("auth");
  const router = useRouter();
  const search = useSearchParams();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    const result = await signIn("credentials", {
      phone: normalizePhone(phone),
      password,
      redirect: false,
    });
    setLoading(false);
    if (result?.ok) {
      const callback = search.get("callbackUrl") ?? "/";
      router.push(callback);
    } else {
      setError(t("invalid"));
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3">
      <label className="field">
        <span className="field-label">{t("phone")}</span>
        <input
          className="input input-sm"
          type="tel"
          required
          autoComplete="tel"
          dir="ltr"
          placeholder={t("phoneHint")}
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
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
  const t = useTranslations("auth");
  const tApp = useTranslations("app");
  return (
    <main className="flex min-h-screen items-center justify-center bg-ink p-6 text-paper">
      <div className="w-full max-w-sm">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <p className="label">{tApp("title")}</p>
            <h1 className="mt-1 h2">{t("title")}</h1>
          </div>
          <span className="kbd">partner</span>
        </div>
        <div className="panel p-5">
          <Suspense fallback={null}>
            <LoginForm />
          </Suspense>
        </div>
        <p className="mt-3 text-[11px] text-muted">{t("footer")}</p>
      </div>
    </main>
  );
}
