import { getTranslations } from "next-intl/server";

import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { AdminSDK } from "@/lib/sdk";

/**
 * System Settings — read-only operator surface.
 *
 * Surfaces runtime configuration that's otherwise invisible:
 *  - which environment is live (dev vs production sentinel),
 *  - which provider adapters are wired (SMS / payment),
 *  - the JWT TTLs and admin-exchange skew window (so an operator
 *    debugging a "session expired too fast" report can verify the
 *    setting without SSH'ing into the container),
 *  - infrastructure liveness (Postgres + Redis ping with latency).
 *
 * Mutations are deliberately absent — these values are env-driven
 * and changing them at runtime would diverge a single backend
 * instance from the rest of the fleet. The page links the operator
 * to the right artifact (`.env`, deploy doc) for each section
 * instead.
 */
export default async function SettingsPage() {
  const settings = await AdminSDK.settings();
  const t = await getTranslations("settings");

  return (
    <section className="flex flex-col gap-5">
      <Toolbar title={t("title")} description={t("description")} />

      {/* Environment + uptime headline */}
      <div className="grid gap-4 md:grid-cols-2">
        <div className="card">
          <div className="label mb-2">Environment</div>
          <div className="flex items-center gap-3">
            <span className="text-[26px] font-semibold tracking-tight text-paper capitalize">
              {settings.appEnv}
            </span>
            <StatusPill tone={settings.isDev ? "warn" : "ok"}>
              {settings.isDev ? "DEV MODE" : "LIVE"}
            </StatusPill>
          </div>
          <p className="mt-2 text-[12px] text-muted">
            {settings.isDev
              ? "OTP fixed to 1234, payments mocked, CORS permissive. Do NOT bill members from this build."
              : "Real SMS, real payments, locked CORS. Mutating writes go to the production database."}
          </p>
        </div>

        <div className="card">
          <div className="label mb-2">Domains</div>
          <dl className="space-y-1.5 text-[13px]">
            <div className="flex items-center justify-between">
              <dt className="text-muted">API</dt>
              <dd className="text-paper font-medium num">
                {settings.apiDomain}
              </dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-muted">Admin</dt>
              <dd className="text-paper font-medium num">
                {settings.adminDomain}
              </dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-muted">Media prefix</dt>
              <dd className="text-paper font-medium num">
                {settings.mediaUrlPrefix}
              </dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-muted">Max upload</dt>
              <dd className="text-paper font-medium num">
                {settings.maxUploadMb} MB
              </dd>
            </div>
          </dl>
        </div>
      </div>

      {/* Health probes */}
      <section>
        <h2 className="h2 mb-2">Infrastructure health</h2>
        <p className="mb-3 text-[12.5px] text-muted">
          Live probes against the dependencies the API can&apos;t function
          without. A failing probe means writes are likely failing
          everywhere — escalate immediately.
        </p>
        <div className="panel divide-y divide-line">
          {settings.health.map((h) => (
            <div
              key={h.name}
              className="flex items-center justify-between px-4 py-3"
            >
              <div className="flex items-center gap-3">
                <span
                  className={`dot ${h.ok ? "bg-accent" : "bg-red-500"}`}
                  aria-hidden
                />
                <span className="font-medium text-paper capitalize">
                  {h.name}
                </span>
                {h.detail ? (
                  <code className="code">{h.detail}</code>
                ) : null}
              </div>
              <div className="flex items-center gap-2">
                {h.latencyMs != null ? (
                  <span className="num text-[12px] text-muted">
                    {h.latencyMs} ms
                  </span>
                ) : null}
                <StatusPill tone={h.ok ? "ok" : "bad"}>
                  {h.ok ? "OK" : "DOWN"}
                </StatusPill>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Provider adapters */}
      <section>
        <h2 className="h2 mb-2">Provider adapters</h2>
        <p className="mb-3 text-[12.5px] text-muted">
          Which external service the backend talks to for each
          capability. Provider names match the value in{" "}
          <code className="code">.env</code>; rotating one means
          editing the env and redeploying.
        </p>
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>Capability</th>
                <th>Adapter</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {settings.providers.map((p) => {
                const isMock = p.name === "mock";
                return (
                  <tr key={p.kind}>
                    <td className="capitalize">{p.kind}</td>
                    <td>
                      <code className="code">{p.name}</code>
                    </td>
                    <td>
                      {isMock ? (
                        <StatusPill tone="warn">Mock</StatusPill>
                      ) : (
                        <StatusPill tone="ok">Live</StatusPill>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* Token / session policy */}
      <section>
        <h2 className="h2 mb-2">Session &amp; token policy</h2>
        <p className="mb-3 text-[12.5px] text-muted">
          Lifetimes the JWT layer and the NextAuth ↔ FastAPI
          handshake are configured for. Useful when debugging a
          &ldquo;signed me out too fast&rdquo; report from a member.
        </p>
        <div className="panel">
          <dl className="divide-y divide-line">
            <PolicyRow
              label="Access token TTL"
              value={`${settings.jwtAccessTtlSeconds} s`}
              hint={`${humanDuration(settings.jwtAccessTtlSeconds)} between forced refreshes`}
            />
            <PolicyRow
              label="Refresh token TTL"
              value={`${settings.jwtRefreshTtlSeconds} s`}
              hint={`${humanDuration(settings.jwtRefreshTtlSeconds)} until full re-login required`}
            />
            <PolicyRow
              label="Service token TTL"
              value={`${settings.jwtServiceTtlSeconds} s`}
              hint="Admin → backend hop; minted per-request by NextAuth"
            />
            <PolicyRow
              label="Exchange envelope skew"
              value={`±${settings.adminExchangeMaxSkewSeconds} s`}
              hint="HMAC envelopes outside this window are rejected as stale or replayed"
            />
          </dl>
        </div>
      </section>
    </section>
  );
}

function PolicyRow({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint: string;
}) {
  return (
    <div className="flex items-baseline justify-between gap-4 px-4 py-3">
      <div className="min-w-0">
        <div className="text-[13px] font-medium text-paper">{label}</div>
        <div className="text-[11.5px] text-muted">{hint}</div>
      </div>
      <div className="num text-[13px] font-semibold text-paper shrink-0">
        {value}
      </div>
    </div>
  );
}

/**
 * Render a duration in seconds as a coarse "1h 30m" / "30 days"
 * string. Operators look at "900 s" and immediately ask "how long
 * is that"; spelling it out avoids the head-math step.
 */
function humanDuration(totalSeconds: number): string {
  if (totalSeconds < 60) return `${totalSeconds} s`;
  if (totalSeconds < 3600) {
    const m = Math.round(totalSeconds / 60);
    return `${m} min`;
  }
  if (totalSeconds < 86_400) {
    const h = Math.floor(totalSeconds / 3600);
    const m = Math.round((totalSeconds % 3600) / 60);
    return m === 0 ? `${h} h` : `${h} h ${m} m`;
  }
  const d = Math.round(totalSeconds / 86_400);
  return `${d} day${d === 1 ? "" : "s"}`;
}
