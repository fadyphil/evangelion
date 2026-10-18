import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:fpdart/fpdart.dart';

/// Turns one `GET /api/v1/streak` body into its `history[]`.
///
/// ## THE SIBLING OF `StreakSummaryMapper`, AND WHY IT IS NOT THAT CLASS
///
/// §3's SRP row is "one reason to change per file", and the two responses have two:
/// `/streak/summary` changes when the **summary's** nine scalars change, and
/// `/streak` changes when a **row** gains a key — `points_earned` did, and
/// `streak.service.ts:130-142` is where it appeared. One mapper with two methods
/// would have both reasons to change and no way to change one without opening the
/// other. It is also a second endpoint constant (`/api/v1/streak`, not
/// `/api/v1/streak/summary`) and a second set of type guards, so the file is about
/// twice the size of what one class would be.
///
/// ## IT DROPS NINE KEYS, AND SAYS WHY FOR EACH GROUP
///
/// The body also carries `user_id`, `group_id`, `today_date` and the six summary
/// scalars the sibling mapper owns. **The scalars are not re-projected here** —
/// `streak.routes.ts:163-172` builds `/streak/summary` by picking fields off this
/// very call, so a second projection would be two entities for one fact and two
/// places for the two requests to disagree. `user_id` / `group_id` are the request
/// headers this client already sends, for `StreakSummaryMapper`'s reason. And
/// `today_date` is a date with no time and no zone, which
/// `StreakHistoryEntry.scheduledDate` records as a reason to keep dates as the
/// server's strings.
///
/// ## EVERY KEY IS REQUIRED, AND ONE ROW FAILS THE WHOLE ARRAY
///
/// The sibling mapper's rule, applied to a row: a missing key is a
/// `FailureKind.serialization` and not a default, because a default is a claim
/// about a payload this client has not seen. **A row's failure fails the array**
/// rather than skipping the row, for the reason the port's doc gives — `history[0]`
/// is the one row `/` renders, so a list that silently dropped malformed rows
/// would move the card to a different day without saying so.
///
/// ## `reference` IS AN OBJECT AND BOTH ARMS ARE KEPT
///
/// `streak.routes.ts:40-45` types it `{ ar, en }`, and `streak.service.ts:120-124`
/// builds each with a colon after the chapter in Arabic (`٢٣: ١-٦`) and none in
/// English (`23:1-6`). The spacing difference is the server's and is carried
/// verbatim, for `TodayReading.reference`'s reason.
final class StreakHistoryMapper {
  /// Creates a mapper. Stateless and `const`.
  const StreakHistoryMapper();

  /// The endpoint, including the `/api/v1` prefix.
  ///
  /// Beside `StreakSummaryMapper.summaryEndpoint` and not in `AppConfig`, for
  /// `dio_client.dart`'s reason: the base URL is the host, and a deployment
  /// behind a path-prefixed proxy has to stay reachable.
  static const String historyEndpoint = '/api/v1/streak';

  /// Maps [body] to the endpoint's `history[]`, in the server's order.
  ///
  /// Never throws, and every [Failure.message] names the key, the row it was in
  /// and what was expected — so the message a reader sees is a statement about the
  /// response rather than a Dart type error.
  Result<List<StreakHistoryEntry>> map(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<List<StreakHistoryEntry>>.left(_notAnObject(body));
    }

    final Object? rawHistory = body['history'];
    if (rawHistory is! List<Object?>) {
      return Result<List<StreakHistoryEntry>>.left(
        _bad('history', rawHistory, 'an array'),
      );
    }

    final List<StreakHistoryEntry> entries = <StreakHistoryEntry>[];
    for (int index = 0; index < rawHistory.length; index++) {
      final Result<StreakHistoryEntry> row = _row(rawHistory[index], index);
      if (row case Left<Failure, StreakHistoryEntry>(value: final failure)) {
        return Result<List<StreakHistoryEntry>>.left(failure);
      }
      entries.add(row.getOrElse((_) => _unreachable));
    }
    return Result<List<StreakHistoryEntry>>.of(
      List<StreakHistoryEntry>.unmodifiable(entries),
    );
  }

  /// The value `_row`'s `getOrElse` fallback would return, and which the gate in
  /// `_row` proves it cannot return.
  ///
  /// Named so that the list loop's fallback is one identifier rather than an
  /// inline literal: an inline one would be a `StreakHistoryEntry` built from
  /// nothing, which is the exact shape a reader scanning this file would copy.
  static const StreakHistoryEntry _unreachable = StreakHistoryEntry(
    readingId: '',
    scheduledDate: '',
    bookNumber: 0,
    bookNameEn: '',
    bookNameAr: '',
    referenceEn: '',
    referenceAr: '',
    totalQuestions: 0,
    answeredQuestions: 0,
    correctAnswers: 0,
    pointsEarned: 0,
    isCompleted: false,
  );

  /// One `history[]` element.
  ///
  /// Wire order, so the message on a row with several problems names the key a
  /// reader meets first in the JSON.
  Result<StreakHistoryEntry> _row(Object? raw, int index) {
    if (raw is! Map<Object?, Object?>) {
      return Result<StreakHistoryEntry>.left(
        Failure(
          kind: FailureKind.serialization,
          message:
              'Could not read the streak history: `history[$index]` is '
              '${raw == null ? 'absent' : 'a ${raw.runtimeType}'}, not a JSON '
              'object.',
        ),
      );
    }

    final Result<String> referenceAr = _referenceArm(raw, 'ar', index);
    final Result<String> referenceEn = _referenceArm(raw, 'en', index);

    final Result<String> readingId = _string(raw, 'reading_id', index);
    final Result<String> scheduledDate = _string(raw, 'scheduled_date', index);
    final Result<int> bookNumber = _int(raw, 'book_number', index);
    final Result<String> bookNameEn = _string(raw, 'book_name_en', index);
    final Result<String> bookNameAr = _string(raw, 'book_name_ar', index);
    final Result<int> totalQuestions = _int(raw, 'total_questions', index);
    final Result<int> answeredQuestions = _int(
      raw,
      'answered_questions',
      index,
    );
    final Result<int> correctAnswers = _int(raw, 'correct_answers', index);
    final Result<int> pointsEarned = _int(raw, 'points_earned', index);
    final Result<bool> isCompleted = _bool(raw, 'is_completed', index);

    final Result<void> scalars = _firstFailure(<Result<Object?>>[
      readingId,
      scheduledDate,
      bookNumber,
      bookNameEn,
      bookNameAr,
      referenceAr,
      referenceEn,
      totalQuestions,
      answeredQuestions,
      correctAnswers,
      pointsEarned,
      isCompleted,
    ]);
    if (scalars case Left<Failure, void>(value: final failure)) {
      return Result<StreakHistoryEntry>.left(failure);
    }

    // `getOrElse` rather than `!`, and with the same fallbacks the sibling mapper
    // uses: the gate above has proved there is no failure arm, so **the fallback
    // cannot be reached** and §4 forbids a `!` that is not provably non-null. The
    // values in it are therefore never read, and they are the zero values rather
    // than sentinels so that a future refactor which removes the gate fails on the
    // empty row rather than on a plausible-looking one.
    return Result<StreakHistoryEntry>.of(
      StreakHistoryEntry(
        readingId: readingId.getOrElse((_) => ''),
        scheduledDate: scheduledDate.getOrElse((_) => ''),
        bookNumber: bookNumber.getOrElse((_) => 0),
        bookNameEn: bookNameEn.getOrElse((_) => ''),
        bookNameAr: bookNameAr.getOrElse((_) => ''),
        referenceEn: referenceEn.getOrElse((_) => ''),
        referenceAr: referenceAr.getOrElse((_) => ''),
        totalQuestions: totalQuestions.getOrElse((_) => 0),
        answeredQuestions: answeredQuestions.getOrElse((_) => 0),
        correctAnswers: correctAnswers.getOrElse((_) => 0),
        pointsEarned: pointsEarned.getOrElse((_) => 0),
        isCompleted: isCompleted.getOrElse((_) => false),
      ),
    );
  }

  /// One arm of the row's `reference` object.
  Result<String> _referenceArm(
    Map<Object?, Object?> row,
    String arm,
    int index,
  ) {
    final Object? reference = row['reference'];
    if (reference is! Map<Object?, Object?>) {
      return Result<String>.left(
        Failure(
          kind: FailureKind.serialization,
          message:
              'Could not read the streak history: `history[$index].reference` is '
              '${reference == null ? 'absent' : 'a ${reference.runtimeType}'}, '
              'not a JSON object.',
        ),
      );
    }
    final Object? value = reference[arm];
    return value is String
        ? Result<String>.of(value)
        : Result<String>.left(
            _bad('history[$index].reference.$arm', value, 'a String'),
          );
  }

  Result<String> _string(Map<Object?, Object?> row, String key, int index) {
    final Object? value = row[key];
    return value is String
        ? Result<String>.of(value)
        : Result<String>.left(_bad('history[$index].$key', value, 'a String'));
  }

  /// An `int`, and not a `num`, for `streak_summary_mapper.dart`'s reason: JSON
  /// `6.0` decodes to a `double` and every field read here is a count, so
  /// accepting it would truncate a number the server sent, silently.
  Result<int> _int(Map<Object?, Object?> row, String key, int index) {
    final Object? value = row[key];
    return value is int
        ? Result<int>.of(value)
        : Result<int>.left(_bad('history[$index].$key', value, 'an int'));
  }

  Result<bool> _bool(Map<Object?, Object?> row, String key, int index) {
    final Object? value = row[key];
    return value is bool
        ? Result<bool>.of(value)
        : Result<bool>.left(_bad('history[$index].$key', value, 'a bool'));
  }

  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case Left<Failure, Object?>(value: final failure)) {
        return Result<void>.left(failure);
      }
    }
    return const Right<Failure, void>(null);
  }

  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        'Could not read the streak history: the response body was empty. A 200 '
            'with no body is what a proxy returns when it swallows the upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the streak history: the response body is an HTML document '
            '(${text.length} characters), not JSON. Something between the app and '
            'the backend answered instead of it.',
      final Object other =>
        'Could not read the streak history: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the streak history: `$key` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
