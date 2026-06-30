"use client";

import { useTranslations } from "next-intl";
import { useRef } from "react";

import { selectBranch } from "@/app/(dashboard)/branch-actions";
import type { PartnerGymRef } from "@/lib/sdk-types";

/// Branch picker for chain owners. A single-gym partner has nothing to
/// switch, so it renders nothing — the common case stays untouched. On
/// change it submits the `selectBranch` server action, which sets the
/// branch cookie and revalidates the dashboard so every page re-scopes.
export function BranchSwitcher({
  branches,
  currentId,
}: {
  branches: PartnerGymRef[];
  currentId?: string;
}) {
  const t = useTranslations("branch");
  const formRef = useRef<HTMLFormElement>(null);

  if (branches.length <= 1) return null;

  // Fall back to the first branch if the cookie points at one the partner
  // can no longer see (revoked access) — keeps the control consistent
  // with what the backend would resolve.
  const selected =
    currentId && branches.some((b) => b.id === currentId)
      ? currentId
      : branches[0].id;

  return (
    <form action={selectBranch} ref={formRef}>
      <label htmlFor="gp-branch" className="sr-only">
        {t("switchAria")}
      </label>
      <div className="relative">
        <select
          id="gp-branch"
          name="gymId"
          defaultValue={selected}
          onChange={() => formRef.current?.requestSubmit()}
          aria-label={t("switchAria")}
          className="w-full appearance-none rounded-md border border-line bg-ink px-3 py-2 pe-8 text-[13px] font-medium text-paper focus:border-paper focus:outline-none"
        >
          {branches.map((b) => (
            <option key={b.id} value={b.id}>
              {b.nameEn}
            </option>
          ))}
        </select>
        <span
          className="pointer-events-none absolute inset-y-0 end-2.5 flex items-center text-muted"
          aria-hidden
        >
          ▾
        </span>
      </div>
    </form>
  );
}
