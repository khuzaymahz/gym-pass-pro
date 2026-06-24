"use client";

import { useTranslations } from "next-intl";

import ConfirmActionButton from "@/components/ui/ConfirmActionButton";
import type { ActionResult } from "@/lib/action-result";

export default function RefundPaymentButton({
  action,
}: {
  action: () => Promise<ActionResult<unknown>>;
}) {
  const t = useTranslations("users.detail");
  return (
    <ConfirmActionButton
      action={action}
      label={t("refund")}
      confirm={t("refundConfirm")}
    />
  );
}
