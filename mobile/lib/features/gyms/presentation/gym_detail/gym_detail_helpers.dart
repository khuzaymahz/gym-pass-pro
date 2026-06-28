import 'package:flutter/material.dart';

import '../../../../core/theme/gp_text.dart';
import '../../../../core/theme/gp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/opening_hours.dart';

/// Converts a 24-hour `"HH:MM"` string to a locale-aware AM/PM string.
/// Returns the original string unchanged if it can't be parsed.
String formatAmPm(String hhmm, AppLocalizations l) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = parts[1];
  if (h == null) return hhmm;
  final suffix = h < 12 ? l.gymTimeAm : l.gymTimePm;
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $suffix';
}

String resolvePhotoUrl(String mediaBase, String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '$mediaBase$url';
}

/// Small uppercase section eyebrow, matching the "About" header on the
/// gym detail page.
Widget sectionHeader(GpColors gp, String title) => Text(
      title.toUpperCase(),
      style: GPText.mono(size: 10, letterSpacing: 1.8, color: gp.muted),
    );

/// Map a weekday (1=Mon … 7=Sun) to its localized short name. Shared
/// by the header status line and the expandable hours list so the two
/// never drift.
String dayShortName(AppLocalizations l, int weekday) {
  switch (weekday) {
    case 1:
      return l.gymDayMon;
    case 2:
      return l.gymDayTue;
    case 3:
      return l.gymDayWed;
    case 4:
      return l.gymDayThu;
    case 5:
      return l.gymDayFri;
    case 6:
      return l.gymDaySat;
    default:
      return l.gymDaySun;
  }
}

/// Compose the localized one-line open/closed status (e.g. "Open now ·
/// Closes 23:00"). Null when hours are unknown so callers can hide the
/// whole cluster rather than printing a hardcoded fallback.
String? openStatusLine(AppLocalizations l, OpenStatus s) {
  if (s.always) return l.gymStatusOpen247;
  if (s.isOpen) {
    final closes = s.boundaryTime;
    return closes == null
        ? l.gymStatusOpen
        : '${l.gymStatusOpen} · ${l.gymStatusClosesAt(formatAmPm(closes, l))}';
  }
  final t = s.boundaryTime;
  if (t == null) return l.gymStatusClosed;
  final tFmt = formatAmPm(t, l);
  final String opens;
  if (s.nextOpenIsToday) {
    opens = l.gymStatusOpensAt(tFmt);
  } else if (s.nextOpenIsTomorrow) {
    opens = l.gymStatusOpensTomorrow(tFmt);
  } else if (s.nextOpenWeekday != null) {
    opens = l.gymStatusOpensDay(dayShortName(l, s.nextOpenWeekday!), tFmt);
  } else {
    return l.gymStatusClosed;
  }
  return '${l.gymStatusClosed} · $opens';
}
