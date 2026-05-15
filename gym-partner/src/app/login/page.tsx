"use client";

import { signIn } from "next-auth/react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Suspense, useState } from "react";

import { LocaleToggle } from "@/components/LocaleToggle";
import { ThemeToggle } from "@/components/ThemeToggle";
import { Wordmark } from "@/components/Wordmark";

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
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    const result = await signIn("credentials", {
      phone: normalizePhone(phone),
      password,
      // String, not boolean — NextAuth's credentials shape is
      // string-only. The `authorize()` callback compares against
      // the literal "true" to flip the flag.
      rememberMe: rememberMe ? "true" : "false",
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
        <div className="relative">
          <input
            className="input input-sm w-full pe-9"
            // Flip between password (masked) and text (visible)
            // based on the eye toggle. autoComplete stays
            // current-password so password managers still work.
            type={showPassword ? "text" : "password"}
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <button
            type="button"
            // `onMouseDown` (not click) with preventDefault stops
            // the input from losing focus when the eye is tapped —
            // the user keeps typing without an annoying cursor
            // blink. Click is the canonical activation, retained
            // for keyboard / a11y.
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => setShowPassword((v) => !v)}
            // `end-2` so the icon flips to the start side under RTL.
            className="absolute end-2 top-1/2 inline-flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-md text-muted transition-colors hover:bg-line/40 hover:text-paper focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
            aria-label={
              showPassword ? t("passwordHide") : t("passwordShow")
            }
            title={showPassword ? t("passwordHide") : t("passwordShow")}
            aria-pressed={showPassword}
          >
            {showPassword ? (
              // eye-off — currently visible, tapping hides it
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.75"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden
              >
                <path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
                <path d="M9.9 4.24A10.93 10.93 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
                <path d="M14.12 14.12a3 3 0 1 1-4.24-4.24" />
                <line x1="1" y1="1" x2="23" y2="23" />
              </svg>
            ) : (
              // eye — currently hidden, tapping reveals it
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.75"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden
              >
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
            )}
          </button>
        </div>
      </label>
      {/* Remember-me — defaults to ON because partner operators are
          on-site at their gym, not on a public kiosk; staying
          logged in for 30 days matches their workflow. Off keeps
          the session at 8 hours, the safer default for shared
          devices. */}
      <label className="flex cursor-pointer items-center gap-2 select-none">
        <input
          type="checkbox"
          checked={rememberMe}
          onChange={(e) => setRememberMe(e.target.checked)}
          className="h-4 w-4 cursor-pointer rounded border-line bg-surface text-accent accent-accent focus-visible:ring-2 focus-visible:ring-accent/40"
        />
        <span className="text-[12.5px] text-paper">{t("rememberMe")}</span>
        <span className="text-[11px] text-muted">
          {t("rememberMeHint")}
        </span>
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
    <main className="relative flex min-h-screen items-center justify-center bg-ink p-6 text-paper">
      {/* Logo locked to the top-left physical corner. `left-6`
          (not `start-6`) so the wordmark sits in the same screen
          position whether the locale is LTR or RTL — the operator
          who toggles to Arabic should see the brand mark in the
          same place, not flipped to the right. The Wordmark itself
          is `dir="ltr"` internally so the letters never reorder. */}
      <div className="absolute left-6 top-6 z-10">
        <Wordmark size={28} />
      </div>
      {/* Locale + theme toggles pinned top-right in screen space.
          `right-6` (not `end-6`) so the cluster stays put across
          RTL. `dir="ltr"` on the wrapper keeps the two buttons in
          the same internal order (locale, then theme) regardless
          of the page's writing direction — without it, RTL flex
          would render theme-then-locale and the operator would see
          the buttons swap positions when toggling to Arabic. */}
      <div
        dir="ltr"
        className="absolute right-6 top-6 z-10 flex items-center gap-2"
      >
        <LocaleToggle />
        <ThemeToggle />
      </div>
      <div className="w-full max-w-sm">
        <div className="mb-5 flex items-end justify-between">
          <div className="flex flex-col gap-2">
            <p className="label">{tApp("title")}</p>
            <h1 className="mt-1 h2">{t("title")}</h1>
          </div>
          <span className="kbd">partner</span>
        </div>
        <Suspense fallback={null}>
          <SessionExpiredNotice />
        </Suspense>
        <div className="panel p-5">
          <Suspense fallback={null}>
            <LoginForm />
          </Suspense>
        </div>
        <p className="mt-3 text-[11px] text-muted">{t("footer")}</p>
        <p className="mt-2 text-[11px] leading-relaxed text-muted">
          {t("consentPrefix")}{" "}
          <Link
            href="/legal/terms"
            className="text-paper underline decoration-line/60 underline-offset-2 hover:text-accent"
          >
            {t("consentLinkTerms")}
          </Link>{" "}
          {t("consentAnd")}{" "}
          <Link
            href="/legal/privacy"
            className="text-paper underline decoration-line/60 underline-offset-2 hover:text-accent"
          >
            {t("consentLinkPrivacy")}
          </Link>
          .
        </p>
      </div>
    </main>
  );
}

/// Banner shown when the dashboard's `api()` helper redirected us
/// here with `?reason=session_expired`. The gym owner sees a clear,
/// blame-free explanation instead of bouncing to /login with no
/// context. Reads `useSearchParams` so it's wrapped in <Suspense> at
/// the parent — Next.js requires that for any client component that
/// reads search params during static prerender.
function SessionExpiredNotice() {
  const t = useTranslations("auth");
  const search = useSearchParams();
  if (search.get("reason") !== "session_expired") return null;
  return (
    <div
      role="status"
      className="mb-3 rounded-md border border-line-2 bg-surface px-3 py-2 text-[12px] text-paper"
    >
      {t("sessionExpired")}
    </div>
  );
}
