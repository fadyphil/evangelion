import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// The `/communion` derived strings.
///
/// ## WHY A WRAPPER AND NOT THE GENERATED CALL AT THE CALL SITE
///
/// `gen_l10n` emits **positional** parameters, so the raw call is
/// `leaderboardRowSemantics(score, digits(score), initials, '${rank}', '$isReader')`
/// — five arguments in an order no reader of the call site can check, with the same
/// number appearing twice.
///
/// Two of those five are the same number and must stay in step: `count` is what the
/// plural selects on, `digits` is what the reader sees. Spelling that out at a call
/// site makes keeping them together the caller's job, which is the exact defect a
/// helper exists to prevent — `reading_l10n.dart` gives the argument for `reading`.
/// So [LeaderboardRowAnnouncement] takes the row and derives both.
///
/// ## WHY `isReader` CROSSES AS THE STRING `'$isReader'`
///
/// Because it is a `select` in the message, and a `select` matches against string
/// values. The conversion happens here, once, rather than at each call site where it
/// could be written `isReader: isReader ? 'true' : ''` and drift.
extension LeaderboardStringsPhrases on AppLocalizations {
  /// The screen-reader sentence for [row].
  ///
  /// ## AND IT RESPECTS THE VEIL
  ///
  /// When [isVeiled] is true and [isReader] is false, the initials placeholder
  /// announces the veiled witness label instead of the monogram, so a voice-over
  /// user cannot hear what the screen is forbidden to show (AGENT_CONTEXT §14 /
  /// decision 145 / D11).
  ///
  /// ## AND IT ANNOUNCES **BOTH** NUMBERS THE ROW SHOWS
  ///
  /// The row carries two numbers and the screen shows both: the **value** (the
  /// selected metric's number) and the **sub-line** (the other metric's number).
  ///
  /// **The announcement used to carry only the score**, and under the `streaks`
  /// metric that is a **wrong number**: a screen-reader user was told "80 points"
  /// about a row whose big number was "12". That is the same class of defect as
  /// the veil leak above — the accessible layer contradicting the visible layer —
  /// and it was invisible to every gate, because the gates read *painted* runs and
  /// this string is a name.
  ///
  /// So the announcement carries **both**, each with its own plural and its own
  /// numeral: the points and the streaks. The order is fixed — **points, then
  /// streaks** — which is the order the screen shows them under the `light`
  /// metric, and the **reverse** of the screen's order under `streaks`. That
  /// reversal is recorded rather than fixed, because fixing it means a message
  /// per metric, and the two numbers with their nouns are the facts; the order
  /// they arrive in is not.
  String leaderboardRowAnnouncement(
    LeaderboardRow row, {
    required bool isReader,
    bool isVeiled = false,
    int? displayPosition,
  }) {
    final int position = displayPosition ?? row.rank;
    // **The position goes through [digits]**, for the same reason the row's own
    // rank column does: the prototype prints it through its `N()` transform
    // (`eva/redesign.html:1114`), so the Arabic arm reads `٢` and not `2`.
    // An announcement that said `2` beside a screen that showed `٢` would be
    // the screen contradicting itself in the one place a screen-reader user
    // cannot see the screen to check.
    final String positionText = digits(position);
    final String identity = isVeiled && !isReader
        ? leaderboardWitness(positionText)
        : row.initials;
    return leaderboardRowSemantics(
      row.score,
      digits(row.score),
      row.currentStreak,
      digits(row.currentStreak),
      identity,
      positionText,
      '$isReader',
    );
  }
}
