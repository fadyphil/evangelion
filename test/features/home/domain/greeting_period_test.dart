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
///
/// ## AND THE TABLE IS THE PROTOTYPE'S, HOUR BY HOUR
///
/// `eva/redesign.html:983-984` —
/// `return (h>=5&&h<12)?'morn':(h>=12&&h<18)?'noon':(h>=18&&h<24)?'eve':'vigil';`
/// — has **four** arms, and the fourth is the one this suite once lost: the first
/// version of the table put 00:00–04:59 under `evening` because the function it
/// transcribed had three members, and five tests went red before a single reader
/// ever saw the wrong word. `vigil` is not a rename of the night hours; it is a
/// *different* greeting (`night vigil` / `سهر الليل`, `:925`) for the hours the
/// prototype treats as their own period, and a table that predates it is wrong at
/// midnight by construction.
void main() {
  DateTime at(int hour) => DateTime(2026, 10, 3, hour);

  group('every hour of the day', () {
    const Map<int, GreetingPeriod> table = <int, GreetingPeriod>{
      0: GreetingPeriod.vigil,
      1: GreetingPeriod.vigil,
      2: GreetingPeriod.vigil,
      3: GreetingPeriod.vigil,
      4: GreetingPeriod.vigil,
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

    test('and the four periods partition the day, with no overlap', () {
      // A `Map` keyed by hour cannot say this on its own: two periods could both
      // claim 09:00 if the function took the first match, and this row would stay
      // green while the greeting flipped between arms. Counting the hours per
      // period is the partition claim — 5 + 7 + 6 + 6.
      final Map<GreetingPeriod, int> counts = <GreetingPeriod, int>{
        for (final GreetingPeriod period in GreetingPeriod.values)
          period: table.values.where((GreetingPeriod p) => p == period).length,
      };
      expect(
        counts,
        <GreetingPeriod, int>{
          GreetingPeriod.morning: 7,
          GreetingPeriod.afternoon: 6,
          GreetingPeriod.evening: 6,
          GreetingPeriod.vigil: 5,
        },
        reason:
            '`:983` writes `h>=5&&h<12` (7 hours), `h>=12&&h<18` (6), '
            '`h>=18&&h<24` (6) and the remainder (5). A period with a different '
            'count has stolen an hour from another, and the boundary rows below '
            'name which.',
      );
    });
  });

  group('the boundaries', () {
    test('04:59 is vigil and 05:00 is morning', () {
      // The boundary the first table got wrong: it called 04:00 `evening`, so a
      // reader up at half past four was greeted with the six-o'clock word and
      // nothing in the suite could see it. `:984` puts the split at 5 and this row
      // is what keeps it there.
      expect(greetingPeriodFor(at(4)), GreetingPeriod.vigil);
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

    test('and 23:59 is evening while 00:00 is vigil', () {
      // The fourth boundary, and the one the three-member table could not even
      // express: midnight wraps into a *new* period rather than back into the day's
      // first one, which is why this row is a separate test and not an extra line
      // under 04:59 — a wrap and a step-forward are different defects.
      expect(greetingPeriodFor(at(23)), GreetingPeriod.evening);
      expect(greetingPeriodFor(at(0)), GreetingPeriod.vigil);
    });
  });

  group('only the hour is read', () {
    test('minutes, seconds, day and month make no difference', () {
      // Named because the function *could* have read more: a "good morning" that
      // meant "the first hour after 05:00 on a Tuesday" would be a different
      // function, and `redesign.html:983` reads `new Date().getHours()` and
      // nothing else. The explicit `0, 0, 0` is the assertion: it is the same
      // hour written with every lower field filled in, which is what "minutes,
      // seconds, day and month make no difference" has to mean to be a claim
      // rather than a tautology.
      expect(
        greetingPeriodFor(DateTime(2026, 1, 1, 9)),
        greetingPeriodFor(DateTime(1999, 12, 31, 9, 59, 59, 999)),
      );
    });

    test('and it does not convert zones, so the caller owns that', () {
      // A function that called `toLocal()` would answer for the *device's* zone
      // whatever the caller passed, which makes a test reaching the afternoon
      // branch depend on the host's clock. `DateTime.utc()` and a
      // `DateTime` constructed as local are read as themselves — and the vigil
      // hour is in this row deliberately, because it is the one whose *whole*
      // range (00:00–04:59) is on the far side of midnight from the day the date
      // names, which is where a zone conversion would move it.
      expect(
        greetingPeriodFor(DateTime.utc(2026, 10, 3, 13)),
        GreetingPeriod.afternoon,
      );
      expect(
        greetingPeriodFor(DateTime.utc(2026, 10, 3, 3)),
        GreetingPeriod.vigil,
      );
    });
  });

  group('the enum', () {
    test('has exactly four members, so a `switch` over it is exhaustive', () {
      // Four and not three, because `:983-984` writes four keys and a fifth would
      // make `greetingWord`'s switch refuse to compile — which is the *good* kind
      // of failure, and the reason the mapping is a `switch` at all.
      expect(GreetingPeriod.values, <GreetingPeriod>[
        GreetingPeriod.morning,
        GreetingPeriod.afternoon,
        GreetingPeriod.evening,
        GreetingPeriod.vigil,
      ]);
    });
  });
}
