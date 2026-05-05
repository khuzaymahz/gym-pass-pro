import Link from "next/link";

import EmptyState from "@/components/EmptyState";
import { FilterBar, Segmented, SearchInput } from "@/components/FilterBar";
import Pager from "@/components/Pager";
import StatTile from "@/components/StatTile";
import StatusPill from "@/components/StatusPill";
import Toolbar from "@/components/Toolbar";
import { listGyms, resolvePhotoUrl, type GymRead } from "@/lib/gyms";

const CATEGORY_OPTIONS = ["gym", "crossfit", "martial", "yoga"] as const;
const TIER_OPTIONS = ["silver", "gold", "platinum", "diamond"] as const;

type SearchParams = {
  page?: string;
  category?: string;
  tier?: string;
  q?: string;
};

const PAGE_SIZE = 30;

export default async function GymsPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const pageParam = Math.max(1, Number.parseInt(searchParams.page ?? "1", 10) || 1);
  const category = searchParams.category as
    | (typeof CATEGORY_OPTIONS)[number]
    | undefined;
  const tier = searchParams.tier as (typeof TIER_OPTIONS)[number] | undefined;
  const q = (searchParams.q ?? "").trim().toLowerCase();

  // Pull a big enough window for client-side filter; the backend endpoint
  // does not yet support these filters server-side. Backend caps pageSize at 100.
  const firstPage = await listGyms(1, 100);
  let items = firstPage.items;

  if (category) items = items.filter((g) => g.category.toLowerCase() === category);
  if (tier) items = items.filter((g) => g.requiredTier === tier);
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
        title="Gyms"
        description="Partner venues on the network. Edit pricing, tier, and status per row."
        count={{ label: "on network", value: firstPage.items.length }}
        actions={
          <Link href="/gyms/new" className="btn-primary">
            Add gym
          </Link>
        }
      />

      <div className="grid grid-cols-2 gap-2 md:grid-cols-6">
        <StatTile label="Total" value={firstPage.items.length} />
        <StatTile
          label="Active"
          value={activeCount}
          tone={activeCount === firstPage.items.length ? "ok" : "default"}
        />
        <StatTile label="Silver" value={tierCounts.silver} />
        <StatTile label="Gold" value={tierCounts.gold} />
        <StatTile label="Platinum" value={tierCounts.platinum} />
        <StatTile label="Diamond" value={tierCounts.diamond} />
      </div>

      <FilterBar>
        <Segmented
          value={category}
          options={CATEGORY_OPTIONS}
          labelFor={(o) =>
            ({ gym: "Gyms", crossfit: "CrossFit", martial: "Martial", yoga: "Yoga" })[o]
          }
          hrefFor={(o) => hrefFor({ category: o, page: undefined })}
        />
        <Segmented
          value={tier}
          options={TIER_OPTIONS}
          labelFor={(o) => o.charAt(0).toUpperCase() + o.slice(1)}
          hrefFor={(o) => hrefFor({ tier: o, page: undefined })}
          allLabel="All tiers"
        />
        <div className="ml-auto">
          <SearchInput
            defaultValue={searchParams.q}
            placeholder="Search name, area, slug…"
            action="/gyms"
            hidden={{ category: searchParams.category, tier: searchParams.tier }}
          />
        </div>
      </FilterBar>

      {pageItems.length === 0 ? (
        <EmptyState
          title={total === 0 ? "No gyms match" : "No rows on this page"}
          hint={
            total === 0
              ? "Adjust filters, clear search, or add your first venue."
              : "Try the previous page."
          }
          action={
            firstPage.items.length === 0
              ? { href: "/gyms/new", label: "Add gym" }
              : undefined
          }
        />
      ) : (
        <div className="panel overflow-hidden">
          <table className="table">
            <thead>
              <tr>
                <th>Venue</th>
                <th>Area</th>
                <th>Category</th>
                <th>Tier</th>
                <th className="num">Per visit</th>
                <th className="num">Photos</th>
                <th>Status</th>
                <th className="w-0" />
              </tr>
            </thead>
            <tbody>
              {pageItems.map((g) => (
                <GymRow key={g.id} g={g} />
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

function GymRow({ g }: { g: GymRead }) {
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
          {g.isActive ? "Live" : "Off"}
        </StatusPill>
      </td>
      <td className="num text-right">
        <Link href={`/gyms/${g.id}`} className="btn-ghost btn-sm">
          Edit →
        </Link>
      </td>
    </tr>
  );
}

function GymThumb({ logoUrl, name }: { logoUrl?: string | null; name: string }) {
  const initial = name.trim().charAt(0).toUpperCase() || "·";
  if (logoUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={resolvePhotoUrl(logoUrl)}
        alt=""
        className="h-7 w-7 flex-shrink-0 rounded-md border border-line object-cover"
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
