import Link from "next/link";

type PagerProps = {
  page: number;
  totalPages: number;
  total: number;
  hrefFor: (target: number) => string;
};

function Chevron({ dir }: { dir: "left" | "right" }) {
  return (
    <svg
      viewBox="0 0 16 16"
      className="h-3.5 w-3.5"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {dir === "left" ? <path d="M10 3 5 8l5 5" /> : <path d="M6 3l5 5-5 5" />}
    </svg>
  );
}

export default function Pager({ page, totalPages, total, hrefFor }: PagerProps) {
  if (total === 0) return null;

  const prevDisabled = page <= 1;
  const nextDisabled = page >= totalPages;
  const navBase =
    "inline-flex h-7 w-7 items-center justify-center rounded-md border border-line-2 bg-surface text-muted transition-all duration-150 ease-out";

  return (
    <div className="mt-4 flex items-center justify-between border-t border-line pt-3 text-[12px] text-muted">
      <span className="num">
        <span className="font-medium text-paper">{total.toLocaleString()}</span>{" "}
        total · page <span className="font-medium text-paper">{page}</span> of{" "}
        {totalPages}
      </span>
      <div className="flex items-center gap-1.5">
        {prevDisabled ? (
          <span className={`${navBase} cursor-not-allowed opacity-40`}>
            <Chevron dir="left" />
          </span>
        ) : (
          <Link
            href={hrefFor(page - 1)}
            aria-label="Previous page"
            className={`${navBase} hover:border-line-2 hover:bg-surface-1 hover:text-paper`}
          >
            <Chevron dir="left" />
          </Link>
        )}
        {nextDisabled ? (
          <span className={`${navBase} cursor-not-allowed opacity-40`}>
            <Chevron dir="right" />
          </span>
        ) : (
          <Link
            href={hrefFor(page + 1)}
            aria-label="Next page"
            className={`${navBase} hover:border-line-2 hover:bg-surface-1 hover:text-paper`}
          >
            <Chevron dir="right" />
          </Link>
        )}
      </div>
    </div>
  );
}
