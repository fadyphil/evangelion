import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:flutter_test/flutter_test.dart';

/// [TodayReading] — red-first (AGENT_CONTEXT §6: domain entities).
///
/// ## WHY A NARROW PROJECTION AND NOT THE RESPONSE
///
/// `GET /readings/today/{lang}` returns verses and questions in full — five verse
/// objects and one question with a four-entry options map, for the live payload.
/// None of that is on Home. What Home draws is: a reference, a translation name,
/// a verse count, the first verse's text, **how many reflection questions exist
/// and how many are answered**, whether the reading is finished, and two numbers.
///
/// So this entity is that list and nothing more. The wide shape belongs to
/// `features/reading/`, which Phase 7 needs in full and which already owns the
/// `text_clean` trap AGENT_CONTEXT §5 documents. Putting the wide shape here
/// would be §3's "nothing enters `core/domain/` speculatively" in reverse: a
/// domain object carrying a `Map<String, String>` of quiz options that no
/// `core/domain` consumer reads.
///
/// **The cost is stated rather than discovered later:** the reading section's
/// panel and Phase 7's sanctuary read the same endpoint through two
/// projections. Phase 7 therefore **widens** `ReadingRepository` rather than
/// creating a second adapter — see `features/reading/data/repositories/`.
void main() {
  // The live English payload, projected.
  const TodayReading live = TodayReading(
    readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    groupId: 3,
    scheduledDate: '2026-10-03',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV (New King James Version)',
    verseCount: 5,
    firstVerseText:
        'There was a man of the Pharisees, named Nicodemus, a '
        'ruler of the Jews:',
    questionCount: 1,
    answeredQuestionCount: 1,
    isFullyCompleted: true,
    pointsEarnedToday: 10,
    currentStreak: 4,
  );

  group('equality', () {
    test('two equal instances compare equal and hash alike', () {
      expect(live, live.copyWith());
      expect(live.hashCode, live.copyWith().hashCode);
    });

    test('every field participates, so no two of them can be confused', () {
      // Walked rather than sampled: a `props` list that dropped one field would
      // leave every *other* pair unequal and this test green.
      final List<TodayReading> others = <TodayReading>[
        live.copyWith(readingId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
        live.copyWith(groupId: 4),
        live.copyWith(scheduledDate: '2026-10-04'),
        live.copyWith(language: ReadingLanguage.arabic),
        live.copyWith(reference: 'John 3:1-6'),
        live.copyWith(translation: 'NKJV'),
        live.copyWith(verseCount: 6),
        live.copyWith(firstVerseText: 'In the beginning'),
        live.copyWith(questionCount: 2),
        live.copyWith(answeredQuestionCount: 0),
        live.copyWith(isFullyCompleted: false),
        live.copyWith(pointsEarnedToday: 0),
        live.copyWith(currentStreak: 0),
      ];
      for (final TodayReading other in others) {
        expect(live, isNot(other), reason: '$other differs from $live');
      }
    });
  });

  group('the two completion numbers are independent, by design', () {
    // `answeredQuestionCount` comes from counting `already_answered` on the
    // questions array; `isFullyCompleted` comes from the response's own flag.
    // They are not the same fact and neither is derived from the other — §5
    // records the live case where the two disagree with `streak/summary`.
    test('a partly-answered reading is not fully completed', () {
      const TodayReading partly = TodayReading(
        readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        groupId: 3,
        scheduledDate: '2026-10-03',
        language: ReadingLanguage.english,
        reference: 'John 3:1-5',
        translation: 'NKJV',
        verseCount: 5,
        firstVerseText: 'There was a man of the Pharisees',
        questionCount: 3,
        answeredQuestionCount: 1,
        isFullyCompleted: false,
        pointsEarnedToday: 10,
        currentStreak: 4,
      );

      expect(partly.answeredQuestionCount, lessThan(partly.questionCount));
      expect(partly.isFullyCompleted, isFalse);
    });

    test('nothing derives one from the other', () {
      // The counter-example a derivation would fail: every question answered,
      // yet the server says the reading is not finished.
      const TodayReading contradicted = TodayReading(
        readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        groupId: 3,
        scheduledDate: '2026-10-03',
        language: ReadingLanguage.english,
        reference: 'John 3:1-5',
        translation: 'NKJV',
        verseCount: 5,
        firstVerseText: 'There was a man of the Pharisees',
        questionCount: 1,
        answeredQuestionCount: 1,
        isFullyCompleted: false,
        pointsEarnedToday: 0,
        currentStreak: 0,
      );

      expect(contradicted.answeredQuestionCount, contradicted.questionCount);
      expect(contradicted.isFullyCompleted, isFalse);
    });
  });

  group('the dates are Strings', () {
    test('scheduledDate round-trips the wire value verbatim', () {
      expect(live.scheduledDate, '2026-10-03');
    });

    test('and it is not a DateTime', () {
      // See `streak_summary_test.dart` for the full argument. `DateTime.parse`
      // on `YYYY-MM-DD` yields local midnight: a different instant per device
      // and a different calendar day for a reader far from UTC, in exchange for
      // a field nothing in this app reads as an instant.
      expect(live.scheduledDate, isA<String>());
    });
  });

  group('isFullyCompleted is what the panel\'s status reads', () {
    // The contradiction this entity has to be able to carry is measured:
    // `readings/today/*.is_fully_completed` is `true` while
    // `streak/summary.today_completed` is `false`. The panel reads this field
    // and the flame reads `StreakSummary.currentStreak`, and neither consults
    // the other.
    test('the live reading is complete', () {
      expect(live.isFullyCompleted, isTrue);
      expect(live.answeredQuestionCount, live.questionCount);
    });
  });
}
