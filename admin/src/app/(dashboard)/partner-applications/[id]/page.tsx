import { notFound } from "next/navigation";
import { getTranslations } from "next-intl/server";

import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { env } from "@/lib/env";
import { AdminSDK } from "@/lib/sdk";

import { ReviewActions } from "./ReviewActions";

export const dynamic = "force-dynamic";

function mediaUrl(raw: string): string {
  // Backend issues URLs as `/media/applications/<id>/<file>` or an
  // absolute URL depending on settings. Either is fine inside an
  // <img src>; absolute passes through; relative gets prefixed with
  // the env-validated API base. Previously this fell back to a
  // hardcoded `https://api.gym-pass.net` literal that bypassed the
  // Zod env-schema check — staging builds would silently serve
  // images from the wrong host. `env.API_BASE_URL` is the single
  // source of truth.
  if (raw.startsWith("http")) return raw;
  return `${env.API_BASE_URL}${raw}`;
}

export default async function PartnerApplicationDetailPage(props: {
  params: Promise<{ id: string }>;
}) {
  const params = await props.params;
  const t = await getTranslations("partnerApplications");

  let app;
  try {
    app = await AdminSDK.getPartnerApplication(params.id);
  } catch {
    notFound();
  }

  return (
    <section className="flex flex-col gap-6">
      <Toolbar
        title={app.gymNameEn}
        description={`${app.gymArea} · ${app.gymCategory}`}
        actions={
          <StatusPill
            tone={
              app.status === "approved"
                ? "ok"
                : app.status === "rejected"
                ? "bad"
                : "warn"
            }
          >
            {t(`statuses.${app.status}`)}
          </StatusPill>
        }
      />

      {/* Review actions sit at the top so the admin sees them
          immediately — buried below the fold would mean every
          review requires a scroll. The component handles the
          confirm prompts and toasts internally. */}
      {app.status === "pending" ? (
        <ReviewActions applicationId={app.id} />
      ) : (
        <div className="panel p-4 text-[13px] text-muted">
          {app.status === "approved" ? (
            <>
              {t("approvedSummary")}
              {app.approvedGymId ? (
                <>
                  {" "}
                  <a
                    href={`/gyms/${app.approvedGymId}`}
                    className="text-lime underline"
                  >
                    {t("viewGym")}
                  </a>
                </>
              ) : null}
            </>
          ) : (
            t("rejectedSummary")
          )}
          {app.adminNotes ? (
            <div className="mt-2 text-[12.5px] text-paper/80">
              <span className="text-muted">{t("notesLabel")}: </span>
              {app.adminNotes}
            </div>
          ) : null}
        </div>
      )}

      {/* Owner block */}
      <div className="panel flex flex-col gap-3 p-5">
        <h2 className="label">{t("sectionOwner")}</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <FieldRow label={t("ownerName")} value={app.ownerName} />
          <FieldRow label={t("ownerPhone")} value={app.ownerPhone} dir="ltr" />
          <FieldRow
            label={t("ownerEmail")}
            value={app.ownerEmail ?? "—"}
            dir="ltr"
          />
        </div>
      </div>

      {/* Gym block */}
      <div className="panel flex flex-col gap-3 p-5">
        <h2 className="label">{t("sectionGym")}</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <FieldRow label={t("gymNameEn")} value={app.gymNameEn} dir="ltr" />
          <FieldRow label={t("gymNameAr")} value={app.gymNameAr} />
          <FieldRow label={t("gymArea")} value={app.gymArea} />
          <FieldRow label={t("gymPhone")} value={app.gymPhone ?? "—"} dir="ltr" />
          <FieldRow
            label={t("gymAddressEn")}
            value={app.gymAddressEn}
            dir="ltr"
          />
          <FieldRow label={t("gymAddressAr")} value={app.gymAddressAr} />
          <FieldRow label={t("category")} value={app.gymCategory} />
          <FieldRow label={t("audience")} value={app.gymAudienceGender} />
          <FieldRow
            label={t("coords")}
            value={`${app.gymLat}, ${app.gymLng}`}
            dir="ltr"
          />
        </div>
      </div>

      {/* Media block */}
      {app.logoUrl || app.photoUrls.length > 0 ? (
        <div className="panel flex flex-col gap-3 p-5">
          <h2 className="label">{t("sectionMedia")}</h2>
          {app.logoUrl ? (
            <div>
              <div className="text-[11px] uppercase tracking-wide text-muted mb-1">
                {t("logo")}
              </div>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={mediaUrl(app.logoUrl)}
                alt=""
                className="h-20 w-20 rounded border border-line object-cover"
              />
            </div>
          ) : null}
          {app.photoUrls.length > 0 ? (
            <div>
              <div className="text-[11px] uppercase tracking-wide text-muted mb-1">
                {t("photos")} ({app.photoUrls.length})
              </div>
              <div className="flex flex-wrap gap-2">
                {app.photoUrls.map((url) => (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    key={url}
                    src={mediaUrl(url)}
                    alt=""
                    className="h-24 w-24 rounded border border-line object-cover"
                  />
                ))}
              </div>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}

function FieldRow({
  label,
  value,
  dir,
}: {
  label: string;
  value: string;
  dir?: "ltr" | "rtl";
}) {
  return (
    <div>
      <div className="text-[11px] uppercase tracking-wide text-muted mb-1">
        {label}
      </div>
      <div className="text-[13px] text-paper" dir={dir}>
        {value}
      </div>
    </div>
  );
}
