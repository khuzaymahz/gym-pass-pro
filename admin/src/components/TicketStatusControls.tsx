"use client";

import { useState, useTransition } from "react";

import type { ActionResult } from "@/lib/action-result";
import type {
  SupportTicketListItem,
  TicketCategory,
  TicketPriority,
  TicketStatus,
  TicketUpdateBody,
} from "@/lib/sdk";

const STATUSES: TicketStatus[] = [
  "open",
  "in_progress",
  "waiting_user",
  "resolved",
  "closed",
];
const PRIORITIES: TicketPriority[] = ["low", "normal", "high", "urgent"];
const CATEGORIES: TicketCategory[] = [
  "bug",
  "payment",
  "account",
  "gym_issue",
  "feature",
  "complaint",
  "other",
];

type Props = {
  initialStatus: TicketStatus;
  initialPriority: TicketPriority;
  initialCategory: TicketCategory;
  initialAssignee: string | null;
  currentAdminId: string;
  action: (
    body: TicketUpdateBody,
  ) => Promise<ActionResult<SupportTicketListItem>>;
};

export default function TicketStatusControls({
  initialStatus,
  initialPriority,
  initialCategory,
  initialAssignee,
  currentAdminId,
  action,
}: Props) {
  const [status, setStatus] = useState<TicketStatus>(initialStatus);
  const [priority, setPriority] = useState<TicketPriority>(initialPriority);
  const [category, setCategory] = useState<TicketCategory>(initialCategory);
  const [assignee, setAssignee] = useState<string | null>(initialAssignee);
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState<{ tone: "ok" | "err"; text: string } | null>(
    null,
  );

  function submit(body: TicketUpdateBody) {
    setMessage(null);
    startTransition(async () => {
      const result = await action(body);
      if (result.ok) {
        setMessage({ tone: "ok", text: "Updated." });
        if (result.data) {
          setStatus(result.data.status);
          setPriority(result.data.priority);
          setCategory(result.data.category);
          setAssignee(result.data.assignedAdminId);
        }
      } else {
        setMessage({ tone: "err", text: result.message });
      }
    });
  }

  return (
    <div className="flex flex-col gap-3">
      <Field label="Status">
        <select
          className="select input-sm"
          value={status}
          disabled={pending}
          onChange={(e) => {
            const next = e.target.value as TicketStatus;
            setStatus(next);
            submit({ status: next });
          }}
        >
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {s.replace("_", " ")}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Priority">
        <select
          className="select input-sm"
          value={priority}
          disabled={pending}
          onChange={(e) => {
            const next = e.target.value as TicketPriority;
            setPriority(next);
            submit({ priority: next });
          }}
        >
          {PRIORITIES.map((p) => (
            <option key={p} value={p}>
              {p}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Category">
        <select
          className="select input-sm"
          value={category}
          disabled={pending}
          onChange={(e) => {
            const next = e.target.value as TicketCategory;
            setCategory(next);
            submit({ category: next });
          }}
        >
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {c.replace("_", " ")}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Assignee">
        {assignee === currentAdminId ? (
          <button
            type="button"
            disabled={pending}
            onClick={() => {
              setAssignee(null);
              submit({ clearAssignee: true });
            }}
            className="btn-secondary btn-sm w-full"
          >
            Unassign me
          </button>
        ) : (
          <button
            type="button"
            disabled={pending}
            onClick={() => {
              setAssignee(currentAdminId);
              submit({ assignedAdminId: currentAdminId });
            }}
            className="btn-primary btn-sm w-full"
          >
            Assign to me
          </button>
        )}
        <p className="mt-1 text-[11px] text-muted num">
          {assignee ? `Assigned: ${assignee.slice(0, 8)}…` : "Unassigned"}
        </p>
      </Field>

      {message ? (
        <p
          className={`text-[12px] ${
            message.tone === "ok" ? "text-lime" : "text-red-300"
          }`}
        >
          {message.text}
        </p>
      ) : null}
    </div>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
    </label>
  );
}
