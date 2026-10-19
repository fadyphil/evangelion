/// `/quiz`, the screen Phase 8 built over the Phase-0c stub.
///
/// ## WHAT THIS FILE REPLACED, AND WHY THE REPLACEMENT IS A DUTY AND NOT A DELETE
///
/// The stub's two tests were `pumps as a Scaffold with an app bar titled by its
/// route` and `body says it is a placeholder, not the real screen`. Both are gone.
/// Neither was deleted for being inconvenient: each was a *tripwire* aimed at the
/// moment this screen stopped being a placeholder, and the moment has arrived, so
/// both fired. `settings_page_test.dart` still holds its identical pair, unchanged,
/// because `/settings` is **still** a stub — that asymmetry is the honest state of
/// the six screens and is why the file below does not try to generalise over them.
///
/// The first version of this rewrite was lost to an unrelated edit, and the stub came
/// back from `git checkout`. That is recorded because it is the second time in this
/// phase that a broad `import`-ordering sweep reverted real work, and the lesson is
/// the one `verification-before-completion` keeps restating: the tool that fixes the
/// imports is not the tool that decides which files the fix belongs in.
///
/// ## THE LOAD-BEARING CLAIM IN HERE IS THE **SPOILER BOUNDARY**, AND IT IS
/// ## ASSERTED IN BOTH DIRECTIONS, ON BOTH TREES
///
/// §5 trap 3 is the one this screen exists to enforce: the live payload carries
/// `is_correct`, and a quiz that renders it before the reader commits has given the
/// answer away. `08-build-phases.md` Phase 8 states the requirement as "the correct
/// option is not marked before the check", and Phase 4's reviewer restated it as
/// "asserted in both directions" — *nothing leaks*, and *the verdict appears*.
///
/// Both directions matter and they fail differently. A test that only asserted the
/// verdict appears would pass on a screen that showed `is_correct` from the first
/// frame and then showed it again after the check. A test that only asserted
/// nothing leaks would pass on a screen that never revealed anything, because a card
/// with no accent at all satisfies "no run marked correct" — the vacuous direction
/// §7 warns about. So the groups below are:
///
/// * **before the check** — no `is_correct`-derived string, no correct accent, no
///   flecks, on the *widget* tree and on the *semantics* tree;
/// * **after the check** — exactly one correct card, exactly one fleck burst, the
///   verdict sentence, and the verdict in the accessible names.
///
/// ## AND IT IS READ OFF THE RENDERED TREE, NEVER OFF `Question`
///
/// The tempting shortcut is `expect(bloc.state.currentAnswer!.question.isCorrect,
/// isTrue)` — the field is right there. It proves the *entity* carries the answer and
/// nothing at all about what the screen did with it, which is the defect Phase 7 was
/// written for: a correct fix reported wrong because the instrument read the model
/// instead of the pixels. Hence the `find.text` / `find.byType` / semantics-node
/// assertions below, and hence the Frame A/B check.
library;

import 'dart:io';

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/quiz_harness.dart';
import '../../../../support/reading_harness.dart';

/// The English strings, once, for the whole file.
final AppLocalizations en = AppLocalizationsEn();

/// The letter this suite taps.
///
/// ## AND WHY IT IS **NOT** READ OFF THE QUESTION
///
/// The obvious definition is `liveEnglishQuestion.userAnswer!`, and it is `null` on
/// the open capture — which is the point: an open question carries no answer key, and
/// a suite that took the letter from the fixture would be reading the field it is
/// trying to prove is not read.
///
/// So the letter is the **reader's choice**, and which card comes back marked correct
/// is decided by [defaultSubmission]'s `is_correct: true` — the submit response, over
/// HTTP, not the payload. That is what makes the assertions below about the *screen*
/// rather than about a fixture's opinion: a screen that trusted the payload's
/// `is_correct` would mark a card correct **before** the press, and the "before the
/// reader commits" groups below are what catch that.
const String theAnsweredLetter = 'A';

/// The option text at [theAnsweredLetter], read off the payload.
String get theAnsweredOption => liveEnglishQuestion.options[theAnsweredLetter]!;

/// [liveEnglishQuizPassage] carrying [verdictCarryingQuestion].
///
/// The **open** question that nevertheless holds the server's answer key — see that
/// fixture's doc for why the capture-based passage cannot test the spoiler boundary.
Result<ScriptureText> get aSpoilerFixture => Result<ScriptureText>.of(
  englishPassageWith(<Question>[verdictCarryingQuestion]),
);

/// [liveEnglishQuizPassage] carrying [answeredQuestion] — the only question closed.
///
/// §5 trap 3's 2026-10-03 shape. A single closed question is what makes the last two
/// groups reachable: it is simultaneously "there is nothing to submit" and "there is
/// no question after this one", which is the dead end `QuizCta.none` exists for.
Result<ScriptureText> get aClosedFixture =>
    Result<ScriptureText>.of(englishPassageWith(<Question>[answeredQuestion]));

/// Renders [QuizPage] at [pumpQuiz]'s default surface and returns nothing.
///
/// A thin alias so the geometry group reads as one sentence per case rather than
/// repeating `pumpQuiz`'s argument list, and so there is exactly one place that
/// decides what "a phone" means for this screen.
Future<void> mountQuiz(
  WidgetTester tester, {
  required QuizBloc bloc,
  Locale locale = const Locale('en'),
}) => pumpQuiz(tester, bloc: bloc, locale: locale);

void main() {
  group('the screen the redesign described', () {
    // `eva/redesign.html:562-574` is the markup this group pins: an appbar whose
    // row is a `‹` chevron, the centred crumb and the gold score (`:563-566`), the
    // `.dots` row beneath (`:568`), the prompt (`:570`), the options (`:571`) and
    // the `.qnext` pill (`:573`). No `AppBar`, no title, no count sentence.
    testWidgets('is chrome over the question, and NO app bar', (
      WidgetTester tester,
    ) async {
      // ## THE OPPOSITE OF THE STUB'S FIRST TEST, ASSERTED EXPLICITLY
      //
      // The stub's test asserted `find.byType(AppBar), findsOneWidget` and
      // `find.text(AppRoutes.quiz), findsOneWidget` — it asserted the route constant
      // was painted as a title. The redesign has no `AppBar` and no title: its top
      // row is the chevron, the crumb and the score, which is `QuizHeader`. So both
      // halves are inverted, and saying "no app bar" is stronger than "some other
      // app bar": a future `AppBar` titled `Quiz` would satisfy the old test and
      // violate the prototype.
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(QuizHeader), findsOneWidget);
      expect(find.text('/quiz'), findsNothing);
    });

    testWidgets('renders the question the payload gave it, not a placeholder', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      // The prompt, and all four options, from the **fixture**. This is the test the
      // stub's `find.text('Placeholder for /quiz')` was the inverse of: the string
      // that must be on screen is now the reader's own question.
      expect(find.text(liveEnglishQuestion.prompt), findsOneWidget);
      for (final String option in liveEnglishQuestion.options.values) {
        expect(find.text(option), findsOneWidget, reason: 'option "$option"');
      }
      expect(find.text('Placeholder for /quiz'), findsNothing);

      // And the letters, which the redesign draws as a 26px badge beside each
      // option (`eva/redesign.html:342`).
      for (final String letter in liveEnglishQuestion.options.keys) {
        expect(find.text(letter), findsOneWidget, reason: 'letter "$letter"');
      }
    });

    testWidgets('the crumb composes the payload reference, and the score is the '
        'session\'s running total', (WidgetTester tester) async {
      // `eva/redesign.html:565` is `Refraction · Psalms 1`, filled from the
      // reader's passage (`:1348`); the client's second half is the payload's
      // reference, carried on `QuizSession` and composed by `quiz_l10n.dart` —
      // never an ARB placeholder and never a hard-coded book. The score is
      // `:566`'s `✦ N`, and N is the **session's running total**: the seed plus
      // what this session's correct submits earned (`QuizSession.runningScore`).
      // `liveEnglishQuizPassage` seeds `0`, so the first frame reads `0`.
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      expect(find.text(en.quizCrumb('John 3:1-5')), findsOneWidget);
      expect(find.text(en.digits(0)), findsOneWidget);
      // The old mono count sentence is gone with the chrome that drew it —
      // asserted by its retired literal, because the method that composed it no
      // longer exists to compose it.
      expect(find.text('Question 1 of 1'), findsNothing);
    });
  });

  // ## THE SPOILER BOUNDARY, IN BOTH DIRECTIONS
  group('before the reader commits to an answer', () {
    testWidgets(
      'the widget tree carries nothing that says which option is right',
      (WidgetTester tester) async {
        // ## AND IT IS READ WITH THE **PAYLOAD'S OWN** ANSWER KEY HANDED TO THE BLOC
        //
        // [answeredQuestion] carries `is_correct: true`, `userAnswer: 'A'`. That is the
        // §5 trap 3 payload verbatim, and it is the only way to prove the boundary: a
        // fixture with no `is_correct` would pass on a screen that leaked the answer
        // out of a field the fixture never set.
        final QuizBloc bloc = quizBloc(aSpoilerFixture);
        await mountQuiz(tester, bloc: bloc);

        // Every card is `idle`. Four cards, four states, and the assertion is on the
        // `QuizOptionCard.state` of each — not on a colour, which a theme change could
        // make indistinguishable, and not on the absence of text.
        final List<QuizOptionState> states = tester
            .widgetList<QuizOptionCard>(find.byType(QuizOptionCard))
            .map((QuizOptionCard card) => card.state)
            .toList();
        expect(states, hasLength(4));
        expect(
          states,
          everyElement(QuizOptionState.idle),
          reason:
              'the payload says "$theAnsweredLetter" is correct and the reader has '
              'tapped nothing, so no card may be marked',
        );
        expect(states, isNot(contains(QuizOptionState.correct)));
        expect(states, isNot(contains(QuizOptionState.incorrect)));

        // No verdict suffix anywhere as TEXT, and the retired verdict sentences
        // are nowhere either — they died with the banner that spoke them.
        expect(find.text(en.quizCorrectSuffix), findsNothing);
        expect(find.text(en.quizIncorrectSuffix), findsNothing);

        // And no flecks: the redesign's quiz options carry none
        // (`eva/redesign.html:337-362` paints borders, fills and a key badge), so
        // even the OLD prototype's reward animation must be absent.
        expect(find.byType(GoldFlecks), findsNothing);
      },
    );

    testWidgets('nor does the SEMANTICS tree, which is the half a screen reader '
        'would leak through', (WidgetTester tester) async {
      // The widget tree and the semantics tree are different objects, and a
      // screen-reader user reads the second one. `QuizOptionCard`'s accessible name
      // is built by `AppLocalizations.optionLabel`, which takes the suffix as a
      // **parameter** precisely so the decision has one home — and that home returns
      // `null` until there is a verdict. If it returned a suffix unconditionally, the
      // colour would stay idle and this test would still catch it.
      final QuizBloc bloc = quizBloc(aSpoilerFixture);
      await mountQuiz(tester, bloc: bloc);

      final SemanticsNode node = tester.getSemantics(
        find.byType(QuizOptionCard).first,
      );
      expect(node.label, isNot(contains(en.quizCorrectSuffix)));
      expect(node.label, isNot(contains(en.quizIncorrectSuffix)));

      // Every card's merged label, not just the first. A `first` here would pass on
      // an implementation that leaked from the fourth card only.
      for (final Element element in find.byType(QuizOptionCard).evaluate()) {
        final String label = tester
            .getSemantics(find.byWidget(element.widget))
            .label;
        expect(label, isNot(contains(en.quizCorrectSuffix)));
        expect(label, isNot(contains(en.quizIncorrectSuffix)));
      }
    });

    testWidgets('and the CTA is `Check answer`, which names the action without '
        'naming the answer', (WidgetTester tester) async {
      final QuizBloc bloc = quizBloc(aSpoilerFixture);
      await mountQuiz(tester, bloc: bloc);

      expect(find.text(en.quizCheckAnswer), findsOneWidget);
      expect(find.text(en.quizNextQuestion), findsNothing);
      expect(find.text(en.quizSeeResults), findsNothing);
    });
  });

  group('after the reader checks an answer', () {
    /// Loads, taps [theAnsweredLetter] and presses the CTA, leaving the screen in
    /// the graded state.
    ///
    /// Shared by the four tests below so a change to *how* the flow is driven fails
    /// once here rather than four times over, and so all four observe the same
    /// sequence. It asserts nothing: a fixture that also asserted would report the
    /// setup's own bugs as the behaviour's.
    Future<QuizBloc> gradeTheAnsweredOption(WidgetTester tester) async {
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
        submission: defaultSubmission,
      );
      await mountQuiz(tester, bloc: bloc);

      await tester.tap(find.text(theAnsweredOption));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(en.quizCheckAnswer));
      await pumpQuizFrames(tester, 6);

      return bloc;
    }

    testWidgets('EXACTLY ONE card is marked correct, and it is the right one', (
      WidgetTester tester,
    ) async {
      await gradeTheAnsweredOption(tester);

      final List<QuizOptionCard> cards = tester
          .widgetList<QuizOptionCard>(find.byType(QuizOptionCard))
          .toList();
      expect(cards, hasLength(4));

      final List<QuizOptionState> graded = <QuizOptionState>[
        for (final QuizOptionCard card in cards)
          if (QuizOptionCard.isGraded(card.state)) card.state,
      ];
      // The direction that fails loudly: **exactly one**, not "at least one". Three
      // cards with a `correct` accent is the defect `_optionStateFor` actually had in
      // its first version, and a `contains` assertion passed straight through it.
      expect(
        graded,
        hasLength(1),
        reason: 'one correct and one selected, no more',
      );
      expect(graded.single, QuizOptionState.correct);

      // And it is the card whose letter the payload names. Asserting the *count*
      // alone would not catch a screen that marked the right number of cards and
      // the wrong ones.
      final Set<String> correctLetters = <String>{
        for (final QuizOptionCard card in cards)
          if (card.state == QuizOptionState.correct) card.letter,
      };
      expect(correctLetters, <String>{theAnsweredLetter});
    });

    testWidgets('the verdict glyph appears on that one card and nowhere else', (
      WidgetTester tester,
    ) async {
      // The shape, not the colour — decision 127's row. The redesign's verdict is
      // the card's own recolour (`eva/redesign.html:350-352`), and the glyph is
      // what a reader who cannot separate the two tints is given on top of it.
      // Counting is what distinguishes "on the right card" from "anywhere": the
      // first version of the state switch marked all four cards, and a
      // `findsOneWidget` here is what that mutation fails.
      await gradeTheAnsweredOption(tester);

      expect(
        find.descendant(
          of: find.byType(QuizOptionCard),
          matching: find.byIcon(Icons.check_circle_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('REDUCED MOTION REACHES THE AMBIENT ANIMATIONS, MEASURED AT '
        'EACH WIDGET', (WidgetTester tester) async {
      // ## WHY THIS IS HERE, AND WHAT IT DELIBERATELY DOES **NOT** RE-PROVE
      //
      // `pumpQuiz`'s `disableAnimations` existed with no caller, and the doc argued
      // for keeping it on the grounds that it was "plumbing, not a knob nothing
      // turns". That argument was never measured, and it is the same shape as a claim
      // already retracted elsewhere in this phase: a flag that reaches a `MediaQuery`
      // which nothing reads is indistinguishable from a flag nothing turns.
      //
      // So this test closes the **screen** half of the chain, and the design system
      // already owns the other half: `progress_beads_test.dart`'s reduced-motion row
      // proves the dot pulse is not painted when the clock is stopped, and
      // `neural_background`'s tier tests prove the same for the orbs. What neither
      // can do is show that `pumpQuiz`'s flag arrives at those widgets — that is a
      // wiring fact about this screen, and it is what this asserts. (The probe used
      // to be `GoldFlecks`, which died with the old prototype's flecks; the beads
      // row is the redesign's own ambient animation, and it reads the same flag.)
      //
      // **No freeze assertion here on purpose.** A first draft compared the two
      // `CustomPaint` widgets the two runs produced and asserted they differed. That
      // is **vacuous**: `CustomPaint` is rebuilt on every build, so two instances are
      // never identical whether or not the flag was observed. Planting
      // `final bool animate = true;` in `GoldFlecks` — deleting the whole
      // `MediaQuery` read — left that assertion green. A test that survives the
      // removal of the behaviour it names is worse than no test, so it is gone rather
      // than dressed up.
      Future<void> runWith({required bool disableAnimations}) async {
        final QuizBloc bloc = quizBloc(
          const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
          submission: defaultSubmission,
        );
        // **Unmount first.** `QuizPage` is published through `BlocProvider.value`, so
        // pumping a second `QuizPage` in one test reuses the element and the screen
        // stays in the graded state of the first run — the second tap then finds no
        // option card. Disposing the tree between runs is what makes the two runs
        // independent, and it is here rather than in `pumpQuiz` because no other
        // caller mounts two screens in one test.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpQuiz(
          tester,
          bloc: bloc,
          disableAnimations: disableAnimations,
        );
        await tester.tap(find.text(theAnsweredOption));
        await pumpQuizFrames(tester, 2);
        await tester.tap(find.text(en.quizCheckAnswer));
        await pumpQuizFrames(tester, 6);

        // A graded screen, not an idle one: the current bead is `current`, the one
        // state whose pulse reads the flag, so a flag that reached `MediaQuery`
        // without reaching this widget would pass an idle-screen test.
        expect(find.byType(ProgressBeads), findsOneWidget);
      }

      /// The flag as `ProgressBeads._Bead` and `NeuralBackground.build` read it,
      /// taken off the mounted tree at each widget rather than from a parameter —
      /// so a harness that stopped passing the flag reads `false` here and fails.
      ({bool atBeads, bool atBackground, NeuralTier tier}) probe() {
        final BuildContext beads = tester.element(find.byType(ProgressBeads));
        final BuildContext background = tester.element(
          find.byType(NeuralBackground),
        );
        return (
          atBeads: MediaQuery.maybeDisableAnimationsOf(beads) ?? false,
          atBackground:
              MediaQuery.maybeDisableAnimationsOf(background) ?? false,
          // The exact two arguments `NeuralBackground.build` passes, at the position
          // it passes them from. A literal `resolve(…, animationsEnabled: false)`
          // would assert the pure function against itself and survive the background
          // ceasing to read the flag.
          // `override` is left at its `null` default, which is the claim: the
          // background passes no override, and a call that merely omitted it
          // would say nothing.
          tier: NeuralTiers.resolve(
            size: MediaQuery.sizeOf(background),
            animationsEnabled:
                !(MediaQuery.maybeDisableAnimationsOf(background) ?? false),
          ),
        );
      }

      await runWith(disableAnimations: true);
      final ({bool atBeads, bool atBackground, NeuralTier tier}) on = probe();
      expect(on.atBeads, isTrue, reason: 'the flag reaches the bead row');
      expect(on.atBackground, isTrue, reason: '…and the background');
      expect(
        on.tier,
        NeuralTier.low,
        reason: '430×932 resolves `mid` with motion on, so the flag moved it',
      );

      // **The negative control the first run cannot supply for itself.** Without it,
      // "the flag arrives" would also be satisfied by a screen where the flag arrives
      // at everything because the harness always set it.
      await runWith(disableAnimations: false);
      final ({bool atBeads, bool atBackground, NeuralTier tier}) off = probe();
      expect(off.atBeads, isFalse, reason: 'the default call does not set it');
      expect(off.atBackground, isFalse);
      expect(
        off.tier,
        NeuralTier.mid,
        reason: 'the control that makes the `low` above mean something',
      );
    });

    testWidgets('the graded card is a live region, and the CTA relabels', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = await gradeTheAnsweredOption(tester);

      // The verdict the **submission** reported, not one derived from the payload.
      // `contractSubmitAnswerFixture` says `is_correct: true`, so the card reads
      // "correct"; the first version of this file asserted the payload's answer key
      // and would have kept passing if the submit response and the fixture disagreed —
      // which is precisely the case §5 trap 3's dead `question-group-3` makes
      // reachable.
      expect(
        bloc.state.lastResult?.isCorrect,
        isTrue,
        reason:
            'the verdict shown is the submit response\'s, and the response says '
            'true. Asserting the payload instead would not notice the two '
            'disagreeing',
      );

      // The retired banner's live region moved onto the graded card — the wrapper
      // is a container, so what is announced is the card's own subtree, verdict
      // suffix included.
      expect(
        semanticsTree(tester)
            .where((SemanticsData node) => node.flagsCollection.isLiveRegion),
        hasLength(1),
        reason:
            'the verdict arrives after the screen has settled; without the flag a '
            'screen-reader user learns about it only by exploring. '
            '`FeedbackBanner` used to carry it; the graded card does now',
      );

      // `eva/redesign.html:1431` — the same pill, relabelled by the graded state,
      // and the live payload has **one** question: grading it IS the terminal
      // state, so the label is `seeRes` with the painted star beside it.
      // `checkAnswer` must be **gone**, because a screen showing both is ambiguous
      // about which press does what.
      expect(find.text(en.quizSeeResults), findsOneWidget);
      expect(find.text(en.quizCheckAnswer), findsNothing);
    });

    testWidgets('and the SEMANTICS tree carries the verdict the card colours '
        'carry', (WidgetTester tester) async {
      await gradeTheAnsweredOption(tester);

      final List<String> labels = <String>[
        for (final Element element in find.byType(QuizOptionCard).evaluate())
          tester.getSemantics(find.byWidget(element.widget)).label,
      ];
      expect(
        labels.where((String l) => l.contains(en.quizCorrectSuffix)),
        hasLength(1),
      );
    });
  });

  // ## THE PAYLOAD'S OWN SHAPE: A QUESTION THAT IS **ALREADY ANSWERED**
  group('a question the server has already graded', () {
    // §5 trap 3's live shape: the 2026-10-03 capture has one question with
    // `already_answered: true`, so a reader arriving today lands on a closed
    // question with a selection and nothing to submit.

    // ## AND THE CARD IS ANNOUNCED **ONCE**, WHICH IS WHAT `excludeSemantics` IS
    // ## FOR AND WHAT NOTHING WAS ASSERTING
    //
    // `QuizOptionCard`'s `Semantics(label: semanticLabel, excludeSemantics: true)`
    // builds the name out of `AppLocalizations.optionLabel` — the letter, the text and the
    // verdict — and then **drops the children's own nodes**, which are the letter badge
    // and the option text as `Text`s. Without `excludeSemantics` the merged node's
    // label is `A. Nicodemus — …` **plus** `A` **plus** `Nicodemus`, and a screen
    // reader says all of it twice.
    //
    // Every other assertion on this name is a `contains`, which tolerates duplication
    // by construction — the same shape as Phase 7's recorded `find.textContaining`
    // miss. So the count below is the assertion that can see it: the option text
    // appears **exactly once**, whatever else the node carries.
    testWidgets('the option text is announced ONCE, not once per child', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(aClosedFixture);
      await mountQuiz(tester, bloc: bloc);

      for (final Element element in find.byType(QuizOptionCard).evaluate()) {
        final QuizOptionCard card = element.widget as QuizOptionCard;
        final String label = tester
            .getSemantics(find.byWidget(element.widget))
            .label;
        final String text = card.text;

        expect(
          _occurrences(label, text),
          1,
          reason:
              'letter ${card.letter} — the name is '
              '`${en.optionLabel(letter: card.letter, text: text)}`, built from the '
              'letter and the text once each. Announcing the child `Text`s as well '
              'would say the option twice',
        );
        // Stated rather than derived: the name is exactly what `optionLabel` builds,
        // which is what makes "the child nodes are gone" observable.
        expect(
          label,
          en.optionLabel(
            letter: card.letter,
            text: text,
            suffix: en.quizAlreadyAnsweredSuffix,
          ),
        );
      }
    });

    testWidgets('and still once AFTER a check, when a suffix is appended', (
      WidgetTester tester,
    ) async {
      // The graded arm, because that is where a third string enters the name and a
      // duplicated option text would be least noticeable behind it.
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
        submission: defaultSubmission,
      );
      await mountQuiz(tester, bloc: bloc);
      await tester.tap(find.text(theAnsweredOption));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(en.quizCheckAnswer));
      await pumpQuizFrames(tester, 6);

      for (final Element element in find.byType(QuizOptionCard).evaluate()) {
        final QuizOptionCard card = element.widget as QuizOptionCard;
        final String label = tester
            .getSemantics(find.byWidget(element.widget))
            .label;
        expect(
          _occurrences(label, card.text),
          1,
          reason: 'letter ${card.letter}',
        );
      }
    });
    testWidgets('cannot be submitted, and the option that was chosen is dimmed '
        'rather than marked', (WidgetTester tester) async {
      final QuizBloc bloc = quizBloc(aClosedFixture);
      await mountQuiz(tester, bloc: bloc);

      // The fixture carries the flag, so the cards come up closed.
      final List<QuizOptionCard> cards = tester
          .widgetList<QuizOptionCard>(find.byType(QuizOptionCard))
          .toList();
      expect(
        cards.every((QuizOptionCard c) => !c.enabled),
        isTrue,
        reason:
            '`already_answered: true` means every card is inert. A card left '
            'enabled would accept a tap that the bloc would then refuse — a dead '
            'control, which is the thing §5 trap 3 exists to prevent',
      );
      expect(find.text(en.quizAlreadyAnsweredSuffix), findsNothing);

      // ## AND **NOTHING** IS MARKED — NOT EVEN THE READER'S OWN PREVIOUS ANSWER
      //
      // `answeredQuestion` carries `user_answer: 'A'` and `is_correct: true`. The
      // first draft of this test expected the `'A'` card to read `selected`, on the
      // reasoning that the reader chose it and has nothing to hide from themselves.
      // The screen says `idle`, and the screen is right, for a reason worth
      // recording:
      //
      // `_optionStateFor` keys off `QuizAnswer.selectedLetter`, which is the
      // **local** selection this session made. An already-answered question is never
      // opened for answering, so nothing ever set it. Seeding it from
      // `question.userAnswer` would be the first line of the page that reads the
      // payload's grading fields — and `is_correct` is on the *same object*, one line
      // away. A reader who opens an already-done question and sees their old answer
      // highlighted has been told nothing about this one, but the code that drew it
      // is the code that could have drawn the verdict, and the boundary is supposed to
      // be a place where that cannot happen rather than a place where it currently
      // does not.
      //
      // So the assertion is the stronger one: the payload's answer key reached
      // **no** card, in any of the three graded states.
      for (final QuizOptionCard card in cards) {
        expect(
          card.state,
          QuizOptionState.idle,
          reason: 'letter ${card.letter}',
        );
        expect(QuizOptionCard.isGraded(card.state), isFalse);
      }
    });

    testWidgets('and the accessible name says why it is inert', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(aClosedFixture);
      await mountQuiz(tester, bloc: bloc);

      // The reason, in the accessible name. `Semantic(s.enabled: false)` alone
      // announces "dimmed" and leaves the reader to guess; §14's disabled row is
      // `enabled: false` **and** the reason in the name, and this is the assertion
      // that keeps both halves.
      //
      // **Every card, not the first.** Decision 86 says the reason is per-card,
      // because the screen has one question and a reader navigating by element hears
      // each option's own state. A `first` here would pass on an implementation that
      // put the reason on one card and left the other three mute — which is the
      // defect the spoiler group's own iteration guards against on the other side of
      // the boundary.
      final List<SemanticsNode> nodes = <SemanticsNode>[
        for (final Element element in find.byType(QuizOptionCard).evaluate())
          tester.getSemantics(find.byWidget(element.widget)),
      ];
      expect(nodes, hasLength(4));
      for (final SemanticsNode each in nodes) {
        expect(each.label, contains(en.quizAlreadyAnsweredSuffix));
        // `flagsCollection`, not `hasFlag` — §4's forbidden-API table takes
        // `SemanticsNode.hasFlag`, deprecated after 3.32, and the replacement reads
        // `isEnabled` off the collection rather than passing a flag to a predicate.
        // `toBoolOrNull()` because the collection's flags are tri-state: **unset** is
        // not **false**, and a screen that never mentioned the flag is the opposite
        // defect — a screen reader would experience it as enabled for want of an
        // answer.
        expect(each.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      }
    });

    testWidgets('and the CTA says `next` when a question follows it, which is the '
        'only way to reach that arm', (WidgetTester tester) async {
      // ## TWO QUESTIONS, NOT ONE — AND THIS IS A FINDING, NOT A FIXTURE WHIM
      //
      // `QuizCta`'s table has `closed, on the last, not yet finished → next` and
      // `closed, on the last, and nothing was submitted → none`. Those two rows
      // differ by **nothing in the payload**: a last closed question with no
      // `SubmitResult` is the same object in both.
      //
      // The first draft of this test drove the transition with a press — press
      // `next` on a one-question payload and expect `none`. That is not what happens,
      // and it cannot be: with one closed question the state is `none` **from the
      // first frame**, so there is no `next` to press. The rows are separated by
      // whether a question *follows*, not by anything the reader does. So the row is
      // reachable only from a multi-question payload, which is what
      // `mixedQuizPassage` is for.
      //
      // ## AND THE LABEL IS THE REDESIGN'S OWN `next`, WHICH IS THE **TRUE** WORD
      //
      // The old screen labelled this frame `Check answer` — the superseded
      // prototype's `{checked ? 'Next question' : 'Check answer'}` with `checked`
      // false — which named the one action the control cannot perform: the question
      // is closed by the wire and will never be checkable in this session. The
      // redesign's `.qnext` names what the press DOES (`eva/redesign.html:1431`:
      // `label = last ? seeRes : next`), and here the press advances — so `next ▸`
      // is the honest label, on a control that is **enabled** because advancing is
      // possible. The dead end two tests down keeps the written reason, because
      // there the press can do nothing at all.
      final QuizBloc bloc = quizBloc(
        Result<ScriptureText>.of(mixedQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      // The `next` arm, reached.
      expect(bloc.state.cta, QuizCta.next);

      // And the button is enabled, because advancing is possible — which is the
      // difference between this arm and the dead end two tests down.
      final Finder cta = find.bySemanticsLabel(en.quizNextQuestion);
      expect(
        tester.getSemantics(cta).flagsCollection.isEnabled.toBoolOrNull(),
        isTrue,
      );
    });
  });

  // ## THE DEAD END, AND IT IS NOT PAPERED OVER
  group('a quiz whose questions were all already answered', () {
    // ## WHY THIS GROUP EXISTS RATHER THAN A TODO
    //
    // A reader who has done today's quiz arrives on `/quiz` and finds every question
    // closed and nothing to submit. There is no `SubmitResult` — no request was ever
    // sent — and `ResultPage` takes one as a **required** parameter. So `/result`
    // cannot be reached, and the honest rendering of that is a button that says
    // nothing is available, disabled, with the reason in its accessible name.
    //
    // The alternative — hiding the button, or leaving it enabled and letting the tap
    // do nothing — is the defect this pins. `QuizCta.none` is the state that makes
    // it expressible, and this is the test that proves the enum's least-valued arm
    // is not dead code.
    testWidgets('offers a DISABLED button that names what is missing', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(aClosedFixture);
      await mountQuiz(tester, bloc: bloc);

      // **No press, and that is the finding.** See the `next` arm's test above: with
      // one closed question the state is `none` from the first frame, so there is
      // nothing to advance off and nothing to wait for. A reader who has done today's
      // quiz lands here and stays here.
      expect(
        bloc.state.cta,
        QuizCta.none,
        reason:
            'nothing was submitted, so there is no `SubmitResult` for '
            '`ResultPage`\'s required parameter',
      );
      expect(bloc.state.lastResult, isNull);

      // The button is still on screen — §14's disabled row, not a removed control.
      final Finder cta = find.bySemanticsLabel(en.quizUnavailableSuffix);
      expect(cta, findsOneWidget);

      // ## AND ITS **VISIBLE** LABEL NAMES WHAT IS MISSING, NOT AN ACTION THIS
      // ## SCREEN CANNOT PERFORM
      //
      // This used to assert `find.text(en.quizCheckAnswer)`, on the reasoning that
      // `QuizScreen.tsx:127` transcribes `{checked ? 'Next question' : 'Check
      // answer'}` and `graded` is false here. But the prototype's `disabled={!checked
      // && !selected}` covers **one** state — nothing chosen yet — and this is the
      // other: the question is closed by the wire and there is nothing to check
      // *ever*. A disabled "Check answer" names the one action this screen cannot
      // perform, and every other `Text` on the screen is content the reader already
      // has, so the **sighted** reader is told nothing at all.
      //
      // Decision 85's reasoning was *"a reader who cannot see the button is the one
      // who needs the reason"* — which holds only if the sighted reader has a second
      // channel. Here they do not: no banner, no empty state, no caption. So the
      // reason moves onto the label, and it is `unavailableSuffix` because that is
      // the string already written for exactly this state and already bilingual.
      expect(find.text(en.quizCheckAnswer), findsNothing);
      expect(find.text(en.quizUnavailableSuffix), findsOneWidget);

      final SemanticsNode node = tester.getSemantics(cta);
      // `isFalse` and not `isNull`: `QuizOptionCard` states `enabled: false`
      // explicitly, and `Semantics(enabled: false)` on the button is the §14 row. A
      // tri-state `isNull` would mean "never mentioned", which is a *different* bug —
      // a control that simply forgot to say so.
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      // **Equality, not `contains`.** The reason is now the label, so appending it a
      // second time would read "there is no answer to show — there is no answer to
      // show" — and a `contains` assertion would sit right through that. This is the
      // same lesson as `the reason is named only by a DEAD cta`, one level down.
      expect(node.label, en.quizUnavailableSuffix);
    });

    testWidgets('but "nothing chosen yet" KEEPS the prototype\'s label', (
      WidgetTester tester,
    ) async {
      // The other `QuizCta.none`, and the reason the split is a *state* test rather
      // than a label test. Nothing is selected on an open question: the button is
      // disabled for the prototype's own reason (`disabled={!checked && !selected}`)
      // and "Check answer" is an accurate description of what the press will do once
      // the reader chooses. Naming the absence here would be wrong — there is an
      // answer to show, the reader has not asked for it yet.
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      expect(bloc.state.cta, QuizCta.none, reason: 'nothing selected');
      expect(bloc.state.currentAnswer!.isOpen, isTrue);

      expect(find.text(en.quizCheckAnswer), findsOneWidget);
      expect(find.text(en.quizUnavailableSuffix), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel(en.quizCheckAnswer)).label,
        en.quizCheckAnswer,
      );
    });
  });

  // ## AND THE **LIVE** HALF OF THE SPLIT, WHICH THE DEAD-END GROUP ALONE DID NOT
  // ## OBSERVE
  //
  // The group above asserts the reason is on the **dead** CTA. This one asserts it is
  // **not** on a live one, and the two halves are the whole of decision 85's split:
  // the reason names a *state*, so it may only appear on a control that is in that
  // state.
  //
  // ## WHY A **PAYLOAD** PREDICATE WAS THE WRONG ONE, MEASURED
  //
  // The reason was computed as `answeredCount == questionCount` — "the reader has
  // answered everything" — and every session that reaches an answer does. So on the
  // success path the one control that **opens the graded answer** carried an
  // accessible name reading *"Next question — there is no answer to show"*. A
  // screen-reader user is told the answer is missing by the button that reveals it,
  // after they gave it.
  //
  // `QuizCta.none` is the state, and it is the state `_Cta` itself tests for
  // `enabled`. `reason` is therefore now derived from the same value that decides
  // whether the button works, which is the only way the two cannot disagree.
  group('the reason is named only by a DEAD cta', () {
    /// A two-open-question payload — the smallest one whose **first** graded state
    /// is a live `next` CTA rather than the terminal `seeResults`.
    ///
    /// The live payload's single open question cannot serve: grading it IS the
    /// terminal state now, and both tests below need a graded question that still
    /// has a question after it.
    final ScriptureText twoOpen = englishPassageWith(<Question>[
      liveEnglishQuestion,
      liveEnglishQuestion.copyWith(
        id: 'question-group-4',
        sortOrder: 2,
        prompt: 'Where did Nicodemus find Jesus?',
        options: <String, String>{'A': 'In Galilee', 'B': 'In Jerusalem'},
      ),
    ]);

    /// Drives the group's payload to the state the test names: [last] selects the
    /// terminal frame (both questions graded) or the live `next` frame (one).
    Future<QuizBloc> gradeOnTwoOpenQuestions(
      WidgetTester tester, {
      required bool last,
    }) async {
      final QuizBloc bloc = quizBloc(
        Result<ScriptureText>.of(twoOpen),
        submission: defaultSubmission,
      );
      await mountQuiz(tester, bloc: bloc);
      await tester.tap(find.text(theAnsweredOption));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(en.quizCheckAnswer));
      await pumpQuizFrames(tester, 6);
      if (last) {
        await tester.tap(find.text(en.quizNextQuestion));
        await pumpQuizFrames(tester, 4);
        await tester.tap(find.text('In Galilee'));
        await pumpQuizFrames(tester, 2);
        await tester.tap(find.text(en.quizCheckAnswer));
        await pumpQuizFrames(tester, 6);
      }
      return bloc;
    }

    /// The CTA's accessible name.
    ///
    /// Read off the node whose label is the CTA's — `_Cta`'s own `Semantics` —
    /// with `excludeSemantics` folding the pill's caption into it, so this is the
    /// string a screen reader announces, not the caption a sighted reader sees.
    /// The label is resolved by **name** rather than by type, because the ghost
    /// pill is not an `EvaButton` and a type find would name a private widget.
    String ctaAccessibleName(WidgetTester tester, String label) =>
        tester.getSemantics(find.bySemanticsLabel(label)).label;

    testWidgets('a LIVE cta does not claim there is no answer to show', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = await gradeOnTwoOpenQuestions(tester, last: false);

      // The precondition stated as an assertion: one question graded, one still to
      // come, and the button **live** on the frame whose label the assertion below
      // pins. If the CTA stopped being `next` here the label below would be absent
      // for a reason that is not the one being fixed.
      expect(bloc.state.session!.answeredCount, 1);
      expect(bloc.state.session!.questionCount, 2);
      expect(bloc.state.cta, QuizCta.next);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(en.quizNextQuestion))
            .flagsCollection
            .isEnabled
            .toBoolOrNull(),
        isTrue,
      );

      // The exact string, not a `contains` on the *absent* side only. The `contains`
      // form is what let this through: every existing assertion was
      // `label.contains(suffix)` on a merged node, and none of them was on a live
      // CTA at all.
      expect(
        ctaAccessibleName(tester, en.quizNextQuestion),
        en.quizNextQuestion,
        reason:
            'the label is the redesign\'s own, with nothing appended. '
            '"${en.quizUnavailableSuffix}" is a fact about a DEAD control and this '
            'control opens the graded answer',
      );
    });

    testWidgets('and the TERMINAL cta does not either', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = await gradeOnTwoOpenQuestions(tester, last: true);

      // The redesign's own terminal rule: the last graded question IS the terminal
      // state (`eva/redesign.html:1431` labels it `seeRes`), and one press opens
      // `/result` (`:1432`). There is no second "advance" press in between any more.
      expect(bloc.state.cta, QuizCta.seeResults);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(en.quizSeeResults))
            .flagsCollection
            .isEnabled
            .toBoolOrNull(),
        isTrue,
      );
      expect(ctaAccessibleName(tester, en.quizSeeResults), en.quizSeeResults);
    });
  });

  // ## THE ANTI-VACUITY SWEEP, AND IT READS THE **SOURCE**
  group('no prototype or debug string reaches lib/', () {
    // ## WHY THIS IS A **PLAIN `test`**, NOT A `testWidgets`
    //
    // The first version of this group pumped a page and asserted `find.text(...)`,
    // which is worth explaining at length because it is the wrong instrument and the
    // mistake is a common one.
    //
    // Two strings named a work-in-progress on screen during this phase:
    // `this screen was rebuilt from the prototype` and `the sibling button wired its
    // own onFinish`. A `find.text` assertion against them passes **the moment the
    // string stops being rendered** — that is, the moment it stops mattering. It is a
    // test of the present, and the defect it is guarding against is a future branch
    // re-introducing the string.
    //
    // So the gate is the **source tree**: if the string is anywhere in `lib/`, some
    // branch renders it. And it is a plain `test` for the same reason — no widget, no
    // `tester`, no pump, and therefore nothing that could make it vacuous.
    //
    // ## AND WHY IT IS A **RAW** GREP, DOC COMMENTS INCLUDED
    //
    // The first version of this sweep stripped doc comments before matching, on the
    // reasoning that a provenance note ought to be allowed to quote what it is
    // documenting. That reasoning was wrong, and the requirement settled it: the
    // strings must not reach `lib/` **at all**. `lib/features/quiz/presentation/
    // pages/quiz_page.dart` and `lib/core/design_system/widgets/eva_chip.dart` both
    // documented the not-ported preview toggle and both quoted its prototype labels
    // verbatim — so the sweep had to be the sophisticated kind to let them through,
    // and a sweep that has to be sophisticated enough to forgive comments will also
    // forgive a comment quoting the very string it exists to keep out.
    //
    // Both docs now describe the toggle **by behaviour** and neither prints its label.
    // That is a small loss of provenance and it is recoverable — `01-source-analysis.md`
    // defect #12 is the authority and it is not in `lib/` — while a comment-scoped
    // exemption is a permanent hole.
    //
    // ## AND THE MATCH **DELETES WHITESPACE**, WHICH IS NOT "TIGHTENING" IT
    //
    // The third version of this gate was a line-level `contains`, and the planted
    // mutation `const String plantedLeak = 'Frame' ' A';` **passed** — Dart joins
    // adjacent literals at compile time, so the forbidden string is not in the file
    // and neither this sweep nor `rg` can see it. `\_hitIn`'s decision 90 has the
    // transform and the reasoning; the short version is that comparing with the
    // compiler's own join characters removed catches the split literal and leaves the
    // gate's hit-set on natural text **unchanged**, so it is wider without being
    // stricter.
    test('the two prototype preview labels are nowhere in lib/', () {
      // `lib/`, resolved from the package root rather than from the test's own
      // directory, so the sweep cannot be narrowed by moving this file.
      final Directory lib = Directory('lib');
      expect(
        lib.existsSync(),
        isTrue,
        reason:
            'the suite runs with the package root as its working directory. If this '
            'fails, the sweep below would have passed vacuously by reading nothing',
      );

      final List<String> hits = <String>[
        for (final FileSystemEntity entity in lib.listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            for (final String line in entity.readAsLinesSync())
              if (_hitIn(line)) '${entity.path}: $line',
      ];

      expect(
        hits,
        isEmpty,
        reason:
            'these strings are not to be ported and are not to be printed. They are '
            'named here, in `test/`, which is where a prohibition belongs:\n'
            '${hits.join('\n')}',
      );
    });

    test('and neither work-in-progress string is in lib/ either', () {
      // The other pair, kept as a **second** test rather than folded into the first.
      // One `test` with one `reason` is easier to read, and the reason these are not
      // merged is that they fail for different reasons: the prototype labels are
      // prohibited by `01-source-analysis.md` defect #12, and these two are simply
      // sentences that were never meant to ship. A merged list would have to explain
      // both in one paragraph and would therefore explain neither.
      final List<String> hits = <String>[
        for (final FileSystemEntity entity in Directory(
          'lib',
        ).listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            for (final String line in entity.readAsLinesSync())
              if (_hitIn(line)) '${entity.path}: $line',
      ];

      expect(hits, isEmpty);
    });
  });
}

/// The strings `01-source-analysis.md` defect #12 says must not be ported, plus the
/// two sentences that named unfinished work.
///
/// ## WHY A CONSTANT AND NOT A `RegExp`, AND WHY **CONTAINS** AND NOT EQUALITY
///
/// **Not a `RegExp`:** `Frame A` as a pattern matches `Frame Area` and `FrameApple`,
/// so a future widget named `FrameAnnouncer` would turn the suite red for no reason —
/// and the fix an agent reaches for under time pressure is loosening the pattern,
/// which is how a real hit gets past one. A literal cannot be loosened.
///
/// **Contains, not equality — and the first version of this was equality, which was
/// vacuous in the most expensive way available.** The planted mutation for this gate
/// was `const String _leak = 'Frame A';`, and the suite stayed green: an equality
/// comparison against `Frame A` does not match a line that *carries* the string
/// among other tokens, which is the only shape a real violation has. A gate that
/// cannot fail is worse than no gate (§7), and this one looked like it was working.
///
/// So [\_hitIn] is a `contains` — now a **whitespace-deleted** one, which is decision
/// 90 below. A `RegExp.escape` is unnecessary and would be wrong: there is nothing to
/// escape in any of these four strings, and a reader who reaches for it has been told
/// to expect metacharacters that are not there.
const Set<String> _forbiddenInLib = <String>{
  'Frame A',
  'Frame B',
  'this screen was rebuilt from the prototype',
  'the sibling button wired its own onFinish',
};

/// [line] with whitespace and string-literal delimiters deleted, before it is
/// searched.
///
/// **The raw line, comment markers and all.** This function had a
/// `_significantText` helper in front of it that stripped `//` markers, and the
/// planted mutation for it was `/// Do not port Frame B.` — which that helper reduced
/// to the empty string and which therefore passed. A comment-exemption is not a
/// smaller hole than the gate; it is the gate, with the one place a real reader would
/// copy from exempted. So there is no comment stripping, and `///` counts.
///
/// ## 90. AND THE MATCH DELETES **THE COMPILER'S JOIN CHARACTERS**, BECAUSE A
/// ## LINE-LEVEL `contains` CANNOT SEE WHAT THE COMPILER ASSEMBLES
///
/// The planted mutation for this one was `const String plantedLeak = 'Frame' ' A';` —
/// and it **passed**. Dart's implicit adjacent-string concatenation is a
/// *compile-time* join, so the source line carries `'Frame' ' A'` — with a quote and
/// a space where the space belongs — and `line.contains('Frame A')` cannot match text
/// that is not in the file. Neither can `rg`. The gate was blind to a string the
/// language itself assembles, which is the worst shape for a gate to be blind to.
///
/// **The fix is not more patterns and not a stricter pattern — it is deleting the
/// characters the compiler's own join deletes**, which is exactly two: whitespace and
/// the literal delimiters.
///
/// ```text
/// forbidden  'Frame A'          → FrameA
/// source     "'Frame' ' A'"     → FrameA     ← hit;  before: not a hit
/// source     "'Frame A'"        → FrameA     ← hit;  before: a hit
/// ```
///
/// **Why this is not "tightening the sweep".** The reviewer's verdict on the gate was
/// that it is not too strict — 0 false positives, the suite green — and that verdict
/// is preserved *exactly*. The hit-set on natural text is **unchanged**, because
/// deleting whitespace cannot create a match that `contains` would have missed: it
/// only ever brings two characters *closer*, and the two it brings together are ones
/// the compiler would have joined anyway.
///
/// | line | before | after | verdict |
/// | --- | --- | --- | --- |
/// | `'Frame A'` | hit | hit | the violation, both ways |
/// | `'Frame' ' A'` | **miss** | hit | **the hole this closes** |
/// | `/// Do not port Frame B.` | hit | hit | the mutation for the rejected comment-stripper |
/// | `/// Frame Area is a heading` | hit | hit | a pre-existing false positive, **not** made worse |
///
/// The last row is honest rather than flattering: `Frame Area` matches `Frame A` under
/// both rules, because the forbidden string contains a space and the prose contains
/// the same two words next to each other. This change neither fixes nor worsens that.
/// Fixing it would mean matching *whole words with their spacing intact* — which is
/// precisely what cannot see `'Frame' ' A'`. **The two requirements are in direct
/// opposition and one of them has to give**; the forbidden strings are prototype
/// chrome nobody will write prose about, so the split literal is the side worth
/// catching.
///
/// **Two limits recorded rather than papered over.**
///
/// * **Explicit `+` concatenation** — `'Frame' + ' A'` — is still missed, because
///   catching it means deleting `+` from every line and `Frame + A` in ordinary code
///   is two identifiers, not one string. The compiler does not assemble this one for
///   you either; a reader has to type it.
/// * **A literal split across two lines** — `'Frame'` newline `' A'` — because the
///   file is read a line at a time, and that is what buys the `path: line`
///   diagnostics that make a failure actionable. `dart format` keeps adjacent
///   literals on one line unless the line exceeds 80 columns and none of these four
///   strings can reach that length, so the shape is not one the formatter produces.
///
/// The general fix for both is an AST walk, which needs `package:analyzer`, and §2
/// forbids a new dependency.
bool _hitIn(String line) {
  final String joined = _joinedByTheCompiler(line);
  return _forbiddenInLib.any(
    (String forbidden) => joined.contains(_joinedByTheCompiler(forbidden)),
  );
}

/// [value] with whitespace and string-literal delimiters removed.
///
/// **A `RegExp` over `\s`, `'` and `"`, and not a hand-rolled walk:** this is a
/// diagnostic aid on test-only code, and the character classes are short enough that
/// a walk would be a second place to get the set wrong. `'` is written `\x27` so the
/// pattern can stay a single-quoted raw string. The result is only ever compared,
/// never rendered — a failure message quotes the line, not this.
String _joinedByTheCompiler(String value) =>
    value.replaceAll(_whitespaceOrDelimiter, '');

final RegExp _whitespaceOrDelimiter = RegExp(r'[\s\x27"]');

/// How many times [needle] appears in [haystack] — non-overlapping.
///
/// `RegExp.allMatches` over an escaped needle rather than `split().length`, because
/// `'a'.split('a')` is `[]`, not `['', '']`, and an option's text is a word rather
/// than a character. Only used on accessible names, so the cost is irrelevant.
int _occurrences(String haystack, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(haystack).length;
