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

/// The board's two metrics — the prototype's `metricSeg` options
/// (`eva/redesign.html:623-625`, labels at `:941`).
///
/// ## WHY AN ENUM AND NOT A `String` OR A `bool`
///
/// A `bool` would be `isStreakMetric`, which names one arm and leaves the other as
/// the absence of a name. The prototype writes two named options and the segmented
/// control renders two labels; an enum is the same shape, and adding a third metric
/// is a compile error in every exhaustive `switch` rather than a silently-selected
/// default.
enum LeaderboardMetric {
  /// Ranked by the window's [LeaderboardRow.score].
  light,

  /// Ranked by [LeaderboardRow.currentStreak].
  streaks,
}

/// One ranked child, as far as this app is concerned.
///
/// ## WHY THESE FIELDS ARE HERE NOW, WHERE PHASE 1 DELIBERATELY OMITTED THEM
///
/// This entity used to carry three fields and three doc sections explaining the
/// absences: no [fullName], no [currentStreak], no [userId]. Each absence was a
/// structural privacy or honesty argument, and each is now **superseded** by
/// `docs/adr/0022-full-fidelity-redesign-supersedes-0001.md`'s full-fidelity
/// decision. The old reasoning is not deleted — it is recorded here as the position
/// that was correct for the screen Phase 1 shipped and is wrong for the screen
/// `eva/redesign.html:612-636` draws.
///
/// ### [fullName] — the requirement was "initials only"; the veil replaces it
///
/// The old text said: the payload's `full_name` is converted to [initials] and
/// dropped, because "a field that is not on the entity cannot be rendered" and a
/// convention would be one forgotten `Text(row.fullName)` away from a privacy bug.
///
/// **What changed:** ADR-0022 `:110-113` establishes that a ranked reader *is*
/// nameable — the board's own design prints names, and `:1070` is the rendering rule
/// for hiding them. The control is no longer the type system's silence; it is the
/// **veil** (`:1069-1072`, ADR-0022 `:243-245`), a rendering choice over rows that
/// already arrived. The entity carries the name because the row must be able to print
/// it, and `CommunionPage` renders `witness {position}` instead whenever the veil is
/// on. The mapper still derives [initials] from this same string, so the monogram and
/// the name cannot disagree about who the row is.
///
/// ### [currentStreak] — the disagreement is still real, and the metric switch is real too
///
/// The old text said the payload's `current_streak` is "wrong": it is the stored
/// `users.current_streak`, which the backend's memory fixture disagrees with — the
/// seeded `David Mina` row says `4` while a fresh recompute yields `0`, and
/// `last_completed_date` is `'2026-09-29'`, three days before the fixture's "today".
/// The authoritative copy is `streak/summary.current_streak`, which the top bar's
/// flame draws.
///
/// **What changed:** ADR-0022 `:49` makes the board's second metric real — the
/// prototype's `streakM` option (`redesign.html:941`) ranks rows by this field. It is
/// the row's own ranking value, not a second answer to the top bar's question, and the
/// ranking arithmetic lives in `features/leaderboard/domain/leaderboard_ranking.dart`.
/// **The disagreement can be visible**: the reader's row may show
/// `streak/summary`'s number beside the flame while this entity's number ranks the
/// board, because the two come from different endpoints with different recompute
/// times. That is recorded rather than smoothed over; inventing agreement in the
/// client would be a third number.
///
/// ### [userId] — the tap target arrived, so the id arrives with it
///
/// The old text said: nothing acts on another child, so holding the cohort's UUIDs
/// would be data with no reader; "if a row ever becomes tappable, the id comes back at
/// the same time as the behaviour that needs it."
///
/// **That behaviour is the cheer** (ADR-0022 `:58`, `:126-129`, `:207-215`;
/// `redesign.html:1119-1124`): a non-reader row is tapped once per session, and the
/// cheer is keyed by this id in `LeaderboardState.cheered`. The sentence is discharged,
/// not reversed.
@freezed
final class LeaderboardRow with _$LeaderboardRow {
  /// A ranked child.
  const LeaderboardRow({
    required this.rank,
    required this.score,
    required this.initials,
    required this.userId,
    required this.fullName,
    required this.currentStreak,
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
  ///
  /// ## DIVERGENCE FROM THE PROTOTYPE'S MONOGRAM, AND WHY THIS ONE STANDS
  ///
  /// The prototype's monogram is the **first character** of the display name —
  /// `monogram()` returns `dispName(p,idx).trim()[0] || '✦'`
  /// (`eva/redesign.html:1072`) — so `'David Mina'` is `D`, not `DM`.
  ///
  /// This carries the **mapper's** two-letter rule instead, and the reason is that
  /// the mapper's rule is the one already in this repository, is tested, and is
  /// written down: `LeaderboardMapper.initialsOf` strips the grade annotation
  /// before it takes the letters, and takes the **first and last** token so that
  /// `'Ana Maria Silva'` reads `AS` rather than `AM`. The prototype's rule would
  /// make the grade annotation the monogram's second letter for every seeded row.
  ///
  /// The alternative — carrying the first character — would mean a second monogram
  /// rule in the app, and the two surfaces (the row's orb and the podium's orb)
  /// would have to agree about which one they use. They agree about this one.
  final String initials;

  /// The server's id for this child — the key the cheer is recorded against.
  ///
  /// The payload's key is camelCase `userId` in an otherwise snake_case object; see
  /// `LeaderboardMapper`'s doc. Never rendered. It is what makes "cheered once per
  /// witness" a set membership test rather than a name comparison, and names are not
  /// unique.
  final String userId;

  /// The child's name exactly as the server sent it, grade annotation included.
  ///
  /// Rendered as the row's name and as the podium's label, or replaced by
  /// `witness {position}` while the veil is on. The mapper also derives [initials]
  /// from this string, so the two surfaces cannot disagree about a row's identity.
  final String fullName;

  /// The row's ranking value under the `streaks` metric.
  ///
  /// The server's stored `users.current_streak`. See the class doc for the measured
  /// disagreement with `streak/summary`, which is recorded rather than repaired here.
  final int currentStreak;
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
    required this.cohortSize,
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

  /// How many children in this cohort have a score in this window — or `null` when
  /// that number cannot be known from what was returned.
  ///
  /// ## WHY IT IS NULLABLE, AND WHY IT IS NOT SIMPLY ABSENT
  ///
  /// A leaderboard that says "3rd" and one that says "3rd of 12" are different claims,
  /// and only the second is safe when the list is capped. [LeaderboardMapper] derives
  /// this from `ZREVRANGE`'s own semantics — see its `cohortSizeOf` for the rule and
  /// for why the answer is correct today *and* stays correct when the backend adds a
  /// `ZCARD`.
  ///
  /// `null` means **"more exist, and here is where the list stops"** — the one case a
  /// screen must not paper over. It is a first-class value rather than a fallback of
  /// `rows.length`, because `rows.length` is exactly the number that makes "3rd of 3"
  /// look true when it is not.
  final int? cohortSize;

  /// The reader's own position, or `null` when the request carried no `X-User-Id`.
  ///
  /// Distinct from `my_standing: {rank: null, score: 0}`, which is a standing with no
  /// rank. The endpoint returns `null` for the whole object when no user id was sent,
  /// and this app always sends one — so in practice `null` here means the server
  /// dropped it, which is worth rendering differently from "you are unranked".
  final LeaderboardStanding? standing;
}
