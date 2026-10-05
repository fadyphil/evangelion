import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The quiz's top row: a close control, the progress beads, and a spacer.
///
/// `QuizScreen.tsx:45-53`.
///
/// ## AND THIS IS THE **ONLY** SURVIVING SHARED CALL SITE OF `ProgressBeads`
///
/// `04-widget-inventory.md` line 52 puts `ProgressBeads` on its **demotion watch
/// list** — six widgets that survived the Library cut with one shared call site each
/// and therefore no longer clear §3.1's "two call sites, or deleting the widget
/// makes complexity reappear" bar on their own. This is that call site, and it is
/// why `ProgressBeads` is still in `core/design_system/widgets/` and still
/// exported from the barrel.
///
/// **The deletion test, run.** Deleting the row from this file and writing it
/// inline reappears as: a `Row`, two 44-wide boxes, `mainAxisAlignment:
/// spaceBetween`, and a `ProgressBeads`. That is four lines, not complexity, so on
/// its own the widget would be demoted.
///
/// It stays for a measured reason instead: `ProgressBeads`'s own doc carries the
/// `beadStateAt` rule and `ProgressBeads` is a **shared design-system widget with
/// its own nine-hundred-line-of-tests situation** — demoting it means either
/// duplicating the rule into `quiz_header.dart` or reaching across features for it
/// (§3, Gate 2). And §7's rule about the *other* direction applies too: the
/// widget's own suite is what makes `done`/`current`/`upcoming` distinguishable for
/// a reader who cannot separate `ember` from transparent, and that suite is worth
/// keeping whatever the call-site count.
///
/// Recorded rather than left implicit: **this is a one-call-site widget that is
/// deliberately not demoted**, and the reason is the rule inside it rather than the
/// call count.
class QuizHeader extends StatelessWidget {
  /// The row, at question [current] of [total], with [completed] graded.
  const QuizHeader({
    required this.total,
    required this.completed,
    required this.current,
    required this.language,
    required this.strings,
    this.onExit,
    super.key,
  });

  /// `ProgressBeads.total` — the session's `questionCount`.
  final int total;

  /// `ProgressBeads.completed` — the session's `answeredCount`.
  ///
  /// **`answeredCount` and not "checked in this session"**, because
  /// `QuizSession.answeredCount` counts a question the wire already answered. A
  /// reader arriving on a session whose question is flagged must see a filled bead,
  /// because that is the truth about their day; a row of empty beads beside a
  /// disabled card would say the opposite.
  final int completed;

  /// `ProgressBeads.current` — `QuizState.currentIndex`.
  final int current;

  /// Which arm of the corpus, which selects the close control's tooltip family.
  ///
  /// **The payload arm, for the same reason `QuizOptionCard.language` is**
  /// (decision 75): the reader's language is a property of the payload they are
  /// answering, and the header's chrome is drawn over it.
  final ReadingLanguage language;

  /// The bilingual strings.
  final AppLocalizations strings;

  /// What the close control runs. `null` renders it disabled, as [SocialAuthButton]
  /// does.
  final VoidCallback? onExit;

  /// `QuizScreen.tsx:46` and `:52` — the close control and its spacer are both
  /// `width: 44, height: 44`, and the right-hand one is an **empty** box.
  ///
  /// The spacer is not a layout nicety: `justifyContent: 'space-between'` on `:45`
  /// puts the beads in the middle **because** both ends are 44 wide. With one end
  /// 44 and the other 0 the beads sit off-centre by 22px. So the spacer is a
  /// `SizedBox` with a **named constant** rather than `Expanded`, and
  /// `quiz_geometry_test.dart` asserts the two are equal.
  static const double endWidth = 44;

  /// `QuizScreen.tsx:45` — `marginBottom: 24`, the gap under the whole row.
  static const double bottomGap = EvaSpacing.xxl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: bottomGap),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        IconActionButton(
          icon: Icons.close,
          // `QuizScreen.tsx:46-50` is a `<button>` wrapping a bare `<svg>` cross
          // with **no label at all** — §14's first row, the same gap as
          // `ReadingEnScreen.tsx:14-16`, and the reason this is
          // `AppLocalizations.quizExit` rather than the string a reader would guess.
          tooltip: strings.quizExit,
          // `tooltipFamily` is **required** (recorded decision 71): `IconActionButton`
          //'s `Tooltip` carries no `textStyle` of its own, so omitting this resolves
          // to `ThemeData.textTheme.bodyMedium` — measured **`DMSans`** on both
          // themes — which is tofu for every Arabic character in the word.
          tooltipFamily: switch (language) {
            ReadingLanguage.english => EvaTypography.uiFamily,
            ReadingLanguage.arabic => EvaTypography.arabicFamily,
          },
          onPressed: onExit,
          size: endWidth,
        ),
        ProgressBeads(
          total: total,
          completed: completed,
          current: current,
          // **The caller's prefix, not the default.** `ProgressBeads`'s
          // `semanticLabel` defaults to the English `'Progress'`, which would put an
          // English word in the Arabic arm's semantics tree — the same half-translated
          // string decision 78 removed from `FontSizeStepper`.
          semanticLabel: strings.quizProgress,
        ),
        const SizedBox(width: endWidth),
      ],
    ),
  );
}
