import { useTranslations } from "next-intl";

import { formatDate, formatDateTime } from "@/components/users/format";

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

/// Identity side panel — email, phone, member-since, last-active.
/// Pure display.
export default function IdentityPanel({
  user,
}: {
  user: {
    email: string | null;
    phone: string | null;
    createdAt: string;
    lastActiveAt: string | null;
  };
}) {
  const t = useTranslations("users.detail");
  const tEdit = useTranslations("users.edit");
  return (
    <section className="flex flex-col gap-3">
      <h2 className="h2">{t("identity")}</h2>
      <div className="panel flex flex-col gap-3 p-4">
        <KeyVal label={tEdit("email")} value={user.email} mono />
        <KeyVal label={tEdit("phone")} value={user.phone} mono />
        <KeyVal label={t("memberSince")} value={formatDate(user.createdAt)} />
        <KeyVal
          label={t("lastActive")}
          value={formatDateTime(user.lastActiveAt)}
        />
      </div>
    </section>
  );
}
