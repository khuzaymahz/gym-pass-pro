import Link from "next/link";
import { useTranslations } from "next-intl";

import StatusPill from "@/components/StatusPill";
import EmptyRow from "@/components/users/EmptyRow";
import { formatDateTime } from "@/components/users/format";
import type {
  AdminUserDetailTicket,
  TicketPriority,
  TicketStatus,
} from "@/lib/sdk";

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

/// Support history table for the user detail page.
export default function TicketsSection({
  tickets,
}: {
  tickets: AdminUserDetailTicket[];
}) {
  const t = useTranslations("users.detail");
  const tStatuses = useTranslations("support.statuses");
  const tPriorities = useTranslations("support.priorities");
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h2 className="h2">{t("supportHistory")}</h2>
        <span className="text-[11px] text-muted">
          {tickets.length === 1
            ? t("tickets", { count: tickets.length })
            : t("ticketsPlural", { count: tickets.length })}
        </span>
      </div>
      <div className="panel overflow-hidden">
        {tickets.length === 0 ? (
          <EmptyRow label={t("noTickets")} />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>{t("subject")}</th>
                <th>{t("category")}</th>
                <th>{t("priority")}</th>
                <th>{t("status")}</th>
                <th>{t("updated")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {tickets.map((ticket) => (
                <tr key={ticket.id}>
                  <td>
                    <div className="flex flex-col">
                      <span className="text-paper">{ticket.subject}</span>
                      <span className="text-[11px] text-muted num">
                        #{ticket.id.slice(0, 8)}
                      </span>
                    </div>
                  </td>
                  <td className="capitalize text-muted">{ticket.category}</td>
                  <td>
                    <StatusPill tone={priorityTone(ticket.priority)}>
                      {tPriorities(ticket.priority)}
                    </StatusPill>
                  </td>
                  <td>
                    <StatusPill tone={ticketStatusTone(ticket.status)}>
                      {tStatuses(ticket.status)}
                    </StatusPill>
                  </td>
                  <td className="num text-muted">
                    {formatDateTime(ticket.updatedAt)}
                  </td>
                  <td className="num">
                    <Link
                      href={`/support/${ticket.id}`}
                      className="btn-ghost btn-sm"
                    >
                      {t("openTicket")}
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
