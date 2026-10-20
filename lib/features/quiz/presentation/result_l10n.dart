import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/l10n.dart';

/// The result's strings that are **composed** rather than translated.
///
/// Both were methods on `ResultStrings`, and both are here for the same reason:
/// each is a *decision* about the payload, and the payload is a Dart type rather
/// than a translation.
///
/// ## AND WHY THIS FILE IS NECESSARY AT ALL
///
/// The derivation cannot be shared: `features/reading` may not import
/// `features/quiz`, so `AppLocalizations.quizRetry` is not reachable from a
/// shared extension on `AppLocalizations` in `lib/l10n/`. The ARB is one shared
/// file precisely *because* these collisions are resolved by namespacing rather
/// than by duplication, but the derivation still cannot be shared.
///
/// ## AND WHY IT LIVES **HERE**, IN THE QUIZ FEATURE
///
/// The result is the quiz's outcome, shown **over** the quiz, so it belongs to
/// the quiz feature — and this file moved with it.
///
/// **This paragraph used to give the opposite reason, and the move made it
/// false.** It said: *"§3's feature independence: `features/result` may not
/// import `features/quiz`, so `AppLocalizations.quizRetry` is not reachable from
/// here. That is also the whole reason `/result` **cannot** resolve a bloc."*
///
/// That was true while the result was its own feature: the wall ran
/// `features/result` → `features/quiz`, so the result could neither import the
/// quiz's strings nor read the quiz's bloc. **Both walls are gone now**, because
/// the result *is* the quiz feature — `features/quiz/presentation/widgets/
/// result_sheet.dart` sits beside this file and reads `QuizBloc`'s state
/// through the page that owns it.
///
/// The rule that survives is the one this file exists for: the derived strings
/// are **composition**, and composition lives with the feature that composes.
extension ResultStringsPhrases on AppLocalizations {
  /// The headline sentence for the three states.
  ///
  /// **A `switch` expression over the two booleans**, per §4 — an `if`-chain here
  /// would be the same four branches in a different order and one of them would be
  /// unreachable by accident rather than by construction.
  String messageFor({
    required bool isCorrect,
    required bool readingCompleted,
  }) => switch ((isCorrect, readingCompleted)) {
    (true, true) => resultCompleteMessage,
    (true, false) => resultPartialMessage,
    (false, _) => resultIncorrectMessage,
  };

  /// The streak pill's label, for [current] days against a best of [longest].
  ///
  /// ## "AT THEIR BEST" IS `>=`, NOT `==`, AND THE REASON IS THE ZERO
  ///
  /// The prototype's own sentence is `"Day 12 — your longest yet"` beside
  /// `longest_streak: 6` — a **hard-coded mismatch** in the fixture the prototype
  /// drew, so the word is transcribed but the comparison is this client's.
  ///
  /// `current >= longest` rather than `==`: `longest_streak` is the reader's best run
  /// **as the server last computed it**, and a reader who has just extended their run
  /// by one can be *ahead* of it if the server has not caught up. Saying "your
  /// longest yet" about `6` when the reader is on `7` is true; saying it only on `==`
  /// would show nothing for the one case the reader would most want to see.
  ///
  /// **A streak of `0` never claims it.** `current_streak: 0` against
  /// `longest_streak: 0` satisfies `>=`, and "Day 0 — your longest yet" is a sentence
  /// about a reader who has not started.
  ///
  /// ## AND THE COUNT IS **NOT** PLURALISED HERE, ON PURPOSE
  ///
  /// `resultDay` stays a bare noun. The pill is a *label form* — `Day 12`,
  /// `اليوم ١٢` — which is correct for every count in both arms, so a `plural` would
  /// alter a transcribed prototype string (`Days 12`) to fix nothing. The count on
  /// this screen that genuinely needed one was the score caption, and
  /// `resultTotalCaption` is it.
  String streakLabelFor({required int current, required int longest}) {
    final String label = '$resultDay ${digits(current)}';
    if (current <= 0 || current < longest) return label;
    return '$label — $resultLongestYet';
  }
}
