import Link from "next/link";
import type { ReactNode } from "react";

export function FilterBar({ children }: { children: ReactNode }) {
  return (
    <div className="mb-4 flex flex-wrap items-center gap-2">{children}</div>
  );
}

export function Segmented<T extends string>({
  value,
  options,
  labelFor,
  hrefFor,
  allLabel = "All",
}: {
  value: T | undefined;
  options: readonly T[];
  labelFor: (o: T) => string;
  hrefFor: (o: T | undefined) => string;
  allLabel?: string;
}) {
  return (
    <div className="seg">
      <Link
        href={hrefFor(undefined)}
        className={value === undefined ? "is-active" : ""}
      >
        {allLabel}
      </Link>
      {options.map((o) => (
        <Link
          key={o}
          href={hrefFor(o)}
          className={value === o ? "is-active" : ""}
        >
          {labelFor(o)}
        </Link>
      ))}
    </div>
  );
}

export function SearchInput({
  name = "q",
  defaultValue,
  placeholder,
  hidden,
  action,
}: {
  name?: string;
  defaultValue?: string;
  placeholder?: string;
  hidden?: Record<string, string | undefined>;
  action: string;
}) {
  return (
    <form
      action={action}
      method="get"
      autoComplete="off"
      className="relative flex items-center"
    >
      <svg
        viewBox="0 0 16 16"
        className="pointer-events-none absolute left-2.5 h-3.5 w-3.5 text-muted"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
      >
        <circle cx="7" cy="7" r="5" />
        <path d="m11 11 3 3" strokeLinecap="round" />
      </svg>
      <input
        key={`${name}-${defaultValue ?? ""}`}
        name={name}
        defaultValue={defaultValue ?? ""}
        placeholder={placeholder ?? "Search"}
        autoComplete="off"
        className="input input-sm h-8 w-64 pl-8"
        suppressHydrationWarning
      />
      {hidden
        ? Object.entries(hidden).map(([k, v]) =>
            v ? <input key={k} type="hidden" name={k} value={v} /> : null,
          )
        : null}
    </form>
  );
}
