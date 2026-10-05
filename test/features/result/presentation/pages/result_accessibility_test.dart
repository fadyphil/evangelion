import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/result/presentation/result_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/quiz_harness.dart';

/// §14 for `/result`: no unlabeled interactive node, and no state carried by colour alone.
///
/// ## WHY THIS FILE EXISTS
///
/// `09-quality-gates.md` §14's target is "all 6 pages pass a semantics sweep with no
/// unlabeled interactive node". `login`, `/`, `/reading` and (as of Phase 10) `/quiz`
/// have a `*_accessibility_test.dart` whose first group is that sweep over the page's
/// whole semantics tree. `/result` had **no** such file after Phase 9 — so four of six
/// pages, and the sentence could not be claimed for the app.
///
/// `result_page_test.dart` does assert semantics: that the burst is decorative, that
/// the flame is not named twice, and that both buttons are live. None of those is the
/// sweep, and none of them can become it — they each look at one node the test already
/// knows about, which is the hand-written-list shape `login_accessibility_test.dart`
/// records as the thing that has to be extended by hand whenever a widget changes.
///
/// ## AND `/result` HAS A PROPERTY THAT MAKES THE SWEEP WORTH HAVING
///
/// It is the **one screen with no state machine**. `SubmitResult` is a required
/// constructor parameter, so there is no loading, no failure, no empty state and no
/// disabled control to sweep — `ResultPage`'s doc says so and says why. That means the
/// whole of §14's surface here is *two buttons and some numbers*, and the sweep's value
/// is that it will say so the first time a third control appears without a name. The
/// test below asserts the count as well as the names precisely so that adding a control
/// is a deliberate act rather than an accident: a fourth `EvaButton` with no label
/// would still pass "every tappable is named", and fail "there are exactly two".
void main() {
  final AppLocalizations strings = AppLocalizationsEn();

  /// A complete response with recognisable numbers, so nothing on screen is blank.
  ///
  /// The two stat tiles draw [SubmitResult.pointsEarned] and
  /// [SubmitResult.longestStreak], and a `StatTile` with an empty value renders nothing —
  /// which would make "no unlabeled node" vacuous in a way that is easy to miss.
  const SubmitResult aResult = SubmitResult(
    questionId: 'question-group-3',
    isCorrect: true,
    pointsEarned: 10,
    currentTotalPoints: 120,
    currentStreak: 12,
    longestStreak: 30,
    readingCompleted: true,
  );

  group('no unlabeled interactive node', () {
    testWidgets('every node offering an action has a non-empty label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpResult(tester, result: aResult);

      // The whole tree, not a list of controls this file knows about —
      // `login_accessibility_test.dart` gives the argument. `semanticsTree` fails
      // closed when semantics are off, so "nothing to check" is a failure rather than
      // a pass.
      final List<SemanticsData> tappable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );

      expect(
        tappable,
        isNotEmpty,
        reason:
            'the screen has two buttons; an empty list means the walk saw '
            'nothing, which would make the loop below vacuously true',
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

      expect(
        tappable,
        hasLength(2),
        reason:
            'and there are exactly **two**. `/result` has no state machine — '
            '`SubmitResult` is a required constructor parameter — so every control on '
            'it is one of the two CTAs. A third `EvaButton` with a name would still '
            'pass the sweep above, so this is what makes adding one deliberate.',
      );

      handle.dispose();
    });

    testWidgets('and the two are the prototype\'s own labels', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpResult(tester, result: aResult);

      expect(find.bySemanticsLabel(strings.resultReflectAgain), findsOneWidget);
      expect(find.bySemanticsLabel(strings.resultBackHome), findsOneWidget);
      // `result_page_test.dart` records the transcription: the prototype's label was
      // `Back to library` and there IS no library (§2 decision 1 cut it), so the
      // label names where the button actually goes. Asserted here as well as there
      // because this is the file that owns "every control on this screen is named".
      expect(
        find.bySemanticsLabel('Back to library'),
        findsNothing,
        reason: 'the destination does not exist, so neither does the label',
      );

      handle.dispose();
    });
  });

  group('§14 — nothing on this screen is carried by colour alone', () {
    testWidgets('the verdict is in a sentence, not in a hue', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      // Both arms, because "right, and the reading is finished" and "right, and there
      // is more to do" are two different sentences and a colour would be one.
      for (final (String name, SubmitResult result) case_
          in <(String, SubmitResult)>[
            ('the finished reading', aResult),
            (
              'the unfinished one',
              SubmitResult(
                questionId: aResult.questionId,
                isCorrect: true,
                pointsEarned: aResult.pointsEarned,
                currentTotalPoints: aResult.currentTotalPoints,
                currentStreak: aResult.currentStreak,
                longestStreak: aResult.longestStreak,
                readingCompleted: false,
              ),
            ),
          ]) {
        await pumpResult(tester, result: case_.$2);

        expect(
          find.text(
            case_.$2.readingCompleted
                ? strings.resultCompleteMessage
                : strings.resultPartialMessage,
          ),
          findsOneWidget,
          reason:
              '${case_.$1}: the headline is the sentence that carries the state, and '
              'it is text rather than a colour. `SubmitResult` carries `is_correct` '
              'AND `reading_completed` precisely so this screen can say which.',
        );
      }

      handle.dispose();
    });

    testWidgets('the streak pill is a label with a number in it', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpResult(tester, result: aResult);

      // **Decision 22, extended — and this is the carried-over control.** The pill
      // draws `SubmitResult.currentStreak`, which is the *third* copy of that field
      // in this app. A sweep that touched the pill's label, or a semantics pass that
      // relabelled it, is exactly the edit that would break it: the assertion below is
      // that the number on screen is **this response's** and not the other two
      // endpoints' values, which the page cannot read at all.
      // The whole composed label, **not** the noun on its own.
      // `ResultStringsPhrases.streakLabelFor` builds `$resultDay $digits(current)` and
      // appends ` — $resultLongestYet` when `current >= longest` and is non-zero — so
      // `find.text(resultDay)` matches nothing on either arm, and an earlier version of
      // this test failed with `Found 0 widgets with text "Day"` for exactly that
      // reason. Asserting the noun alone would also have been a weaker claim: it would
      // pass on a pill that lost its number.
      expect(
        find.text(
          AppLocalizationsEn().streakLabelFor(
            current: aResult.currentStreak,
            longest: aResult.longestStreak,
          ),
        ),
        findsOneWidget,
        reason:
            'the pill is a label **with a number in it**, drawn from this response '
            'and composed by the feature\'s own derivation rather than restated '
            'here',
      );

      // The flame is decorative and `result_page_test.dart` holds that; re-asserted
      // here because the sweep is the file that claims nothing on this screen is
      // missed, and a second unlabelled node would be invisible to a name check.
      expect(find.byType(StreakFlame), findsOneWidget);
      expect(
        find.bySemanticsLabel('Streak'),
        findsNothing,
        reason: 'the pill already carries the streak, so the flame adds no second name',
      );

      handle.dispose();
    });
  });

  group('the Arabic arm names the same things in Arabic', () {
    testWidgets('both controls and the headline', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpResult(tester, result: aResult, locale: const Locale('ar'));

      final AppLocalizations ar = AppLocalizationsAr();
      expect(find.bySemanticsLabel(ar.resultReflectAgain), findsOneWidget);
      expect(find.bySemanticsLabel(ar.resultBackHome), findsOneWidget);
      // The failure this is guarding is the `EvaToggle` class of bug — a name that is
      // true in one arm and a transliteration or an English leftover in the other —
      // which `app_localizations_test.dart` catches in the ARB and this catches on the
      // screen.
      expect(
        find.bySemanticsLabel(strings.resultReflectAgain),
        findsNothing,
        reason: 'the English label must not survive into the Arabic arm',
      );
      expect(find.text(ar.resultCompleteMessage), findsOneWidget);

      handle.dispose();
    });
  });
}
