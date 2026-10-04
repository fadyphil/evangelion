import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:flutter_test/flutter_test.dart';

/// [greetingPeriodFor] — red-first (AGENT_CONTEXT §6: domain logic is TDD'd, not
/// buried in a widget).
///
/// ## EVERY HOUR IS CHECKED, NOT A SAMPLE
///
/// The whole claim is three boundaries, and a boundary is only a boundary because
/// of the hour on either side of it. A sampled suite would pass on a function
/// that got 05:00–11:00 right and 11:00 wrong — and the only artefact is which
/// word a reader is greeted with, which nobody notices until it is themselves.
/// So this walks all 24.
void main() {
  DateTime at(int hour) => DateTime(2026, 10, 3, hour);

  group('every hour of the day', () {
    const Map<int, GreetingPeriod> table = <int, GreetingPeriod>{
      0: GreetingPeriod.evening,
      1: GreetingPeriod.evening,
      2: GreetingPeriod.evening,
      3: GreetingPeriod.evening,
      4: GreetingPeriod.evening,
      5: GreetingPeriod.morning,
      6: GreetingPeriod.morning,
      7: GreetingPeriod.morning,
      8: GreetingPeriod.morning,
      9: GreetingPeriod.morning,
      10: GreetingPeriod.morning,
      11: GreetingPeriod.morning,
      12: GreetingPeriod.afternoon,
      13: GreetingPeriod.afternoon,
      14: GreetingPeriod.afternoon,
      15: GreetingPeriod.afternoon,
      16: GreetingPeriod.afternoon,
      17: GreetingPeriod.afternoon,
      18: GreetingPeriod.evening,
      19: GreetingPeriod.evening,
      20: GreetingPeriod.evening,
      21: GreetingPeriod.evening,
      22: GreetingPeriod.evening,
      23: GreetingPeriod.evening,
    };

    test(
      'the table covers all twenty-four, so a new hour cannot be forgotten',
      () {
        expect(table, hasLength(24));
        expect(table.keys.toSet(), <int>{
          for (int h = 0; h < 24; h++) h,
        }, reason: 'the table must name every hour, or a gap is untested');
      },
    );

    for (final MapEntry<int, GreetingPeriod> hour in table.entries) {
      test(
        '${hour.key.toString().padLeft(2, '0')}:00 is ${hour.value.name}',
        () {
          expect(greetingPeriodFor(at(hour.key)), hour.value);
        },
      );
    }
  });

  group('the boundaries', () {
    test('04:59 is evening and 05:00 is morning', () {
      expect(greetingPeriodFor(at(4)), GreetingPeriod.evening);
      expect(greetingPeriodFor(at(5)), GreetingPeriod.morning);
    });

    test('11:59 is morning and 12:00 is afternoon', () {
      expect(greetingPeriodFor(at(11)), GreetingPeriod.morning);
      expect(greetingPeriodFor(at(12)), GreetingPeriod.afternoon);
    });

    test('17:59 is afternoon and 18:00 is evening', () {
      expect(greetingPeriodFor(at(17)), GreetingPeriod.afternoon);
      expect(greetingPeriodFor(at(18)), GreetingPeriod.evening);
    });
  });

  group('only the hour is read', () {
    test('minutes, seconds, day and month make no difference', () {
      // Named because the function *could* have read more: a "good morning" that
      // meant "the first hour after 05:00 on a Tuesday" would be a different
      // function, and `HomeScreen.tsx:26` gives nothing to support it.
      expect(
        greetingPeriodFor(DateTime(2026, 1, 1, 9, 0, 0, 0)),
        greetingPeriodFor(DateTime(1999, 12, 31, 9, 59, 59, 999)),
      );
    });

    test('and it does not convert zones, so the caller owns that', () {
      // A function that called `toLocal()` would answer for the *device's* zone
      // whatever the caller passed, which makes a test reaching the afternoon
      // branch depend on the host's clock. `DateTime.utc()` and a
      // `DateTime` constructed as local are read as themselves.
      expect(
        greetingPeriodFor(DateTime.utc(2026, 10, 3, 13)),
        GreetingPeriod.afternoon,
      );
      expect(
        greetingPeriodFor(DateTime.utc(2026, 10, 3, 3)),
        GreetingPeriod.evening,
      );
    });
  });

  group('the enum', () {
    test('has exactly three members, so a `switch` over it is exhaustive', () {
      expect(GreetingPeriod.values, <GreetingPeriod>[
        GreetingPeriod.morning,
        GreetingPeriod.afternoon,
        GreetingPeriod.evening,
      ]);
    });
  });
}
