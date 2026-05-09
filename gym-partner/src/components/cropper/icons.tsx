/// Tiny SVG glyphs used inside the cropper bundle. Kept colocated
/// because they don't appear elsewhere — promoting them to a global
/// icon library would be premature.

const STROKE_PROPS = {
  fill: "none",
  stroke: "currentColor",
  strokeLinecap: "round",
  strokeLinejoin: "round",
} as const;

export function CloseIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      strokeWidth="2"
      aria-hidden
      {...STROKE_PROPS}
    >
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  );
}

export function PlusIcon() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      strokeWidth="2.4"
      aria-hidden
      {...STROKE_PROPS}
    >
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  );
}

export function MinusIcon() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      strokeWidth="2.4"
      aria-hidden
      {...STROKE_PROPS}
    >
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  );
}
