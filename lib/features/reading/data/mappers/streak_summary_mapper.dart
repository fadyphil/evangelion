import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';

/// Turns one `GET /api/v1/streak/summary` body into a [StreakSummary].
///
/// ## WHY IT RETURNS A `Result`, LIKE `TodayReadingMapper` DOES
///
/// §3's LSP row: a repository never throws and always returns a `Result`. A 200
/// whose body cannot be read is `FailureKind.serialization` — `failure.dart`
/// documents that kind as "a 2xx response body could not be parsed into a domain
/// entity" — and this is the only place that knows whether it can be.
///
/// ## EVERY KEY IS REQUIRED, AND `today_status` HAS NO DEFAULT
///
/// The important one is `today_status`. `StreakTodayStatus.fromCode` returns
/// `null` for anything outside `completed | pending | off_day | broken`, and the
/// mapper turns that into a serialization failure rather than picking one.
/// Defaulting to `pending` would report *nothing done today* for a server that
/// has said something this client does not understand, and Phase 8's streak pill
/// would then draw a claim instead of an error.
///
/// The same rule applies to every other key: a missing one is an error, because a
/// default is a claim about a payload this client has not seen.
///
/// ## THE TWO KEYS IT DELIBERATELY IGNORES
///
/// The live body also carries `user_id` and `group_id`, and neither reaches the
/// entity. Both are **request headers this client already sends**
/// (`IdentityHeadersInterceptor`), so a response echoing them adds nothing
/// actionable — and carrying them would put an echo in an equality contract, so a
/// server that normalised its `user_id` would look to bloc state like a different
/// streak. `streak_summary_mapper_test.dart` asserts both absences in the failing
/// direction, because "we decided" and "we forgot" look the same in a diff.
final class StreakSummaryMapper {
  /// Creates a mapper. Stateless and `const`.
  const StreakSummaryMapper();

  /// The endpoint, including the `/api/v1` prefix.
  ///
  /// Here and not in `AppConfig`, for the reason `dio_client.dart`'s doc gives:
  /// the base URL is the host, and a deployment behind a path-prefixed proxy has
  /// to stay reachable.
  static const String summaryEndpoint = '/api/v1/streak/summary';

  /// Maps [body] to a [StreakSummary].
  ///
  /// Never throws, and the [Failure.message] on every rejection names the key and
  /// what was expected — so the message a reader sees is a statement about the
  /// response rather than a Dart type error.
  Result<StreakSummary> map(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<StreakSummary>.failure(_notAnObject(body));
    }

    // Wire order, so the message on a body with several problems names the key a
    // reader meets first in the JSON.
    final Result<int> currentStreak = _int(body, 'current_streak');
    final Result<int> longestStreak = _int(body, 'longest_streak');
    final Result<String> lastCompletedDate = _string(
      body,
      'last_completed_date',
    );
    final Result<StreakTodayStatus> todayStatus = _status(body);
    final Result<bool> todayCompleted = _bool(body, 'today_completed');
    final Result<bool> todayScheduled = _bool(body, 'today_scheduled');
    final Result<int> nextMilestone = _int(body, 'next_milestone');
    final Result<int> daysToMilestone = _int(body, 'days_to_milestone');

    final Result<void> scalars = _firstFailure(<Result<Object?>>[
      currentStreak,
      longestStreak,
      lastCompletedDate,
      todayStatus,
      todayCompleted,
      todayScheduled,
      nextMilestone,
      daysToMilestone,
    ]);
    if (scalars case FailureResult<void>(:final Failure failure)) {
      return Result<StreakSummary>.failure(failure);
    }

    // `valueOrElse` rather than `!`: the gate above has proved there is no failure
    // arm, so the fallback cannot be reached, and §4 forbids a `!` that is not
    // provably non-null.
    return Result<StreakSummary>.success(
      StreakSummary(
        currentStreak: currentStreak.valueOrElse(0),
        longestStreak: longestStreak.valueOrElse(0),
        lastCompletedDate: lastCompletedDate.valueOrElse(''),
        todayStatus: todayStatus.valueOrElse(StreakTodayStatus.pending),
        todayCompleted: todayCompleted.valueOrElse(false),
        todayScheduled: todayScheduled.valueOrElse(false),
        nextMilestone: nextMilestone.valueOrElse(0),
        daysToMilestone: daysToMilestone.valueOrElse(0),
      ),
    );
  }

  /// `today_status`, through [StreakTodayStatus.fromCode].
  ///
  /// A missing key and an unrecognised value take the same path, and both are
  /// rejections. The distinction is not worth a branch: either way this client
  /// cannot say what today is, and the honest rendering of that is an error.
  Result<StreakTodayStatus> _status(Map<Object?, Object?> body) {
    final Object? value = body['today_status'];
    if (value is! String) {
      return Result<StreakTodayStatus>.failure(
        _bad('today_status', value, 'a String'),
      );
    }
    final StreakTodayStatus? status = StreakTodayStatus.fromCode(value);
    return status == null
        ? Result<StreakTodayStatus>.failure(
            _bad('today_status', value, 'one of ${StreakTodayStatus.values}'),
          )
        : Result<StreakTodayStatus>.success(status);
  }

  Result<String> _string(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.success(value)
        : Result<String>.failure(_bad(key, value, 'a String'));
  }

  /// An `int`, and not a `num`.
  ///
  /// JSON `6.0` decodes to a Dart `double`, and every field read here is a count.
  /// Accepting it would mean truncating a number the server sent, silently.
  Result<int> _int(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is int
        ? Result<int>.success(value)
        : Result<int>.failure(_bad(key, value, 'an int'));
  }

  Result<bool> _bool(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is bool
        ? Result<bool>.success(value)
        : Result<bool>.failure(_bad(key, value, 'a bool'));
  }

  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case FailureResult<Object?>(:final Failure failure)) {
        return Result<void>.failure(failure);
      }
    }
    return const Result<void>.success(null);
  }

  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        'Could not read the streak summary: the response body was empty. A 200 '
            'with no body is what a proxy returns when it swallows the upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the streak summary: the response body is an HTML document '
            '(${text.length} characters), not JSON. Something between the app and '
            'the backend answered instead of it.',
      final Object other =>
        'Could not read the streak summary: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the streak summary: `$key` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
