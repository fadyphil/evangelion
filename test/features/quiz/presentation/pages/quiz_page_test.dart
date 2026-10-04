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

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/quiz/presentation/quiz_strings.dart';
import 'package:evangelion/features/quiz/presentation/widgets/feedback_banner.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_header.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/quiz_harness.dart';
import '../../../../support/reading_harness.dart';

/// The English strings, once, for the whole file.
const QuizStrings en = QuizStrings.en();

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
Result<ScriptureText> get aSpoilerFixture => Result<ScriptureText>.success(
  englishPassageWith(<Question>[verdictCarryingQuestion]),
);

/// [liveEnglishQuizPassage] carrying [answeredQuestion] — the only question closed.
///
/// §5 trap 3's 2026-10-03 shape. A single closed question is what makes the last two
/// groups reachable: it is simultaneously "there is nothing to submit" and "there is
/// no question after this one", which is the dead end `QuizCta.none` exists for.
Result<ScriptureText> get aClosedFixture => Result<ScriptureText>.success(
  englishPassageWith(<Question>[answeredQuestion]),
);

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
  group('the screen the prototype described', () {
    testWidgets('is a Scaffold with NO app bar, and says why', (
      WidgetTester tester,
    ) async {
      // ## THE OPPOSITE OF THE STUB'S FIRST TEST, ASSERTED EXPLICITLY
      //
      // The stub's test asserted `find.byType(AppBar), findsOneWidget` and
      // `find.text(AppRoutes.quiz), findsOneWidget` — it asserted the route constant
      // was painted as a title. `QuizScreen.tsx` has no `AppBar` and no title: its
      // top row is a close control, `ProgressBeads` and a spacer, which is
      // `QuizHeader`, and §13.6's chrome table puts the header there rather than in
      // an `AppBar`. So both halves are inverted, and saying "no app bar" is stronger
      // than "some other app bar": a future `AppBar` titled `Quiz` would satisfy the
      // old test and violate the prototype.
      final QuizBloc bloc = quizBloc(
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
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
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
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

      // And the letters, which the prototype draws as a badge beside each option.
      for (final String letter in liveEnglishQuestion.options.keys) {
        expect(find.text(letter), findsOneWidget, reason: 'letter "$letter"');
      }
    });

    testWidgets('and its progress line counts the questions it has', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      expect(find.text(en.questionProgress(1, 1)), findsOneWidget);
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

        // No verdict sentence. [FeedbackBanner] exists but is not on screen.
        expect(find.byType(FeedbackBanner), findsNothing);
        expect(find.text(en.verdictCorrect), findsNothing);
        expect(find.text(en.verdictIncorrect), findsNothing);
        expect(find.text(en.correctSuffix), findsNothing);
        expect(find.text(en.incorrectSuffix), findsNothing);

        // And no flecks, which are the prototype's reward animation for a correct
        // answer. Four `GoldFlecks` would be the giveaway even with the colours gone.
        expect(find.byType(GoldFlecks), findsNothing);
      },
    );

    testWidgets(
      'nor does the SEMANTICS tree, which is the half a screen reader '
      'would leak through',
      (WidgetTester tester) async {
        // The widget tree and the semantics tree are different objects, and a
        // screen-reader user reads the second one. `QuizOptionCard`'s accessible name
        // is built by `QuizStrings.optionLabel`, which takes the suffix as a
        // **parameter** precisely so the decision has one home — and that home returns
        // `null` until there is a verdict. If it returned a suffix unconditionally, the
        // colour would stay idle and this test would still catch it.
        final QuizBloc bloc = quizBloc(aSpoilerFixture);
        await mountQuiz(tester, bloc: bloc);

        final SemanticsNode node = tester.getSemantics(
          find.byType(QuizOptionCard).first,
        );
        expect(node.label, isNot(contains(en.correctSuffix)));
        expect(node.label, isNot(contains(en.incorrectSuffix)));

        // Every card's merged label, not just the first. A `first` here would pass on
        // an implementation that leaked from the fourth card only.
        for (final Element element in find.byType(QuizOptionCard).evaluate()) {
          final String label = tester
              .getSemantics(find.byWidget(element.widget))
              .label;
          expect(label, isNot(contains(en.correctSuffix)));
          expect(label, isNot(contains(en.incorrectSuffix)));
        }
      },
    );

    testWidgets('and the CTA is `Check answer`, which names the action without '
        'naming the answer', (WidgetTester tester) async {
      final QuizBloc bloc = quizBloc(aSpoilerFixture);
      await mountQuiz(tester, bloc: bloc);

      expect(find.text(en.checkAnswer), findsOneWidget);
      expect(find.text(en.nextQuestion), findsNothing);
      expect(find.text(en.seeResults), findsNothing);
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
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
        submission: defaultSubmission,
      );
      await mountQuiz(tester, bloc: bloc);

      await tester.tap(find.text(theAnsweredOption));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(en.checkAnswer));
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

    testWidgets('the flecks appear on that one card and nowhere else', (
      WidgetTester tester,
    ) async {
      // The animation, not the colour. `QuizScreen.tsx:90-97` puts four flecks on the
      // correct option only, and this is the assertion that catches the offset bug
      // `quiz_option_card_test.dart` also carries: the pair that was positioned
      // inside the card instead of outside it was still *present*, so counting them
      // is what distinguishes "in the right place" from "there".
      await gradeTheAnsweredOption(tester);

      expect(find.byType(GoldFlecks), findsOneWidget);
    });

    testWidgets('REDUCED MOTION REACHES BOTH AMBIENT ANIMATIONS, MEASURED AT '
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
      // already owns the other half: `gold_flecks_test.dart`'s *"disableAnimations
      // freezes the flecks at rest"* compares **pixels** and proves the freeze, and
      // `neural_background`'s tier tests prove the same for the orbs. What neither can
      // do is show that `pumpQuiz`'s flag arrives at those widgets — that is a wiring
      // fact about this screen, and it is what this asserts.
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
          const Result<ScriptureText>.success(liveEnglishQuizPassage),
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
        await tester.tap(find.text(en.checkAnswer));
        await pumpQuizFrames(tester, 6);

        // `GoldFlecks` only mounts on a graded-correct card, so this runs on a screen
        // in that state rather than an idle one — a flag that reached `MediaQuery`
        // without reaching this widget would pass an idle-screen test.
        expect(find.byType(GoldFlecks), findsOneWidget);
      }

      /// The flag as `GoldFlecks.build` and `NeuralBackground.build` read it, taken
      /// off the mounted tree at each widget rather than from a parameter — so a
      /// harness that stopped passing the flag reads `false` here and fails.
      ({bool atFlecks, bool atBackground, NeuralTier tier}) probe() {
        final BuildContext flecks = tester.element(find.byType(GoldFlecks));
        final BuildContext background = tester.element(
          find.byType(NeuralBackground),
        );
        return (
          atFlecks: MediaQuery.maybeDisableAnimationsOf(flecks) ?? false,
          atBackground:
              MediaQuery.maybeDisableAnimationsOf(background) ?? false,
          // The exact two arguments `NeuralBackground.build` passes, at the position
          // it passes them from. A literal `resolve(…, animationsEnabled: false)`
          // would assert the pure function against itself and survive the background
          // ceasing to read the flag.
          tier: NeuralTiers.resolve(
            size: MediaQuery.sizeOf(background),
            animationsEnabled:
                !(MediaQuery.maybeDisableAnimationsOf(background) ?? false),
            override: null,
          ),
        );
      }

      await runWith(disableAnimations: true);
      final ({bool atFlecks, bool atBackground, NeuralTier tier}) on = probe();
      expect(on.atFlecks, isTrue, reason: 'the flag reaches the flecks');
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
      final ({bool atFlecks, bool atBackground, NeuralTier tier}) off = probe();
      expect(off.atFlecks, isFalse, reason: 'the default call does not set it');
      expect(off.atBackground, isFalse);
      expect(
        off.tier,
        NeuralTier.mid,
        reason: 'the control that makes the `low` above mean something',
      );
    });

    testWidgets('the banner states the verdict, and the CTA moves on', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = await gradeTheAnsweredOption(tester);

      expect(find.byType(FeedbackBanner), findsOneWidget);
      // The verdict the **submission** reported, not one derived from the payload.
      // `contractSubmitAnswerFixture` says `is_correct: true`, so the banner reads
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
      expect(find.text(en.verdictCorrect), findsOneWidget);
      expect(find.text(en.verdictIncorrect), findsNothing);

      // `QuizScreen.tsx:127`'s `{checked ? 'Next question' : 'Check answer'}` — the
      // same button, relabelled. `checkAnswer` must be **gone**, because a screen
      // showing both is ambiguous about which press does what.
      expect(find.text(en.nextQuestion), findsOneWidget);
      expect(find.text(en.checkAnswer), findsNothing);
    });

    testWidgets('and the SEMANTICS tree carries the verdict the card colours '
        'carry', (WidgetTester tester) async {
      await gradeTheAnsweredOption(tester);

      final List<String> labels = <String>[
        for (final Element element in find.byType(QuizOptionCard).evaluate())
          tester.getSemantics(find.byWidget(element.widget)).label,
      ];
      expect(
        labels.where((String l) => l.contains(en.correctSuffix)),
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
    // builds the name out of `QuizStrings.optionLabel` — the letter, the text and the
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
            suffix: en.alreadyAnsweredSuffix,
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
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
        submission: defaultSubmission,
      );
      await mountQuiz(tester, bloc: bloc);
      await tester.tap(find.text(theAnsweredOption));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(en.checkAnswer));
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
      expect(find.text(en.alreadyAnsweredSuffix), findsNothing);

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
        expect(each.label, contains(en.alreadyAnsweredSuffix));
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
      // ## AND THE LABEL IS `nextQuestion`, WHICH IS THE PROTOTYPE'S OWN WORD
      //
      // `QuizScreen.tsx:127` labels every graded answer `Next question` and
      // `ds.tsx` disables it on `!checked && !selected`. An already-answered question
      // is `checked` as far as the server is concerned and `selected` as far as the
      // reader is concerned — so it is neither, and the label has to come from
      // somewhere. It comes from `checked`, which is false here, so the button says
      // `Check answer` and is **disabled**: the honest rendering, because "check
      // answer" is the only action this control can perform on this screen and there
      // is nothing to check.
      final QuizBloc bloc = quizBloc(
        Result<ScriptureText>.success(mixedQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      // The `next` arm, reached.
      expect(bloc.state.cta, QuizCta.next);

      // And the button is enabled, because advancing is possible — which is the
      // difference between this arm and the dead end two tests down.
      final Finder cta = find.byType(EvaButton);
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
      final Finder cta = find.byType(EvaButton);
      expect(cta, findsOneWidget);

      // ## AND ITS **VISIBLE** LABEL NAMES WHAT IS MISSING, NOT AN ACTION THIS
      // ## SCREEN CANNOT PERFORM
      //
      // This used to assert `find.text(en.checkAnswer)`, on the reasoning that
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
      expect(find.text(en.checkAnswer), findsNothing);
      expect(find.text(en.unavailableSuffix), findsOneWidget);

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
      expect(node.label, en.unavailableSuffix);
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
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
      );
      await mountQuiz(tester, bloc: bloc);

      expect(bloc.state.cta, QuizCta.none, reason: 'nothing selected');
      expect(bloc.state.currentAnswer!.isOpen, isTrue);

      expect(find.text(en.checkAnswer), findsOneWidget);
      expect(find.text(en.unavailableSuffix), findsNothing);
      expect(tester.getSemantics(find.byType(EvaButton)).label, en.checkAnswer);
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
    /// Drives one open question to graded, and returns the bloc.
    ///
    /// The same sequence as `gradeTheAnsweredOption`, reached through this group's own
    /// copy on purpose: that helper lives inside the group above and is not visible
    /// here, and duplicating four lines is cheaper than hoisting a fixture whose every
    /// other use asserts nothing about the frame it leaves behind.
    Future<QuizBloc> gradeToReadyOnTheLastQuestion(WidgetTester tester) async {
      final QuizBloc bloc = quizBloc(
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
        submission: defaultSubmission,
      );
      await mountQuiz(tester, bloc: bloc);
      await tester.tap(find.text(theAnsweredOption));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(en.checkAnswer));
      await pumpQuizFrames(tester, 6);
      return bloc;
    }

    /// The CTA's accessible name.
    ///
    /// Read off the `EvaButton` because that is the node `_Cta`'s `Semantics` labels,
    /// and `excludeSemantics` folds the button's own caption into it — so this is the
    /// string a screen reader announces, not the caption a sighted reader sees.
    String ctaAccessibleName(WidgetTester tester) =>
        tester.getSemantics(find.byType(EvaButton)).label;

    testWidgets('a LIVE cta does not claim there is no answer to show', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = await gradeToReadyOnTheLastQuestion(tester);

      // The precondition stated as an assertion, because the whole finding is that
      // the payload predicate and the CTA state disagree **on this frame**: every
      // question is answered *and* the button is live. If either stopped being true
      // the reason below would be absent for a reason that is not the one being fixed.
      expect(
        bloc.state.session!.answeredCount,
        bloc.state.session!.questionCount,
      );
      expect(bloc.state.cta, QuizCta.next);
      expect(
        tester
            .getSemantics(find.byType(EvaButton))
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
        ctaAccessibleName(tester),
        en.nextQuestion,
        reason:
            'the label is the prototype\'s own, with nothing appended. '
            '"${en.unavailableSuffix}" is a fact about a DEAD control and this '
            'control opens the graded answer',
      );
    });

    testWidgets('and the TERMINAL cta does not either', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = await gradeToReadyOnTheLastQuestion(tester);
      await tester.tap(find.text(en.nextQuestion));
      await pumpQuizFrames(tester, 6);

      expect(bloc.state.cta, QuizCta.finish);
      expect(
        tester
            .getSemantics(find.byType(EvaButton))
            .flagsCollection
            .isEnabled
            .toBoolOrNull(),
        isTrue,
      );
      expect(ctaAccessibleName(tester), en.seeResults);
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
