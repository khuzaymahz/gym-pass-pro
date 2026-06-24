import 'package:flutter/foundation.dart';

/// One day's window in the weekly schedule. Either `closed`, or an
/// `open`/`close` pair as `"HH:MM"` strings (24-hour, Western digits —
/// the Jordanian convention this app follows in both locales).
@immutable
class DayWindow {
  const DayWindow.closed()
      : closed = true,
        open = null,
        close = null;
  const DayWindow.open(this.open, this.close) : closed = false;

  final bool closed;
  final String? open;
  final String? close;
}

/// Which of the three payload shapes a gym's `opening_hours` resolved
/// to. `unknown` means the partner never filled it — the UI shows no
/// status line at all rather than guessing.
enum HoursKind { unknown, always, scheduled }

/// Computed open/closed state at a given instant. The widget layer
/// turns this into a localized one-liner; this object stays free of
/// any `BuildContext`/l10n so it's unit-testable.
@immutable
class OpenStatus {
  const OpenStatus({
    required this.isOpen,
    this.always = false,
    this.boundaryTime,
    this.nextOpenWeekday,
    this.nextOpenIsToday = false,
    this.nextOpenIsTomorrow = false,
  });

  /// True when the gym is open at the queried instant.
  final bool isOpen;

  /// True only for the always-open (`{"24_7": true}`) case.
  final bool always;

  /// When [isOpen]: the closing time (`"23:00"`).
  /// When closed: the next opening time. Null when hours are unknown.
  final String? boundaryTime;

  /// Weekday (1=Mon … 7=Sun) of the next opening when closed. Null
  /// when the whole week is closed / unknown.
  final int? nextOpenWeekday;
  final bool nextOpenIsToday;
  final bool nextOpenIsTomorrow;
}

/// Parses the partner-authored `opening_hours` JSON into a weekly
/// schedule and answers "open right now?" against the device clock.
///
/// Accepts the three shapes `HoursEditor` emits:
///   - `{ "24_7": true }`                          → [HoursKind.always]
///   - `{ "open": "06:00", "close": "23:00" }`     → same window every day
///   - `{ "mon": {open,close|closed}, "tue": … }`  → per-weekday
///
/// A `close` that is less-than-or-equal-to `open` (e.g. open 06:00,
/// close 00:00, or open 22:00 close 02:00) is treated as crossing
/// midnight so "Platinum closes at 00:00" reads as open until midnight,
/// not instantly closed.
@immutable
class OpeningHours {
  const OpeningHours._(this.kind, this._week);

  final HoursKind kind;
  final Map<int, DayWindow> _week;

  bool get isKnown => kind != HoursKind.unknown;
  bool get is247 => kind == HoursKind.always;

  /// Window for a weekday (1=Mon … 7=Sun). Days absent from a per-day
  /// payload count as closed.
  DayWindow windowFor(int weekday) =>
      _week[weekday] ?? const DayWindow.closed();

  // weekday int (DateTime.weekday) → the partner portal's day key.
  static const Map<int, String> _dayKeys = {
    1: 'mon',
    2: 'tue',
    3: 'wed',
    4: 'thu',
    5: 'fri',
    6: 'sat',
    7: 'sun',
  };

  factory OpeningHours.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const OpeningHours._(HoursKind.unknown, <int, DayWindow>{});
    }
    if (json['24_7'] == true) {
      return const OpeningHours._(HoursKind.always, <int, DayWindow>{});
    }

    final hasDayKey = _dayKeys.values.any(json.containsKey);

    // Uniform: one window applied to all seven days.
    if (!hasDayKey && json['open'] is String && json['close'] is String) {
      final w = DayWindow.open(json['open'] as String, json['close'] as String);
      return OpeningHours._(
        HoursKind.scheduled,
        {for (var d = 1; d <= 7; d++) d: w},
      );
    }

    if (hasDayKey) {
      final week = <int, DayWindow>{};
      for (var d = 1; d <= 7; d++) {
        final raw = json[_dayKeys[d]];
        if (raw is Map &&
            raw['closed'] != true &&
            raw['open'] is String &&
            raw['close'] is String) {
          week[d] =
              DayWindow.open(raw['open'] as String, raw['close'] as String);
        } else {
          week[d] = const DayWindow.closed();
        }
      }
      return OpeningHours._(HoursKind.scheduled, week);
    }

    return const OpeningHours._(HoursKind.unknown, <int, DayWindow>{});
  }

  static int? _toMinutes(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Evaluate the schedule at [now] (device local time).
  OpenStatus statusAt(DateTime now) {
    if (kind == HoursKind.always) {
      return const OpenStatus(isOpen: true, always: true);
    }
    if (kind == HoursKind.unknown) {
      return const OpenStatus(isOpen: false);
    }

    final wd = now.weekday;
    final nowMin = now.hour * 60 + now.minute;
    final today = windowFor(wd);

    if (!today.closed) {
      final o = _toMinutes(today.open);
      final c = _toMinutes(today.close);
      if (o != null && c != null) {
        final overnight = c <= o;
        final openNow = overnight
            ? (nowMin >= o || nowMin < c)
            : (nowMin >= o && nowMin < c);
        if (openNow) {
          return OpenStatus(isOpen: true, boundaryTime: today.close);
        }
        // Closed for now but opens again later today.
        if (nowMin < o) {
          return OpenStatus(
            isOpen: false,
            boundaryTime: today.open,
            nextOpenWeekday: wd,
            nextOpenIsToday: true,
          );
        }
      }
    }

    // Walk forward to the next day that has an open window.
    for (var i = 1; i <= 7; i++) {
      final d = ((wd - 1 + i) % 7) + 1;
      final w = windowFor(d);
      if (!w.closed) {
        return OpenStatus(
          isOpen: false,
          boundaryTime: w.open,
          nextOpenWeekday: d,
          nextOpenIsTomorrow: i == 1,
        );
      }
    }

    return const OpenStatus(isOpen: false);
  }
}
