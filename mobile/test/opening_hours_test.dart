import 'package:flutter_test/flutter_test.dart';
import 'package:gympass/features/gyms/data/opening_hours.dart';

void main() {
  group('OpeningHours.fromJson', () {
    test('empty / null payload → unknown', () {
      expect(OpeningHours.fromJson(null).kind, HoursKind.unknown);
      expect(OpeningHours.fromJson(const {}).kind, HoursKind.unknown);
      expect(OpeningHours.fromJson(const {}).isKnown, isFalse);
    });

    test('{"24_7": true} → always', () {
      final h = OpeningHours.fromJson(const {'24_7': true});
      expect(h.kind, HoursKind.always);
      expect(h.is247, isTrue);
    });

    test('uniform open/close applies to every weekday', () {
      final h = OpeningHours.fromJson(const {'open': '06:00', 'close': '23:00'});
      expect(h.kind, HoursKind.scheduled);
      for (var d = 1; d <= 7; d++) {
        expect(h.windowFor(d).closed, isFalse, reason: 'day $d');
        expect(h.windowFor(d).open, '06:00');
        expect(h.windowFor(d).close, '23:00');
      }
    });

    test('per-day payload honours closed days and absent keys', () {
      final h = OpeningHours.fromJson(const {
        'mon': {'open': '06:00', 'close': '22:00'},
        'fri': {'closed': true},
        // sat/sun absent → treated as closed
      });
      expect(h.windowFor(1).closed, isFalse); // mon
      expect(h.windowFor(5).closed, isTrue); // fri explicit closed
      expect(h.windowFor(6).closed, isTrue); // sat absent
    });
  });

  group('statusAt', () {
    // A Wednesday at 10:00 local — picked so weekday math is exercised
    // (Wed = 3) without depending on the real clock.
    DateTime wedAt(int h, int m) => DateTime(2026, 6, 17, h, m); // 2026-06-17 is a Wed

    test('always-open is open at any instant', () {
      final s = OpeningHours.fromJson(const {'24_7': true}).statusAt(wedAt(3, 0));
      expect(s.isOpen, isTrue);
      expect(s.always, isTrue);
    });

    test('inside a normal window → open, reports closing time', () {
      final h = OpeningHours.fromJson(const {'open': '06:00', 'close': '23:00'});
      final s = h.statusAt(wedAt(10, 0));
      expect(s.isOpen, isTrue);
      expect(s.boundaryTime, '23:00');
    });

    test('before opening → closed, opens later today', () {
      final h = OpeningHours.fromJson(const {'open': '06:00', 'close': '23:00'});
      final s = h.statusAt(wedAt(5, 0));
      expect(s.isOpen, isFalse);
      expect(s.nextOpenIsToday, isTrue);
      expect(s.boundaryTime, '06:00');
    });

    test('after closing → closed, opens tomorrow', () {
      final h = OpeningHours.fromJson(const {'open': '06:00', 'close': '23:00'});
      final s = h.statusAt(wedAt(23, 30));
      expect(s.isOpen, isFalse);
      expect(s.nextOpenIsTomorrow, isTrue);
    });

    test('close 00:00 is treated as midnight (open until then)', () {
      final h = OpeningHours.fromJson(const {'open': '06:00', 'close': '00:00'});
      expect(h.statusAt(wedAt(23, 59)).isOpen, isTrue);
      expect(h.statusAt(wedAt(5, 0)).isOpen, isFalse);
    });

    test('overnight window (22:00→02:00) open in the early-morning tail', () {
      final h = OpeningHours.fromJson(const {'open': '22:00', 'close': '02:00'});
      expect(h.statusAt(wedAt(1, 0)).isOpen, isTrue);
      expect(h.statusAt(wedAt(23, 0)).isOpen, isTrue);
      expect(h.statusAt(wedAt(12, 0)).isOpen, isFalse);
    });

    test('closed today → finds the next open weekday', () {
      // Wed + Thu closed, Fri open. From Wed we should skip to Fri.
      final h = OpeningHours.fromJson(const {
        'wed': {'closed': true},
        'thu': {'closed': true},
        'fri': {'open': '09:00', 'close': '17:00'},
      });
      final s = h.statusAt(wedAt(10, 0));
      expect(s.isOpen, isFalse);
      expect(s.nextOpenWeekday, 5); // Friday
      expect(s.nextOpenIsTomorrow, isFalse);
      expect(s.boundaryTime, '09:00');
    });
  });
}
