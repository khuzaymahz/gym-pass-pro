"use client";

/// Generic segmented control. The cropper uses it for the
/// fit-mode toggle (Fill / Contain). Kept here colocated with the
/// cropper bundle since that's its only caller today; promote it
/// to a top-level shared component if a second use-case lands.
export function SegmentedControl<T extends string>({
  value,
  options,
  disabled,
  onChange,
}: {
  value: T;
  options: { value: T; label: string }[];
  disabled?: boolean;
  onChange: (next: T) => void;
}) {
  return (
    <div
      className={`seg ${disabled ? "pointer-events-none opacity-50" : ""}`}
      role="group"
      aria-disabled={disabled}
    >
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          className={value === o.value ? "is-active" : ""}
          onClick={() => onChange(o.value)}
          disabled={disabled}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
