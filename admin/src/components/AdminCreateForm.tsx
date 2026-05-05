"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";
import type { AdminCreateBody, AdminUser } from "@/lib/sdk";

type Props = {
  action: (data: AdminCreateBody) => Promise<ActionResult<AdminUser>>;
};

export default function AdminCreateForm({ action }: Props) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");

  function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    startTransition(async () => {
      const result = await action({ email, name, password });
      if (result.ok) {
        setEmail("");
        setName("");
        setPassword("");
        router.refresh();
      } else {
        setError(result.message);
      }
    });
  }

  return (
    <form
      onSubmit={onSubmit}
      className="flex flex-wrap items-end gap-2 rounded-lg border border-line bg-surface p-3"
    >
      <label className="field">
        <span className="field-label">Email</span>
        <input
          className="input input-sm w-56"
          type="email"
          required
          placeholder="name@domain"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
      </label>
      <label className="field">
        <span className="field-label">Full name</span>
        <input
          className="input input-sm w-52"
          required
          placeholder="First Last"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
      </label>
      <label className="field">
        <span className="field-label">Password</span>
        <input
          className="input input-sm w-52"
          type="password"
          required
          minLength={8}
          placeholder="≥ 8 chars"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </label>
      <button className="btn-primary btn-sm" disabled={pending}>
        {pending ? "Creating…" : "Create admin"}
      </button>
      {error ? (
        <span className="w-full text-[12px] text-red-300">{error}</span>
      ) : null}
    </form>
  );
}
