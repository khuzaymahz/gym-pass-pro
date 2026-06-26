import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";

import ManageSubscription from "@/components/ManageSubscription";
import RefundPaymentButton from "@/components/RefundPaymentButton";
import StatTile from "@/components/StatTile";
import Toolbar from "@/components/Toolbar";
import UserEditForm from "@/components/UserEditForm";
import CheckinsSection from "@/components/users/CheckinsSection";
import IdentityPanel from "@/components/users/IdentityPanel";
import PaymentsSection from "@/components/users/PaymentsSection";
import ReferralPanel from "@/components/users/ReferralPanel";
import SubscriptionsSection from "@/components/users/SubscriptionsSection";
import TicketsSection from "@/components/users/TicketsSection";
import UserSessionsPanel from "@/components/users/UserSessionsPanel";
import { runAction } from "@/lib/action-result";
import { UserUpdateBodySchema, parseAction } from "@/lib/action-schemas";
import { AdminSDK, type AdminUserUpdate, type Tier } from "@/lib/sdk";

type Props = { params: Promise<{ id: string }> };

export default async function UserDetailPage({ params }: Props) {
  const { id } = await params;
  const t = await getTranslations("users.detail");
  // Fetch detail (required) + sessions (soft) concurrently rather than
  // in a waterfall — they're independent, halving the round-trip wait.
  const [detailR, sessionsR] = await Promise.allSettled([
    AdminSDK.getUserDetail(id),
    AdminSDK.listUserSessions(id),
  ]);
  if (detailR.status !== "fulfilled") {
    notFound();
  }
  const detail = detailR.value;
  const sessions = sessionsR.status === "fulfilled" ? sessionsR.value : [];

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
    const validated = parseAction(UserUpdateBodySchema, data);
    if (!validated.ok) return validated;
    return runAction(() => AdminSDK.updateUser(id, validated.data));
  }
  async function extendSub(subId: string, days: number) {
    "use server";
    return runAction(() => AdminSDK.extendSubscription(subId, days));
  }
  async function setSubVisits(subId: string, visitsUsed: number) {
    "use server";
    return runAction(() => AdminSDK.setSubscriptionVisits(subId, visitsUsed));
  }
  async function changeSubTier(subId: string, tier: Tier) {
    "use server";
    return runAction(() => AdminSDK.changeSubscriptionTier(subId, tier));
  }
  async function restoreSub(subId: string) {
    "use server";
    return runAction(() => AdminSDK.restoreSubscription(subId));
  }
  async function resumeSubPause(subId: string) {
    "use server";
    return runAction(() => AdminSDK.resumeSubscriptionPause(subId));
  }
  async function refundPayment(paymentId: string) {
    "use server";
    return runAction(() => AdminSDK.refundPayment(paymentId));
  }
  async function revokeSessions() {
    "use server";
    return runAction(() => AdminSDK.revokeUserSessions(id));
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
            ← {t("back")}
          </Link>
        }
      />

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatTile
          label={t("totalPaid")}
          value={totals.totalPaidJod}
          unit="JOD"
          tone="default"
        />
        <StatTile
          label={t("subscriptions")}
          value={totals.subscriptionCount}
          sub={
            totals.hasActiveSubscription && totals.activeTier
              ? t("active", { tier: totals.activeTier })
              : t("noneActive")
          }
          tone={totals.hasActiveSubscription ? "ok" : "default"}
        />
        <StatTile
          label={t("openTickets")}
          value={totals.openTicketCount}
          sub={t("totalTickets", { count: totals.ticketCount })}
          tone={totals.openTicketCount > 0 ? "warn" : "default"}
        />
        <StatTile
          label={t("referrals")}
          value={totals.referralCount}
          sub={t("converted", { count: totals.convertedReferralCount })}
          tone={totals.convertedReferralCount > 0 ? "ok" : "default"}
        />
      </div>

      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        <div className="flex flex-col gap-5 xl:col-span-2">
          <section className="flex flex-col gap-3">
            <h2 className="h2">{t("profile")}</h2>
            <UserEditForm user={user} action={update} />
          </section>

          <SubscriptionsSection
            subscriptions={subscriptions}
            renderActions={(s) => (
              <ManageSubscription
                sub={{
                  id: s.id,
                  status: s.status,
                  tier: s.tier,
                  visitsUsed: s.visitsUsed,
                }}
                extend={extendSub.bind(null, s.id)}
                setVisits={setSubVisits.bind(null, s.id)}
                changeTier={changeSubTier.bind(null, s.id)}
                restore={restoreSub.bind(null, s.id)}
                resumePause={resumeSubPause.bind(null, s.id)}
              />
            )}
          />
          <PaymentsSection
            payments={payments}
            paymentMethods={paymentMethods}
            renderActions={(p) =>
              p.status === "succeeded" ? (
                <RefundPaymentButton
                  action={refundPayment.bind(null, p.id)}
                />
              ) : (
                <span className="text-[11px] text-muted">—</span>
              )
            }
          />
          <UserSessionsPanel sessions={sessions} revoke={revokeSessions} />
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
