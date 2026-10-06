import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// The `/leaderboard` derived strings.
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
  /// ## AND IT CANNOT CONTAIN A NAME
  ///
  /// The only child-identifying text in the message is [LeaderboardRow.initials].
  /// `LeaderboardRow` has no `fullName` to pass, so this string cannot leak a name —
  /// which matters here more than anywhere else in the app, because a voice-over user
  /// must not be able to **hear** what the screen is forbidden to show.
  String leaderboardRowAnnouncement(
    LeaderboardRow row, {
    required bool isReader,
  }) => leaderboardRowSemantics(
    row.score,
    digits(row.score),
    row.initials,
    '${row.rank}',
    '$isReader',
  );
}
