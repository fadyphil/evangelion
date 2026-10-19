/// §14: "text scales to 1.22× without overflow at 320px width" — for `/quiz`.
///
/// ## WHY THIS FILE EXISTS, GIVEN THE REVIEW ALREADY MEASURED IT
///
/// The review verified by hand that `/quiz` throws on neither arm at 320×568 @
/// 1.22×. **A manual verification is not a gate.** `login_text_scale_test.dart`,
/// `home_text_scale_test.dart` and `reading_text_scale_test.dart` all assert the same
/// requirement for their screens, and `/quiz` and `/result` were the only two of the
/// six without one — which means §14's standing clause was, for these two screens, a
/// claim in a doc comment and nothing else.
///
/// ## AND THE VERDICT SURFACE MOVED WITH THE REDESIGN
///
/// The old screen added a `FeedbackBanner` after a check; `eva/redesign.html:562-574`
/// has no banner. The verdict is the **card's own state** (`:350-359`), so the
/// graded layout below scrolls a `QuizOptionState.correct` card into view instead.
/// The claim is the same one — the tallest addition is reachable, not dropped — and
/// the instrument moved with the widget that carries it.
///
/// That is the same defect class as the four doc comments this phase pointed at
/// geometry suites that did not exist: a reader follows the pointer and finds a gap.
///
/// ## BOTH NUMBERS COME FROM THE DOCUMENT AND NEITHER IS NEGOTIABLE
///
/// `kNarrowSurface` is `Size(320, 568)` and `kEvaRequiredTextScale` is `1.22`, both
/// declared in `design_system_harness.dart` and both quoted from §14. They are used
/// rather than repeated so this file cannot drift from its four siblings.
///
/// ## AND EVERY STATE IS MOUNTED, BECAUSE A LAYOUT IS NOT ONE THING
///
/// `/quiz` has several layouts that are not each other's mirror: the **ready** screen
/// (progress label, prompt, four options, CTA), the screen **after a check**, whose
/// verdict is the graded card's own state, the **dead end**, whose button label is a
/// whole sentence after decision 91, and the **empty** session. Arabic is separate
/// again — script height and the `٤٠`-style numerals are not the LTR arm's metrics.
///
/// ## AND THE FOURTH OPTION IS BUILT, ONE DRAG FROM BEING TAPPABLE
///
/// The question and its options live in an `Expanded(child: CustomScrollView(…))`
/// (`quiz_page.dart`'s `SliverFillRemaining`, with the reason written there: at
/// 320×568 with 1.22× text a five-verse day's question plus its options does not fit,
/// and §13 rule 5 forbids a `Column` over unbounded content). The **measured**
/// result at this fixture is that the fourth option is **built** on the first frame
/// — it is part of the sliver's single `Column`, not a lazily-built list child, so
/// `find.text` sees it — but its centre sits below the viewport and it is not
/// hit-testable until the body scrolls. The test below asserts exactly that pair:
/// built (nothing dropped), then `ensureVisible` (a finger can reach it).
///
/// The graded card is onstage **and** hit-testable with no scroll, so its test
/// asserts that directly and then drags to prove the verdict is not conditional on
/// a settled viewport.
///
/// **Which makes "no exception" a weak assertion on its own**, so each graded case
/// below also names the graded card and asserts it is reachable. A gate that only
/// checked for exceptions would pass on a screen that silently lost its verdict — and
/// the review's own manual check, which looked for throws, would have passed on
/// exactly that.
library;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/quiz_harness.dart';
import '../../../../support/reading_harness.dart';

void main() {
  const Size surface = kNarrowSurface;
  const double scale = kEvaRequiredTextScale;

  group('at 320x568 and 1.22x, no state overflows', () {
    testWidgets('ready, English', (WidgetTester tester) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
        ),
        size: surface,
        textScale: scale,
      );

      _expectNoOverflow(tester, screen: 'ready (en)');
      // The visible part of the question, and the CTA beside it.
      expect(find.byType(QuizOptionCard), findsWidgets);
      expect(find.text(AppLocalizationsEn().quizCheckAnswer), findsOneWidget);
    });

    testWidgets('ready, Arabic — a taller script for the same box', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Right<Failure, ScriptureText>(liveArabicQuizPassage),
        ),
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      _expectNoOverflow(tester, screen: 'ready (ar)');
    });

    testWidgets('and the fourth option is built and one scroll away', (
      WidgetTester tester,
    ) async {
      // The falsifying shape for the library doc's claim: the `D` card is **built**
      // from the first frame, so a lazy-list regression that dropped it would fail
      // here — and it is not reachable by a finger until the body scrolls, which a
      // test that only counted `QuizOptionCard`s would never notice.
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
        ),
        size: surface,
        textScale: scale,
      );

      final Finder fourth = find.text('Lazarus');
      expect(fourth, findsOneWidget, reason: 'built, so nothing was dropped');

      await tester.ensureVisible(fourth);
      await pumpQuizFrames(tester, 4);

      expect(
        fourth.hitTestable(),
        findsOneWidget,
        reason: 'the fourth option is reachable by a finger once scrolled into view',
      );
      _expectNoOverflow(tester, screen: 'ready (en), scrolled');
    });

    testWidgets('after a CHECK the graded card is reachable, not dropped', (
      WidgetTester tester,
    ) async {
      // **Events, not taps.** At 320x568 the content scrolls and a tap on the CTA can
      // miss, depending on where the pointer's hit test lands. This file is about
      // **layout**, and driving the bloc is what lets the graded layout be measured
      // at all; the tap path is `quiz_page_test.dart`'s subject at the default
      // surface.
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
        submission: defaultSubmission,
      );
      await pumpQuiz(tester, bloc: bloc, size: surface, textScale: scale);

      bloc.add(const QuizOptionSelected('A'));
      await pumpQuizFrames(tester, 2);
      bloc.add(const QuizAnswerChecked());
      await pumpQuizFrames(tester, 6);

      /// The card that carries the check's verdict.
      Finder gradedCard() => find.byWidgetPredicate(
        (Widget widget) =>
            widget is QuizOptionCard && widget.state == QuizOptionState.correct,
      );

      // The verdict is the screen's tallest single addition and it is painted on the
      // graded frame, not deferred until a scroll.
      expect(
        gradedCard(),
        findsOneWidget,
        reason: 'the graded card is onstage',
      );
      expect(
        gradedCard().hitTestable(),
        findsOneWidget,
        reason: 'the verdict is reachable by a finger, not merely built',
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await pumpQuizFrames(tester, 4);

      expect(
        gradedCard(),
        findsOneWidget,
        reason:
            'the verdict survives a scroll. A gate that only checked for exceptions '
            'would pass on a screen that had quietly lost it',
      );
      _expectNoOverflow(tester, screen: 'graded (en)');
    });

    testWidgets('after a check, Arabic', (WidgetTester tester) async {
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveArabicQuizPassage),
        submission: defaultSubmission,
      );
      await pumpQuiz(
        tester,
        bloc: bloc,
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      bloc.add(const QuizOptionSelected('A'));
      await pumpQuizFrames(tester, 2);
      bloc.add(const QuizAnswerChecked());
      await pumpQuizFrames(tester, 6);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await pumpQuizFrames(tester, 4);

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is QuizOptionCard &&
              widget.state == QuizOptionState.correct,
        ),
        findsOneWidget,
      );
      _expectNoOverflow(tester, screen: 'graded (ar)');
    });

    testWidgets(
      'the DEAD END, whose label is the longest string on the screen',
      (WidgetTester tester) async {
        // Decision 91 put `unavailableSuffix` on the **caption**, so this state now
        // carries a sentence where every other state's button carries one word — and a
        // sentence is what wraps. This test is why that change needed one.
        await pumpQuiz(
          tester,
          bloc: quizBloc(
            Result<ScriptureText>.of(
              englishPassageWith(<Question>[answeredQuestion]),
            ),
          ),
          size: surface,
          textScale: scale,
        );

        expect(
          find.text(AppLocalizationsEn().quizUnavailableSuffix),
          findsOneWidget,
        );
        _expectNoOverflow(tester, screen: 'dead end (en)');
      },
    );

    testWidgets('the DEAD END in Arabic, whose numerals are the other arm\'s', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          Result<ScriptureText>.of(
            arabicPassageWith(<Question>[answeredQuestion]),
          ),
        ),
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      expect(
        find.text(AppLocalizationsAr().quizUnavailableSuffix),
        findsOneWidget,
      );
      _expectNoOverflow(tester, screen: 'dead end (ar)');
    });

    testWidgets('the EMPTY session — no question, no options', (
      WidgetTester tester,
    ) async {
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Right<Failure, ScriptureText>(
            // `questions: []` **maps**, so this is reachable: recorded decision 50
            // skips an unreadable question rather than refusing the passage.
            ScriptureText(
              readingId: 'reading-group-3-2026-10-04',
              groupId: 3,
              scheduledDate: '2026-10-04',
              language: ReadingLanguage.english,
              reference: 'John 3:1-5',
              translation: 'NKJV',
              verses: <Verse>[firstVerse],
              questions: <Question>[],
              isFullyCompleted: false,
              pointsEarnedToday: 0,
              currentStreak: 4,
            ),
          ),
        ),
        size: surface,
        textScale: scale,
      );

      expect(find.byType(QuizPage), findsOneWidget);
      _expectNoOverflow(tester, screen: 'empty (en)');
    });
  });

  group('and the Arabic arm is RTL, not a mirrored LTR', () {
    testWidgets('the content resolves to RTL', (WidgetTester tester) async {
      // §14's RTL row, and the falsifying shape is a screen that renders Arabic
      // left-to-right — which looks *almost* right and is why `pumpQuiz`'s
      // `textDirection` is derived from `locale` rather than left to its default.
      await pumpQuiz(
        tester,
        bloc: quizBloc(
          const Right<Failure, ScriptureText>(liveArabicQuizPassage),
        ),
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      final Finder prompt = find.text(liveArabicQuestion.prompt);
      expect(prompt, findsOneWidget);
      expect(Directionality.of(tester.element(prompt)), TextDirection.rtl);
    });
  });
}

/// Asserts that nothing in the tree reported an overflow, and that the screen drew
/// something.
///
/// **[WidgetTester.takeException] is null, and that is the mechanism.** A
/// `RenderFlex` overflow is reported as a Flutter error, which the test binding
/// records and rethrows — so `takeException` returning `null` is the assertion. The
/// second half is the anti-vacuity check the other four suites carry: a screen that
/// rendered nothing cannot overflow, so "no exception" alone would pass for a blank
/// frame.
void _expectNoOverflow(WidgetTester tester, {required String screen}) {
  expect(
    tester.takeException(),
    isNull,
    reason: '§14 at ${kNarrowSurface.width}px and 1.22× — $screen',
  );
  expect(
    find.byType(QuizPage),
    findsOneWidget,
    reason: 'the page rendered, so "no overflow" is not vacuous',
  );
}
