import Link from "next/link";

type PagerProps = {
  page: number;
  totalPages: number;
  total: number;
  hrefFor: (target: number) => string;
};

export default function Pager({ page, totalPages, total, hrefFor }: PagerProps) {
  if (total === 0) return null;

  return (
    <div className="mt-4 flex items-center justify-between border-t border-line pt-3 text-[12px] text-muted num">
      <span>
        <span className="text-paper">{total.toLocaleString()}</span> total · page{" "}
        <span className="text-paper">{page}</span> of {totalPages}
      </span>
      <div className="flex items-center gap-1">
        {page > 1 ? (
          <Link href={hrefFor(page - 1)} className="btn-secondary btn-sm">
            ← Prev
          </Link>
        ) : (
          <span className="btn-secondary btn-sm cursor-not-allowed opacity-40">
            ← Prev
          </span>
        )}
        {page < totalPages ? (
          <Link href={hrefFor(page + 1)} className="btn-secondary btn-sm">
            Next →
          </Link>
        ) : (
          <span className="btn-secondary btn-sm cursor-not-allowed opacity-40">
            Next →
          </span>
        )}
      </div>
    </div>
  );
}
