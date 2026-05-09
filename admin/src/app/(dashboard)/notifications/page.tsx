import { getTranslations } from "next-intl/server";

import BroadcastForm from "@/components/BroadcastForm";
import Toolbar from "@/components/Toolbar";
import { BroadcastBodySchema, parseAction } from "@/lib/action-schemas";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type BroadcastBody } from "@/lib/sdk";

export default async function NotificationsPage() {
  const t = await getTranslations("notifications");
  const tGuide = await getTranslations("notifications.guidelines");

  async function broadcast(body: BroadcastBody) {
    "use server";
    const validated = parseAction(BroadcastBodySchema, body);
    if (!validated.ok) return validated;
    return runAction(() => AdminSDK.broadcast(validated.data));
  }

  return (
    <section className="flex flex-col gap-5">
      <Toolbar title={t("title")} description={t("description")} />

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-[1.4fr_1fr]">
        <BroadcastForm action={broadcast} />

        <aside className="panel p-4">
          <p className="label mb-3">{tGuide("title")}</p>
          <ul className="flex flex-col gap-3 text-[12.5px] leading-relaxed text-muted">
            <li>
              <span className="font-medium text-paper">
                {tGuide("leadStrong")}
              </span>
              {tGuide("leadBody")}
            </li>
            <li>
              <span className="font-medium text-paper">
                {tGuide("arabicStrong")}
              </span>
              {tGuide("arabicBody")}
            </li>
            <li>
              <span className="font-medium text-paper">
                {tGuide("scopeStrong")}
              </span>
              {tGuide("scopeBody1")}
              <span className="kbd">silver</span>
              {tGuide("scopeBody2")}
            </li>
          </ul>
        </aside>
      </div>
    </section>
  );
}
