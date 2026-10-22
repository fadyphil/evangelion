import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:fpdart/fpdart.dart';

/// The daily report route's wire shape.
///
/// ## THE ASYMMETRY IS THE WHOLE JOB
///
/// The wire speaks **snake_case** (`group_id`, `report_date`, `total_students`,
/// `completed_count`, and inside each row `user_id`, `full_name`,
/// `preferred_lang`, `total_points`, `current_streak`, `points_earned_today`,
/// `completed_today`, `questions_progress`) and the domain speaks
/// **camelCase**. Every key below is transcribed from `admin.routes.ts:344-364`
/// (the response schema) and `:401-422` (the row the route builds).
///
/// ## AND A BAD ROW FAILS THE WHOLE REPORT
///
/// `LeaderboardMapper`'s rule, for the same reason: a skipped row leaves a
/// roster with a hole in it, and a roster that reads as authoritative while
/// being wrong is worse than an error with a retry. The rows are homogeneous
/// by construction — the server builds them all in one `.map()` over one array
/// (`:401-414`) — so the strictness costs nothing in practice.
final class ReportMapper {
  /// Creates a mapper. Stateless and `const`.
  const ReportMapper();

  /// The endpoint, including the `/api/v1` prefix.
  static const String endpoint = '/api/v1/servant/reports/daily';

  /// The path for [groupId] on [date].
  ///
  /// `admin.routes.ts:336-341` declares `group_id` and `date` as querystring
  /// properties, and `:373-374` reads them with
  /// `parseInt(queryParams.group_id || '1', 10)` and
  /// `queryParams.date || today`.
  ///
  /// ## AND THE DATE IS **ENCODED**
  ///
  /// **A QUERY STRING IS A STRUCTURE, AND A VALUE IS NOT.** `&` separates one
  /// parameter from the next and `=` separates a name from its value — so a
  /// date that is neither checked nor encoded is not one value, it is two, and
  /// the second one is the server's to believe.
  ///
  /// **MEASURED, 2026-10-21, over this mapper:**
  ///
  /// ```text
  /// the date = 2026-10-21&group_id=7
  /// the path = /api/v1/servant/reports/daily?group_id=3&date=2026-10-21&group_id=7
  /// the parameters = group_id: 7, date: 2026-10-21
  /// ```
  ///
  /// The request was about **cohort 7** — the server reads the **last**
  /// `group_id` — while the servant had asked for cohort 3, and the roster
  /// that came back was another cohort's children.
  ///
  /// **AND THE ENCODING IS THE **SECOND** OF TWO DEFENCES, NOT THE ONLY
  /// ONE.** `ServantReportCubit` refuses a date that is not `YYYY-MM-DD`
  /// before the request is made, so a well-formed day is what reaches here;
  /// this is what makes the **URL** correct for anything that ever does.
  ///
  /// **AND THE COHORT IS NOT ENCODED, BECAUSE IT IS NOT TEXT.** It is an
  /// `int` — the only value of the two that cannot be anything else.
  static String pathFor({required int groupId, required String date}) =>
      '$endpoint?group_id=$groupId&date=${Uri.encodeQueryComponent(date)}';

  /// Maps the `200` body to a [ServantReport].
  ///
  /// Never throws. A 2xx body that cannot be read is
  /// [FailureKind.serialization].
  Result<ServantReport> map(Object? body) {
    if (body is! Map<Object?, Object?>) {
      return Result<ServantReport>.left(_notAnObject(body));
    }

    final Result<int> groupId = _int(body, 'group_id');
    final Result<String> reportDate = _string(body, 'report_date');
    final Result<int> totalStudents = _int(body, 'total_students');
    final Result<int> completedCount = _int(body, 'completed_count');
    final Result<List<Object?>> rawStudents = _list(body, 'students');

    final Result<void> gate = _firstFailure(<Result<Object?>>[
      groupId,
      reportDate,
      totalStudents,
      completedCount,
      rawStudents,
    ]);
    if (gate case Left<Failure, void>(value: final failure)) {
      return Result<ServantReport>.left(failure);
    }

    final Result<List<RosterStudent>> students = _students(
      rawStudents.getOrElse((_) => const <Object?>[]),
    );
    if (students case Left<Failure, List<RosterStudent>>(
      value: final failure,
    )) {
      return Result<ServantReport>.left(failure);
    }

    return Result<ServantReport>.of(
      ServantReport(
        groupId: groupId.getOrElse((_) => 0),
        reportDate: reportDate.getOrElse((_) => ''),
        totalStudents: totalStudents.getOrElse((_) => 0),
        completedCount: completedCount.getOrElse((_) => 0),
        students: students.getOrElse((_) => const <RosterStudent>[]),
      ),
    );
  }

  /// The roster, all-or-nothing.
  ///
  /// An **empty** array is a success with no rows: a cohort with no children
  /// is a real answer, and the empty state is a real product state.
  Result<List<RosterStudent>> _students(List<Object?> raw) {
    final List<RosterStudent> students = <RosterStudent>[];
    for (int index = 0; index < raw.length; index++) {
      final Object? entry = raw[index];
      if (entry is! Map<Object?, Object?>) {
        return Result<List<RosterStudent>>.left(
          _bad('students[$index]', entry, 'a JSON object'),
        );
      }
      final Result<RosterStudent> student = _student(entry, index);
      if (student case Left<Failure, RosterStudent>(value: final failure)) {
        return Result<List<RosterStudent>>.left(failure);
      }
      if (student case Right<Failure, RosterStudent>(
        :final RosterStudent value,
      )) {
        students.add(value);
      }
    }
    return Result<List<RosterStudent>>.of(students);
  }

  /// One row, read under [label] so a failure names **which** row was wrong.
  Result<RosterStudent> _student(Map<Object?, Object?> entry, int index) {
    final String where = 'students[$index]';
    final Result<String> userId = _string(entry, 'user_id', where: where);
    final Result<String> fullName = _string(entry, 'full_name', where: where);
    final Result<String> preferredLang = _string(
      entry,
      'preferred_lang',
      where: where,
    );
    final Result<int> totalPoints = _int(entry, 'total_points', where: where);
    final Result<int> currentStreak = _int(
      entry,
      'current_streak',
      where: where,
    );
    final Result<int> pointsEarnedToday = _int(
      entry,
      'points_earned_today',
      where: where,
    );
    final Result<bool> completedToday = _bool(
      entry,
      'completed_today',
      where: where,
    );
    final Result<String> questionsProgress = _string(
      entry,
      'questions_progress',
      where: where,
    );

    final Result<void> fields = _firstFailure(<Result<Object?>>[
      userId,
      fullName,
      preferredLang,
      totalPoints,
      currentStreak,
      pointsEarnedToday,
      completedToday,
      questionsProgress,
    ]);
    if (fields case Left<Failure, void>(value: final failure)) {
      return Result<RosterStudent>.left(failure);
    }

    return Result<RosterStudent>.of(
      RosterStudent(
        userId: userId.getOrElse((_) => ''),
        fullName: fullName.getOrElse((_) => ''),
        preferredLang: preferredLang.getOrElse((_) => ''),
        totalPoints: totalPoints.getOrElse((_) => 0),
        currentStreak: currentStreak.getOrElse((_) => 0),
        pointsEarnedToday: pointsEarnedToday.getOrElse((_) => 0),
        completedToday: completedToday.getOrElse((_) => false),
        questionsProgress: questionsProgress.getOrElse((_) => ''),
      ),
    );
  }

  // --- typed reads ----------------------------------------------------------

  Result<String> _string(
    Map<Object?, Object?> body,
    String key, {
    String? where,
  }) {
    final Object? value = body[key];
    return value is String
        ? Result<String>.of(value)
        : Result<String>.left(_bad(_at(key, where), value, 'a String'));
  }

  /// An `int`, and not a `num`.
  ///
  /// JSON `6.0` decodes to a Dart `double`, and every count here is a count.
  /// Accepting it would mean truncating a number the server sent, silently.
  Result<int> _int(Map<Object?, Object?> body, String key, {String? where}) {
    final Object? value = body[key];
    return value is int
        ? Result<int>.of(value)
        : Result<int>.left(_bad(_at(key, where), value, 'an int'));
  }

  Result<bool> _bool(Map<Object?, Object?> body, String key, {String? where}) {
    final Object? value = body[key];
    return value is bool
        ? Result<bool>.of(value)
        : Result<bool>.left(_bad(_at(key, where), value, 'a bool'));
  }

  Result<List<Object?>> _list(Map<Object?, Object?> body, String key) {
    final Object? value = body[key];
    return value is List<Object?>
        ? Result<List<Object?>>.of(value)
        : Result<List<Object?>>.left(_bad(key, value, 'a list'));
  }

  /// `key`, or `<where>.<key>` — the path a reader needs to find the bad field.
  static String _at(String key, String? where) =>
      where == null ? key : '$where.$key';

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
        'Could not read the report from $endpoint: the response body was empty. A '
            '200 with no body is what a proxy returns when it swallows the '
            'upstream.',
      final String text when text.trimLeft().startsWith('<') =>
        'Could not read the report from $endpoint: the response body is an HTML '
            'document (${text.length} characters), not JSON. Something between the '
            'app and the backend answered instead of it.',
      final Object other =>
        'Could not read the report from $endpoint: the response body is a '
            '${other.runtimeType}, not a JSON object.',
    },
  );

  Failure _bad(String key, Object? value, String expected) => Failure(
    kind: FailureKind.serialization,
    message:
        'Could not read the report from $endpoint: `$key` is '
        '${value == null ? 'absent' : '$value (${value.runtimeType})'}, '
        'and $expected was expected.',
  );
}
