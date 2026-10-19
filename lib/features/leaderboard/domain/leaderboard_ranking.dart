import 'package:evangelion/core/domain/entities/leaderboard_board.dart';

/// The value [row] ranks by under [metric].
///
/// This is the client's whole definition of what the two words mean, and the reason
/// the prototype's `valOf` (`eva/redesign.html:1068`) has an honest port:
///
/// * `light` is the **response's own `score`**, already the right number for the
///   selected window. The prototype multiplies a single weekly figure by `4.35` and
///   `38.6` (`:1067`) to invent the monthly and all-time numbers; ADR-0022 `:97-104`
///   names that as fiction, because the server keeps three independent ZSETs and
///   scores each from real submissions. Nothing here scales.
/// * `streaks` is the row's stored `current_streak`. See [LeaderboardRow] for the
///   measured disagreement with `streak/summary`, which is recorded rather than
///   repaired in the client.
int leaderboardValueOf(LeaderboardRow row, LeaderboardMetric metric) =>
    switch (metric) {
      LeaderboardMetric.light => row.score,
      LeaderboardMetric.streaks => row.currentStreak,
    };

/// [rows] in display order for [metric].
///
/// ## THE ORDER IS THE SERVER'S UNDER `light`, AND THE SERVER'S `RANK` IS THE TIE-BREAK
///
/// Under `light` the response arrives ranked by score, and re-sorting it would be a
/// second implementation of a ranking that must agree with the first on ties — and
/// need not. So the list is returned in wire order, untouched.
///
/// Under `streaks` the server did not rank this metric at all: the payload is still
/// score-ordered, so this function is the only place the streak board is computed.
/// Ties break by the **original server `rank` ascending**, which is deterministic and
/// visible to the reader as the score board's order — the alternative, leaving equal
/// streaks in whatever order a sort happened to produce, would let the same payload
/// render two different boards on two launches.
///
/// Returns a new list in both arms, so a caller cannot mutate the state's rows by
/// sorting them, and an empty board is an empty order rather than a special case.
List<LeaderboardRow> leaderboardOrder(
  List<LeaderboardRow> rows,
  LeaderboardMetric metric,
) {
  final List<LeaderboardRow> ordered = List<LeaderboardRow>.of(rows);
  if (metric == LeaderboardMetric.streaks) {
    ordered.sort((LeaderboardRow a, LeaderboardRow b) {
      final int byStreak = b.currentStreak.compareTo(a.currentStreak);
      return byStreak != 0 ? byStreak : a.rank.compareTo(b.rank);
    });
  }
  return ordered;
}

/// The 1-based display position of [row] in [ordered], or `0` when it is absent.
///
/// ## WHY THIS IS NOT [LeaderboardRow.rank]
///
/// `rank` is the **server's** score ranking and stays that value under both metrics.
/// Under `streaks` the position printed in the rank column is the row's place in the
/// streak order, which is a different number for most rows — the prototype prints
/// `idx+1` over its own sorted array (`eva/redesign.html:1113`), and so does this.
///
/// `0` is the "not present" answer rather than `null` because every caller here has
/// just ordered the list it is asking about; a `null` would add an arm no call site
/// can reach. The function is total and the sentinel is outside every 1-based range.
int leaderboardPositionOf(List<LeaderboardRow> ordered, LeaderboardRow row) {
  final int index = ordered.indexOf(row);
  return index < 0 ? 0 : index + 1;
}

/// The reader's own row, found by [standingRank], or `null` when they are unranked.
///
/// ## WHY THE RANK AND NOT THE `userId`
///
/// `my_standing` carries `{rank, score}` and no id (ADR-0022 `:50`, `:106-113`), and
/// the client has no way to learn which `userId` is the signed-in reader's. The
/// server's rank is unique per response, so matching it identifies exactly one row —
/// and it is the number the reader is looking for on the board anyway.
///
/// Under `streaks` the row is still found by the **server** rank; its display
/// position is then [leaderboardPositionOf]'s answer, not this rank. Neither `null`
/// nor an absent rank invents a row.
LeaderboardRow? leaderboardReaderRow(
  List<LeaderboardRow> rows, {
  required int? standingRank,
}) {
  if (standingRank == null) return null;
  for (final LeaderboardRow row in rows) {
    if (row.rank == standingRank) return row;
  }
  return null;
}

/// The gap between the reader and the witness one display position above them.
///
/// ## WHAT IT IS FOR, AND THE TWO RULES THAT ARE NOT THE PROTOTYPE'S
///
/// `eva/redesign.html:1105-1106` composes `gapLine` from the reader's value, the
/// value of `sorted[yr-2]` — **one place above**, not the first place — and appends
/// `passHint` with `ceil(gap / 15)` verses. This class carries the same three
/// ingredients, plus two divergences recorded at their sites:
///
/// * [verses] is non-null **only under [LeaderboardMetric.light]** (D14). The ÷15
///   constant is the light economy — `:755`'s "15 per verse read + 10 per correct
///   answer" — and converting a streak gap into a number of verses is arithmetic on
///   two different units. The prototype does it anyway (`:1106`), and this does not.
/// * At display position 1 there is no gap and therefore no instance, rather than
///   the prototype's reuse of `noReset` as a congratulation (`:1107`).
///
/// The witness is looked up in [ordered], so under `streaks` it is genuinely the row
/// one place above on the **streak** board. A reader absent from [ordered], or at a
/// position outside it, gets `null`: a gap to nobody is not a smaller gap.
final class LeaderboardGap {
  /// The reader's gap to [aboveName] at [abovePosition].
  const LeaderboardGap({
    required this.aboveName,
    required this.abovePosition,
    required this.gap,
    required this.verses,
  });

  /// The witness's name as the payload sent it, before any veil is applied.
  ///
  /// The veil is a **render-time** choice (ADR-0022 `:243-245`), so it is applied by
  /// the widget that prints this name and not by the arithmetic that found it.
  final String aboveName;

  /// The witness's 1-based display position.
  final int abovePosition;

  /// How much more [LeaderboardMetric] value the witness holds.
  final int gap;

  /// The light-only "pass with ≈n verses" figure, or `null` under `streaks`.
  final int? verses;
}

/// The gap for a reader at [readerPosition], or `null` at the top / outside the board.
///
/// See [LeaderboardGap] for the two rules that diverge from the prototype and for
/// why the witness is the row immediately above rather than the leader.
LeaderboardGap? leaderboardGapFor({
  required List<LeaderboardRow> ordered,
  required int readerPosition,
  required LeaderboardMetric metric,
}) {
  if (readerPosition <= 1 || readerPosition > ordered.length) return null;
  final LeaderboardRow witness = ordered[readerPosition - 2];
  final LeaderboardRow reader = ordered[readerPosition - 1];
  final int gap =
      leaderboardValueOf(witness, metric) - leaderboardValueOf(reader, metric);

  return LeaderboardGap(
    aboveName: witness.fullName,
    abovePosition: readerPosition - 1,
    gap: gap,
    // `ceil` and a floor of 1: the prototype's `Math.max(1, Math.ceil(gap/15))`
    // (`:1106`). A gap of zero cannot pass anybody with zero verses, and a hint of
    // "pass with 0 verses" would be advice to do nothing.
    verses: metric == LeaderboardMetric.light
        ? (gap <= 0 ? 1 : (gap / 15).ceil())
        : null,
  );
}

/// How long until [window]'s next local reset, or `null` for all-time.
///
/// ## THIS IS APPROXIMATE, AND THE APPROXIMATION IS STATED IN THE COPY
///
/// The response carries the window's **name** and no reset instant — measured from
/// `leaderboard.routes.ts`'s five-key body and recorded in ADR-0022 `:66-81`. So the
/// boundary is re-derived locally with the prototype's own rule
/// (`eva/redesign.html:1073-1076`):
///
/// * `weekly` — the next local **Monday 00:00**. A Monday is seven days away, not
///   zero, because the board resets into the new week at that instant.
/// * `monthly` — the local **1st of the next month 00:00**.
/// * `allTime` — `null`; the line renders `noReset` (`:945`).
///
/// ## WHERE IT DIVERGES FROM THE SERVER, NAMED RATHER THAN HIDDEN
///
/// The backend buckets weekly by **ISO week number**
/// (`redis/leaderboard.service.ts:20-36`) and monthly by `monthly:{YYYY-MM}` on its
/// own clock. ISO week 1 is the week holding the first Thursday, so a local
/// "next Monday" can name a different week number across a year boundary; and a
/// server in UTC and a reader in UTC+14 disagree about which day it is for up to a
/// day. The screen therefore prints the prototype's own `≈` and this doc is the
/// reason it is honest: the number is a local boundary, not the server's instant.
///
/// No ticker accompanies it. The prototype computes the countdown inside its one
/// render pass (`:1079-1082`) and re-renders on entry and on a scope change only —
/// `segp('scopeSeg', …)` calls `renderBoard()` and nothing else does (`:1460`,
/// `:1461`) — so a `Timer` would be a second clock to test for one line of text that
/// is stale by at most a minute per frame budget.
Duration? resetLeftFor(LeaderboardWindow window, DateTime now) {
  switch (window) {
    case LeaderboardWindow.weekly:
      // `DateTime.weekday` is 1 (Monday) … 7 (Sunday). The prototype's
      // `day=(getDay()+6)%7` is 0 for Monday, so "days until next Monday" is
      // `day == 0 ? 7 : 7 - day`; constructing the date rather than adding hours
      // lets the calendar handle month and DST boundaries.
      final int day = now.weekday - DateTime.monday;
      final int days = day == 0 ? 7 : 7 - day;
      final DateTime boundary = DateTime(now.year, now.month, now.day + days);
      return boundary.difference(now);
    case LeaderboardWindow.monthly:
      final DateTime boundary = DateTime(now.year, now.month + 1);
      return boundary.difference(now);
    case LeaderboardWindow.allTime:
      return null;
  }
}
