import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/presentation/result_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/result_sheet.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/quiz_harness.dart';

/// The result **card** — and the extension of recorded decision 22 it is.
///
/// ## IT IS A **CARD OVER THE QUIZ**, NOT A SCREEN
///
/// `/result` retired to a modal in Phase 6 (the redesign's card over a veil,
/// `eva/redesign.html:718-727`), so there is no result *page* any more. The
/// screen's content is the client's own and it is all still here: the score,
/// the caption, the three messages, the streak pill, the two stat tiles and the
/// two CTAs. **What changed is the surface**, and these tests are about the
/// content, so they moved with it.
///
/// ## THE STREAK ON THIS CARD IS **THE SUBMIT RESPONSE'S**, AND THESE TESTS ARE
/// ## THE WHOLE OF THE EXTENSION
///
/// §5 trap 8 measures `current_streak` appearing in **two** places and disagreeing
/// with itself: `readings/today` says `4`, `streak/summary` says `0`, for the same
/// reader on the same day. Recorded decision 22 resolved that by never reconciling
/// them — each field comes from the endpoint whose job it is.
///
/// Phase 8 adds a **third** copy, on `SubmitResult`, and this card draws it. The
/// reason is §5 trap 4: the streak fields only move when `reading_completed` is
/// true, so this number was written **by the submission the reader just made**,
/// while `/`'s two were written by a read. It is an **extension** of decision 22 and
/// not a replacement — `/` still reads `StreakSummary.currentStreak` and still
/// reconciles nothing.
///
/// ## AND THE FIXTURE IS A **SENTINEL**, BECAUSE THE OTHER TWO VALUES COINCIDE
///
/// The live `SubmitResult` transcription carries `current_streak: 4`, which is also
/// `readings/today`'s value. A test asserting `find.text('4')` would therefore pass
/// against a card reading the **wrong** field, because the two agree — the same
/// shape recorded decision 33 found for `AppTopBar`'s wordmark, where the
/// prototype's literal and the shipped value were the same string.
///
/// So the fixture is built with `77`, which is **neither** `4` nor `0`, and the
/// tests assert the sentinel is on screen and **both** live values are not.
/// A graded answer whose numbers are **sentinels**: nothing else in this
/// repository is `1234`, `77` or `90`.
///
/// **Top-level, not a local in `main`,** because the three helpers at the foot of
/// this file read it and a local would be out of their scope — the first draft had
/// it local and the file did not compile.
const SubmitResult aSentinelResult = SubmitResult(
  questionId: 'question-group-3',
  isCorrect: true,
  pointsEarned: 10,
  currentTotalPoints: 1234,
  // **Not** `4` and **not** `0` — §5's two live values. See the library doc.
  currentStreak: 77,
  longestStreak: 90,
  readingCompleted: true,
);

void main() {
  group('the streak is the SUBMIT RESPONSE\'s — decision 22, extended', () {
    testWidgets('and the sentinel is the number on screen', (
      WidgetTester tester,
    ) async {
      await pumpResult(tester, result: aSentinelResult);

      // The pill reads `Day 77 — your longest yet`, because `77 < 90` is false and
      // the reader is therefore at their best. **One** `77`.
      expect(find.textContaining('77'), findsOneWidget);
    });

    testWidgets('and **neither** of §5\'s two live values reaches the screen', (
      WidgetTester tester,
    ) async {
      // **The control.** Asserting the sentinel is present says "this field is read";
      // asserting `0` and `4` are **absent** says "**not those two**", which is the
      // extension's actual claim — that this screen does not read `streak/summary` or
      // `readings/today`. A page that grew a port would show `0`; a page that read the
      // reading payload would show `4`. Both are red here.
      await pumpResult(tester, result: aSentinelResult);

      expect(
        find.text('0'),
        findsNothing,
        reason: '`streak/summary.current_streak`',
      );
      expect(
        find.text('4'),
        findsNothing,
        reason: '`readings/today.current_streak`',
      );
    });

    testWidgets('and the FIXTURE is not one of those two values', (
      WidgetTester tester,
    ) async {
      // The falsifying-direction half of the pair above. Without it, the two
      // assertions could both pass against a screen that printed nothing — which is
      // decision 21's "the control" and Phase 6's C1 in the same shape.
      expect(aSentinelResult.currentStreak, isNot(4));
      expect(aSentinelResult.currentStreak, isNot(0));
      await pumpResult(tester, result: aSentinelResult);
      expect(
        find.textContaining('${aSentinelResult.currentStreak}'),
        findsOneWidget,
      );
    });

    testWidgets(
      '"your longest yet" appears only when the reader is AT their best',
      (WidgetTester tester) async {
        final AppLocalizations strings = AppLocalizationsEn();

        // Behind the record.
        await pumpResult(tester, result: aSentinelResult);
        expect(find.textContaining(strings.resultLongestYet), findsNothing);
        expect(
          find.text(strings.streakLabelFor(current: 77, longest: 90)),
          findsOneWidget,
        );

        // **On** the record: `>=` is what says so.
        await pumpResult(tester, result: _withStreak(current: 90, longest: 90));
        expect(find.textContaining(strings.resultLongestYet), findsOneWidget);

        // **Ahead** of it: a reader who has just extended their run by one is the case
        // the sentence is most true of, and `==` would say nothing.
        await pumpResult(tester, result: _withStreak(current: 91, longest: 90));
        expect(find.textContaining(strings.resultLongestYet), findsOneWidget);
      },
    );

    testWidgets('and a streak of ZERO never claims it', (
      WidgetTester tester,
    ) async {
      // `0 >= 0` is true, and "Day 0 — your longest yet" is a sentence about a reader
      // who has not started.
      final AppLocalizations strings = AppLocalizationsEn();
      await pumpResult(tester, result: _withStreak(current: 0, longest: 0));
      expect(find.textContaining(strings.resultLongestYet), findsNothing);
      expect(
        find.text(strings.streakLabelFor(current: 0, longest: 0)),
        findsOneWidget,
      );
    });
  });

  group('the headline, and the denominator that is **not** there', () {
    testWidgets('the running total is the figure, and there is no `/n`', (
      WidgetTester tester,
    ) async {
      await pumpResult(tester, result: aSentinelResult);

      // `ResultScreen.tsx:44-45` is `4` beside `/5`; the `5` is a hard-coded literal
      // and `SubmitResult` carries no question count. So the figure is the total and
      // the denominator is **gone** rather than invented — decision 45's rejected
      // "derive a measurement" at its largest.
      //
      // **`findsOneWidget`, not `findsWidgets`** — and the first draft said
      // `findsOneWidget` and failed with **two** matches, because the stat row also
      // drew `currentTotalPoints`. That is how the third tile became a duplicate and
      // then a two-tile row: see `_StatRow`'s doc.
      expect(find.text('1234'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
      // The **answer's** score is a separate tile, not the headline.
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets(
      'the prototype\'s `Read` / `Reflected` labels are NOT on screen',
      (WidgetTester tester) async {
        await pumpResult(tester, result: aSentinelResult);

        // §2 decision 1 cut the profile, and no endpoint in this backend returns
        // days-read or reflections-so-far. Shipping the prototype's three tiles would
        // mean inventing three numbers a reader would read as facts about their own
        // history.
        for (final String label in <String>['Read', 'Reflected']) {
          expect(
            find.text(label.toUpperCase()),
            findsNothing,
            reason:
                '`$label` is a profile-history figure this client cannot fetch',
          );
        }
        // …and the **written** two are, and there are **two** tiles, not three.
        final AppLocalizations strings = AppLocalizationsEn();
        expect(
          find.text(strings.resultThisAnswer.toUpperCase()),
          findsOneWidget,
        );
        expect(find.text(strings.resultBestRun.toUpperCase()), findsOneWidget);
        expect(find.byType(StatTile), findsNWidgets(2));
      },
    );

    testWidgets('and no tile repeats the headline\'s own figure', (
      WidgetTester tester,
    ) async {
      // ## A DUPLICATION CHECK, NOT A COUNT CHECK, AND THE DIFFERENCE IS THE POINT
      //
      // `findsNWidgets(2)` above passes on a screen that kept three tiles and merged
      // two of them into one widget, and it says nothing at all about *which* two.
      // The defect `_StatRow` actually had was a third tile carrying
      // `currentTotalPoints` — the number already in the headline, one line above, in
      // Arabic-Indic digits on the Arabic arm.
      //
      // So the assertion is on the **identity of the values**: read every `StatTile`'s
      // value widget off the tree and require that the headline's figure is not among
      // them. That catches the duplicate whether it arrives as a third tile, as a
      // fourth, or as a value swapped into one of the two that were already there.
      await pumpResult(tester, result: aSentinelResult);

      const String headline = '1234';
      // `.first`, because a `StatTile` draws **two** `Text`s — the value over the
      // caption — and `tester.widget` on a two-element finder throws
      // `Bad state: Too many elements`. The value is first in `StatTile.build`'s
      // `Column`, which is the document order the tree preserves, so `.first` is the
      // value and `.last` is the caption. Asserting on the caption instead would be a
      // comparison against `THIS ANSWER` / `BEST RUN`, which the test above already
      // covers and which would pass on a duplicated headline.
      final List<String> tileValues = <String>[
        for (final StatTile tile in tester.widgetList<StatTile>(
          find.byType(StatTile),
        ))
          tester
              .widget<Text>(
                find
                    .descendant(
                      of: find.byWidget(tile),
                      matching: find.byType(Text),
                    )
                    .first,
              )
              .data!,
      ];

      expect(tileValues, hasLength(2));
      expect(
        tileValues,
        isNot(contains(headline)),
        reason:
            'the headline already says $headline. A tile saying it again is the '
            'duplication that turned this row from three tiles into two.',
      );
      // And positively: the two tiles carry the two figures the response gives that
      // the headline does not. Asserted so the check above cannot pass by both tiles
      // being blank.
      expect(tileValues, containsAll(<String>['10', '90']));
    });

    testWidgets('`longest_streak` is a tile and `current_streak` is the pill', (
      WidgetTester tester,
    ) async {
      // The split is deliberate: the pill is the **current** streak with its
      // comparison, and the second tile is the **best run**. So `90` and `77` are
      // both on screen, in different roles, and neither is doing the other's job.
      await pumpResult(tester, result: aSentinelResult);
      expect(find.text('90'), findsOneWidget);
      expect(find.textContaining('77'), findsOneWidget);
    });
  });

  group('the headline sentence, and its three states', () {
    testWidgets('right and finished, right and not, and wrong', (
      WidgetTester tester,
    ) async {
      final AppLocalizations strings = AppLocalizationsEn();

      for (final (SubmitResult, String) row in <(SubmitResult, String)>[
        (aSentinelResult, strings.resultCompleteMessage),
        (_withReadingCompleted(false), strings.resultPartialMessage),
        (contractWrongAnswerFixture, strings.resultIncorrectMessage),
      ]) {
        await pumpResult(tester, result: row.$1);
        expect(find.text(row.$2), findsOneWidget);
        // **Only the three sentences**, not every field: `reflectAgain` is a button
        // label and is on screen in all three states.
        for (final String other in <String>[
          strings.resultCompleteMessage,
          strings.resultPartialMessage,
          strings.resultIncorrectMessage,
        ]) {
          if (other == row.$2) continue;
          expect(
            find.text(other),
            findsNothing,
            reason: 'only the sentence for THIS state is on screen',
          );
        }
      }
    });
  });

  group('the buttons', () {
    testWidgets('the primary says `Reflect again`, the secondary says `Back`', (
      WidgetTester tester,
    ) async {
      // **`Back`, not `Back to library`.** `ResultScreen.tsx:78` writes the latter and
      // §2 decision 1 cut the library; the destination is `/`. Transcribing the label
      // would be a lie about where the button leads.
      final AppLocalizations strings = AppLocalizationsEn();
      await pumpResult(tester, result: aSentinelResult);

      expect(find.text(strings.resultReflectAgain), findsOneWidget);
      expect(find.text(strings.resultBackHome), findsOneWidget);
      expect(find.textContaining('library'), findsNothing);
      expect(find.byType(EvaButton), findsNWidgets(2));
    });

    testWidgets('and both are enabled', (WidgetTester tester) async {
      // The dead-CTA problem `/quiz` has is **not** the card's: the card is
      // built only with a graded answer in hand, so there is nothing to
      // disable.
      await pumpResult(tester, result: aSentinelResult);
      for (final EvaButton button in tester.widgetList<EvaButton>(
        find.byType(EvaButton),
      )) {
        expect(button.onPressed, isNotNull, reason: button.label);
      }
    });
  });

  group('the widget tree', () {
    testWidgets('the burst is decorative and the flame is not named twice', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpResult(tester, result: aSentinelResult);

      // `SunBurst`'s own doc says it is `ExcludeSemantics`d — a "celebration" node
      // that says nothing would be read out as noise on every visit.
      expect(find.byType(SunBurst), findsOneWidget);
      expect(find.byType(StreakFlame), findsOneWidget);
      // The pill's label already says the streak, so the flame adds no second name.
      expect(find.bySemanticsLabel('Streak'), findsNothing);
      handle.dispose();
    });
  });

  group('the ARABIC arm', () {
    testWidgets('renders Arabic strings and Arabic-Indic numerals', (
      WidgetTester tester,
    ) async {
      final AppLocalizations strings = AppLocalizationsAr();
      await pumpResult(
        tester,
        result: const SubmitResult(
          questionId: 'q',
          isCorrect: true,
          pointsEarned: 10,
          currentTotalPoints: 40,
          currentStreak: 4,
          longestStreak: 6,
          readingCompleted: true,
        ),
        locale: const Locale('ar'),
      );

      expect(find.text(strings.resultCompleteMessage), findsOneWidget);
      // **The pill's own sentence**, not `find.textContaining`: the flame's semantic
      // label is the same word and a `containing` search matched both nodes.
      expect(
        find.text(strings.streakLabelFor(current: 4, longest: 6)),
        findsOneWidget,
      );
      // **The two tiles and the headline**, all in Arabic-Indic digits — U+0660–U+0669
      // are Arabic-block codepoints, so `arabic_typography_test.dart` holding them to
      // Amiri is what makes the numerals a typography question.
      expect(find.text('٦'), findsOneWidget, reason: 'the `Best run` tile');
      expect(find.text('١٠'), findsOneWidget, reason: 'the `This answer` tile');
      expect(find.text('٤٠'), findsOneWidget, reason: 'the headline');
      // The first version of this test rendered the headline with `toString()` and
      // found `٤٠` **absent** while the tiles were Arabic — one Western numeral on an
      // otherwise Arabic-Indic screen.
    });
  });

  group('§14\'s own surface, and RTL', () {
    testWidgets('320×568 at 1.22× overflows nothing, on both arms', (
      WidgetTester tester,
    ) async {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        await pumpResult(
          tester,
          result: aSentinelResult,
          locale: locale,
          size: const Size(320, 568),
          textScale: 1.22,
        );
        expect(tester.takeException(), isNull, reason: '§14 at $locale');
      }
    });

    testWidgets('and the AR arm lays out right-to-left', (
      WidgetTester tester,
    ) async {
      await pumpResult(
        tester,
        result: aSentinelResult,
        locale: const Locale('ar'),
      );
      expect(
        Directionality.of(tester.element(find.byType(ResultSheet))),
        TextDirection.rtl,
        reason:
            'the harness installs the direction from the locale, so a screen '
            'that ignored it would render LTR, and this is where that would show.',
      );
    });
  });

  group('REDUCED MOTION, AND THE CARD IS **OVER** THE QUIZ', () {
    // ## WHAT CHANGED, AND WHY THE GROUP IS STILL HERE
    //
    // The old group asked whether the result *page*'s ambient background stopped
    // at the LOW tier. **The result is a card over the quiz now**, and the card
    // paints no background of its own — the quiz underneath does, and the quiz
    // has its own suite. So that half of the question moved with the surface.
    //
    // **What is left for this card is its own motion**: the scale-in from `.9`
    // to `1` over 500ms (`:444-446`). §14's rule is that a reader who asked for
    // less motion gets the **end state**, not a shorter animation.
    //
    // The switch is therefore still live, and this is the test that makes it a
    // *live* parameter rather than a second unturned knob — which is the shape
    // §7's "a knob nothing turns" actually warns about.
    testWidgets('the card paints no ambient background of its own', (
      WidgetTester tester,
    ) async {
      // **A fact about the surface, and the reason the old group's question
      // moved.** The result is a card; the quiz under it is the screen. A
      // background here would be a second one painted under the first.
      await pumpResult(tester, result: aSentinelResult);

      expect(
        find.byType(NeuralBackground),
        findsNothing,
        reason:
            'the result is a card over the quiz, and the background belongs to '
            'the quiz',
      );
    });

    testWidgets(
      'and the scale-in JUMPS to the end state when motion is reduced',
      (WidgetTester tester) async {
        await pumpResult(
          tester,
          result: aSentinelResult,
          disableAnimations: true,
        );

        // **The burst's PAINTED box**, which is the card's scale applied to a
        // known 100px square. `getRect` walks the ancestor transforms, so this
        // reads the **scale** and not the layout — which is the claim.
        final Rect burst = tester.getRect(find.byType(SunBurst));
        expect(
          burst.width,
          moreOrLessEquals(ResultSheet.burstSize, epsilon: 0.5),
          reason:
              'the card is at full size, so the burst is its own '
              '${ResultSheet.burstSize}px square',
        );
      },
    );

    testWidgets(
      'and it is MID-SCALE on the default call, so the assertion above is '
      'not vacuous',
      (WidgetTester tester) async {
        // The negative control the previous test cannot supply for itself.
        // Without it, "the card is at full size" would also be satisfied by a
        // card that never animated at all.
        await pumpResult(tester, result: aSentinelResult);

        final Rect burst = tester.getRect(find.byType(SunBurst));
        expect(
          burst.width,
          lessThan(ResultSheet.burstSize),
          reason:
              'the card enters at .9 and grows to 1 over 500ms, so four frames '
              'in it has not arrived yet — and this is what makes the '
              'reduced-motion assertion above mean something',
        );
      },
    );
  });
}

/// [aSentinelResult] with the streak pair replaced, and everything else verbatim.
SubmitResult _withStreak({required int current, required int longest}) =>
    SubmitResult(
      questionId: aSentinelResult.questionId,
      isCorrect: aSentinelResult.isCorrect,
      pointsEarned: aSentinelResult.pointsEarned,
      currentTotalPoints: aSentinelResult.currentTotalPoints,
      currentStreak: current,
      longestStreak: longest,
      readingCompleted: aSentinelResult.readingCompleted,
    );

/// [aSentinelResult] with the reading **not** finished, so `messageFor` picks
/// `partialMessage`.
SubmitResult _withReadingCompleted(bool completed) => SubmitResult(
  questionId: aSentinelResult.questionId,
  isCorrect: true,
  pointsEarned: aSentinelResult.pointsEarned,
  currentTotalPoints: aSentinelResult.currentTotalPoints,
  currentStreak: aSentinelResult.currentStreak,
  longestStreak: aSentinelResult.longestStreak,
  readingCompleted: completed,
);
