import 'billing_state.dart';

/// Pure input validators and formatters for payment drafts.
/// No BuildContext, no localization — callers decide how to surface errors.
/// Keeping these as plain functions makes them trivially unit-testable and
/// re-usable from any form.
class PaymentValidators {
  const PaymentValidators._();

  static final _digitsOnly = RegExp(r'[^0-9]');
  static final _nameChars = RegExp(r"^[\p{L} .'-]+$", unicode: true);
  static final _aliasChars = RegExp(r'^[A-Za-z0-9._-]+$');

  /// Strips every non-digit from [input]. Used before luhn / length checks.
  static String digitsOnly(String input) => input.replaceAll(_digitsOnly, '');

  // ── Card number ────────────────────────────────────────────────────────

  /// Card number is valid if 13–19 digits AND passes Luhn.
  static bool isCardNumberValid(String input) {
    final digits = digitsOnly(input);
    if (digits.length < 13 || digits.length > 19) return false;
    return _luhn(digits);
  }

  static bool _luhn(String digits) {
    var sum = 0;
    var alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 0x30;
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  /// Detect card network from the BIN. Visa = leading 4, Mastercard = 51-55
  /// or 2221-2720. Anything else currently falls back to Visa — we don't
  /// accept Amex/Discover/JCB in v1.
  static PaymentMethodKind detectNetwork(String input) {
    final d = digitsOnly(input);
    if (d.isEmpty) return PaymentMethodKind.visa;
    if (d.startsWith('4')) return PaymentMethodKind.visa;
    if (d.length >= 2) {
      final p2 = int.tryParse(d.substring(0, 2)) ?? 0;
      if (p2 >= 51 && p2 <= 55) return PaymentMethodKind.mastercard;
    }
    if (d.length >= 4) {
      final p4 = int.tryParse(d.substring(0, 4)) ?? 0;
      if (p4 >= 2221 && p4 <= 2720) return PaymentMethodKind.mastercard;
    }
    return PaymentMethodKind.visa;
  }

  /// "4242424242424242" → "4242 4242 4242 4242".
  static String formatCardNumber(String raw) {
    final d = digitsOnly(raw);
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.writeCharCode(d.codeUnitAt(i));
    }
    return buf.toString();
  }

  static String last4(String input) {
    final d = digitsOnly(input);
    if (d.length < 4) return d;
    return d.substring(d.length - 4);
  }

  // ── Expiry ─────────────────────────────────────────────────────────────

  /// Returns (month, year) if [input] parses as MM/YY or MMYY and the month
  /// is 01-12 and the card has not yet expired. [now] is injectable for test.
  static ({int mm, int yy})? parseExpiry(String input, {DateTime? now}) {
    final d = digitsOnly(input);
    if (d.length != 4) return null;
    final mm = int.tryParse(d.substring(0, 2));
    final yy = int.tryParse(d.substring(2, 4));
    if (mm == null || yy == null) return null;
    if (mm < 1 || mm > 12) return null;
    final today = now ?? DateTime.now();
    final fullYear = 2000 + yy;
    // Card expires at end of the stated month; compare with the first of the
    // next month so "this month" is still valid.
    final endOfMonth = DateTime(fullYear, mm + 1, 1);
    if (!endOfMonth.isAfter(today)) return null;
    return (mm: mm, yy: yy);
  }

  static bool isExpiryValid(String input, {DateTime? now}) =>
      parseExpiry(input, now: now) != null;

  /// "0827" → "08 / 27". Accepts partial input for live formatting.
  static String formatExpiry(String raw) {
    final d = digitsOnly(raw);
    if (d.length <= 2) return d;
    return '${d.substring(0, 2)} / ${d.substring(2, d.length.clamp(2, 4))}';
  }

  // ── CVV ────────────────────────────────────────────────────────────────

  static bool isCvvValid(String input) {
    final d = digitsOnly(input);
    return d.length == 3 || d.length == 4;
  }

  // ── Holder name ────────────────────────────────────────────────────────

  static bool isHolderValid(String input) {
    final trimmed = input.trim();
    if (trimmed.length < 2) return false;
    return _nameChars.hasMatch(trimmed);
  }

  // ── CliQ alias ─────────────────────────────────────────────────────────

  /// CliQ aliases are 3-30 characters, letters / digits / `. _ -`.
  static bool isCliqAliasValid(String input) {
    final trimmed = input.trim();
    if (trimmed.length < 3 || trimmed.length > 30) return false;
    return _aliasChars.hasMatch(trimmed);
  }

  // ── Jordan phone ───────────────────────────────────────────────────────

  /// Valid Jordanian mobile: exactly 9 digits, first digit 7, starts with
  /// 77/78/79 (Zain / Orange / Umniah). Leading zeros and +962 prefixes are
  /// stripped before the check.
  static bool isJordanPhoneValid(String input) {
    final d = _stripJoPrefix(digitsOnly(input));
    if (d.length != 9) return false;
    if (!d.startsWith('7')) return false;
    final p2 = d.substring(0, 2);
    return p2 == '77' || p2 == '78' || p2 == '79';
  }

  /// Normalize any Jordan mobile input to `+9627XXXXXXXX`.
  /// Returns null for invalid input so callers can surface an error.
  static String? normalizeJordanPhone(String input) {
    final d = _stripJoPrefix(digitsOnly(input));
    if (!isJordanPhoneValid(d)) return null;
    return '+962$d';
  }

  /// "+9627XX XXX XXX" → display form "+962 7X XXX XXXX".
  static String formatJordanPhone(String input) {
    final d = _stripJoPrefix(digitsOnly(input));
    if (d.isEmpty) return '';
    final buf = StringBuffer('+962 ');
    for (var i = 0; i < d.length && i < 9; i++) {
      if (i == 2 || i == 5) buf.write(' ');
      buf.writeCharCode(d.codeUnitAt(i));
    }
    return buf.toString();
  }

  static String _stripJoPrefix(String digits) {
    var d = digits;
    if (d.startsWith('00962')) d = d.substring(5);
    if (d.startsWith('962')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }
}
