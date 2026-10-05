import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_board.freezed.dart';

/// Which stretch of time a leaderboard ranks over.
///
/// ## WHY THIS IS AN ENUM AND NOT A `String`
///
/// The three values are the **server's** vocabulary, and the server *rejects*
/// anything else: `window` carries `enum: ['weekly','monthly','all_time']`, and
/// Fastify's schema validation answers an unknown value with **400 Bad Request**
/// before the handler runs. Measured against the live endpoint:
/// `?window=nonsense` → `400 … querystring/window must be equal to one of the
/// allowed values`.
///
/// The handler's own `(['weekly','monthly','all_time'].includes(q.window) ? q.window
/// : 'weekly')` is therefore **dead code** — validation rejects first. So a client
/// that passed a raw string through would get a 400 rather than the documented
/// silent default, and the only way to be sure the value is acceptable is to never
/// hold one.
enum LeaderboardWindow {
  /// `weekly` — the ISO week, Monday-anchored.
  weekly('weekly'),

  /// `monthly` — the calendar month.
  monthly('monthly'),

  /// `all_time` — every score the cohort has ever banked.
  allTime('all_time');

  const LeaderboardWindow(this.code);

  /// The wire value, snake_case included. Spelled out rather than derived from the
  /// member name: `.name` would give `allTime`, and the server sends `all_time`.
  final String code;

  /// The window [code] names, or `null` if it names none of them.
  ///
  /// ## WHY `null` AND NOT A DEFAULT
  ///
  /// Because this enum is the client's half of a 400. An unknown window is not a
  /// window this app should quietly substitute `weekly` for — a server that grew a
  /// fourth window would then be silently reported as "this week", which is a wrong
  /// answer presented confidently. `null` lets the mapper refuse the payload as
  /// [FailureKind.serialization], so the reader is told the app is behind the server
  /// rather than shown a plausible lie.
  static LeaderboardWindow? fromCode(String code) => switch (code) {
    'weekly' => weekly,
    'monthly' => monthly,
    'all_time' => allTime,
    _ => null,
  };
}

/// One ranked child, as far as this app is concerned.
///
/// ## WHY THERE IS NO `fullName` FIELD, AND THAT IS THE POINT
///
/// The payload's row carries `full_name` — `'David Mina (Grade 5)'`, `'Peter George
/// (Grade 6)'`, `'Mark Anton (Grade 5)'` — and the mapper converts it to [initials]
/// and **drops it**. The requirement was "initials only, never full names", and this
/// is the difference between honouring it and promising it: a field that is not on
/// the entity **cannot be rendered**, so no future widget, no debug print, and no
/// careless `toString()` can leak another child's name into the UI. A convention
/// would be one forgotten `Text(row.fullName)` away from a privacy bug.
///
/// ## WHY THERE IS NO `currentStreak` EITHER
///
/// The payload carries it, and it is **wrong**: `users.current_streak` is the stored
/// value, which the backend's own memory fixture disagrees with — the seeded
/// `David Mina` row says `current_streak: 4` while a fresh recompute yields 0, and
/// `last_completed_date` is `'2026-09-29'`, three days before the fixture's "today".
/// The authoritative copy is `streak/summary.current_streak`, which the top bar's
/// flame already draws. Mapping a second, disagreeing copy into a *ranking* widget
/// would put two numbers for one fact on one screen. So it is dropped rather than
/// mapped-and-ignored.
///
/// ## WHY THERE IS NO `userId`
///
/// Nothing in Phase 1 acts on another child — no tap target, no profile, no
/// deep link. Holding the UUIDs of every child in the cohort in a value the UI can
/// reach is data with no reader, and §3's placement test asks what a type is *for*.
/// If a row ever becomes tappable, the id comes back at the same time as the
/// behaviour that needs it.
@freezed
final class LeaderboardRow with _$LeaderboardRow {
  /// A ranked child.
  const LeaderboardRow({
    required this.rank,
    required this.score,
    required this.initials,
  });

  /// 1-based position. Always present and always equal to the row's index + 1.
  ///
  /// The payload sends it explicitly, and it is trusted rather than recomputed: the
  /// server derives it from a Redis `ZREVRANGE` offset, so recomputing it here would
  /// be a second implementation of a ranking that has to agree with the first on ties
  /// — and it need not. See [LeaderboardBoard] for what the server does *not* sort.
  final int rank;

  /// Points in the window, as a whole number.
  final int score;

  /// One or two letters standing in for the child, never their name.
  ///
  /// Produced by the mapper's rule, which strips parenthetical annotations first —
  /// so `'David Mina (Grade 5)'` is `DM`, and not `D` from a token that includes the
  /// grade. Never empty: the mapper substitutes a placeholder rather than shipping a
  /// row with no label at all.
  final String initials;
}

/// Where the reader stands, which is a different question from who is above them.
///
/// ## WHY `rank` IS NULLABLE, AND NULL IS NOT ZERO
///
/// The endpoint answers `my_standing: {"rank": null, "score": 0}` for a child who has
/// not scored — measured, not inferred. `rank: null` means **unranked**, and `score: 0`
/// means **no points**. Those are different sentences: a reader with 0 points and a
/// rank of 9 is ninth; a reader with 0 points and no rank is nobody yet. Collapsing
/// them into a non-nullable `int` would put a fabricated position on a child who has
/// none, and would render as "0th" or "1st" depending on which guard was written.
///
/// Note this is a **`Result`-free null**, not a `Result.failure`. The server answered
/// 200 and told the truth; there is nothing to retry.
@freezed
final class LeaderboardStanding with _$LeaderboardStanding {
  /// The reader's own position.
  const LeaderboardStanding({required this.rank, required this.score});

  /// 1-based position, or `null` when the reader has no score in this window.
  final int? rank;

  /// The reader's own points. `0` with a `null` [rank] is the normal cold state.
  final int score;
}

/// A cohort's ranking for one window.
///
/// ## `total_ranked` IS **DELIBERATELY NOT MAPPED**, AND THIS IS THE ONE FIELD IN
/// THE PAYLOAD MOST LIKELY TO BE MISREAD
///
/// The payload's `total_ranked` is `enrichedEntries.length` — the number of rows
/// **this response returned**, *after* `limit` truncated it. It is not the number of
/// children in the cohort. With the server's default `limit=50`, a cohort of 60 scores
/// `total_ranked: 50`, and a cohort of 3 also scores `total_ranked: 3`.
///
/// The name invites "3rd of 12", and on a leaderboard that string is a lie the moment
/// the list is capped. Rather than map it and rely on every future call site to
/// remember what it means, **the field is not on the entity**: `LeaderboardBoard` has
/// no `totalRanked`, so "3 of N" cannot be rendered from this value because it does not
/// exist here. Recovering the true cohort size is a backend change — `ZCARD` — and it
/// belongs in the port as a new field when it exists, not as a guess made in a widget.
@freezed
final class LeaderboardBoard with _$LeaderboardBoard {
  /// A cohort ranking.
  const LeaderboardBoard({
    required this.window,
    required this.groupId,
    required this.rows,
    required this.standing,
  });

  /// Which window [rows] ranks over.
  ///
  /// Taken from the **response**, not from the request. The server echoes the window
  /// it ranked, and echoing is the only place the two can be compared; a client that
  /// assumed its own request was honoured would render a weekly board under a monthly
  /// heading and have no way to notice.
  final LeaderboardWindow window;

  /// The cohort these rows are for — `3` for the seeded group.
  final int groupId;

  /// The ranked rows, highest score first, capped at the requested limit.
  ///
  /// **Never empty on success.** An empty `leaderboard` is a legitimate server answer
  /// (nobody in the cohort has scored) and stays a success with zero rows — the empty
  /// state is a real product state here, not an error. What *is* refused is a missing
  /// or non-list `leaderboard` key, and a first row that cannot be read.
  final List<LeaderboardRow> rows;

  /// The reader's own position, or `null` when the request carried no `X-User-Id`.
  ///
  /// Distinct from `my_standing: {rank: null, score: 0}`, which is a standing with no
  /// rank. The endpoint returns `null` for the whole object when no user id was sent,
  /// and this app always sends one — so in practice `null` here means the server
  /// dropped it, which is worth rendering differently from "you are unranked".
  final LeaderboardStanding? standing;
}
