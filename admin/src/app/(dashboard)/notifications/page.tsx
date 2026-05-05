import BroadcastForm from "@/components/BroadcastForm";
import Toolbar from "@/components/Toolbar";
import { runAction } from "@/lib/action-result";
import { AdminSDK, type BroadcastBody } from "@/lib/sdk";

export default function NotificationsPage() {
  async function broadcast(body: BroadcastBody) {
    "use server";
    return runAction(() => AdminSDK.broadcast(body));
  }

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title="Broadcast"
        description="Publish an in-app push to every active member. Optionally scope by tier."
      />

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-[1.4fr_1fr]">
        <BroadcastForm action={broadcast} />

        <aside className="panel p-4">
          <p className="label mb-3">Send guidelines</p>
          <ul className="flex flex-col gap-3 text-[12.5px] leading-relaxed text-muted">
            <li>
              <span className="font-medium text-paper">Lead with the news.</span>{" "}
              Members see the notification on the lock screen — keep it under 80
              characters.
            </li>
            <li>
              <span className="font-medium text-paper">
                Arabic is required.
              </span>{" "}
              AR is the default locale. Sending EN alone leaves AR users with
              nothing.
            </li>
            <li>
              <span className="font-medium text-paper">Tier scope is hard.</span>{" "}
              Choosing <span className="kbd">silver</span> reaches only Silver
              members. Leave blank for the whole base.
            </li>
          </ul>
        </aside>
      </div>
    </section>
  );
}
