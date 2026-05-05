"use client";

import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

function LoginForm() {
  const router = useRouter();
  const search = useSearchParams();
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
      setError("Credentials not recognised.");
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-3">
      <label className="field">
        <span className="field-label">Email</span>
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
        <span className="field-label">Password</span>
        <input
          className="input input-sm"
          type="password"
          required
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>

      {error ? (
        <p className="text-[12px] text-red-300">{error}</p>
      ) : null}

      <button
        type="submit"
        className="btn-primary btn-sm mt-1 w-full justify-center"
        disabled={loading}
      >
        {loading ? "Signing in…" : "Continue"}
      </button>

      <p className="mt-1 text-[11px] text-muted">
        NextAuth · service-token exchange
      </p>
    </form>
  );
}

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-ink p-6 text-paper">
      <div className="w-full max-w-sm">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <p className="label">GymPass · Console</p>
            <h1 className="mt-1 h2">Sign in</h1>
          </div>
          <span className="kbd">staff</span>
        </div>
        <div className="panel p-5">
          <Suspense fallback={null}>
            <LoginForm />
          </Suspense>
        </div>
        <p className="mt-3 text-[11px] text-muted">
          Members use the mobile app. This console is staff-only.
        </p>
      </div>
    </main>
  );
}
