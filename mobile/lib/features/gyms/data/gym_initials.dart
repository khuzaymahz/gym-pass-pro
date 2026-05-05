// `String.characters` lives in package:characters; we pull it via
// flutter/widgets.dart which re-exports it (same approach as the
// other monogram callers in this folder).
import 'package:flutter/widgets.dart';

/// Build a short monogram from a gym's name. Returns at most two
/// uppercase letters — one per word for multi-word names, the first
/// letter for single-word names. Used as the fallback inside the
/// circular logo slot whenever a gym has no `logo_url` on file.
///
/// Examples:
///   - "Iron Forge"      → "IF"
///   - "Bedford Yoga"    → "BY"
///   - "Apex CrossFit"   → "AC"
///   - "Halo"            → "H"
///   - "  "              → "·"  (defensive: never returns empty)
///
/// Uses `String.characters` (grapheme clusters) so an Arabic name
/// whose first "letter" is a multi-codepoint composition reads as a
/// single visible character — same approach as `_MiniAvatar` on
/// /plans, keeps the avatar layer consistent across the app.
String gymInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '·';
  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '·';
  if (words.length == 1) {
    return words.first.characters.first.toUpperCase();
  }
  // Two letters: first grapheme of the first word + first grapheme
  // of the last word. Skipping middle words handles "Apex Cross Fit"
  // → "AF" cleanly without crowding three letters into a small disc.
  final first = words.first.characters.first.toUpperCase();
  final last = words.last.characters.first.toUpperCase();
  return '$first$last';
}
