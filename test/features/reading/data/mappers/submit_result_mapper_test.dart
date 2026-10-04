import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/reading/data/mappers/submit_result_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';

/// `SubmitResultMapper` — red-first (AGENT_CONTEXT §6: "API models and mappers").
///
/// ## WHY THIS MAPPER EXISTS AT ALL, AND WHY IT IS NEXT TO `TodayReadingMapper`
///
/// §3's SRP row gives the mapper exactly one job — "body → entity" — and the
/// submission's body is a **different** body from the reading's. One mapper that
/// read both would need a flag saying which one it was handed, and a flag in a
/// mapper is a second parsing mode free to disagree with itself.
///
/// It lives in `features/reading/data/mappers/` rather than a `quiz/` directory for
/// two reasons, and both are Phase 8 decisions rather than taste:
///
/// * **the request rides `reading`'s remote data source**, because the endpoint is
///   `/readings/:id/submit` and the body has nothing to do with the quiz feature's
///   own state;
/// * **`quiz` declares no data layer at all** — `08-build-phases.md` §Phase 8 says
///   so and `injection_test.dart` will assert it. Putting the mapper under
///   `features/quiz/data/` would create the first `data/` directory in a feature
///   whose entire architectural claim is that it has none.
///
/// ## AND THE SCALAR POLICY IS DECISION 45'S QUESTION, ASKED AGAIN
///
/// Decision 45 gave one rule for `TodayReadingMapper`: *would this client render
/// the value as something a reader would read as a fact about their own reading?*
/// Nothing else decides it. Applied to this payload, field by field, in
/// `SubmitResultMapper`'s own table — and the table is the test, because an
/// unstated policy is how decision 45 began as "two unstated habits".
void main() {
  const SubmitResultMapper mapper = SubmitResultMapper();

  SubmitResult entityOf(Result<SubmitResult> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: result.isFailure
          ? 'expected a success, got ${result.failureOrElse(const Failure(kind: FailureKind.unknown, message: '?'))}'
          : null,
    );
    return (result as Success<SubmitResult>).value;
  }

  Failure failureOf(Result<SubmitResult> result) {
    expect(result.isFailure, isTrue, reason: 'expected a failure, got $result');
    return (result as FailureResult<SubmitResult>).failure;
  }

  group('the contract body, transcribed from the service interface', () {
    test('reads all seven fields', () {
      final SubmitResult result = entityOf(mapper.map(contractSubmitAnswer()));
      expect(result.questionId, 'question-group-3');
      expect(result.isCorrect, isTrue);
      expect(result.pointsEarned, 10);
      expect(result.currentTotalPoints, 40);
      expect(result.currentStreak, 4);
      expect(result.longestStreak, 6);
      expect(result.readingCompleted, isTrue);
    });

    test('and a WRONG answer is a different entity, not a missing one', () {
      // The `is_correct: false` shape is the one a reader meets most often, and it
      // is the case a nullable field would have made unrepresentable. `points_earned
      // // 0` comes with it because `points_value` on the question is `10` and the
      // service awards `0` for a wrong answer — which is why `pointsEarned` is
      // required and non-nullable and why `0` must not be read as "not sent".
      final SubmitResult result = entityOf(
        mapper.map(
          contractWithKey(
            contractWithKey(contractSubmitAnswer(), 'is_correct', false),
            'points_earned',
            0,
          ),
        ),
      );
      expect(result.isCorrect, isFalse);
      expect(result.pointsEarned, 0);
      expect(result.currentTotalPoints, 40, reason: 'the total is unchanged');
    });

    test(
      '`reading_completed: false` with an unchanged streak, which is §5 trap 4',
      () {
        // The measured shape: a single correct answer does **not** advance the streak.
        // The payload cannot be produced against this backend today, so it is a
        // transcription rather than a capture — but it is the case `/result` has to
        // get right, and `result_page_test.dart` reads it.
        final SubmitResult result = entityOf(
          mapper.map(
            contractWithKey(
              contractWithKey(
                contractSubmitAnswer(),
                'reading_completed',
                false,
              ),
              'current_streak',
              4,
            ),
          ),
        );
        expect(result.readingCompleted, isFalse);
        expect(result.currentStreak, 4);
        expect(result.longestStreak, 6);
      },
    );

    test('the mapper is `const`, so it registers as a singleton', () {
      expect(
        identical(const SubmitResultMapper(), const SubmitResultMapper()),
        isTrue,
      );
    });

    test('and maps the same body to equal entities', () {
      expect(
        mapper.map(contractSubmitAnswer()),
        mapper.map(contractSubmitAnswer()),
      );
    });
  });

  group('the required keys, one per case', () {
    for (final String key in <String>[
      'question_id',
      'is_correct',
      'points_earned',
      'current_total_points',
      'current_streak',
      'longest_streak',
      'reading_completed',
    ]) {
      test('a body without `$key` is a serialization failure naming it', () {
        final Failure failure = failureOf(
          mapper.map(contractWithoutKey(contractSubmitAnswer(), key)),
        );
        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains('`$key`'));
      });

      test('and `$key` of the wrong type is a serialization failure', () {
        final Failure failure = failureOf(
          mapper.map(
            contractWithKey(contractSubmitAnswer(), key, <String, Object?>{}),
          ),
        );
        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains('`$key`'));
      });
    }
  });

  group('the scalar policy: refused as impossible, or passed through', () {
    test('a NEGATIVE `points_earned` is refused', () {
      // Decision 45's rule, applied where the field is **loud**. That decision
      // recorded "rejected: refuse negative points too — it is rendered nowhere on
      // `/`", and `/result` is the screen that renders a score. So the asymmetry it
      // left on purpose (`total_points_earned_today` is not refused because nothing
      // draws it) does not extend here: a `-10` beside `4` is a number a reader
      // would read as a fact about their own reading, which is decision 45's whole
      // test.
      final Failure failure = failureOf(
        mapper.map(
          contractWithKey(contractSubmitAnswer(), 'points_earned', -10),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('0 or more'));
    });

    test(
      'a NEGATIVE `current_total_points` is refused, for the same reason',
      () {
        final Failure failure = failureOf(
          mapper.map(
            contractWithKey(contractSubmitAnswer(), 'current_total_points', -1),
          ),
        );
        expect(failure.kind, FailureKind.serialization);
      },
    );

    test('a NEGATIVE `current_streak` is refused', () {
      final Failure failure = failureOf(
        mapper.map(
          contractWithKey(contractSubmitAnswer(), 'current_streak', -5),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('count of completed days'));
    });

    test('a NEGATIVE `longest_streak` is refused', () {
      // The same rule, and it was **missed** in the first draft of this mapper: the
      // class doc's table listed three refusals and this was the fourth. A best-run
      // is a count of days like `currentStreak` is, it is drawn by `/result`, and
      // `StreakPill` **compares** the two — so a `-1` longest against a `4` current
      // would make the screen say the reader has never done better than a number
      // that did not exist. The test is here so that the table and the code cannot
      // drift.
      final Failure failure = failureOf(
        mapper.map(
          contractWithKey(contractSubmitAnswer(), 'longest_streak', -1),
        ),
      );
      expect(failure.kind, FailureKind.serialization);
      expect(failure.message, contains('0 or more'));
    });

    test(
      'a `points_earned` of 0 is PASSED THROUGH — it is the wrong-answer value',
      () {
        final SubmitResult result = entityOf(
          mapper.map(
            contractWithKey(contractSubmitAnswer(), 'points_earned', 0),
          ),
        );
        expect(result.pointsEarned, 0);
      },
    );

    test(
      'a `current_streak` of 0 is PASSED THROUGH — it is the live value',
      () {
        // Decision 45's rejected rule, restated because the same mistake is available
        // here: a rule that refused "empty-looking" numbers would make this the one
        // value on every cold launch a serialization failure.
        final SubmitResult result = entityOf(
          mapper.map(
            contractWithKey(contractSubmitAnswer(), 'current_streak', 0),
          ),
        );
        expect(result.currentStreak, 0);
      },
    );

    test('an EMPTY `question_id` is passed through, like `reference`', () {
      // Same verdict as decision 45's `reference: ''`: identity is passed through,
      // because nothing here would be drawn and refusing would make the whole
      // submission unreadable over a value the server echoes rather than computes.
      final SubmitResult result = entityOf(
        mapper.map(contractWithKey(contractSubmitAnswer(), 'question_id', '')),
      );
      expect(result.questionId, isEmpty);
    });

    test('a very large streak is PASSED THROUGH — no bound is invented', () {
      // Decision 45's other rejection: this client has seen no upper bound, and a
      // bound is a claim about a payload it has not seen. What keeps that honest is
      // layout, and `result_page_test.dart` renders a twelve-digit streak at 320px
      // and asserts no overflow — the same witness `home_page_test.dart` gives.
      final SubmitResult result = entityOf(
        mapper.map(
          contractWithKey(
            contractSubmitAnswer(),
            'current_streak',
            123456789012,
          ),
        ),
      );
      expect(result.currentStreak, 123456789012);
    });
  });

  group('a body that is not an object', () {
    test('is a serialization failure, never an exception', () {
      for (final Object? body in <Object?>[
        null,
        'not an object',
        42,
        <Object?>[],
      ]) {
        final Failure failure = failureOf(mapper.map(body));
        expect(failure.kind, FailureKind.serialization);
        expect(
          failure.message,
          contains(SubmitResultMapper.endpoint),
          reason:
              'the message names the operation by its path, so a reader holding '
              'four requests in a log can tell which one failed. A shared '
              '"Could not read" prefix would not.',
        );
        expect(
          failure.message,
          startsWith(
            'Could not read the answer from /api/v1/readings/:id/submit',
          ),
        );
      }
    });

    test('and an HTML document is named as one', () {
      // `today_reading_mapper.dart` established the wording for this shape: a proxy
      // in front of the backend answers instead of it, and "type String is not a
      // Map" tells a reader nothing about that.
      final Failure failure = failureOf(
        mapper.map('<!DOCTYPE html><html><body>502</body></html>'),
      );
      expect(failure.message, contains('HTML'));
    });
  });
}
