/**
 * GYMPASS wordmark — mirrors `mobile/lib/core/widgets/wordmark.dart`
 * 1:1 so the brand identity feels continuous between the member app
 * and this operator portal. `GYM` paints in the current
 * foreground colour (so it inverts cleanly between light and dark
 * mode), `PASS` paints in the brand amber accent. Italic Archivo
 * Black, ultra-bold, with a slight negative letter-spacing
 * matching the Flutter implementation's `letterSpacing: -size *
 * 0.045` rule.
 *
 * The wordmark is a logo, not translatable text — the surrounding
 * locale's text-direction does not flip it. We force `dir="ltr"`
 * on the span so an Arabic page doesn't render it as "PASSGYM".
 */

type WordmarkProps = {
  /** Pixel size of the wordmark (drives both height and the
   *  proportional negative letter-spacing). */
  size?: number;
  /** Optional CSS class for the outer span. */
  className?: string;
};

export function Wordmark({ size = 22, className = "" }: WordmarkProps) {
  return (
    <span
      dir="ltr"
      className={`inline-flex items-baseline font-display italic ${className}`}
      style={{
        // Inline because the value depends on the dynamic `size` —
        // can't be a Tailwind class.
        fontSize: `${size}px`,
        lineHeight: 1,
        letterSpacing: `${(-size * 0.045).toFixed(2)}px`,
        fontWeight: 900,
      }}
    >
      <span className="text-paper">GYM</span>
      <span className="text-accent">PASS</span>
    </span>
  );
}
