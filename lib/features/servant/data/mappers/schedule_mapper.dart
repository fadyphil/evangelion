import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:fpdart/fpdart.dart';

/// The schedule route's wire shape, in both directions.
///
/// ## THE ASYMMETRY IS THE WHOLE JOB
///
/// The wire speaks **snake_case** (`group_ids`, `scheduled_date`,
/// `book_number`, `start_chapter`, `start_verse`, `end_chapter`, `end_verse`,
/// `excluded_verses`, `generate_ai_questions`) and the domain speaks
/// **camelCase**. Every key in the body below is transcribed from
/// `admin.routes.ts:8-33` — the server's own `scheduleSchema` — and the
/// mapper is the one place that knows both spellings.
///
/// ## AND THE KEYS ARE WRITTEN **OUT**, NEVER DERIVED
///
/// A body builder that camel-cased the domain's field names would send
/// `groupIds` and the server would **strip it** — zod's `z.object` drops
/// unknown keys — and the schedule would be created with **no cohorts at
/// all**, and the server's `min(1)` on `group_ids` would refuse it with a 400
/// that names a field the client never wrote. So the keys are literals.
///
/// ## AND THE BODY IS **EXACT** — NO EXTRA KEYS
///
/// The same zod rule, from the other side: a key this client invented is
/// dropped without a word, and the test that would have noticed it is the one
/// that asserts the whole map.
final class ScheduleMapper {
  /// Creates a mapper. Stateless and `const`.
  const ScheduleMapper();

  /// The endpoint, including the `/api/v1` prefix.
  ///
  /// Here and not in `AppConfig`, for the reason `dio_client.dart`'s doc gives:
  /// the base URL is the host, and a deployment behind a path-prefixed proxy
  /// has to stay reachable.
  static const String endpoint = '/api/v1/admin/readings/schedule';

  /// The request body for [schedule].
  ///
  /// ## `end_chapter` IS **OMITTED**, NEVER SENT AS `null`
  ///
  /// The server types it `z.number().int().min(1).optional()`
  /// (`admin.routes.ts:14`), and `.optional()` accepts `undefined` and
  /// **refuses `null`** — a literal `null` in the body is a **400**. The
  /// server's own transform then writes `end_chapter: data.end_chapter ??
  /// data.start_chapter` (`:31-33`), which is exactly what "the passage does
  /// not cross a chapter boundary" means.
  ///
  /// ## AND `excluded_verses` AND `generate_ai_questions` ARE ALWAYS SENT
  ///
  /// Both have server-side defaults (`[]` at `:28` and `false` at `:29`), and
  /// the domain carries the same defaults. Sending them explicitly is
  /// harmless — zod accepts a value that matches the default — and it means
  /// the body a reader can read is the body the request carries.
  static Map<String, Object?> bodyFor(ReadingSchedule schedule) {
    final Map<String, Object?> body = <String, Object?>{
      // **A copy**, not the domain's own list: the body outlives this call and
      // a list shared with a caller is a list that can change under it.
      'group_ids': <int>[...schedule.groupIds],
      'scheduled_date': schedule.scheduledDate,
      'book_number': schedule.bookNumber,
      'start_chapter': schedule.startChapter,
      'start_verse': schedule.startVerse,
      'end_verse': schedule.endVerse,
      'excluded_verses': <Map<String, Object?>>[
        for (final ExcludedVerse excluded in schedule.excludedVerses)
          <String, Object?>{
            'chapter': excluded.chapter,
            'verse': excluded.verse,
          },
      ],
      'generate_ai_questions': schedule.generateAiQuestions,
    };
    final int? endChapter = schedule.endChapter;
    if (endChapter != null) {
      body['end_chapter'] = endChapter;
    }
    return body;
  }

  /// Maps the `201` body to a [ScheduleResult].
  ///
  /// Never throws. A 2xx body that cannot be read is
  /// [FailureKind.serialization], produced next to the field that is malformed
  /// — §3's LSP row and `failure.dart`'s vocabulary for that kind.
  Result<ScheduleResult> mapScheduleResult(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<ScheduleResult>.left(_notAnObject(body));
    }

    final Result<String> message = _string(body, 'message');
    final Result<List<String>> readingIds = _stringList(body, 'reading_ids');

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      message,
      readingIds,
    ]);
    if (gate case Left<Failure, void>(value: final failure)) {
      return Result<ScheduleResult>.left(failure);
    }

    return Result<ScheduleResult>.of(
      ScheduleResult(
        message: message.getOrElse((_) => ''),
        readingIds: readingIds.getOrElse((_) => const <String>[]),
      ),
    );
  }

  // --- typed reads ----------------------------------------------------------

  Result<String> _string(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.of(value)
        : Result<String>.left(_bad(key, value, 'a String'));
  }

  Result<List<String>> _stringList(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    if (value is! List<Object?>) {
      return Result<List<String>>.left(_bad(key, value, 'a list of strings'));
    }
    final List<String> strings = <String>[];
    for (int index = 0; index < value.length; index++) {
      final Object? entry = value[index];
      if (entry is! String) {
        return Result<List<String>>.left(
          _bad('$key[$index]', entry, 'a String'),
        );
      }
      strings.add(entry);
    }
    return Result<List<String>>.of(strings);
  }

  /// The first failure among [results], as a `Result<void>` so the caller
  /// pattern-matches once instead of checking every local.
  Result<void> _firstFailure(List<Result<Object?>> results) {
    for (final Result<Object?> result in results) {
      if (result case Left<Failure, Object?>(value: final failure)) {
        return Result<void>.left(failure);
      }
    }
    return const Right<Failure, void>(null);
  }

  /// Why a body that is not an object is named by *what it was*.
  ///
  /// `SubmitResultMapper._notAnObject`'s three named cases, for the same three
  /// reasons, and the wording is the operation's own so a reader can tell which
  /// of this client's requests failed.
  Failure _notAnObject(Object? body) => Failure(
    kind: FailureKind.serialization,
    message: switch (body) {
      null =>
        'Could not read the schedule from $endpoint: the response body was empty. '
            'A 200 with no body is what a proxy returns when it swallows the '
            'upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the schedule from $endpoint: the response body is an HTML '
            'document (${text.length} characters), not JSON. Something between the '
            'app and the backend answered instead of it.',
      final Object other =>
        'Could not read the schedule from $endpoint: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the schedule from $endpoint: `$key` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
