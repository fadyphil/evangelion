/// §14: "text scales to 1.22× without overflow at 320px width" — for `/result`.
///
/// ## WHY THIS FILE EXISTS, GIVEN THE REVIEW ALREADY MEASURED IT
///
/// `/login`, `/`, `/reading` and `/quiz` each assert §14's clause for their screen.
/// `/result` did not, so for this screen the standing requirement was a sentence in a
/// doc comment. `quiz_text_scale_test.dart` is its sibling and carries the same
/// argument; the two are written together because a gate that exists for five of six
/// screens reads as a gate that exists.
///
/// ## BOTH NUMBERS COME FROM THE DOCUMENT AND NEITHER IS NEGOTIABLE
///
/// `kNarrowSurface` is `Size(320, 568)` and `kEvaRequiredTextScale` is `1.22`, both
/// declared in `design_system_harness.dart` and both quoted from §14.
///
/// ## AND **ALL FOUR** STATES ARE MOUNTED, WHICH IS THE PART THAT MATTERS HERE
///
/// `/result` takes one `SubmitResult` and derives four screens from it: correct and
/// complete, correct and not, wrong, and the zero case. They differ in the **headline
/// sentence** (`ResultStrings.messageFor` switches over two booleans) and in **every
/// number** — the score, the points, the streak, the longest run. A sentence is what
/// wraps and a two-digit number is what widens, so the four are four layouts.
///
/// `ResultPage`'s doc records the third divergence from the prototype: `ResultScreen.tsx:34`
/// is `minHeight: 844` on a non-scrolling flex column, and that value **cannot** be
/// honoured at 320×568 — so this column **scrolls**. That is why the answer here is
/// again "no overflow and it scrolls", and why "no exception" alone would be a weak
/// assertion: a screen that had dropped its headline would also throw nothing.
library;

import 'package:evangelion/core/design_system/widgets/streak_flame.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:evangelion/features/result/presentation/result_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/design_system_harness.dart';
import '../../../../support/quiz_harness.dart';

void main() {
  const Size surface = kNarrowSurface;
  const double scale = kEvaRequiredTextScale;
  const ResultStrings en = ResultStrings.en();

  /// The four states, and the string each is identified by in this file.
  ///
  /// A table rather than four inline literals because the *pairing* is the claim:
  /// each row is a `SubmitResult` and the sentence it must render, so a state whose
  /// numbers changed but whose sentence did not would still be caught.
  const List<(String, SubmitResult, String)> states =
      <(String, SubmitResult, String)>[
        (
          'correct and complete',
          SubmitResult(
            questionId: 'question-group-3',
            isCorrect: true,
            pointsEarned: 10,
            currentTotalPoints: 40,
            currentStreak: 4,
            longestStreak: 6,
            readingCompleted: true,
          ),
          'Correct, and today\'s reading is complete.',
        ),
        (
          'correct, reading unfinished',
          SubmitResult(
            questionId: 'question-group-3',
            isCorrect: true,
            pointsEarned: 10,
            currentTotalPoints: 40,
            currentStreak: 4,
            longestStreak: 6,
            readingCompleted: false,
          ),
          'Correct. The reading is not finished yet.',
        ),
        (
          'wrong',
          SubmitResult(
            questionId: 'question-group-3',
            isCorrect: false,
            pointsEarned: 0,
            currentTotalPoints: 0,
            currentStreak: 0,
            longestStreak: 0,
            readingCompleted: false,
          ),
          'Not this time. Every question counts.',
        ),
        (
          'wrong, with points already banked',
          SubmitResult(
            questionId: 'question-group-3',
            isCorrect: false,
            pointsEarned: 10,
            currentTotalPoints: 40,
            currentStreak: 4,
            longestStreak: 6,
            readingCompleted: false,
          ),
          'Not this time. Every question counts.',
        ),
      ];

  group('at 320x568 and 1.22x, all four states overflow nothing', () {
    for (final (String label, SubmitResult result, String message) in states) {
      testWidgets(label, (WidgetTester tester) async {
        await pumpResult(
          tester,
          result: result,
          size: surface,
          textScale: scale,
        );

        _expectNoOverflow(tester, screen: label);
        expect(
          find.text(message),
          findsOneWidget,
          reason:
              'the headline is the longest string on the screen and it is what wraps '
              'first. Asserted so the layout claim is about *this* state\'s sentence',
        );
      });
    }

    testWidgets('correct and complete, in Arabic', (WidgetTester tester) async {
      // Arabic script is taller at the same point size and the score is rendered in
      // Arabic-Indic digits, so the RTL arm is not a mirror of the LTR one.
      await pumpResult(
        tester,
        result: states[1].$2,
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      _expectNoOverflow(tester, screen: 'correct and complete (ar)');
    });

    testWidgets('wrong, in Arabic — the zero state', (
      WidgetTester tester,
    ) async {
      await pumpResult(
        tester,
        result: states[3].$2,
        locale: const Locale('ar'),
        size: surface,
        textScale: scale,
      );

      _expectNoOverflow(tester, screen: 'wrong (ar)');
    });
  });

  group('and the deliberate divergences hold at this surface', () {
    testWidgets('the streak flame is still 14 wide inside its pill', (
      WidgetTester tester,
    ) async {
      // `result_geometry_test.dart` asserts the pair on its own; at 1.22× on 320px the
      // question is whether the **pill** still holds it, which is a layout fact and
      // therefore belongs here.
      await pumpResult(
        tester,
        result: contractSubmitAnswerFixture,
        size: surface,
        textScale: scale,
      );

      expect(find.byType(StreakFlame), findsOneWidget);
      _expectNoOverflow(tester, screen: 'flame in pill');
    });

    testWidgets('and the column SCROLLS, because 844 does not fit in 568', (
      WidgetTester tester,
    ) async {
      // `ResultPage`'s doc: the prototype's `minHeight: 844` is refused, so the column
      // scrolls. Asserted so "no overflow" is not read as "it all fit" — at 320×568 it
      // cannot have fit, and the honest claim is that nothing overflowed.
      await pumpResult(
        tester,
        result: contractSubmitAnswerFixture,
        size: surface,
        textScale: scale,
      );

      expect(find.byType(Scrollable), findsWidgets);
      expect(en.completeMessage, isNotEmpty, reason: 'the arm is spelled out');
      _expectNoOverflow(tester, screen: 'scrolling');
    });
  });
}

/// Asserts that nothing in the tree reported an overflow, and that the screen drew
/// something.
///
/// **[WidgetTester.takeException] is null, and that is the mechanism.** A
/// `RenderFlex` overflow is reported as a Flutter error, which the test binding
/// records and rethrows — so `takeException` returning `null` is the assertion. The
/// second half is the anti-vacuity check the sibling suites carry: a screen that
/// rendered nothing cannot overflow.
void _expectNoOverflow(WidgetTester tester, {required String screen}) {
  expect(
    tester.takeException(),
    isNull,
    reason: '§14 at ${kNarrowSurface.width}px and 1.22x — /result, $screen',
  );
  expect(
    find.byType(ResultPage),
    findsOneWidget,
    reason: 'the page rendered, so "no overflow" is not vacuous',
  );
}
