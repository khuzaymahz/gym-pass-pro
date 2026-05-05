import Link from "next/link";

import GymForm from "@/components/GymForm";
import Toolbar from "@/components/Toolbar";
import { createGym, type GymRead } from "@/lib/gyms";

async function action(data: Partial<GymRead>) {
  "use server";
  try {
    await createGym(data);
    return { ok: true };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Failed to create gym.";
    return { ok: false, error: message };
  }
}

export default function NewGymPage() {
  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title="New gym"
        description="Register a partner venue. Slug is permanent once saved."
        actions={
          <Link href="/gyms" className="btn-ghost btn-sm">
            ← Gyms
          </Link>
        }
      />
      <GymForm action={action} submitLabel="Create gym" />
    </section>
  );
}
