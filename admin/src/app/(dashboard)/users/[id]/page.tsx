import Link from "next/link";
import { notFound } from "next/navigation";

import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import UserEditForm from "@/components/UserEditForm";
import { runAction } from "@/lib/action-result";
import {
  AdminSDK,
  type AdminUserDetailCheckin,
  type AdminUserDetailPayment,
  type AdminUserDetailPaymentMethod,
  type AdminUserDetailReferral,
  type AdminUserDetailSubscription,
  type AdminUserDetailTicket,
  type AdminUserUpdate,
  type CheckinStatus,
  type PaymentMethod,
  type PaymentStatus,
  type ReferralStatus,
  type SubscriptionStatus,
  type Tier,
  type TicketPriority,
  type TicketStatus,
} from "@/lib/sdk";

type Props = { params: Promise<{ id: string }> };

function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  } catch {
    return value.slice(0, 10);
  }
}

function formatDateTime(value: string | null | undefined): string {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return value.slice(0, 16).replace("T", " ");
  }
}

const METHOD_LABEL: Record<PaymentMethod, string> = {
  card: "Card",
  cliq: "CliQ",
  apple_pay: "Apple Pay",
  mock: "Mock",
};

const TIER_TONE: Record<Tier, "ok" | "warn" | "info" | "mute"> = {
  silver: "mute",
  gold: "warn",
  platinum: "ok",
  diamond: "info",
};

function subTone(status: SubscriptionStatus): "ok" | "warn" | "bad" | "mute" {
  switch (status) {
    case "active":
      return "ok";
    case "pending":
      return "warn";
    case "cancelled":
      return "bad";
    case "expired":
    default:
      return "mute";
  }
}

function payTone(status: PaymentStatus): "ok" | "warn" | "bad" {
  switch (status) {
    case "succeeded":
      return "ok";
    case "pending":
      return "warn";
    case "failed":
    default:
      return "bad";
  }
}

function ticketStatusTone(
  status: TicketStatus,
): "ok" | "warn" | "bad" | "info" | "mute" {
  switch (status) {
    case "open":
      return "warn";
    case "in_progress":
      return "info";
    case "waiting_user":
      return "info";
    case "resolved":
      return "ok";
    case "closed":
    default:
      return "mute";
  }
}

function priorityTone(
  priority: TicketPriority,
): "ok" | "warn" | "bad" | "mute" {
  switch (priority) {
    case "urgent":
      return "bad";
    case "high":
      return "warn";
    case "normal":
      return "mute";
    case "low":
    default:
      return "mute";
  }
}

function checkinTone(status: CheckinStatus): "ok" | "warn" | "bad" | "mute" {
  if (status === "success") return "ok";
  if (status === "rate_limited") return "warn";
  return "bad";
}

function referralTone(status: ReferralStatus): "ok" | "warn" | "mute" {
  if (status === "converted") return "ok";
  if (status === "pending") return "warn";
  return "mute";
}

function methodSummaryDescription(
  entry: AdminUserDetailPaymentMethod,
): string | null {
  const last = entry.last;
  if (!last) return null;
  if (entry.method === "cliq") {
    const alias = typeof last.alias === "string" ? last.alias : null;
    const phone = typeof last.phone === "string" ? last.phone : null;
    return alias ?? phone ?? null;
  }
  if (entry.method === "card") {
    const brand = typeof last.brand === "string" ? last.brand : null;
    const last4 = typeof last.last4 === "string" ? last.last4 : null;
    if (brand && last4) return `${brand.toUpperCase()} •• ${last4}`;
    if (last4) return `•• ${last4}`;
    return brand ?? null;
  }
  return null;
}

function paymentMetaSummary(
  method: PaymentMethod,
  meta: Record<string, unknown>,
): string | null {
  if (method === "cliq") {
    const alias = typeof meta.alias === "string" ? meta.alias : null;
    const phone = typeof meta.phone === "string" ? meta.phone : null;
    return alias ?? phone ?? null;
  }
  if (method === "card") {
    const brand = typeof meta.brand === "string" ? meta.brand : null;
    const last4 = typeof meta.last4 === "string" ? meta.last4 : null;
    if (brand && last4) return `${brand.toUpperCase()} •• ${last4}`;
    if (last4) return `•• ${last4}`;
    return brand ?? null;
  }
  return null;
}

export default async function UserDetailPage({ params }: Props) {
  const { id } = await params;
  let detail;
  try {
    detail = await AdminSDK.getUserDetail(id);
  } catch {
    notFound();
  }

  const {
    user,
    invitedBy,
    referralCode,
    referralCounts,
    referrals,
    subscriptions,
    payments,
    tickets,
    recentCheckins,
    paymentMethods,
    totals,
  } = detail;

  async function update(data: AdminUserUpdate) {
    "use server";
    return runAction(() => AdminSDK.updateUser(id, data));
  }

  const displayName =
    [user.firstName, user.lastName].filter(Boolean).join(" ") ||
    user.name ||
    user.email ||
    user.phone ||
    user.id.slice(0, 8);

  const description = [
    `#${user.id.slice(0, 8)}`,
    user.role,
    user.locale.toUpperCase(),
    user.deletedAt ? "soft-deleted" : "active",
  ].join(" · ");

  return (
    <section className="flex flex-col gap-6">
      <Toolbar
        title={displayName}
        description={description}
        actions={
          <Link href="/users" className="btn-ghost btn-sm">
            ← Users
          </Link>
        }
      />

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatTile
          label="Total paid"
          value={totals.totalPaidJod}
          unit="JOD"
          tone="default"
        />
        <StatTile
          label="Subscriptions"
          value={totals.subscriptionCount}
          sub={
            totals.hasActiveSubscription && totals.activeTier
              ? `Active · ${totals.activeTier}`
              : "None active"
          }
          tone={totals.hasActiveSubscription ? "ok" : "default"}
        />
        <StatTile
          label="Open tickets"
          value={totals.openTicketCount}
          sub={`${totals.ticketCount} total`}
          tone={totals.openTicketCount > 0 ? "warn" : "default"}
        />
        <StatTile
          label="Referrals"
          value={totals.referralCount}
          sub={`${totals.convertedReferralCount} converted`}
          tone={totals.convertedReferralCount > 0 ? "ok" : "default"}
        />
      </div>

      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        <div className="flex flex-col gap-5 xl:col-span-2">
          <section className="flex flex-col gap-3">
            <h2 className="h2">Profile</h2>
            <UserEditForm user={user} action={update} />
          </section>

          <SubscriptionsSection subscriptions={subscriptions} />
          <PaymentsSection
            payments={payments}
            paymentMethods={paymentMethods}
          />
          <TicketsSection tickets={tickets} />
          <CheckinsSection checkins={recentCheckins} />
        </div>

        <div className="flex flex-col gap-5">
          <ReferralPanel
            code={referralCode}
            counts={referralCounts}
            invitedBy={invitedBy}
            referrals={referrals}
          />
          <IdentityPanel user={user} />
        </div>
      </div>
    </section>
  );
}

function SubscriptionsSection({
  subscriptions,
}: {
  subscriptions: AdminUserDetailSubscription[];
}) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">Subscriptions & tier history</h2>
        <span className="text-[11px] text-muted">
          {subscriptions.length} record{subscriptions.length === 1 ? "" : "s"}
        </span>
      </div>
      <div className="panel overflow-hidden">
        {subscriptions.length === 0 ? (
          <EmptyRow label="No subscriptions yet." />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Tier</th>
                <th>Status</th>
                <th>Window</th>
                <th className="num">Visits</th>
                <th className="num">Price</th>
                <th>Auto-renew</th>
              </tr>
            </thead>
            <tbody>
              {subscriptions.map((s) => (
                <tr key={s.id}>
                  <td>
                    <div className="flex flex-col">
                      <span className="font-medium capitalize">{s.tier}</span>
                      {s.planDurationMonths ? (
                        <span className="text-[11px] text-muted">
                          {s.planDurationMonths} mo plan
                        </span>
                      ) : null}
                    </div>
                  </td>
                  <td>
                    <StatusPill tone={subTone(s.status)}>
                      {s.status.replace("_", " ")}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    {formatDate(s.startsAt)} → {formatDate(s.expiresAt)}
                    {s.cancelledAt ? (
                      <div className="text-[11px] text-red-300">
                        cancelled {formatDate(s.cancelledAt)}
                      </div>
                    ) : null}
                  </td>
                  <td className="num">
                    {s.visitsUsed}
                    {s.planMonthlyVisits
                      ? ` / ${s.planMonthlyVisits}`
                      : ""}
                  </td>
                  <td className="num">{s.planPriceJod ?? "—"}</td>
                  <td>
                    {s.autoRenew ? (
                      <span className="text-lime">on</span>
                    ) : (
                      <span className="text-muted">off</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function PaymentsSection({
  payments,
  paymentMethods,
}: {
  payments: AdminUserDetailPayment[];
  paymentMethods: AdminUserDetailPaymentMethod[];
}) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">Payments</h2>
        <span className="text-[11px] text-muted">
          {payments.length} record{payments.length === 1 ? "" : "s"}
        </span>
      </div>

      {paymentMethods.length > 0 ? (
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          {paymentMethods.map((m) => (
            <div key={m.method} className="panel p-3">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-medium uppercase tracking-[0.04em] text-muted">
                  {METHOD_LABEL[m.method]}
                </span>
                <span className="text-[11px] text-muted num">
                  ×{m.count}
                </span>
              </div>
              <div className="mt-1 text-[13px] text-paper">
                {methodSummaryDescription(m) ?? (
                  <span className="text-muted">—</span>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : null}

      <div className="panel overflow-hidden">
        {payments.length === 0 ? (
          <EmptyRow label="No payments yet." />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>When</th>
                <th>Method</th>
                <th>Detail</th>
                <th>Tier</th>
                <th>Status</th>
                <th className="num">Amount</th>
              </tr>
            </thead>
            <tbody>
              {payments.map((p) => (
                <tr key={p.id}>
                  <td className="num text-muted">
                    {formatDateTime(p.processedAt ?? p.createdAt)}
                  </td>
                  <td>{METHOD_LABEL[p.method]}</td>
                  <td className="text-muted">
                    {paymentMetaSummary(p.method, p.meta) ?? (
                      <span className="text-muted">—</span>
                    )}
                  </td>
                  <td className="capitalize">{p.subscriptionTier ?? "—"}</td>
                  <td>
                    <StatusPill tone={payTone(p.status)}>
                      {p.status}
                    </StatusPill>
                  </td>
                  <td className="num">{p.amountJod} JOD</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function TicketsSection({
  tickets,
}: {
  tickets: AdminUserDetailTicket[];
}) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">Support history</h2>
        <span className="text-[11px] text-muted">
          {tickets.length} ticket{tickets.length === 1 ? "" : "s"}
        </span>
      </div>
      <div className="panel overflow-hidden">
        {tickets.length === 0 ? (
          <EmptyRow label="No support tickets." />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Subject</th>
                <th>Category</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Updated</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={t.id}>
                  <td>
                    <div className="flex flex-col">
                      <span className="text-paper">{t.subject}</span>
                      <span className="text-[11px] text-muted num">
                        #{t.id.slice(0, 8)}
                      </span>
                    </div>
                  </td>
                  <td className="capitalize text-muted">{t.category}</td>
                  <td>
                    <StatusPill tone={priorityTone(t.priority)}>
                      {t.priority}
                    </StatusPill>
                  </td>
                  <td>
                    <StatusPill tone={ticketStatusTone(t.status)}>
                      {t.status.replace("_", " ")}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    {formatDateTime(t.updatedAt)}
                  </td>
                  <td className="num">
                    <Link
                      href={`/support/${t.id}`}
                      className="btn-ghost btn-sm"
                    >
                      open
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function CheckinsSection({
  checkins,
}: {
  checkins: AdminUserDetailCheckin[];
}) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">Recent check-ins</h2>
        <span className="text-[11px] text-muted">
          last {checkins.length}
        </span>
      </div>
      <div className="panel overflow-hidden">
        {checkins.length === 0 ? (
          <EmptyRow label="No check-ins yet." />
        ) : (
          <table className="table table-compact">
            <thead>
              <tr>
                <th>When</th>
                <th>Gym</th>
                <th>Status</th>
                <th>Reason</th>
              </tr>
            </thead>
            <tbody>
              {checkins.map((c) => (
                <tr key={c.id}>
                  <td className="num text-muted">
                    {formatDateTime(c.scannedAt)}
                  </td>
                  <td>{c.gymNameEn}</td>
                  <td>
                    <StatusPill tone={checkinTone(c.status)}>
                      {c.status.replace("_", " ")}
                    </StatusPill>
                  </td>
                  <td className="text-muted">{c.failureReason ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function ReferralPanel({
  code,
  counts,
  invitedBy,
  referrals,
}: {
  code: string;
  counts: Record<ReferralStatus, number>;
  invitedBy: {
    id: string;
    name: string | null;
    email: string | null;
    phone: string | null;
  } | null;
  referrals: AdminUserDetailReferral[];
}) {
  const shareUrl = `https://gym-pass.net/invite/${code}`;
  return (
    <section className="flex flex-col gap-3">
      <h2 className="h2">Referrals</h2>

      <div className="panel flex flex-col gap-3 p-4">
        <div>
          <span className="field-label">Referral code</span>
          <div className="mt-1 flex items-center gap-2">
            <span className="kbd text-[13px]">{code}</span>
            <span className="text-[11px] text-muted">
              share link: {shareUrl}
            </span>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-2 border-t border-line pt-3">
          <MiniStat label="Pending" value={counts.pending} tone="warn" />
          <MiniStat label="Converted" value={counts.converted} tone="ok" />
          <MiniStat label="Expired" value={counts.expired} tone="mute" />
        </div>

        {invitedBy ? (
          <div className="border-t border-line pt-3">
            <span className="field-label">Invited by</span>
            <div className="mt-1 flex flex-col">
              <Link
                href={`/users/${invitedBy.id}`}
                className="text-paper hover:text-lime"
              >
                {invitedBy.name ??
                  invitedBy.email ??
                  invitedBy.phone ??
                  invitedBy.id.slice(0, 8)}
              </Link>
              <span className="text-[11px] text-muted num">
                #{invitedBy.id.slice(0, 8)}
              </span>
            </div>
          </div>
        ) : null}
      </div>

      <div className="panel overflow-hidden">
        {referrals.length === 0 ? (
          <EmptyRow label="No invited friends yet." />
        ) : (
          <table className="table table-compact">
            <thead>
              <tr>
                <th>Invited</th>
                <th>Status</th>
                <th>When</th>
              </tr>
            </thead>
            <tbody>
              {referrals.map((r) => (
                <tr key={r.id}>
                  <td>
                    <Link
                      href={`/users/${r.invited.id}`}
                      className="text-paper hover:text-lime"
                    >
                      {r.invited.name ??
                        r.invited.email ??
                        r.invited.phone ??
                        r.invited.id.slice(0, 8)}
                    </Link>
                  </td>
                  <td>
                    <StatusPill tone={referralTone(r.status)}>
                      {r.status}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    {formatDate(r.convertedAt ?? r.createdAt)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function IdentityPanel({
  user,
}: {
  user: {
    email: string | null;
    phone: string | null;
    createdAt: string;
    lastActiveAt: string | null;
  };
}) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="h2">Identity</h2>
      <div className="panel flex flex-col gap-3 p-4">
        <KeyVal label="Email" value={user.email} mono />
        <KeyVal label="Phone" value={user.phone} mono />
        <KeyVal label="Member since" value={formatDate(user.createdAt)} />
        <KeyVal
          label="Last active"
          value={formatDateTime(user.lastActiveAt)}
        />
      </div>
    </section>
  );
}

function KeyVal({
  label,
  value,
  mono,
}: {
  label: string;
  value: string | null;
  mono?: boolean;
}) {
  return (
    <div className="flex flex-col">
      <span className="field-label">{label}</span>
      <span
        className={`mt-0.5 text-[13px] text-paper ${mono ? "num" : ""}`}
      >
        {value ?? <span className="text-muted">—</span>}
      </span>
    </div>
  );
}

function MiniStat({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: "ok" | "warn" | "mute";
}) {
  const toneClass =
    tone === "ok"
      ? "text-lime"
      : tone === "warn"
        ? "text-amber-300"
        : "text-paper";
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-[10.5px] font-medium uppercase tracking-[0.04em] text-muted">
        {label}
      </span>
      <span className={`text-[18px] font-semibold num ${toneClass}`}>
        {value}
      </span>
    </div>
  );
}

function EmptyRow({ label }: { label: string }) {
  return (
    <div className="px-4 py-6 text-[12.5px] text-muted">{label}</div>
  );
}
