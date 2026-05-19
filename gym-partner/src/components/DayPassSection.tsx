"use client";

import { useTranslations } from "next-intl";
import { useState, useTransition } from "react";

import { saveDayPassOfferingAction } from "@/app/(dashboard)/profile/actions";
import type {
  DayPassOffering,
  DayPassOfferingUpsertBody,
} from "@/lib/sdk-types";
import PendingButton from "@/components/PendingButton";

/**
 * Per-gym day-pass configuration. Renders below the main gym
 * profile form on `/profile`. Self-contained — owns its own save
 * action, error/status pill, and state — so a save here doesn't
 * trigger the main profile form's save and vice versa.
 *
 * The `initial` prop is the partner's currently-saved offering
 * (null when never configured). On first render we render the
 * "off" state; once the partner toggles on, we surface the price
 * input. Net amount preview is computed client-side from the
 * locked platform-fee percentage (10% default, surfaced from the
 * server-side offering when present so a future admin override
 * is reflected without a code change).
 */
const DEFAULT_PLATFORM_FEE_PCT = 10;
const DEFAULT_PRICE_JOD = 8;
const PRICE_MIN = 0;
const PRICE_MAX = 100;

export function DayPassSection({
  initial,
}: {
  initial: DayPassOffering | null;
}) {
  const t = useTranslations("profile");
  const [pending, startTransition] = useTransition();
  const [status, setStatus] = useState<"idle" | "ok" | "err">("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const [isEnabled, setIsEnabled] = useState<boolean>(
    initial?.isEnabled ?? false,
  );
  const [priceJod, setPriceJod] = useState<number>(
    initial ? Number(initial.priceJod) : DEFAULT_PRICE_JOD,
  );
  const [dailyCap, setDailyCap] = useState<string>(
    initial?.dailyCap != null ? String(initial.dailyCap) : "",
  );

  const platformFeePct = initial
    ? Number(initial.platformFeePct)
    : DEFAULT_PLATFORM_FEE_PCT;
  const fee = Math.round(priceJod * platformFeePct) / 100;
  const net = Math.max(priceJod - fee, 0);

  const priceInvalid = !Number.isFinite(priceJod)
    || priceJod < PRICE_MIN
    || priceJod > PRICE_MAX;

  function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (priceInvalid) {
      setStatus("err");
      setErrorMsg(t("dayPassPriceInvalid"));
      return;
    }
    setStatus("idle");
    setErrorMsg(null);
    const body: DayPassOfferingUpsertBody = {
      isEnabled,
      priceJod,
      // Empty string -> null (unlimited). NaN guard so a member
      // typing "abc" into a number field doesn't ship as cap=NaN.
      dailyCap: (() => {
        const trimmed = dailyCap.trim();
        if (!trimmed) return null;
        const n = Number(trimmed);
        return Number.isFinite(n) && n > 0 ? n : null;
      })(),
    };
    startTransition(async () => {
      const res = await saveDayPassOfferingAction(body);
      if (res.ok) {
        setStatus("ok");
      } else {
        setStatus("err");
        setErrorMsg(res.error ?? t("dayPassError"));
      }
    });
  }

  return (
    <form
      onSubmit={onSubmit}
      className="card flex flex-col gap-5 p-6"
      aria-labelledby="day-pass-section-title"
    >
      <header className="flex items-start justify-between gap-4">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h2
              id="day-pass-section-title"
              className="text-lg font-semibold text-paper"
            >
              {t("sectionDayPass")}
            </h2>
            {/* Live status badge reflecting the saved offering. Helps
                the partner glance at the section and instantly know
                whether day-pass is currently selling — useful when
                they have multiple gyms / come back to the form a
                week later wondering "is this even on right now?". */}
            <span
              className={[
                "rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
                initial?.isEnabled
                  ? "bg-emerald-500/15 text-emerald-300"
                  : "bg-paper/10 text-muted",
              ].join(" ")}
            >
              {initial?.isEnabled
                ? t("dayPassStatusLive")
                : t("dayPassStatusOff")}
            </span>
          </div>
          <p className="mt-1 text-sm text-muted">{t("sectionDayPassHint")}</p>
        </div>
        {/* Save-result pill mirrors the main profile form's pattern
            so the partner doesn't have to learn a new affordance. */}
        {status === "ok" && (
          <span className="status-pill status-pill--ok">
            {t("dayPassSaved")}
          </span>
        )}
        {status === "err" && (
          <span className="status-pill status-pill--bad" title={errorMsg ?? ""}>
            {t("dayPassError")}
          </span>
        )}
      </header>

      <label className="flex items-center gap-3">
        <input
          type="checkbox"
          checked={isEnabled}
          onChange={(e) => setIsEnabled(e.target.checked)}
          className="h-4 w-4"
        />
        <span className="text-sm font-medium text-paper">
          {t("dayPassEnabled")}
        </span>
      </label>

      {/* When disabled, surface a quiet inline hint instead of
          pulling the price/cap fields out of the DOM — keeping
          them mounted lets the partner toggle on/off without
          re-typing values. */}
      {!isEnabled && (
        <p className="text-xs text-muted">{t("dayPassEnabledOff")}</p>
      )}

      <div className={isEnabled ? "" : "opacity-50"}>
        <label className="flex flex-col gap-1.5">
          <span className="text-xs font-medium uppercase tracking-wide text-muted">
            {t("dayPassPrice")}
          </span>
          <input
            type="number"
            inputMode="decimal"
            min={PRICE_MIN}
            max={PRICE_MAX}
            step="0.5"
            value={priceJod}
            onChange={(e) => setPriceJod(Number(e.target.value))}
            disabled={!isEnabled}
            aria-invalid={priceInvalid || undefined}
            className="input w-32"
          />
          <span className="text-xs text-muted">{t("dayPassPriceHint")}</span>
          {/* Net-amount preview. Renders even when disabled so the
              partner can model a future price before flipping on. */}
          {!priceInvalid && (
            <span
              className="text-xs text-paper/80"
              dir="ltr"
            >
              {t("dayPassNet", {
                amount: net.toFixed(2),
                fee: fee.toFixed(2),
                percent: platformFeePct,
              })}
            </span>
          )}
        </label>
      </div>

      <div className={isEnabled ? "" : "opacity-50"}>
        <label className="flex flex-col gap-1.5">
          <span className="text-xs font-medium uppercase tracking-wide text-muted">
            {t("dayPassDailyCap")}
          </span>
          <input
            type="number"
            inputMode="numeric"
            min={1}
            step={1}
            value={dailyCap}
            onChange={(e) => setDailyCap(e.target.value)}
            placeholder={t("dayPassDailyCapPlaceholder")}
            disabled={!isEnabled}
            className="input w-32"
          />
          <span className="text-xs text-muted">{t("dayPassDailyCapHint")}</span>
        </label>
      </div>

      {/* Validity is admin-controlled — show as read-only context
          so the partner knows what they're selling. */}
      <div className="flex flex-col gap-1">
        <span className="text-xs font-medium uppercase tracking-wide text-muted">
          {t("dayPassValidity")}
        </span>
        <span className="text-sm text-paper">{t("dayPassValidityValue")}</span>
        <span className="text-xs text-muted">{t("dayPassValidityHint")}</span>
      </div>

      {/* Live mini-preview of the member-app CTA. Pure client-side
          render of the same lime-pill shape the gym detail page
          will show — gives the partner instant feedback on what
          their buyers see, no need to switch to the mobile app to
          eyeball it. Renders dimmed when the offering is OFF so
          the partner reads it as "this is what WILL show once you
          enable it". */}
      <div className="flex flex-col gap-2">
        <span className="text-xs font-medium uppercase tracking-wide text-muted">
          {t("dayPassPreview")}
        </span>
        <div
          className={[
            "rounded-2xl border border-paper/10 bg-ink/40 p-4",
            isEnabled && !priceInvalid ? "" : "opacity-50",
          ].join(" ")}
          aria-hidden="true"
        >
          <div className="text-[10px] uppercase tracking-wider text-muted">
            {t("dayPassPreviewHeader")}
          </div>
          <div
            className="mt-2 inline-flex items-center gap-3 rounded-full bg-gradient-to-b from-lime-300 to-lime-400 px-5 py-2.5 text-ink shadow-md"
            dir="ltr"
          >
            <span
              className="grid h-7 w-7 place-items-center rounded-full bg-ink/10"
              aria-hidden="true"
            >
              {/* Ticket icon, matches the mobile CTA */}
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="h-3.5 w-3.5"
              >
                <path d="M2 9a3 3 0 0 1 3-3h14a3 3 0 0 1 3 3v2a2 2 0 0 0 0 4v2a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-2a2 2 0 0 0 0-4z" />
                <path d="M13 5v2M13 11v2M13 17v2" />
              </svg>
            </span>
            <div className="flex flex-col leading-tight">
              <span className="text-[13px] font-extrabold">
                {t("dayPassPreviewCta", { price: priceInvalid ? "0" : priceJod })}
              </span>
              <span className="text-[10px] font-medium text-ink/70">
                {t("dayPassPreviewSub")}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-end gap-3">
        <PendingButton
          pending={pending}
          type="submit"
          disabled={priceInvalid}
          className="btn-primary"
          pendingLabel={t("saving")}
          idleLabel={t("save")}
        />
      </div>
    </form>
  );
}
