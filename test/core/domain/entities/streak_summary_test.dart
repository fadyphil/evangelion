import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// [StreakSummary] — red-first (AGENT_CONTEXT §6: domain entities).
///
/// ## THE RAW VALUES, MEASURED, AND WHY THEY ARE NOT RECONCILED
///
/// Two live readings against `HEAD = 4a1c834`, group 3, user
/// `11111111-1111-1111-1111-111111111111`:
///
/// ```
/// GET /api/v1/streak/summary
///   current_streak: 0   today_status: 'pending'   today_completed: false
/// GET /api/v1/readings/today/en
///   current_streak: 4   is_fully_completed: true
/// ```
///
/// **The backend disagrees with itself**, and neither number is a transcription
/// slip. The resolution this client takes is that *each field comes from the
/// endpoint whose job it is and the two are never reconciled*: the top-bar flame
/// reads [StreakSummary.currentStreak] and the panel's completion state reads
/// `TodayReading.isFullyCompleted`. Nothing sums them, nothing prefers one, and
/// nothing cross-checks them — so when the backend fixes the disagreement, no
/// line of this client changes.
///
/// The test that holds that is a **widget** test, not this one:
/// `test/features/home/presentation/pages/home_page_test.dart` builds the two
/// fakes with deliberately contradictory numbers and asserts each surface shows
/// its own. Asserting it here would be asserting only that the fields are stored,
/// which is `props`.
void main() {
  // The live payload, field for field.
  const StreakSummary live = StreakSummary(
    currentStreak: 0,
    longestStreak: 6,
    lastCompletedDate: '2026-09-29',
    todayStatus: StreakTodayStatus.pending,
    todayCompleted: false,
    todayScheduled: true,
    nextMilestone: 3,
    daysToMilestone: 3,
  );

  group('equality', () {
    test('two equal instances compare equal and hash alike', () {
      expect(
        live,
        const StreakSummary(
          currentStreak: 0,
          longestStreak: 6,
          lastCompletedDate: '2026-09-29',
          todayStatus: StreakTodayStatus.pending,
          todayCompleted: false,
          todayScheduled: true,
          nextMilestone: 3,
          daysToMilestone: 3,
        ),
      );
      expect(
        live.hashCode,
        const StreakSummary(
          currentStreak: 0,
          longestStreak: 6,
          lastCompletedDate: '2026-09-29',
          todayStatus: StreakTodayStatus.pending,
          todayCompleted: false,
          todayScheduled: true,
          nextMilestone: 3,
          daysToMilestone: 3,
        ).hashCode,
      );
    });

    test('every field participates, so no two of them can be confused', () {
      // Walked rather than sampled, because a `props` list that dropped one
      // field would leave every *other* pair unequal and this test green. The
      // enumeration is what makes the omission impossible to hide.
      final List<StreakSummary> others = <StreakSummary>[
        live.copyWith(currentStreak: 1),
        live.copyWith(longestStreak: 7),
        live.copyWith(lastCompletedDate: '2026-09-30'),
        live.copyWith(todayStatus: StreakTodayStatus.completed),
        live.copyWith(todayCompleted: true),
        live.copyWith(todayScheduled: false),
        live.copyWith(nextMilestone: 4),
        live.copyWith(daysToMilestone: 4),
      ];
      for (final StreakSummary other in others) {
        expect(live, isNot(other), reason: '$other differs from $live');
      }
    });

    test('and it is not the same object as an equal one', () {
      expect(live, isNot(identical(live, live.copyWith())));
    });
  });

  group('copyWith', () {
    test('changes only what it is given', () {
      final StreakSummary changed = live.copyWith(currentStreak: 4);

      expect(changed.currentStreak, 4);
      expect(changed.longestStreak, live.longestStreak);
      expect(changed.lastCompletedDate, live.lastCompletedDate);
      expect(changed.todayStatus, live.todayStatus);
      expect(changed.todayCompleted, live.todayCompleted);
      expect(changed.todayScheduled, live.todayScheduled);
      expect(changed.nextMilestone, live.nextMilestone);
      expect(changed.daysToMilestone, live.daysToMilestone);
    });
  });

  group('the date is a String, and that is the design', () {
    test('the live value round-trips verbatim', () {
      expect(live.lastCompletedDate, '2026-09-29');
    });

    test('no field is a DateTime, because nothing here is an instant', () {
      // The backend sends `YYYY-MM-DD` with no zone and no time. `DateTime.parse`
      // on that yields local midnight, which is a *different instant* on every
      // device and a different *day* for a reader east or west of UTC — and this
      // app never needs an instant, only the label. Asserted as a type so the
      // next reader who wants to "improve" it sees why it is a String.
      expect(live.lastCompletedDate, isA<String>());
      expect(live.lastCompletedDate.contains('-'), isTrue);
    });
  });

  group('StreakTodayStatus', () {
    test('has exactly the four values §5 lists', () {
      // `today_status` ∈ `completed | pending | off_day | broken`. Asserted as an
      // ordered list rather than a length so a rename is a failure here and a
      // `switch` in the mapper is exhaustive against the same set.
      expect(StreakTodayStatus.values, <StreakTodayStatus>[
        StreakTodayStatus.completed,
        StreakTodayStatus.pending,
        StreakTodayStatus.offDay,
        StreakTodayStatus.broken,
      ]);
    });

    test('reads the wire value, snake_case included', () {
      expect(
        StreakTodayStatus.fromCode('completed'),
        StreakTodayStatus.completed,
      );
      expect(StreakTodayStatus.fromCode('pending'), StreakTodayStatus.pending);
      expect(StreakTodayStatus.fromCode('off_day'), StreakTodayStatus.offDay);
      expect(StreakTodayStatus.fromCode('broken'), StreakTodayStatus.broken);
    });

    test('returns null for a fifth value, so a mapper can reject it', () {
      // **Not** a default. `FailureKind.serialization` is the honest answer to a
      // 2xx whose body this client cannot read, and a `switch` that defaulted an
      // unknown status to `pending` would report "nothing done today" for a
      // server that has said something this client does not understand.
      expect(StreakTodayStatus.fromCode('off-day'), isNull);
      expect(StreakTodayStatus.fromCode(''), isNull);
      expect(StreakTodayStatus.fromCode('done'), isNull);
    });

    test('and names the wire value back', () {
      for (final StreakTodayStatus status in StreakTodayStatus.values) {
        expect(StreakTodayStatus.fromCode(status.code), same(status));
      }
    });
  });

  group('the fields Phase 8 will read', () {
    test('nextMilestone and daysToMilestone are carried, unused by Phase 6', () {
      // These are the two values `/result`'s `StreakPill` needs. They are on the
      // entity **now**, before a consumer exists, which is §3's "nothing enters
      // `core/domain/` speculatively" pushed the other way — and the reason is
      // recorded rather than the rule being bent quietly: the raw values are
      // measured (§5) and dropping them would mean re-fetching to draw a pill
      // this phase could already have carried. Phase 6 reads neither, and
      // `home_page_test.dart` asserts the panel shows no milestone, so a future
      // phase cannot find them already on screen.
      expect(live.nextMilestone, 3);
      expect(live.daysToMilestone, 3);
    });
  });
}
