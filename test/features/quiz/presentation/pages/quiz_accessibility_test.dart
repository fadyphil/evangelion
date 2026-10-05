import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/design_system_harness.dart';
import '../../../../support/quiz_harness.dart';
import '../../../../support/reading_harness.dart' show answeredQuestion;

/// §14 for `/quiz`: no unlabeled interactive node, and no state carried by colour alone.
///
/// ## WHY THIS FILE EXISTS WHEN `quiz_page_test.dart` ALREADY ASSERTS SEMANTICS
///
/// It does assert semantics, and well — its spoiler boundary owns the
/// `quizCorrectSuffix`/`quizIncorrectSuffix` vocabulary and the verdict banner's
/// live region. What it does not do is the thing `09-quality-gates.md` §14 asks for
/// by name: *"all 6 pages pass a semantics sweep with no unlabeled interactive node"*.
///
/// `login`, `/` and `/reading` each have a `*_accessibility_test.dart` whose first
/// group is exactly that sweep, over the page's whole semantics tree rather than
/// over a hand-written list of controls. `/quiz`, `/result` and `/settings` had
/// **no** such file after Phase 9 — three of six pages, which is why the §14
/// sentence could not be claimed for the app.
///
/// ## AND WHY THE SWEEP IS OVER STATES RATHER THAN OVER CONTROLS
///
/// `login_accessibility_test.dart` records the argument in full: a hand-written list
/// of controls is what `focus_ring_gate_test.dart` already does for the design
/// system's eleven, and its own doc records the cost — `kInteractiveWidgets` had to
/// be extended by hand when a widget's gate changed. A page's own controls cannot be
/// discovered that way, so the sweep walks the tree and asks of every node that
/// offers an action whether it has a name.
///
/// `/quiz` has **four** states worth sweeping and they add controls rather than
/// remove them: a question nothing is chosen on, a graded question, a question the
/// server already graded, and a dead CTA. `home_accessibility_test.dart`'s group is
/// split one test per state for a measured reason — a single looping test named a
/// *state* in prose and a *line* that was the same for all of them, so a failure
/// could not say which state produced an empty node list. That is repeated here
/// rather than reinvented.
void main() {
  final AppLocalizations strings = AppLocalizationsEn();

  /// A **wrong** grade's response, over the contract capture.
  ///
  /// `contract_payloads.dart` already ships the pair — `contractSubmitAnswerFixture`
  /// and `contractWrongAnswerFixture` — transcribed from two real 2026-10-03 and
  /// 2026-10-04 captures, and `quiz_harness.dart`'s `defaultSubmission` is the first
  /// of them wrapped. A suite that built its own `SubmitResult` for the wrong arm
  /// would be a fourth transcription of a shape two already exist in, and the two
  /// copies could disagree about which numbers a wrong answer moves.
  final Result<SubmitResult> wrongSubmission =
      const Result<SubmitResult>.success(contractWrongAnswerFixture);

  group('no unlabeled interactive node', () {
    /// Sweeps one state.
    ///
    /// A closure rather than a body so the loop below can register one `testWidgets`
    /// per state, and so a failure names the state in the test's own description.
    void sweep(String state, Future<void> Function(WidgetTester) arrange) {
      testWidgets(state, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await arrange(tester);

        final List<SemanticsData> tappable = nodesOffering(
          tester,
          SemanticsAction.tap,
        );
        expect(
          tappable,
          isNotEmpty,
          reason:
              'a screen with no activatable node is a screen this sweep cannot '
              'judge — an empty list would make the loop below vacuously true',
        );
        for (final SemanticsData node in tappable) {
          expect(
            node.label.trim(),
            isNotEmpty,
            reason:
                'an interactive node with no accessible name. §14\'s first row. '
                'flags=${node.flagsCollection} actions=${node.actions}',
          );
        }
        handle.dispose();
      });
    }

    sweep('a question with nothing chosen on it', (WidgetTester tester) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Result<ScriptureText>.success(liveEnglishQuizPassage),
        ),
      );
    });

    sweep('a graded question, which is the state with the most nodes', (
      WidgetTester tester,
    ) async {
      // Driven through a **press**, not by handing the bloc a state — a fixture that
      // emitted the graded state directly would sweep a screen no reader ever
      // reaches. `quiz_page_test.dart` drives the same flow and this is deliberately
      // the same sequence rather than a second way of reaching it.
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Result<ScriptureText>.success(liveEnglishQuizPassage),
          submission: defaultSubmission,
        ),
      );
      await tester.tap(find.text(liveEnglishQuestion.options['A']!));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(strings.quizCheckAnswer));
      await pumpQuizFrames(tester, 6);

      // The anti-vacuity half: the check has to have happened, or "no unlabeled
      // node" is a statement about the pre-check screen twice.
      expect(
        find.bySemanticsLabel(RegExp(strings.quizCorrectSuffix)),
        findsOneWidget,
        reason: 'the reveal is what adds the verdict nodes this state is about',
      );
    });

    sweep('a question the server had already graded', (
      WidgetTester tester,
    ) async {
      // §5 trap 3's 2026-10-03 shape, which is simultaneously "there is nothing to
      // submit" and "there is no question after this one" — the dead end
      // `QuizCta.none` exists for. `quiz_page_test.dart` owns what that state
      // *says*; what is swept here is that its dead CTA is still named.
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          Result<ScriptureText>.success(
            englishPassageWith(<Question>[answeredQuestion]),
          ),
        ),
      );
    });

    sweep('the failed load, which is the one state with an `ErrorView`', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Result<ScriptureText>.failure(
            Failure(kind: FailureKind.network, message: 'offline'),
          ),
        ),
      );
    });

    sweep('the Arabic arm, which is not a mirror of the English one', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Result<ScriptureText>.success(liveArabicQuizPassage),
        ),
        locale: const Locale('ar'),
      );
    });
  });

  group('the named controls are the ones the prototype declares', () {
    testWidgets('the exit, the four options and the CTA are all named', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Result<ScriptureText>.success(liveEnglishQuizPassage),
        ),
      );

      // **Enumerated, not "some of them."** §14's gap is an *unnamed* control, and a
      // label that drifted off the control it names is the same defect one step
      // later — which is exactly what happened on `/reading`, where one string
      // describing two nodes made `readingTextSize` the slider's name as well as
      // the disclosure's.
      expect(find.bySemanticsLabel(strings.quizExit), findsOneWidget);
      for (final String option in <String>[
        'A. Nicodemus',
        'B. Paul',
        'C. Peter',
        'D. Lazarus',
      ]) {
        expect(
          find.bySemanticsLabel(option),
          findsOneWidget,
          reason: 'every option is a control, and a control needs a name',
        );
      }
      expect(
        find.bySemanticsLabel(strings.quizCheckAnswer),
        findsOneWidget,
        reason:
            'the CTA is dead at this point — §14\'s disabled row — and it is '
            'still named',
      );

      handle.dispose();
    });
  });

  group('§14 — colour is never the only signal', () {
    // `quiz_option_card_test.dart` already asserts the card's own
    // `correct`/`incorrect` labels and their `Semantics` flags. What is asserted
    // **here** is the pair §14 asks for at the page level: the verdict is carried by
    // an ICON as well as a colour, so the state survives a screen reader and a
    // colour-blind reader.
    // ## READ OFF THE **CARD**, NOT OFF A LIST THIS FILE KEEPS
    //
    // The first draft of this group carried a `[(correct, QuizOptionState.correct),
    // (incorrect, …)]` table and built a submission per arm. It was wrong twice: the
    // state is the *card's* property and it is derived from **the submit response**,
    // so the arms have to be driven by two different `SubmitResult` fixtures rather
    // than by two values of a local variable — and a table that re-states
    // `QuizOptionState`'s own two verdicts is a second copy of an enum that already
    // exists. `quiz_page_test.dart` owns the correct arm; the incorrect one is
    // driven here from the same sequence with a different response.
    testWidgets('a correct card carries an icon as well as the colour', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await gradeTheAnsweredOption(tester, submission: defaultSubmission);

      // **The glyph, not `colors.ok`.** A shape is the one signal a screen reader can
      // convey and a colour-blind reader can see; the colour is the third, and §14
      // says it must not be the only one.
      expect(
        find.descendant(
          of: find.byType(QuizOptionCard),
          matching: find.byIcon(Icons.check_circle_outline),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('and an incorrect one carries the other glyph', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await gradeTheAnsweredOption(tester, submission: wrongSubmission);

      expect(
        find.descendant(
          of: find.byType(QuizOptionCard),
          matching: find.byIcon(Icons.cancel_outlined),
        ),
        findsOneWidget,
      );
      // And the two verdicts are told apart by the glyph as well as by the colour —
      // which is the assertion that makes this §14 rather than a screenshot.
      expect(
        find.descendant(
          of: find.byType(QuizOptionCard),
          matching: find.byIcon(Icons.check_circle_outline),
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('and the feedback banner is a live region', (
      WidgetTester tester,
    ) async {
      // The banner arrives after the screen has settled, so without
      // `liveRegion` a screen-reader user learns about it only by exploring.
      final SemanticsHandle handle = tester.ensureSemantics();
      await gradeTheAnsweredOption(tester, submission: defaultSubmission);

      expect(
        semanticsTree(tester)
            .where((SemanticsData node) => node.flagsCollection.isLiveRegion),
        isNotEmpty,
      );
      handle.dispose();
    });
  });

  group('§14 — the spoiler boundary survives this pass', () {
    // The four carried-over controls this phase must not regress. `/quiz`'s is the
    // spoiler boundary, and it is re-asserted here rather than only in
    // `quiz_page_test.dart` because a **semantics** sweep is exactly the kind of edit
    // that leaks: reading the tree and relabelling nodes is how "nothing announces
    // `quizCorrectSuffix` before a check" becomes "one node does".
    testWidgets('nothing carries the verdict before the reader commits', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpQuiz(tester, bloc: quizBloc(answerBearingQuizPassage));

      for (final SemanticsData node in semanticsTree(tester)) {
        expect(
          node.label.contains(strings.quizCorrectSuffix) ||
              node.label.contains(strings.quizIncorrectSuffix),
          isFalse,
          reason:
              '"${node.label}" names the verdict before the reader has answered. '
              '§5 trap 3 and the boundary `QuizPage` owns; this suite exists so that '
              'sweeping the tree cannot quietly open the leak.',
        );
      }
      handle.dispose();
    });
  });
}

/// The option at `A`, which is the one the submit response above marks correct.
///
/// [liveEnglishQuestion]'s own option map rather than a literal, so a fixture edit to
/// the question and a stale string here cannot disagree — which is the same reason
/// `englishPassageWith` exists instead of a fourth transcription of the passage.
final String theAnsweredOption = liveEnglishQuestion.options['A']!;

/// Selects option A and presses Check, so a test observes a **graded** screen.
///
/// Shared by the three tests that need one, for `quiz_page_test.dart`'s reason: a
/// change to *how* the flow is driven should fail once here rather than three times,
/// and a driver that also asserted would report the setup's own bugs as the
/// behaviour's.
Future<void> gradeTheAnsweredOption(
  WidgetTester tester, {
  Result<SubmitResult>? submission,
}) async {
  // `defaultSubmission` is a getter rather than a `const`, so it cannot be a
  // parameter's default value; the null arm resolves it here instead of at the
  // signature.
  final AppLocalizations strings = AppLocalizationsEn();
  await pumpQuiz(
    tester,
    bloc: quizBloc(
      const Result<ScriptureText>.success(liveEnglishQuizPassage),
      submission: submission ?? defaultSubmission,
    ),
  );
  await tester.tap(find.text(theAnsweredOption));
  await pumpQuizFrames(tester, 2);
  await tester.tap(find.text(strings.quizCheckAnswer));
  await pumpQuizFrames(tester, 6);
}
