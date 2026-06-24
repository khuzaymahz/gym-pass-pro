"use client";

import { useTranslations } from "next-intl";

import ConfirmActionButton from "@/components/ui/ConfirmActionButton";
import type { ActionResult } from "@/lib/action-result";

/** Thin wrapper over the shared confirm-action control. Kept as a
 *  named component so existing call sites and their i18n stay put. */
export default function CancelSubscriptionButton({
  action,
}: {
  action: () => Promise<ActionResult<void>>;
}) {
  const t = useTranslations("subscriptions");
  return (
    <ConfirmActionButton
      action={action}
      label={t("cancel")}
      confirm={t("cancelConfirm")}
    />
  );
}
