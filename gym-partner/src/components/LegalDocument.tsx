import { getTranslations } from "next-intl/server";

/// Server component that renders a numbered legal document from the
/// `legal.<kind>` namespace in messages/{locale}.json. Each section is
/// a `(headline, body)` tuple; body strings honour `\n` newlines so a
/// translator can group bullet-style clauses without dragging in a
/// markdown parser.
///
/// **IMPORTANT**: the copy in `messages/*.json` under `legal.terms`
/// and `legal.privacy` is structural placeholder. Before the portal
/// reaches production, the clauses must be reviewed by counsel. The
/// data flows described are accurate (PII masking at the partner
/// API layer, audit-log retention, sub-processor list) — the lawyer's
/// job is wording + jurisdiction adaptation, not fact-gathering.
export async function LegalDocument({
  kind,
}: {
  kind: "terms" | "privacy";
}) {
  const t = await getTranslations(`legal.${kind}`);
  const tLegal = await getTranslations("legal");
  // next-intl exposes a `raw` accessor for non-string structured
  // values. We need it here because the section list is an array of
  // objects, not a single key. The cast is tight to what the JSON
  // contract guarantees.
  const sections = t.raw("sections") as {
    headline: string;
    body: string;
  }[];

  return (
    <article className="flex flex-col gap-10">
      <header className="flex flex-col gap-3 border-b border-line pb-8">
        <p className="tracked text-[10.5px] text-muted">{t("subtitle")}</p>
        <h1 className="text-[34px] leading-[1.05] font-semibold tracking-[-0.01em] text-paper">
          {t("title")}
        </h1>
        <p className="num text-[11px] tracking-[0.12em] text-muted uppercase">
          {tLegal("lastUpdatedLabel")} · {t("updatedAt")}
        </p>
      </header>

      <ol className="flex flex-col gap-7">
        {sections.map((section, idx) => (
          <li
            key={`${kind}-${idx}`}
            className="flex flex-col gap-2"
            id={`section-${idx + 1}`}
          >
            <div className="flex items-baseline gap-3">
              <span
                className="num text-[11px] tracking-[0.18em] text-muted"
                aria-hidden
              >
                {String(idx + 1).padStart(2, "0")}
              </span>
              <h2 className="text-[16px] font-semibold text-paper">
                {section.headline}
              </h2>
            </div>
            {/* Body lines may include `\n` for paragraph breaks — we
                split rather than reach for markdown so a translator
                doesn't have to learn syntax to introduce a new
                paragraph. */}
            <div className="flex flex-col gap-3 ps-7">
              {section.body.split("\n").map((para, pIdx) => (
                <p
                  key={pIdx}
                  className="text-[13.5px] leading-[1.65] text-paper/70"
                >
                  {para}
                </p>
              ))}
            </div>
          </li>
        ))}
      </ol>
    </article>
  );
}
