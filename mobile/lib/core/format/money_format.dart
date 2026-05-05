import '../../l10n/app_localizations.dart';

/// Locale-aware JOD formatter. Uses the existing `billingInvoicePaid`
/// template (`$iso · $amount JOD` / `$iso · $amount د.أ`) as the single
/// source of truth for the currency glyph, so we never hardcode "JOD"
/// or "د.أ" in call sites.
class MoneyFormat {
  const MoneyFormat._();

  /// Formats a whole-JOD amount with the localized currency glyph.
  static String jod(AppLocalizations l, int amount) {
    final templated = l.billingInvoicePaid('', amount);
    const sep = ' · ';
    final idx = templated.indexOf(sep);
    return idx >= 0 ? templated.substring(idx + sep.length) : templated;
  }
}
