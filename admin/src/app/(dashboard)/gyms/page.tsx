import Image from "next/image";
import Link from "next/link";
import { getTranslations } from "next-intl/server";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { listGyms, resolvePhotoUrl, type GymRead } from "@/lib/gyms";

const CATEGORY_OPTIONS = ["gym", "crossfit", "martial", "yoga"] as const;
const TIER_OPTIONS = ["silver", "gold", "platinum", "diamond"] as const;
const AUDIENCE_OPTIONS = ["mixed", "female_only", "male_only"] as const;

type SearchParams = {
  page?: string;
  category?: string;
  tier?: string;
  audience?: string;
  q?: string;
};

const PAGE_SIZE = 30;

export default async function GymsPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const t = await getTranslations("gyms");
  const tStats = await getTranslations("gyms.stats");
  const tFilters = await getTranslations("gyms.filters");
  const tCategory = await getTranslations("gyms.filters.category");
  const tTable = await getTranslations("gyms.table");
  const tEmpty = await getTranslations("gyms.empty");

  const pageParam = Math.max(1, Number.parseInt(searchParams.page ?? "1", 10) || 1);
  const category = searchParams.category as
    | (typeof CATEGORY_OPTIONS)[number]
    | undefined;
  const tier = searchParams.tier as (typeof TIER_OPTIONS)[number] | undefined;
  const audience = searchParams.audience as
    | (typeof AUDIENCE_OPTIONS)[number]
    | undefined;
  const q = (searchParams.q ?? "").trim().toLowerCase();

  // Pull a big enough window for client-side filter; the backend endpoint
  // does not yet support these filters server-side. Backend caps pageSize at 100.
  const firstPage = await listGyms(1, 100);
  let items = firstPage.items;

  if (category) items = items.filter((g) => g.category.toLowerCase() === category);
  if (tier) items = items.filter((g) => g.requiredTier === tier);
  if (audience) items = items.filter((g) => g.audienceGender === audience);
  if (q) {
    items = items.filter(
      (g) =>
        g.nameEn.toLowerCase().includes(q) ||
        g.nameAr.includes(q) ||
        g.area.toLowerCase().includes(q) ||
        g.slug.toLowerCase().includes(q),
    );
  }

  const total = items.length;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const page = Math.min(pageParam, totalPages);
  const offset = (page - 1) * PAGE_SIZE;
  const pageItems = items.slice(offset, offset + PAGE_SIZE);

  const activeCount = firstPage.items.filter((g) => g.isActive).length;
  const tierCounts: Record<string, number> = {
    silver: 0,
    gold: 0,
    platinum: 0,
    diamond: 0,
  };
  for (const g of firstPage.items)
    tierCounts[g.requiredTier] = (tierCounts[g.requiredTier] ?? 0) + 1;

  const hrefFor = (overrides: Partial<SearchParams>) => {
    const merged: SearchParams = {
      category: searchParams.category,
      tier: searchParams.tier,
      audience: searchParams.audience,
      q: searchParams.q,
      page: searchParams.page,
      ...overrides,
    };
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v) qs.set(k, v);
    }
    const s = qs.toString();
    return s ? `/gyms?${s}` : "/gyms";
  };

  return (
    <section className="flex flex-col gap-5">
      <Toolbar
        title={t("title")}
        description={t("description")}
        count={{ label: t("onNetwork"), value: firstPage.items.length }}
        actions={
          <Link href="/gyms/new" className="btn-primary">
            {t("addGym")}
          </Link>
        }
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-6">
        <StatTile label={tStats("total")} value={firstPage.items.length} />
        <StatTile
          label={tStats("active")}
          value={activeCount}
          tone={activeCount === firstPage.items.length ? "ok" : "default"}
        />
        <StatTile label={tStats("silver")} value={tierCounts.silver} />
        <StatTile label={tStats("gold")} value={tierCounts.gold} />
        <StatTile label={tStats("platinum")} value={tierCounts.platinum} />
        <StatTile label={tStats("diamond")} value={tierCounts.diamond} />
      </div>

      <FilterBar>
        <Segmented
          value={category}
          options={CATEGORY_OPTIONS}
          labelFor={(o) => tCategory(o)}
          hrefFor={(o) => hrefFor({ category: o, page: undefined })}
        />
        <Segmented
          value={tier}
          options={TIER_OPTIONS}
          labelFor={(o) => o.charAt(0).toUpperCase() + o.slice(1)}
          hrefFor={(o) => hrefFor({ tier: o, page: undefined })}
          allLabel={tFilters("allTiers")}
        />
        <Segmented
          value={audience}
          options={AUDIENCE_OPTIONS}
          labelFor={(o) => tFilters(`audience.${o}`)}
          hrefFor={(o) => hrefFor({ audience: o, page: undefined })}
          allLabel={tFilters("allAudiences")}
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={searchParams.q}
            placeholder={tFilters("search")}
            action="/gyms"
            hidden={{
              category: searchParams.category,
              tier: searchParams.tier,
              audience: searchParams.audience,
            }}
          />
        </div>
      </FilterBar>

      {pageItems.length === 0 ? (
        <EmptyState
          title={total === 0 ? tEmpty("noMatch") : tEmpty("noRows")}
          hint={
            total === 0 ? tEmpty("noMatchHint") : tEmpty("noRowsHint")
          }
          action={
            firstPage.items.length === 0
              ? { href: "/gyms/new", label: t("addGym") }
              : undefined
          }
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>{tTable("venue")}</th>
                <th>{tTable("area")}</th>
                <th>{tTable("category")}</th>
                <th>{tTable("tier")}</th>
                <th>{tTable("audience")}</th>
                <th className="num">{tTable("perVisit")}</th>
                <th className="num">{tTable("photos")}</th>
                <th>{tTable("status")}</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {pageItems.map((g) => (
                <GymRow
                  key={g.id}
                  g={g}
                  liveLabel={tTable("live")}
                  offLabel={tTable("off")}
                  editLabel={tTable("edit")}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Pager
        page={page}
        totalPages={totalPages}
        total={total}
        hrefFor={(target) => hrefFor({ page: String(target) })}
      />
    </section>
  );
}

function GymRow({
  g,
  liveLabel,
  offLabel,
  editLabel,
}: {
  g: GymRead;
  liveLabel: string;
  offLabel: string;
  editLabel: string;
}) {
  return (
    <tr>
      <td className="min-w-0">
        <Link
          href={`/gyms/${g.id}`}
          className="flex min-w-0 items-center gap-3 leading-tight hover:text-lime"
        >
          <GymThumb logoUrl={g.logoUrl} name={g.nameEn} />
          <span className="flex min-w-0 flex-col">
            <span className="truncate font-medium text-paper">{g.nameEn}</span>
            <span className="truncate text-[11.5px] text-muted">
              {g.nameAr} · {g.slug}
            </span>
          </span>
        </Link>
      </td>
      <td className="text-paper/80">{g.area}</td>
      <td className="capitalize text-paper/80">{g.category}</td>
      <td>
        <span className="kbd capitalize">{g.requiredTier}</span>
      </td>
      <td>
        <AudiencePill audience={g.audienceGender} />
      </td>
      <td className="num">
        <span className="text-paper">{g.perVisitRateJod}</span>
        <span className="ml-1 text-[10.5px] text-muted">JOD</span>
      </td>
      <td className="num">
        <span className={g.photoCount > 0 ? "text-paper" : "text-muted"}>
          {g.photoCount}
        </span>
      </td>
      <td>
        <StatusPill tone={g.isActive ? "ok" : "mute"}>
          {g.isActive ? liveLabel : offLabel}
        </StatusPill>
      </td>
      <td className="num text-right">
        <Link href={`/gyms/${g.id}`} className="btn-ghost btn-sm">
          {editLabel} →
        </Link>
      </td>
    </tr>
  );
}

function AudiencePill({ audience }: { audience: GymRead["audienceGender"] }) {
  if (audience === "female_only") {
    return (
      <span className="inline-flex items-center rounded-md border border-pink-300/30 bg-pink-300/10 px-2 py-0.5 text-[11px] font-medium text-pink-200">
        Women only
      </span>
    );
  }
  if (audience === "male_only") {
    return (
      <span className="inline-flex items-center rounded-md border border-blue-300/30 bg-blue-300/10 px-2 py-0.5 text-[11px] font-medium text-blue-200">
        Men only
      </span>
    );
  }
  return <span className="text-[12px] text-muted">Open</span>;
}

function GymThumb({ logoUrl, name }: { logoUrl?: string | null; name: string }) {
  const initial = name.trim().charAt(0).toUpperCase() || "·";
  if (logoUrl) {
    return (
      <Image
        src={resolvePhotoUrl(logoUrl)}
        alt=""
        width={28}
        height={28}
        className="h-7 w-7 flex-shrink-0 rounded-md border border-line object-cover"
        unoptimized
      />
    );
  }
  return (
    <span
      aria-hidden
      className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-md border border-line bg-surface-2 text-[11px] font-semibold text-muted"
    >
      {initial}
    </span>
  );
}
