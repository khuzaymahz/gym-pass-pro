import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";

import StatTile from "@/components/StatTile";
import Toolbar from "@/components/Toolbar";
import UserEditForm from "@/components/UserEditForm";
import CheckinsSection from "@/components/users/CheckinsSection";
import IdentityPanel from "@/components/users/IdentityPanel";
import PaymentsSection from "@/components/users/PaymentsSection";
import ReferralPanel from "@/components/users/ReferralPanel";
import SubscriptionsSection from "@/components/users/SubscriptionsSection";
import TicketsSection from "@/components/users/TicketsSection";
import { runAction } from "@/lib/action-result";
import { UserUpdateBodySchema, parseAction } from "@/lib/action-schemas";
import { AdminSDK, type AdminUserUpdate } from "@/lib/sdk";

type Props = { params: Promise<{ id: string }> };

export default async function UserDetailPage({ params }: Props) {
  const { id } = await params;
  const t = await getTranslations("users.detail");
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
    const validated = parseAction(UserUpdateBodySchema, data);
    if (!validated.ok) return validated;
    return runAction(() => AdminSDK.updateUser(id, validated.data));
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
