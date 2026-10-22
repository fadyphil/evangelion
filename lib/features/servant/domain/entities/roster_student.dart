import 'package:freezed_annotation/freezed_annotation.dart';

part 'roster_student.freezed.dart';

/// One child on the cohort's roster.
///
/// ## THE ROW, FIELD FOR FIELD
///
/// `admin.routes.ts:403-413` builds each row as:
///
/// ```text
/// user_id, full_name, preferred_lang, total_points, current_streak,
/// points_earned_today, completed_today, questions_progress
/// ```
///
/// and the response schema at `:353-364` declares the same eight keys.
///
/// ## `questionsProgress` IS THE SERVER'S **STRING**, AND THAT IS THE POINT
///
/// `admin.routes.ts:412` writes `` `${answeredQ}/${totalQ}` `` — a **string**,
/// not two numbers. The domain keeps it exactly as the server wrote it, for
/// two reasons:
///
/// * the row can draw `3/5` the way the server wrote it, with no second
///   formatting rule to keep in step; and
/// * the server's own denominator is a count of **approved** questions
///   (`:383`), which a client that parsed the string into two numbers would
///   have to re-derive to explain a `0/0`.
///
/// A `0/0` is a real answer: it means the cohort had no approved question for
/// that date, and the server's `completed_today` is then `false`
/// (`totalQ > 0 && answeredQ >= totalQ`, `:411`).
@freezed
final class RosterStudent with _$RosterStudent {
  /// One child on the roster.
  const RosterStudent({
    required this.userId,
    required this.fullName,
    required this.preferredLang,
    required this.totalPoints,
    required this.currentStreak,
    required this.pointsEarnedToday,
    required this.completedToday,
    required this.questionsProgress,
  });

  /// The server's id for this child.
  final String userId;

  /// The child's name, exactly as the server sent it.
  final String fullName;

  /// The child's preferred language — `'ar'` or `'en'`.
  final String preferredLang;

  /// The child's lifetime points.
  final int totalPoints;

  /// The child's current streak, in days.
  final int currentStreak;

  /// How many points the child earned **today**.
  final int pointsEarnedToday;

  /// Whether the child has answered every approved question for the date.
  final bool completedToday;

  /// The server's own progress token — `3/5`.
  final String questionsProgress;

  /// The row's **numbers**, and not the child.
  ///
  /// ## AND WHY IT IS DECLARED HERE AT ALL
  ///
  /// freezed **generates** a `toString` that lists every property — and two of
  /// them are the child's name and the child's id. A `toString` is a log line,
  /// a crash report and a failed `expect`, so the generated one writes a
  /// child's name into all three, for every row of every roster the client
  /// holds.
  ///
  /// **freezed SKIPS the member the class declares itself**, and this
  /// declaration is what makes it skip it — verified by generation rather than
  /// by reading its documentation: this file's generated part carries an `==`,
  /// a `hashCode` and a `copyWith` and **no** `toString`.
  ///
  /// ## AND WHAT IT CARRIES, AND WHY
  ///
  /// The row's **numbers** — the points, the streak, the day's progress token
  /// — and the language the row was served in. Those are what a failing test
  /// needs *about* a row: which number was wrong.
  ///
  /// **Not the name and not the id.** Those two are the child's identity, and
  /// this client handles **other people's children** — the servant's cohort and
  /// the board's witnesses — so a name in a log line is a child's name in a
  /// place whoever reads the logs has no business seeing it. The scan that
  /// holds this is `test/core/common/secret_masking_test.dart`, and it is the
  /// same scan the password rule uses.
  @override
  String toString() =>
      'RosterStudent(preferredLang: $preferredLang, totalPoints: $totalPoints, '
      'currentStreak: $currentStreak, pointsEarnedToday: $pointsEarnedToday, '
      'completedToday: $completedToday, questionsProgress: $questionsProgress)';
}
