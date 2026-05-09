import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import { getServerSession } from "next-auth";

import StatusPill from "@/components/StatusPill";
import TicketReplyForm from "@/components/TicketReplyForm";
import TicketStatusControls from "@/components/TicketStatusControls";
import Toolbar from "@/components/Toolbar";
import { ApiError } from "@/lib/api";
import { authOptions } from "@/lib/auth";
import { runAction } from "@/lib/action-result";
import {
  AdminSDK,
  type TicketPriority,
  type TicketReplyBody,
  type TicketStatus,
  type TicketUpdateBody,
} from "@/lib/sdk";

const STATUS_TONE: Record<TicketStatus, "ok" | "warn" | "info" | "mute"> = {
  open: "warn",
  in_progress: "info",
  waiting_user: "mute",
  resolved: "ok",
  closed: "mute",
};

const PRIORITY_TONE: Record<TicketPriority, "bad" | "warn" | "ok" | "mute"> = {
  urgent: "bad",
  high: "warn",
  normal: "ok",
  low: "mute",
};

function formatDate(value: string): string {
  try {
    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return value;
  }
}

function formatTime(value: string): string {
  try {
    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return value;
  }
}

export default async function TicketDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const session = await getServerSession(authOptions);
  const currentAdminId = session?.adminId ?? "";
  const t = await getTranslations("support.detail");
  const tStatuses = await getTranslations("support.statuses");
  const tPriorities = await getTranslations("support.priorities");
  const tCategories = await getTranslations("support.categories");

  let ticket;
  try {
    ticket = await AdminSDK.getTicket(id);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) {
      notFound();
    }
    throw error;
  }

  async function update(body: TicketUpdateBody) {
    "use server";
    return runAction(() => AdminSDK.updateTicket(id, body));
  }
  async function reply(body: TicketReplyBody) {
    "use server";
    return runAction(() => AdminSDK.replyTicket(id, body));
  }

  const metaEntries = Object.entries(ticket.meta ?? {});

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={ticket.subject}
        description={`${tCategories(ticket.category)} · #${ticket.id.slice(0, 8)} · ${ticket.userName ?? t("unknownMember")}`}
        actions={
          <>
            <StatusPill tone={STATUS_TONE[ticket.status]}>
              {tStatuses(ticket.status)}
            </StatusPill>
            <StatusPill tone={PRIORITY_TONE[ticket.priority]}>
              {tPriorities(ticket.priority)}
            </StatusPill>
            <Link href="/support" className="btn-ghost btn-sm">
              ← {t("back")}
            </Link>
          </>
        }
      />

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[11.5px] text-muted num">
        <span>
          <span className="text-muted">{t("opened")}</span>{" "}
          <span className="text-paper/80">{formatDate(ticket.createdAt)}</span>
        </span>
        <span>·</span>
        <span>
          <span className="text-muted">{t("updated")}</span>{" "}
          <span className="text-paper/80">{formatDate(ticket.updatedAt)}</span>
        </span>
        {ticket.resolvedAt ? (
          <>
            <span>·</span>
            <span>
              <span className="text-muted">{t("resolved")}</span>{" "}
              <span className="text-lime">{formatDate(ticket.resolvedAt)}</span>
            </span>
          </>
        ) : null}
        <span>·</span>
        <Link
          href={`/users/${ticket.userId}`}
          className="text-paper/80 hover:text-lime"
        >
          {t("viewMember")} →
        </Link>
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1fr_18rem]">
        <div className="flex flex-col gap-4">
          <div className="panel p-4">
            <div className="flex items-center justify-between border-b border-line pb-2">
              <div className="flex items-center gap-2 text-[12px]">
                <span className="text-paper font-medium">
                  {ticket.userName ?? t("unknownMember")}
                </span>
                <span className="kbd">{t("memberLabel")}</span>
                <span className="text-muted num">
                  {[ticket.userEmail, ticket.userPhone]
                    .filter(Boolean)
                    .join(" · ") || "—"}
                </span>
              </div>
              <span className="text-[11px] text-muted num">
                {formatDate(ticket.createdAt)}
              </span>
            </div>
            <p className="mt-3 whitespace-pre-wrap text-[13.5px] leading-relaxed text-paper">
              {ticket.body}
            </p>
            {metaEntries.length > 0 ? (
              <dl className="mt-4 grid grid-cols-2 gap-x-6 gap-y-2 border-t border-line pt-3 text-[11.5px] md:grid-cols-4">
                {metaEntries.map(([k, v]) => (
                  <div key={k} className="flex flex-col gap-0.5 min-w-0">
                    <dt className="text-muted uppercase tracking-wide text-[10px]">
                      {k}
                    </dt>
                    <dd className="truncate text-paper/90 num">
                      {typeof v === "string" ? v : JSON.stringify(v)}
                    </dd>
                  </div>
                ))}
              </dl>
            ) : null}
          </div>

          <div className="panel p-4">
            <div className="flex items-center justify-between border-b border-line pb-2">
              <h2 className="h3">Thread</h2>
              <span className="text-[11px] text-muted num">
                {ticket.messages.length} messages
              </span>
            </div>
            {ticket.messages.length === 0 ? (
              <p className="py-6 text-center text-[12.5px] text-muted">
                No replies yet.
              </p>
            ) : (
              <ul className="mt-2 flex flex-col">
                {ticket.messages.map((m, idx) => {
                  const isAdmin = m.authorRole === "admin";
                  const isInternal = m.isInternalNote;
                  const roleTone = isInternal
                    ? "text-amber-300"
                    : isAdmin
                      ? "text-lime"
                      : "text-muted";
                  return (
                    <li
                      key={m.id}
                      className={`py-3 ${idx > 0 ? "border-t border-line" : ""} ${
                        isInternal
                          ? "-mx-4 bg-amber-400/[0.04] px-4"
                          : ""
                      }`}
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="flex items-center gap-2 text-[12px]">
                          <span className="text-paper font-medium">
                            {m.authorName ?? "Unknown"}
                          </span>
                          {m.authorRole ? (
                            <span className={`kbd ${roleTone}`}>
                              {m.authorRole}
                            </span>
                          ) : null}
                          {isInternal ? (
                            <span className="pill pill-warn">
                              <span className="dot bg-amber-300" />
                              internal
                            </span>
                          ) : null}
                        </div>
                        <span className="text-[11px] text-muted num">
                          {formatTime(m.createdAt)}
                        </span>
                      </div>
                      <p className="mt-1.5 whitespace-pre-wrap text-[13px] leading-relaxed text-paper/95">
                        {m.body}
                      </p>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>

          <div className="panel p-4">
            <div className="mb-3 flex items-center justify-between border-b border-line pb-2">
              <h2 className="h3">{t("reply")}</h2>
              <span className="text-[11px] text-muted">
                {t("internalNote")}
              </span>
            </div>
            <TicketReplyForm action={reply} />
          </div>
        </div>

        <aside className="panel h-fit p-4">
          <div className="mb-3 flex items-center justify-between border-b border-line pb-2">
            <h2 className="h3">{t("controls")}</h2>
            <span className="text-[11px] text-muted">{t("autoSaves")}</span>
          </div>
          <TicketStatusControls
            initialStatus={ticket.status}
            initialPriority={ticket.priority}
            initialCategory={ticket.category}
            initialAssignee={ticket.assignedAdminId}
            currentAdminId={currentAdminId}
            action={update}
          />
        </aside>
      </div>
    </section>
  );
}
