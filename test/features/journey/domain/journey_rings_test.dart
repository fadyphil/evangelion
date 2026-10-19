import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/features/journey/domain/journey_rings.dart';
import 'package:flutter_test/flutter_test.dart';

/// One scheduled day, spelled out.
///
/// ## WHY A FIXTURE BUILDER AND NOT A CONSTANT
///
/// A history is a **list**, and the whole subject of this file is what happens
/// to a list of a particular length and shape — so the fixtures have to be
/// buildable, not constant. Every row carries the twelve fields the live
/// schema declares (`streak.service.ts:5-17`): `total_questions`,
/// `answered_questions`, `correct_answers`, `points_earned`, `is_completed`,
/// plus the identity fields.
///
/// **The three counts are required, not defaulted.** The derivation sums two
/// of them, and a defaulted count would let a fixture state a number by
/// accident rather than by decision. `total` is required for a second reason:
/// it is what the server's own completion rule reads
/// (`totalQ > 0 && answeredQ >= totalQ`, `streak.service.ts:112`), so a
/// fixture that says `isCompleted: true` with `total: 0` would be a fixture
/// the server could never have produced.
///
/// `points_earned` is left at **0**, and that is deliberate: the server's value
/// is the sum of `points_awarded` over the day's submissions
/// (`streak.service.ts:105`), which is a number this client cannot compute and
/// which no quantity in `journey_rings.dart` reads. Writing a made-up number
/// there would be fiction in a fixture whose other numbers are checked.
///
/// The `reading_id` is one constant for every row, because nothing in the
/// derivation reads it — the rows are told apart by their date, which is what
/// the server orders by (`scheduled_date DESC`, `streak.service.ts:93`).
///
/// These are **transcriptions of the schema**, not recordings of a live
/// response — the same rule `test/support/contract_payloads.dart` states for
/// its own fixtures.
StreakHistoryEntry _day({
  required int bookNumber,
  required bool isCompleted,
  required int answered,
  required int correct,
  required int total,
  String date = '2026-10-01',
}) => StreakHistoryEntry(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  scheduledDate: date,
  bookNumber: bookNumber,
  bookNameEn: 'Book $bookNumber',
  bookNameAr: 'كتاب $bookNumber',
  referenceEn: 'Book $bookNumber 1:1',
  referenceAr: 'كتاب $bookNumber 1: 1',
  totalQuestions: total,
  answeredQuestions: answered,
  correctAnswers: correct,
  pointsEarned: 0,
  isCompleted: isCompleted,
);

void main() {
  group('deriveJourneyRings', () {
    test('an EMPTY history is three zeroes — never a NaN, never a throw', () {
      // The case a naive implementation gets wrong: 0 ÷ 0 is a NaN, and a NaN
      // reaching the ring's stroke arithmetic draws nothing and says nothing.
      final JourneyRings rings = deriveJourneyRings(
        const <StreakHistoryEntry>[],
      );

      expect(rings.completion, 0.0);
      expect(rings.answered, 0);
      expect(rings.accuracy, 0.0);
      expect(rings.answeredShare, 0.0);
      expect(rings.completion.isNaN, isFalse);
      expect(rings.accuracy.isNaN, isFalse);
      expect(rings.answeredShare.isNaN, isFalse);
    });

    test('the three quantities, against a hand-built history', () {
      // Four scheduled days. Two of them are completed (books 43 and 19); the
      // other two were started and left, or scheduled and never opened.
      final List<StreakHistoryEntry> history = <StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: true,
          answered: 4,
          correct: 3,
          total: 4,
          date: '2026-10-04',
        ),
        _day(
          bookNumber: 43,
          isCompleted: false,
          answered: 2,
          correct: 1,
          total: 5,
          date: '2026-10-03',
        ),
        _day(
          bookNumber: 19,
          isCompleted: true,
          answered: 6,
          correct: 6,
          total: 6,
          date: '2026-10-02',
        ),
        _day(
          bookNumber: 19,
          isCompleted: false,
          answered: 0,
          correct: 0,
          total: 3,
          date: '2026-09-30',
        ),
      ];

      final JourneyRings rings = deriveJourneyRings(history);

      // Two completed days of four scheduled days.
      expect(rings.completion, 0.5);
      // 4 + 2 + 6 + 0 questions answered.
      expect(rings.answered, 12);
      // 3 + 1 + 6 + 0 correct, of the 12 answered.
      expect(rings.accuracy, closeTo(0.8333333333, 1e-9));
      // 12 answered, of the 4 + 5 + 6 + 3 scheduled.
      expect(rings.answeredShare, closeTo(0.6666666666, 1e-9));
    });

    test('the count ring\'s arc is a REAL ratio, and it is not the count', () {
      // ## WHY THIS QUANTITY EXISTS AT ALL
      //
      // A ring is an arc, and an arc is a fraction — and the count ring's number
      // is a **bare count with no denominator** (12 answered out of how many?).
      // The prototype draws an arc on it anyway (`data-p=".86"`, `:593`), but
      // that `.86` is decoration over a hard-coded literal.
      //
      // So the arc gets a ratio the payload **does** contain: the share of the
      // scheduled questions that were answered. It is a **different quantity**
      // from the number beside it, and that is recorded at the widget.
      final JourneyRings rings = deriveJourneyRings(<StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: true,
          answered: 4,
          correct: 3,
          total: 4,
          date: '2026-10-04',
        ),
        _day(
          bookNumber: 19,
          isCompleted: false,
          answered: 2,
          correct: 1,
          total: 6,
          date: '2026-10-03',
        ),
      ]);

      expect(rings.answered, 6, reason: 'the count is 4 + 2');
      expect(
        rings.answeredShare,
        closeTo(0.6, 1e-9),
        reason: 'and the share is 6 of the 4 + 6 scheduled',
      );
    });

    test('a history of days with NO questions gives a share of zero', () {
      // The third zero case, and the one a naive `answered / total` gets wrong
      // by dividing by zero: a day with no questions at all is a day the reader
      // was scheduled and could not answer, and it is not a denominator of zero
      // to be divided into.
      final JourneyRings rings = deriveJourneyRings(<StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: false,
          answered: 0,
          correct: 0,
          total: 0,
          date: '2026-10-04',
        ),
      ]);

      expect(rings.answered, 0);
      expect(rings.answeredShare, 0.0);
      expect(rings.answeredShare.isNaN, isFalse);
    });

    test('a ONE-DAY history: the only day completed, three of five right', () {
      final JourneyRings rings = deriveJourneyRings(<StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: true,
          answered: 5,
          correct: 3,
          total: 5,
        ),
      ]);

      expect(rings.completion, 1.0);
      expect(rings.answered, 5);
      expect(rings.accuracy, 0.6);
    });

    test('a TIE — one completed day against one that was not — is a half', () {
      // The same book on both sides of the tie: a completed day and a day that
      // was not finished. The completion ratio is a tie at one of two, and the
      // book itself is counted once (see `countCompletedBooks`).
      final JourneyRings rings = deriveJourneyRings(<StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: true,
          answered: 3,
          correct: 2,
          total: 3,
          date: '2026-10-02',
        ),
        _day(
          bookNumber: 43,
          isCompleted: false,
          answered: 1,
          correct: 0,
          total: 3,
        ),
      ]);

      expect(rings.completion, 0.5);
      expect(rings.answered, 4);
      expect(rings.accuracy, 0.5);
    });

    test('a history with NO completed day still counts the questions', () {
      final JourneyRings rings = deriveJourneyRings(<StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: false,
          answered: 2,
          correct: 1,
          total: 4,
          date: '2026-10-03',
        ),
        _day(
          bookNumber: 19,
          isCompleted: false,
          answered: 1,
          correct: 0,
          total: 3,
          date: '2026-10-02',
        ),
        _day(
          bookNumber: 19,
          isCompleted: false,
          answered: 0,
          correct: 0,
          total: 3,
        ),
      ]);

      // No scheduled day was finished, so the first ring is empty — but the
      // reader did answer questions, and those are the second and third rings.
      expect(rings.completion, 0.0);
      expect(rings.answered, 3);
      expect(rings.accuracy, closeTo(0.3333333333, 1e-9));
    });

    test('the same history derives equal rings', () {
      // The derivation is a function of its input, and the rings are a value:
      // two derivations of one history compare equal, so a cubit that rebuilds
      // them on a reload does not see a change where there was none.
      final List<StreakHistoryEntry> history = <StreakHistoryEntry>[
        _day(
          bookNumber: 43,
          isCompleted: true,
          answered: 4,
          correct: 3,
          total: 4,
          date: '2026-10-02',
        ),
        _day(
          bookNumber: 19,
          isCompleted: false,
          answered: 1,
          correct: 0,
          total: 3,
        ),
      ];

      expect(deriveJourneyRings(history), deriveJourneyRings(history));
    });
  });

  group('the rings are a value, and the value has FOUR fields', () {
    test('two rings that differ only in answeredShare are NOT equal', () {
      // ## WHY THIS TEST EXISTS AT ALL
      //
      // `JourneyRings` is a **hand-written** class, not a `freezed` one, so the
      // freezed-equality suite in `test/core/common/` cannot cover it: there
      // is no generated `==` to assert. And the derivation suite's "the same
      // history derives equal rings" compares one history **with itself**, so
      // it passes with any field left out of the comparison.
      //
      // So the omission was invisible to both suites, and it was not
      // harmless: [answeredShare] is the **count ring's arc** — the share of
      // the scheduled questions that were answered — and it is drawn from
      // [JourneyRings.answeredShare] by `journey_page.dart`. Two rings whose
      // arcs differ used to compare **equal**, so a reload that moved only the
      // share was invisible to the cubit and the count ring kept its old
      // sweep while the number beside it had moved.
      //
      // The four fields are the completion ratio, the bare count, the accuracy
      // ratio and the share. This test moves the fourth and leaves the other
      // three alone.
      const JourneyRings base = JourneyRings(
        completion: 0.5,
        answered: 12,
        accuracy: 0.75,
        answeredShare: 0.4,
      );
      const JourneyRings movedShare = JourneyRings(
        completion: 0.5,
        answered: 12,
        accuracy: 0.75,
        answeredShare: 0.9,
      );

      expect(base.answeredShare, isNot(movedShare.answeredShare));
      expect(base, isNot(movedShare));
      expect(movedShare, isNot(base));
    });

    test('and their hash codes differ', () {
      // The other half of the contract, and the half that is easy to forget:
      // two objects that are unequal may still hash the same, but a value type
      // whose unequal instances share a hash pays for every map that holds it.
      const JourneyRings base = JourneyRings(
        completion: 0.5,
        answered: 12,
        accuracy: 0.75,
        answeredShare: 0.4,
      );
      const JourneyRings movedShare = JourneyRings(
        completion: 0.5,
        answered: 12,
        accuracy: 0.75,
        answeredShare: 0.9,
      );

      expect(base.hashCode, isNot(movedShare.hashCode));
    });

    test('and rings that agree on all four ARE equal, with one hash', () {
      // The other direction, so the test above cannot be satisfied by a
      // comparison that is always false.
      const JourneyRings a = JourneyRings(
        completion: 0.5,
        answered: 12,
        accuracy: 0.75,
        answeredShare: 0.4,
      );
      const JourneyRings b = JourneyRings(
        completion: 0.5,
        answered: 12,
        accuracy: 0.75,
        answeredShare: 0.4,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('the zero cases', () {
    test(
      'a history nobody answered divides by zero without dividing by zero',
      () {
        // Two scheduled days, no answers on either. The server's own rule
        // (`totalQ > 0 && answeredQ >= totalQ`, `streak.service.ts:112`) leaves
        // both days uncompleted, and the accuracy ratio is 0 ÷ 0 — the one
        // division in this file with no denominator.
        final JourneyRings rings = deriveJourneyRings(<StreakHistoryEntry>[
          _day(
            bookNumber: 43,
            isCompleted: false,
            answered: 0,
            correct: 0,
            total: 3,
            date: '2026-10-02',
          ),
          _day(
            bookNumber: 19,
            isCompleted: false,
            answered: 0,
            correct: 0,
            total: 3,
          ),
        ]);

        expect(rings.answered, 0);
        expect(rings.accuracy, 0.0);
        expect(rings.accuracy.isNaN, isFalse);
        expect(rings.completion, 0.0);
      },
    );

    test('and the empty history is the other zero — zero days of zero', () {
      final JourneyRings rings = deriveJourneyRings(
        const <StreakHistoryEntry>[],
      );

      expect(rings.completion, 0.0);
      expect(rings.completion.isNaN, isFalse);
    });
  });

  group('countCompletedBooks', () {
    test('two completed days of the SAME book count once', () {
      expect(
        countCompletedBooks(<StreakHistoryEntry>[
          _day(
            bookNumber: 43,
            isCompleted: true,
            answered: 1,
            correct: 1,
            total: 1,
            date: '2026-10-02',
          ),
          _day(
            bookNumber: 43,
            isCompleted: true,
            answered: 1,
            correct: 1,
            total: 1,
          ),
        ]),
        1,
      );
    });

    test('an INCOMPLETE day counts not at all', () {
      expect(
        countCompletedBooks(<StreakHistoryEntry>[
          _day(
            bookNumber: 43,
            isCompleted: true,
            answered: 1,
            correct: 1,
            total: 1,
            date: '2026-10-02',
          ),
          _day(
            bookNumber: 19,
            isCompleted: false,
            answered: 1,
            correct: 1,
            total: 1,
          ),
        ]),
        1,
      );
    });

    test(
      'a book that was completed on one day and not on another counts once',
      () {
        expect(
          countCompletedBooks(<StreakHistoryEntry>[
            _day(
              bookNumber: 43,
              isCompleted: true,
              answered: 1,
              correct: 1,
              total: 1,
              date: '2026-10-02',
            ),
            _day(
              bookNumber: 43,
              isCompleted: false,
              answered: 1,
              correct: 0,
              total: 1,
            ),
          ]),
          1,
        );
      },
    );

    test('distinct books across the completed days', () {
      // Three completed days, two books.
      expect(
        countCompletedBooks(<StreakHistoryEntry>[
          _day(
            bookNumber: 43,
            isCompleted: true,
            answered: 1,
            correct: 1,
            total: 1,
            date: '2026-10-03',
          ),
          _day(
            bookNumber: 19,
            isCompleted: true,
            answered: 1,
            correct: 0,
            total: 1,
            date: '2026-10-02',
          ),
          _day(
            bookNumber: 43,
            isCompleted: true,
            answered: 1,
            correct: 1,
            total: 1,
          ),
        ]),
        2,
      );
    });

    test('an EMPTY history has no books at all', () {
      expect(countCompletedBooks(const <StreakHistoryEntry>[]), 0);
    });
  });
}
