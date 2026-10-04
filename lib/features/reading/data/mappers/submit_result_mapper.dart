import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/reading/data/mappers/today_reading_mapper.dart';

/// Turns one `POST /api/v1/readings/:id/submit` body into a [SubmitResult].
///
/// ## THE PROVENANCE IS A **DECLARATION**, NOT A CAPTURE, AND IT IS THE FIRST
/// ## THING A READER NEEDS TO KNOW
///
/// Every other mapper in this directory was written against a body this client
/// received. **This one was not, and cannot be.** Verified live against
/// `HEAD = 4a1c834`, the endpoint's three reachable answers are a `400` (the
/// fabricated `question_id` is not a UUID), a `404` (`QUESTION_NOT_FOUND`) and a
/// `409` (already submitted) — AGENT_CONTEXT §5 trap 10 carries the exact bodies.
///
/// So the shape here is transcribed from `SubmitAnswerResult` in
/// `src/modules/submissions/submissions.service.ts:5-13`, which is the interface
/// the backend itself compiles against. The **names, types and order** are the
/// declaration's; the *values* in any fixture are plausible rather than observed,
/// and `test/support/contract_payloads.dart` says so where the JSON lives.
///
/// **What that means for the tests beside this one.** They are contract tests, not
/// integration tests: they hold the client to the shape the backend declares, and
/// they would **not** have caught a divergence between the declaration and the
/// running service — because that divergence cannot be observed. The honest
/// statement is the one `SubmitResult`'s own doc makes: a successful submit has
/// never reached this client.
///
/// ## WHY IT IS A SEPARATE MAPPER AND NOT A MODE OF `TodayReadingMapper`
///
/// §3's SRP row: "a mapper owns JSON→domain only", and these are two bodies.
/// One mapper reading both would need a flag naming which it was handed, and a
/// flag in a parser is a second parsing mode free to disagree with itself. Two
/// mappers also means two places a reader looks, and this one's is unambiguous —
/// `SubmitResultMapper` is the only class in the repository that can produce a
/// `SubmitResult`.
///
/// ## THE SCALAR POLICY, WHICH IS DECISION 45'S ONE QUESTION ASKED AGAIN
///
/// Decision 45 gave `TodayReadingMapper` a single test and the instruction that
/// nothing else may decide it: *would this client render the value as something a
/// reader would read as a fact about their own reading?*
///
/// | field | policy | why |
/// | --- | --- | --- |
/// | `question_id` | **passed through**, including `''` | identity. Decision 45's `reference: ''` is the precedent: refusing an echoed value would make the whole submission unreadable over a field nothing draws. |
/// | `is_correct` | **refused** unless a `bool` | it is the whole point of the response, and a non-`bool` means the body is not a submission |
/// | `points_earned` | **refused** if negative | **drawn by `/result`.** Decision 45 explicitly declined this for `total_points_earned_today` "because it is rendered nowhere on `/`" — a screen that *does* draw a score is a different screen, and the asymmetry is deliberate rather than an oversight. |
/// | `current_total_points` | **refused** if negative | same row |
/// | `current_streak` | **refused** if negative; **passed through** at `0` | decision 45's rule and its rejected twin, both restated because both mistakes are available here |
/// | `longest_streak` | **refused** if negative; **passed through** at `0` | the same count of days, and `/result` **compares** the two — see [SubmitResult.longestStreak] |
/// | `reading_completed` | **refused** unless a `bool` | §5 trap 4's gate on the streak |
/// | any **large** positive number | **passed through** | this client has seen no upper bound, and inventing one is a claim about a payload it has not seen |
///
/// ## AND NO `text_clean`-STYLE LENIENCY ANYWHERE
///
/// `TodayReadingMapper` has two deliberately lenient reads — an absent
/// `text_clean`, and an `already_answered` that is not a `bool` — and both are
/// absences **the live payloads actually have** (§5 traps 2 and 3). This payload has
/// no such documented absence: `SubmitAnswerResult` declares all seven fields and
/// the service builds the object itself. So there is nothing to be lenient about,
/// and a lenient read here would be a guess about a body nobody can observe.
///
/// **Rejected: defaulting `reading_completed` to `false`.** It is the field with
/// real consequences (§5 trap 4 — the streak does not move without it), so a default
/// would be a client deciding that a submission did not finish the reading.
final class SubmitResultMapper {
  /// Creates a mapper. Stateless and `const`.
  const SubmitResultMapper();

  /// The endpoint, for the messages a failure names.
  ///
  /// `/api/v1` and the `{id}` placeholder because the mapper has no id — it is
  /// handed a body — and a reader chasing a 400 wants the path, not the template.
  static const String endpoint = '/api/v1/readings/:id/submit';

  /// The path for a submission against [readingId].
  ///
  /// ## AND **NOT** URL-ENCODED, DELIBERATELY
  ///
  /// The obvious hardening is `Uri.encodeComponent(readingId)`, and it is wrong
  /// here. The id is whatever `GET /readings/today/{lang}` handed out — §5 traps 10
  /// and 11 record that this is a fabricated, **date-dependent** non-UUID today, so
  /// a value with a `/` in it is not hypothetical, only unobserved. Encoding would
  /// send a *different* path than the server minted, which is a 404 whose message
  /// names a question rather than a reading. Sending it verbatim means the failure
  /// is the server's own and its message is quotable, and
  /// `dio_repositories_test.dart`'s `pathSegments` assertion is what makes a change
  /// here visible.
  ///
  /// This mirrors [TodayReadingMapper.pathFor] for the read: the endpoint path
  /// lives with the mapper that names the body, so there is no second copy of
  /// `/api/v1/readings` in the data layer.
  static String submitPathFor(String readingId) =>
      '${TodayReadingMapper.readingsRoot}/$readingId/submit';

  /// Maps [body] to a [SubmitResult].
  ///
  /// Never throws. A 2xx body that cannot be read is
  /// [FailureKind.serialization], produced next to the field that is malformed —
  /// §3's LSP row and `failure.dart`'s vocabulary for that kind.
  Result<SubmitResult> map(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<SubmitResult>.failure(_notAnObject(body));
    }

    // Read in **wire order**, for `TodayReadingMapper`'s reason: the message on a
    // body with several problems names the key a reader meets first scrolling the
    // JSON, and the interface's declaration order is the wire order here because
    // the service builds the object literal in that order.
    final Result<String> questionId = _string(body, 'question_id');
    final Result<bool> isCorrect = _bool(body, 'is_correct');
    final Result<int> pointsEarned = _count(body, 'points_earned');
    final Result<int> currentTotalPoints = _count(body, 'current_total_points');
    final Result<int> currentStreak = _streak(body, 'current_streak');
    final Result<int> longestStreak = _count(body, 'longest_streak');
    final Result<bool> readingCompleted = _bool(body, 'reading_completed');

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      questionId,
      isCorrect,
      pointsEarned,
      currentTotalPoints,
      currentStreak,
      longestStreak,
      readingCompleted,
    ]);
    if (gate case FailureResult<void>(:final Failure failure)) {
      return Result<SubmitResult>.failure(failure);
    }

    // `valueOrElse` from here, not `!`: [gate] has proved there is no failure arm to
    // take, so **every fallback below is unreachable**. Phase 6 established the shape
    // and `today_reading_mapper.dart` says the same thing about its own; this file
    // recorded it only after a mutation audit, and the audit is what found it.
    //
    // **That audit produced the one MISSED mutation of this phase, and it is recorded
    // here because the line looks like a gate and is not.** Flipping
    // `isCorrect.valueOrElse(false)` to `valueOrElse(true)` changed **no** test
    // outcome, and the temptation is to call that a gap in the suite. It is not: the
    // `gate` above returns first, so a body with a non-`bool` `is_correct` never
    // reaches this line at all. Mutating a dead line tells you nothing about the gate
    // — which is why the mutation that *does* probe it removes `isCorrect` from the
    // gate list, and that one turns two tests red.
    //
    // So the fallbacks are kept rather than deleted. Deleting them would mean either
    // `!` (which §4 forbids without a proof the compiler cannot see) or a second gate,
    // and the honest statement of "this is unreachable" belongs in a comment where the
    // next reader is about to change it.
    return Result<SubmitResult>.success(
      SubmitResult(
        questionId: questionId.valueOrElse(''),
        isCorrect: isCorrect.valueOrElse(false),
        pointsEarned: pointsEarned.valueOrElse(0),
        currentTotalPoints: currentTotalPoints.valueOrElse(0),
        currentStreak: currentStreak.valueOrElse(0),
        longestStreak: longestStreak.valueOrElse(0),
        readingCompleted: readingCompleted.valueOrElse(false),
      ),
    );
  }

  // --- typed reads ----------------------------------------------------------

  Result<String> _string(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.success(value)
        : Result<String>.failure(_bad(key, value, 'a String'));
  }

  Result<bool> _bool(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is bool
        ? Result<bool>.success(value)
        : Result<bool>.failure(_bad(key, value, 'a bool'));
  }

  /// An `int` that cannot be negative — a score or a total of them.
  ///
  /// [TodayReadingMapper]'s `_int` doc gives the `num` rule (JSON `6.0` decodes to a
  /// `double`, and truncating a number the server sent would be a count one off for
  /// a reader with no way to tell why). Both apply unchanged.
  Result<int> _count(Map<Object?, Object?> body, String key) =>
      _nonNegative(body, key, 'a score of 0 or more');

  /// A count of completed days.
  ///
  /// Its own wording, and its own rule, for `TodayReadingMapper._nonNegativeInt`'s
  /// reason: the message should say what the number *is*, because that is what a
  /// reader looking at `-5` needs to be told.
  Result<int> _streak(Map<Object?, Object?> body, String key) =>
      _nonNegative(body, key, 'a count of completed days of 0 or more');

  Result<int> _nonNegative(
    Map<Object?, Object?> body,
    String key,
    String expected,
  ) {
    final Object? value = body[key];
    if (value is! int) {
      return Result<int>.failure(_bad(key, value, 'an int'));
    }
    if (value < 0) {
      return Result<int>.failure(_bad(key, value, expected));
    }
    return Result<int>.success(value);
  }

  /// The first failure among [results], as a `Result<void>` so the caller
  /// pattern-matches once instead of checking seven locals.
  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case FailureResult<Object?>(:final Failure failure)) {
        return Result<void>.failure(failure);
      }
    }
    return const Result<void>.success(null);
  }

  /// Why a body that is not an object is named by *what it was*.
  ///
  /// `TodayReadingMapper._notAnObject`'s three named cases, for the same three
  /// reasons, and the wording is the operation's own so a reader can tell which of
  /// this client's four requests failed.
  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        'Could not read the answer from $endpoint: the response body was empty. A 200 with no '
            'body is what a proxy returns when it swallows the upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the answer from $endpoint: the response body is an HTML '
            'document '
            '(${text.length} characters), not JSON. Something between the app and '
            'the backend answered instead of it.',
      final Object other =>
        'Could not read the answer from $endpoint: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the answer from $endpoint: `$key` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
