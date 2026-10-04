import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The streak flame and its number, as one semantics node.
///
/// `ds.tsx:512-517`. A `StreakFlame` beside a count in `F.mono 13 / 700`, inside a
/// `display: flex; gap: 5` group.
///
/// ## ONE SEMANTICS NODE, AND WHY NOT TWO
///
/// `StreakFlame` publishes its own node and the count is a sibling `Text`, so a
/// naive transcription gives a screen reader **two** announcements: "Streak", then
/// "4". That is the §14 colour-only rule's shape — two pieces of information the
/// reader must reassemble — and on a number that is the one thing a reader is
/// likely to repeat back.
///
/// So the row is a single `Semantics(container: true, label: '$label: $count',
/// excludeSemantics: true)` and the flame's own node is dropped by the
/// `excludeSemantics`. `home_page_test.dart` walks the tree and asserts exactly
/// one node offers the streak.
///
/// ## WHY THE NUMBERS ARE PARAMETERS AND NOT CONSTANTS
///
/// Because `ds.tsx:508,516,525` hard-codes `Evangelion`, `12` and `MK`, and that
/// trio is **defect #11**. (This read `507`, which was off by one on the first.)
/// Every
/// one of the three — the streak, the monogram, the wordmark — is a parameter here,
/// and the wordmark is a parameter too even though it is a product name, because a
/// hard-coded value and a passed-in value look identical in a diff and only one of
/// them can be wrong. `AppTopBar`'s doc has the full argument.
class StreakFlameRow extends StatelessWidget {
  /// The flame showing [days] — or a spinner while [days] is `null` and a retry
  /// control while [failureMessage] is not.
  ///
  /// Three arms and no `isLoading` flag, because the three are distinguishable and
  /// a boolean pair would make "loading and failed at once" expressible.
  const StreakFlameRow({
    required this.days,
    required this.semanticLabel,
    this.failureMessage,
    this.onRetry,
    super.key,
  });

  /// The streak length from `StreakSummary.currentStreak`, or `null` while it is
  /// unknown.
  final int? days;

  /// The prefix of the announcement — `'Streak'` / `'أيام متتالية'`.
  final String semanticLabel;

  /// The streak could not be read, and this is the repository's own message.
  ///
  /// **Not reworded.** `failure.dart` requires the server's wording to be
  /// preserved verbatim, and this is the one place on `/` a repository message is
  /// shown. It reaches the player as an [IconActionButton]'s tooltip and label,
  /// which is why the bar's height is 44 and not the prototype's 32 — see
  /// [AppTopBar].
  final String? failureMessage;

  /// What to run when the reader asks to try again.
  final VoidCallback? onRetry;

  /// The flame's height. `ds.tsx:514` — `width="14" height="18"`.
  static const double flameSize = 18;

  /// The gap between the flame and the number. `ds.tsx:513` — `gap: 5`. (`ds.tsx:512`
  /// is the group's own `display: flex`, and `:513` is where `gap: 5` is written.)
  static const double gap = 5;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final int? count = days;

    if (count != null) {
      return Semantics(
        container: true,
        label: '$semanticLabel: $count',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StreakFlame(size: flameSize, semanticLabel: semanticLabel),
            const SizedBox(width: gap),
            // `ds.tsx:516` — `F.mono 13 / 700 / ink`.
            Text(
              '$count',
              style: EvaTypography.monoCaps(colors).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ],
        ),
      );
    }

    final String? message = failureMessage;
    if (message != null) {
      // An icon control rather than a paragraph: `Failure.message` for a
      // serialization fault is a sentence with a key name in it, and a sentence
      // does not belong in a top bar. It is the button's accessible name and its
      // tooltip, so a screen-reader user gets the reason and a sighted user gets
      // the same on hover.
      return IconActionButton(
        icon: Icons.sync_problem_outlined,
        tooltip: message,
        // `uiFamily`, and the reason this is not a guess: the message is a
        // `Failure.message` from `ApiErrorMapper` / `TodayReadingMapper`, and both
        // write **English ASCII literals** naming the key that was wrong — there is
        // no Arabic in the vocabulary. So the Latin family is not "the default
        // nobody chose", it is the correct answer for the only string this site can
        // receive, and `IconActionButton.tooltipFamily`'s assert-that-the-caller-said-
        // something requirement is what proves it.
        tooltipFamily: EvaTypography.uiFamily,
        onPressed: onRetry,
      );
    }

    // Nothing is claimed yet, so nothing is drawn. A `CircularProgressIndicator`
    // here would be an animation over an answer that arrives in milliseconds and
    // would make §13's reduced-motion requirement apply to the top bar for no
    // reason; the alternative — a placeholder flame at `0` — would be the
    // hard-coded value this whole widget exists to remove.
    return const SizedBox(width: StreakFlameRow.flameSize * StreakFlame.aspect);
  }
}
