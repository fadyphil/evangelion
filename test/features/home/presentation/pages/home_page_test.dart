/// `/` — the phase's own verification, and the contradictions this phase exists to
/// resolve.
///
/// ## WHAT IS ASSERTED HERE AND WHY IT IS NOT ALL IN ONE FILE
///
/// | claim | where |
/// | --- | --- |
/// | the screen's four sections and their independent states | here |
/// | the contradictory endpoints are **not** reconciled | here, in the failing direction |
/// | a failed reading renders `ErrorView` with a working retry while the flame still renders | here |
/// | one retry re-fetches only what failed | here, by counting the fakes |
/// | the bead row counts **questions**, and a `0 / 0` row says so | here |
/// | the drop cap is Latin-only | here |
/// | §14: no unlabeled interactive node | `home_accessibility_test.dart` |
/// | §14: 1.22× at 320px does not overflow | `home_text_scale_test.dart` |
/// | the prototype's numbers | `home_geometry_test.dart` |
///
/// The state machine itself is `home_bloc_test.dart`'s; this file asserts what the
/// **rendered tree** says, which is a different question and the one Phase 6's
/// verification line is written about ("renders `ErrorView` … not a blank panel").
library;

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/home/domain/preview_text.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/home_strings.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/app_top_bar.dart';
import 'package:evangelion/features/home/presentation/widgets/today_reading_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/home_harness.dart';

/// The preview paragraph's [TextSpan] — the one whose first run is a [WidgetSpan].
///
/// Found by **structure**, not by index, because "the third `RichText` in the tree"
/// is a number that changes the moment the greeting or a button grows a span. The
/// search is: the `TextSpan` that has children and whose first child is a
/// `WidgetSpan`. Only the drop-cap paragraph has that shape.
TextSpan _previewSpan(WidgetTester tester) {
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    final InlineSpan span = rich.text;
    if (span is TextSpan &&
        span.children != null &&
        span.children!.first is WidgetSpan) {
      return span;
    }
  }
  throw StateError(
    'no RichText carries a WidgetSpan-first paragraph: the English preview is not '
    'using PassageDropCap.paragraph()',
  );
}

/// The [Padding] that holds the streak subtitle — the reserved row.
///
/// Found by **the widget's own structure**, not by a text search: in the reserved
/// state the row's text is `''`, so any finder built on a string would find nothing
/// in exactly the state this measures. `_StreakSubtitle` builds one `Padding` with
/// `bottom: EvaSpacing.xxl` and nothing else on the screen does, so that is what is
/// matched — and the returned height is the **rendered** one, from the element tree,
/// because the claim is about pixels and not about a style's arithmetic.
double _subtitleRow(WidgetTester tester) => tester
    .getSize(
      find.byWidgetPredicate(
        (Widget w) => w is Padding && w.padding == subtitleRowPadding,
      ),
    )
    .height;

/// The subtitle row's own padding, from `HomePage`'s documented arrangement: the
/// greeting block's gap lives on the block, so the row is separated from the panel
/// by `HomePage.panelGap` instead.
const EdgeInsets subtitleRowPadding = EdgeInsets.only(bottom: EvaSpacing.xxl);

/// The rendered height of the reserved streak-subtitle row.
///
/// **20.0 for the line plus 24 for the row's own `bottom` padding**, measured: an
/// empty `Text` at `bodyMedium` is 20.0 tall (14sp × 1.4, rounded by the engine) and
/// 0.0 wide, and `EvaSpacing.xxl` is 24. Written as arithmetic on the two measured
/// parts rather than as `44`, so a reader can see which half is which.
final double reservedRowHeight = 20 + EvaSpacing.xxl;

void main() {
  group('the live payload, both languages', () {
    testWidgets(
      'the greeting, the wordmark, the flame and the panel all render',
      (WidgetTester tester) async {
        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc);

        expect(find.text('Evangelion'), findsOneWidget);
        expect(find.textContaining('Good morning'), findsOneWidget);
        expect(find.byType(StreakFlame), findsOneWidget);
        expect(find.byType(TodayReadingPanel), findsOneWidget);
        expect(find.text('John 3:1-5'), findsOneWidget);
      },
    );

    testWidgets('the greeting names the reader from the session', (
      WidgetTester tester,
    ) async {
      // `HomeScreen.tsx:27` renders the literal `Miriam`. `ds.tsx:525` renders `MK`.
      // Both are gone; the values come from `AuthSession` through the
      // `AuthRepository` port. Asserted as **the session's own strings** rather than
      // as literals, so a change to the seed shows up as a change here.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(find.textContaining('Good morning, '), findsOneWidget);
      expect(find.textContaining(liveSession.displayName), findsOneWidget);
      expect(find.text('Miriam'), findsNothing);
      expect(find.text('MK'), findsNothing);
    });

    testWidgets('and the avatar shows the session\'s monogram', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(find.text(liveSession.initials), findsOneWidget);
      expect(find.text('12'), findsNothing, reason: '`ds.tsx:516`\'s literal');
    });

    testWidgets(
      'with no session the greeting closes instead of naming anyone',
      (WidgetTester tester) async {
        // The `…evening, ` / `…evening.` split the prototype has, reachable now
        // because the name comes from the session and there may not be one.
        final HomeHarness h = harness(signedIn: false);
        await pumpHome(tester, bloc: h.bloc);

        expect(find.textContaining('Good morning.'), findsOneWidget);
        expect(find.textContaining('Good morning, '), findsNothing);
        // And the avatar has no monogram rather than the prototype's `MK`.
        expect(find.text('MK'), findsNothing);
      },
    );

    testWidgets('the streak flame reads the STREAK endpoint\'s zero', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // `liveStreakSummary.currentStreak` is `0`, `liveEnglishReading.currentStreak`
      // is `4`. The flame shows `0`.
      expect(find.text('0'), findsOneWidget);
      expect(find.text('4'), findsNothing);
    });

    testWidgets('the panel reads the READING endpoint\'s completion', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // `is_fully_completed: true` on the reading, `today_completed: false` on the
      // summary. The eyebrow comes from the reading.
      expect(find.text(const HomeStrings.en().readingComplete), findsOneWidget);
      expect(find.text(const HomeStrings.en().continueReading), findsNothing);
    });

    testWidgets('and neither number is reconciled anywhere on screen', (
      WidgetTester tester,
    ) async {
      // The test the whole resolution exists for. Both fakes carry **deliberately
      // contradictory** numbers and each surface shows its own: the flame reads
      // `StreakSummary.currentStreak` (0), the eyebrow reads
      // `TodayReading.isFullyCompleted` (true). Nothing on this screen sums them,
      // prefers one, or cross-checks them — so when the backend fixes the
      // disagreement, no line here changes.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final HomeState state = h.bloc.state;
      // The `!`s here are `stateless_nullable` violations if they can be avoided;
      // they are assertions that the two sections answered, and `expect` below
      // would fail with a null anyway — so this is the documented `!` case.
      expect(state.streak!.currentStreak, 0);
      expect(state.reading!.currentStreak, 4);
      expect(state.streak!.todayCompleted, isFalse);
      expect(state.reading!.isFullyCompleted, isTrue);

      expect(find.text('0'), findsOneWidget, reason: 'the flame');
      expect(
        find.text(const HomeStrings.en().readingComplete),
        findsOneWidget,
        reason: 'the panel',
      );
    });

    testWidgets('an Arabic locale renders the Arabic arm end to end', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      h.readings.answer = const Result.success(liveArabicReading);
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      // Asked for the Arabic endpoint, not the English one.
      expect(h.readings.asked, <ReadingLanguage>[ReadingLanguage.arabic]);
      expect(find.text(liveArabicReading.reference), findsOneWidget);
      // Unfinished, so the **other** eyebrow arm.
      expect(find.text(const HomeStrings.ar().continueReading), findsOneWidget);
      expect(find.text(const HomeStrings.ar().readingComplete), findsNothing);
    });
  });

  group('what the prototype hard-coded and this screen does not', () {
    testWidgets('no streak number literal appears', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // `ds.tsx:516` writes `12`; `ds.tsx:508` writes `Evangelion` (which **is**
      // this app's name and is a parameter, not a constant — asserted through
      // `AppTopBar`'s required `wordmark`, and `app_top_bar_test.dart` asserts that
      // parameter is *read*).
      expect(find.text('12'), findsNothing);
    });

    testWidgets('no milestone reaches the screen', (WidgetTester tester) async {
      // `StreakSummary.nextMilestone` and `daysToMilestone` are carried for Phase 8's
      // `StreakPill` and read by nothing. Asserted here so a future phase cannot find
      // them already drawn — the same treatment the entities' docs ask for.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // **Exact, not containing.** `John 3:1-5` contains a `3`, so a substring
      // finder would fail for a reason that has nothing to do with the milestone —
      // which is precisely the kind of false failure that gets a test deleted
      // instead of fixed.
      expect(find.text('3'), findsNothing);
      expect(find.textContaining('milestone'), findsNothing);
      expect(find.textContaining('days to'), findsNothing);
    });

    testWidgets('no points figure reaches the screen', (
      WidgetTester tester,
    ) async {
      // Same argument as the milestone: `pointsEarnedToday` is `10` on the live
      // payload and is read by nothing on `/`.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(find.text('10'), findsNothing);
    });

    testWidgets('no translation name reaches the screen', (
      WidgetTester tester,
    ) async {
      // `TodayReading.translation` is carried because the payload carries it;
      // Phase 7's sanctuary is where an edition belongs.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(find.text(liveEnglishReading.translation), findsNothing);
      expect(find.textContaining('NKJV'), findsNothing);
    });
  });

  group('a failed READING', () {
    testWidgets('renders ErrorView with the repository\'s own message', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result.failure(readingFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.byType(ErrorView), findsOneWidget);
      // Verbatim, per `failure.dart`.
      expect(find.text(readingFailure.message), findsOneWidget);
      expect(find.byType(TodayReadingPanel), findsOneWidget);
    });

    testWidgets(
      'and NOT a whole-screen error — the rest of `/` still renders',
      (WidgetTester tester) async {
        // The phase's own wording: "not a blank panel, and not a whole-screen error".
        final HomeHarness h = harness(
          reading: const Result.failure(readingFailure),
        );
        await pumpHome(tester, bloc: h.bloc);

        expect(find.byType(ErrorView), findsOneWidget);
        // The greeting, the wordmark and — the load-bearing half — **the streak
        // flame**, with its number.
        expect(find.text('Evangelion'), findsOneWidget);
        expect(find.textContaining('Good morning'), findsOneWidget);
        expect(find.byType(StreakFlame), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        // And the streak's own failure never happened, so its subtitle is the
        // "glowing" arm… no: the streak is 0, so it is the *resting* one.
        expect(find.text(const HomeStrings.en().streakResting), findsOneWidget);
      },
    );

    testWidgets('and NOT a blank panel — the panel frame is still there', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result.failure(readingFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.byType(GlassSurface), findsWidgets);
      expect(find.byType(ProgressBeads), findsNothing);
      // The panel is not a button in this state: there is no reading to open.
      expect(
        tester
            .widgetList<GlassSurface>(find.byType(GlassSurface))
            .where((GlassSurface s) => s.onTap != null),
        isEmpty,
        reason: 'a failed reading has no `/reading` to push',
      );
    });

    testWidgets('the retry works and re-fetches ONLY the reading', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result.failure(readingFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(h.readings.calls, 1);
      expect(h.streaks.calls, 1);
      expect(h.auth.calls, 1);

      h.readings.answer = const Result.success(liveEnglishReading);
      // `ensureVisible` first: at 320x568 the panel is below the fold, and a tap on
      // an off-screen widget throws a hit-test warning rather than pressing the
      // button — which reads as "the retry does not work".
      final Finder retry = find.text(const HomeStrings.en().retry);
      await tester.ensureVisible(retry);
      await pumpFrames(tester, 2);
      await tester.tap(retry);
      await pumpFrames(tester, 6);

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('John 3:1-5'), findsOneWidget);

      // **Only** the reading went back to the network. This is the assertion the
      // "not a whole-screen error" claim needs in order to mean anything: a retry
      // that re-issued the streak request would put the flame back into loading and
      // blank the number that was working, for no reason.
      expect(h.readings.calls, 2);
      expect(h.streaks.calls, 1);
      expect(h.auth.calls, 1);
      // And the streak that was **never** re-fetched is still on screen. This is
      // the mirror of the assertion the streak retry needed and did not have, and
      // without it "re-fetches ONLY the reading" is satisfied by a retry that
      // re-fetched the reading *and* blanked the flame.
      expect(
        find.text('0'),
        findsOneWidget,
        reason: 'the streak was never re-issued, so its number must not move',
      );
    });

    testWidgets('a retry that fails again keeps the error up', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result.failure(readingFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      final Finder retry = find.text(const HomeStrings.en().retry);
      await tester.ensureVisible(retry);
      await pumpFrames(tester, 2);
      await tester.tap(retry);
      await pumpFrames(tester, 6);

      expect(find.byType(ErrorView), findsOneWidget);
      expect(h.readings.calls, 2);
    });
  });

  group('a failed STREAK', () {
    testWidgets('the panel still renders, and the flame offers a retry', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        streak: const Result.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('John 3:1-5'), findsOneWidget);
      // The flame's failure is an icon control named with the repository's message,
      // so a screen-reader user gets the reason and a sighted user gets it on hover.
      expect(find.byIcon(Icons.sync_problem_outlined), findsOneWidget);
      expect(
        find.text(streakFailure.message),
        findsNothing,
        reason:
            'a sentence '
            'does not belong in a top bar — it is the button\'s label, asserted in '
            '`home_accessibility_test.dart`',
      );
    });

    testWidgets('and the panel\'s completion state survives it', (
      WidgetTester tester,
    ) async {
      // The half of the contradiction this file exists for: the streak endpoint
      // failing must not take the reading's own `is_fully_completed` with it.
      final HomeHarness h = harness(
        streak: const Result.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.text(const HomeStrings.en().readingComplete), findsOneWidget);
    });

    testWidgets('the retry re-fetches ONLY the streak', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        streak: const Result.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      h.streaks.answer = const Result.success(liveStreakSummary);
      final Finder flameRetry = find.byIcon(Icons.sync_problem_outlined);
      await tester.ensureVisible(flameRetry);
      await pumpFrames(tester, 2);
      await tester.tap(flameRetry);
      await pumpFrames(tester, 6);

      expect(find.byType(StreakFlame), findsOneWidget);
      expect(h.streaks.calls, 2);
      expect(h.readings.calls, 1);
      // **And the reading is still on screen.** The call count alone does not say
      // it is: `HomeState.withSection` decides what survives a status change, and
      // mutating its one line from
      // `reading: nextReading == ready ? reading : null` to `reading: null`
      // re-issued no request, changed no counter, and blanked the panel anyway.
      //
      // This assertion is the whole of the reading half of §6's "two independent
      // sections" claim, and until it existed the claim was certified by one
      // `expect(ready.withSection(), ready)` in `home_bloc_test.dart` — a test named
      // for a *different* property. Delete that one test and nothing else in the
      // phase noticed.
      expect(
        find.text('John 3:1-5'),
        findsOneWidget,
        reason:
            'a streak retry must not take the reading with it — `withSection` has '
            'to leave the section it was not asked about exactly as it found it',
      );
    });
  });

  group('the beads', () {
    testWidgets('count the reading\'s QUESTIONS, not the prototype\'s five', (
      WidgetTester tester,
    ) async {
      // `HomeScreen.tsx:65` — `total={5} completed={2} current={2}` — described
      // passage progress across the cut library grid. The live reading has **one**
      // question.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final ProgressBeads beads = tester.widget<ProgressBeads>(
        find.byType(ProgressBeads),
      );
      expect(beads.total, liveEnglishReading.questionCount);
      expect(beads.completed, liveEnglishReading.answeredQuestionCount);
      expect(beads.total, 1);
    });

    testWidgets(
      'and a reading with NO questions says so instead of a blank row',
      (WidgetTester tester) async {
        // The deliberate answer to `0 / 0`. `ProgressBeads` clamps `total` to `0` and
        // returns `SizedBox.shrink()`, so without this line the panel would render a
        // gap between the reference and the buttons that is indistinguishable from a
        // layout failure.
        final HomeHarness h = harness();
        h.readings.answer = Result.success(
          liveEnglishReading.copyWith(
            questionCount: 0,
            answeredQuestionCount: 0,
          ),
        );
        await pumpHome(tester, bloc: h.bloc);

        expect(find.byType(ProgressBeads), findsNothing);
        expect(
          find.text(const HomeStrings.en().noQuestionsToday),
          findsOneWidget,
        );
      },
    );
  });

  group('the preview\'s typeface', () {
    testWidgets('the ENGLISH arm renders scripture in the Latin face', (
      WidgetTester tester,
    ) async {
      // **The rendered style, not the constant.** `EvaTypography.scriptureLatin` is
      // a method anyone can call, and asserting that `_Preview` called it would be
      // asserting the widget's own source through a mirror of itself. What is being
      // claimed is that the *words a reader sees* carry that family — so the family
      // is read off the `TextSpan` the engine will lay out.
      //
      // The English arm is the `WidgetSpan`-first paragraph (the drop cap), whose
      // second child is the run holding the words.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final TextSpan paragraph = _previewSpan(tester);
      final TextSpan rest = paragraph.children![1] as TextSpan;

      expect(rest.style!.fontFamily, EvaTypography.scriptureFamily);
      expect(rest.style!.fontFamily, 'EBGaramond');
      expect(
        rest.style!.fontFamily,
        isNot(EvaTypography.arabicFamily),
        reason: 'the Latin arm must not render in the Arabic face either',
      );
    });

    testWidgets('and the ARABIC arm renders scripture in the Arabic face', (
      WidgetTester tester,
    ) async {
      // The defect this closes: `_Preview` built **one** `TextStyle` from
      // `scriptureLatin` for both arms, 200 lines below this widget's own
      // doc citing defect #2 — "Arabic never uses the mono family" — as the reason it
      // branches at all. Only the drop cap branched.
      //
      // Measured before the fix: the families in the tree on an `ar` screen were
      // `{CormorantGaramond, SpaceMono, DMSans, EBGaramond}`, `Amiri` absent, and
      // `EvaTypography.scriptureArabic` named by nothing in `lib/` but its own
      // definition. Swapping `scriptureLatin` for `scriptureArabic`
      // unconditionally passed all 1520 tests — so neither direction was watched,
      // and this pair of tests is what watches both.
      final HomeHarness h = harness();
      h.readings.answer = const Result.success(liveArabicReading);
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      // The Arabic arm renders the preview whole — a plain `Text`, because there is
      // no drop cap — so the style is read off that widget directly.
      final Text whole = tester.widget<Text>(
        find.text(previewText(liveArabicReading.firstVerseText)),
      );

      expect(whole.style!.fontFamily, EvaTypography.arabicFamily);
      expect(whole.style!.fontFamily, 'Amiri');
      expect(
        whole.style!.fontFamily,
        isNot(EvaTypography.scriptureFamily),
        reason:
            'this is the direction the mutation nobody caught went: Arabic '
            'scripture drawn in the Latin face',
      );
      // And the same geometry as the Latin arm, which is the reason
      // `scriptureArabic`'s own doc exists — asserted so "branched" cannot quietly
      // become "branched, and also made a size difference".
      expect(whole.style!.fontSize, TodayReadingPanel.previewFontSize);
    });
  });

  group('an empty first verse', () {
    testWidgets('still renders BOTH controls, because it cannot throw', (
      WidgetTester tester,
    ) async {
      // ## THE TOTALITY CLAIM
      //
      // `previewText('')` is `''`. The panel used to call `preview.substring(0, 1)` to
      // build the drop cap, which is a `RangeError` thrown **out of
      // `TodayReadingPanel.build`** — and the panel's `EvaButton` and `TextLink` are
      // that same widget's children, so the exception took **`Continue` →
      // `/reading` and `Start reflection` → `/quiz`** with it. One verse with no text
      // made the reading route unreachable from `/`, and nothing caught it because no
      // fixture had ever had an empty one.
      //
      // The English arm is the one that throws: it is the only branch that indexes
      // into the preview. The Arabic arm was already safe, and asserting the Arabic
      // arm too is what stops a future "simplification" that re-joins them.
      final HomeHarness h = harness();
      h.readings.answer = Result.success(
        liveEnglishReading.copyWith(firstVerseText: ''),
      );
      await pumpHome(tester, bloc: h.bloc);

      // No exception escaped, and the panel is on screen…
      expect(tester.takeException(), isNull);
      expect(find.byType(TodayReadingPanel), findsOneWidget);
      // …**with both destinations still reachable.** These two are the whole point:
      // they are the controls that used to vanish.
      expect(find.text(const HomeStrings.en().continueLabel), findsOneWidget);
      expect(find.text(const HomeStrings.en().startReflection), findsOneWidget);
      // The rest of the panel is intact too — a heading, a bead row, and the status
      // line — so "it did not throw" is not satisfied by a blank frame.
      expect(find.text('John 3:1-5'), findsOneWidget);
      expect(find.byType(ProgressBeads), findsOneWidget);
      expect(find.text(const HomeStrings.en().readingComplete), findsOneWidget);
      // And the preview itself is an empty paragraph rather than an absent widget.
      expect(find.byType(PassageDropCap), findsNothing);
    });

    testWidgets('and the ARABIC arm with an empty verse is equally safe', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      h.readings.answer = Result.success(
        liveArabicReading.copyWith(firstVerseText: ''),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      expect(tester.takeException(), isNull);
      expect(find.text(const HomeStrings.ar().continueLabel), findsOneWidget);
      expect(find.text(const HomeStrings.ar().startReflection), findsOneWidget);
    });
  });

  group('the drop cap', () {
    testWidgets('the English preview opens with an enlarged letter', (
      WidgetTester tester,
    ) async {
      // Asserted on the **span tree**, not on a widget: `PassageDropCap` is placed by
      // `paragraph()` as a `WidgetSpan`, so there is no `PassageDropCap` in the
      // element tree to find. The claim is that the paragraph's first child is a
      // `WidgetSpan` holding the cap, which is what "splits a letter off the front"
      // actually is.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final TextSpan paragraph = _previewSpan(tester);
      expect(paragraph.children, isNotNull);
      expect(paragraph.children, hasLength(2));
      expect(
        paragraph.children!.first,
        isA<WidgetSpan>(),
        reason:
            'the first run is the drop cap, and the prototype\'s Latin split is '
            'what this preserves',
      );
      final InlineSpan rest = paragraph.children![1];
      expect(rest, isA<TextSpan>());
      expect(
        (rest as TextSpan).text,
        startsWith('here was a man of the Pharisees'),
        reason:
            'the rest of the verse, minus its own first letter. The visible '
            'tail starts  because the preview was cut at a word '
            'boundary first.',
      );
    });

    testWidgets('and the cap\'s letter is the verse\'s own first character', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // Read off the `WidgetSpan`'s own child, which is the `Text` the cap paints.
      // `find.byType(PassageDropCap)` would match **nothing**: `paragraph()` places
      // the cap as a span, so the widget instance is never in the element tree —
      // which is also why the test above searches the span tree instead.
      final WidgetSpan cap = _previewSpan(tester).children!.first as WidgetSpan;
      final Text child = cap.child as Text;
      expect(child.data, liveEnglishReading.firstVerseText.substring(0, 1));
      expect(child.data, 'T');
    });

    testWidgets('the Arabic preview is rendered WHOLE — no split letter', (
      WidgetTester tester,
    ) async {
      // `HomeScreen.tsx:55-58` splits a literal `I` off `"n the beginning…"`. The
      // Arabic first verse begins a joined, right-to-left letter, and enlarging it
      // to 76px breaks its connection to the word it belongs to — a defect rather
      // than a rendering of the design, and the same class as Phase 7's defect #2
      // ("Arabic never uses the mono family").
      final HomeHarness h = harness();
      h.readings.answer = const Result.success(liveArabicReading);
      await pumpHome(tester, bloc: h.bloc);

      // **Exact, whole.** 49 characters, so `previewText` leaves it alone, and the
      // whole string being present *is* the claim: nothing was stripped off its head.
      // A substring assertion would have been satisfied by the whole string too —
      // which is why the first version's `isNot(contains('ان إنسان'))` was a test
      // that could not fail.
      expect(find.text(liveArabicReading.firstVerseText), findsOneWidget);
    });
  });

  group('the preview', () {
    testWidgets('is cut on a word boundary with one real ellipsis', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // `liveEnglishReading.firstVerseText` is 71 characters, so this always runs.
      expect(
        find.textContaining('…', findRichText: true),
        findsWidgets,
        reason: 'the preview is truncated with U+2026, not three dots',
      );
      expect(find.textContaining('Nicodemus'), findsNothing);
    });
  });

  group('the streak subtitle', () {
    // The live payload answers `0`, so the `resting` copy is the only one `/`
    // renders and the `glowing` copy was unreachable from any suite that used the
    // live payload — an untranslated string with nothing asserting it. This row is
    // also the one place the two sentences are distinguished at all: they are not a
    // pluralisation of each other, they are different sentences, so a change to
    // either has to be a deliberate act.
    testWidgets(
      'says RESTING for a zero streak — the live payload\'s own value',
      (WidgetTester tester) async {
        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc);

        expect(find.text(const HomeStrings.en().streakResting), findsOneWidget);
        expect(find.text(const HomeStrings.en().streakGlowing), findsNothing);
      },
    );

    testWidgets('says GLOWING for any streak above zero', (
      WidgetTester tester,
    ) async {
      // A copyWith rather than a hand-built summary, so the entity keeps being
      // built by the live payload's own mapper and this test cannot drift from it.
      final HomeHarness h = harness(
        streak: Result<StreakSummary>.success(
          liveStreakSummary.copyWith(currentStreak: 4),
        ),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.text(const HomeStrings.en().streakGlowing), findsOneWidget);
      expect(find.text(const HomeStrings.en().streakResting), findsNothing);
    });

    testWidgets(
      'and the Arabic pair is a different sentence, not a transliteration',
      (WidgetTester tester) async {
        // Named because the assertion is that `streakGlowing` and `streakResting` are
        // **not** interchangeable: if a translator ever made them one string with the
        // number substituted, both English tests would still pass and this one would
        // not.
        expect(
          const HomeStrings.ar().streakGlowing,
          isNot(const HomeStrings.ar().streakResting),
        );
        expect(const HomeStrings.ar().streakGlowing, isNotEmpty);
        expect(const HomeStrings.ar().streakResting, isNotEmpty);
      },
    );

    testWidgets('the row is RESERVED when the streak fails, not removed', (
      WidgetTester tester,
    ) async {
      // ## THE CLAIM, AND WHY IT NEEDED A MEASUREMENT
      //
      // The row used to be `if (state.streak case …)`, so it vanished while loading
      // and again on a streak failure, taking `EvaSpacing.xxl` with it and moving the
      // panel up by a line mid-screen. `TodayReadingPanel`'s
      // `_FailedOrLoading.placeholderHeight` exists for exactly this class of jump —
      // "a panel that grows from one line to nine is the layout moving" — 140 lines
      // away and about a different widget.
      //
      // The fix is an **empty `Text` in the same style**, chosen because it was
      // measured rather than assumed: `Text('')` at `bodyMedium` is 20.0 tall and 0.0
      // wide, the same 20.0 as a non-empty one, so one widget covers both non-ready
      // states and the reserved height cannot drift from the text's.
      //
      // ## ONE WITNESS FOR BOTH NON-READY STATES, AND WHY
      //
      // Loading and failure are the **same** render: `_StreakSubtitle` branches on
      // `streak == null` and both states are `null`, so they are one branch with one
      // witness. Two tests would have been one test written twice.
      //
      // The loading state is in any case **not reachable from a page-level widget
      // test** here, and that is a measurement rather than an omission: both fakes
      // answer in a microtask, and even a bare `tester.pumpWidget` with no
      // `pumpFrames` drains enough of the queue for `_onStarted` to have emitted all
      // three answers by the time it returns — `pumpHome(frames: 0)` included. The
      // only ways to hold the request open are a `Completer` the fake waits on, and
      // Phase 6's decision 37 is that this **hangs the suite**: `HomeBloc.close()`
      // awaits the handler, the handler is parked on the gate, and completing the gate
      // from a teardown schedules the continuation on a fake-async queue nothing pumps
      // again. Four router suites timed out at five minutes each with no error at all.
      // So the state is left unwitnessed here and is `home_bloc_test.dart`'s to own.
      final HomeHarness h = harness(
        streak: const Result.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      // **The arm really is the failed one**, so the assertion below is about the
      // reserved row and not about a state that never happened.
      expect(h.bloc.state.streak, isNull);
      expect(h.bloc.state.streakStatus, HomeSectionStatus.failed);
      // Nothing is claimed, so nothing is said…
      expect(find.text(const HomeStrings.en().streakResting), findsNothing);
      expect(find.text(const HomeStrings.en().streakGlowing), findsNothing);
      // …but the row still occupies its line.
      expect(
        _subtitleRow(tester),
        reservedRowHeight,
        reason: 'a failed streak must not move the panel',
      );
      // And the panel below it is on screen, so "nothing is said" is not satisfied by
      // a blank frame.
      expect(find.byType(TodayReadingPanel), findsOneWidget);
      expect(find.text('John 3:1-5'), findsOneWidget);
    });

    testWidgets('and the reserved row grows with the reader\'s text scale', (
      WidgetTester tester,
    ) async {
      // **The assertion that rules out the alternative.** A `SizedBox` of the
      // measured 20 + 24 would satisfy the test above exactly, and would be wrong:
      // §14 requires 1.22× at 320px to lay out without overflow, and a hard-coded
      // reserved height does not move with the reader's preference — so at 1.22× the
      // row would be reserved short and the sentence would overlap the panel.
      //
      // The empty `Text` moves because it *is* the text. `streak: null` — the
      // **failed** fixture — is the same `null` the loading frame has, so this needs
      // no gate: one branch, one value, reached by the fixture that does not hang.
      final HomeHarness loading = harness(
        streak: const Result.failure(streakFailure),
      );

      await pumpHome(tester, bloc: loading.bloc, textScale: 1.0);
      final double atOne = _subtitleRow(tester);

      await pumpHome(tester, bloc: loading.bloc, textScale: 1.22);
      final double atOneTwentyTwo = _subtitleRow(tester);

      expect(atOneTwentyTwo, greaterThan(atOne));
      // And it is the *scaled* line, not just a bigger number: 20 × 1.22 = 24.4, and
      // the engine rounds the paragraph box, so a lower bound rather than an equality.
      expect(
        atOneTwentyTwo - atOne,
        greaterThan(4),
        reason:
            '1.22× of a 20px line is 24.4; a reserved height that did not move would '
            'be the `SizedBox` this replaced',
      );
    });

    testWidgets('a TWELVE-DIGIT streak overflows nothing', (
      WidgetTester tester,
    ) async {
      // The other half of W4: `TodayReadingMapper` **passes through** a large
      // `current_streak` rather than refusing it, and this is the claim that makes
      // that a decision instead of a hope. The bar puts the wordmark in an `Expanded`
      // with `TextOverflow.ellipsis`, so an arbitrarily long number is absorbed by
      // truncating the wordmark.
      //
      // At 320px — the narrowest surface §14 names — because a row that absorbs twelve
      // digits at 390px has not been shown to absorb them at the size that matters.
      final HomeHarness h = harness(
        streak: Result<StreakSummary>.success(
          liveStreakSummary.copyWith(currentStreak: 999999999999),
        ),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(find.text('999999999999'), findsOneWidget);
      // The claim is that nothing overflowed, and a `RenderFlex` overflow is
      // reported through `takeException` rather than as a failed layout.
      expect(tester.takeException(), isNull);
      // The wordmark is what gives way, and it gives way by ellipsis rather than by
      // overflowing — which is the property, so it is the assertion.
      expect(find.text(const HomeStrings.en().wordmark), findsOneWidget);
    });
  });

  group('the blur budget', () {
    testWidgets('the panel is the ONE GlassTier.blur site on `/`', (
      WidgetTester tester,
    ) async {
      // §13 rule 4's per-screen line used to name "the panel **and the top bar**",
      // and `ds.tsx:499-530` has no `backdropFilter` at all. One site ships.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final List<GlassSurface> blur = tester
          .widgetList<GlassSurface>(find.byType(GlassSurface))
          .where((GlassSurface s) => s.tier == GlassTier.blur)
          .toList();
      expect(blur, hasLength(1));
      expect(blur.single.radius, EvaRadii.heroPanel);
    });

    testWidgets('and the top bar draws no glass at all', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(find.byType(AppTopBar), findsOneWidget);
      // **Scoped to the bar.** A bare `find.byType(BackdropFilter)` finds the
      // panel's own blur — which is the one site that is supposed to exist — so the
      // unscoped form would have been asserting the opposite of its own claim.
      expect(
        find.descendant(
          of: find.byType(AppTopBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });
  });

  group('the first frame', () {
    testWidgets('has no greeting, because no clock has been read yet', (
      WidgetTester tester,
    ) async {
      // `HomeState.greetingPeriod` is null until `HomeStarted` runs, and this pins
      // what that looks like: a hard-coded `Good evening` on the first frame would be
      // a prototype literal surviving for however long the first emit takes.
      final HomeHarness h = harness();
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeDark.theme,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: HomePage(bloc: h.bloc),
        ),
      );

      // `findRichText: true` because the greeting is ONE `Text.rich` with two
      // `TextSpan`s (`home_page.dart:418`) — without it this finder cannot match
      // the greeting at all, so the assertion would hold for any code whatsoever.
      expect(find.textContaining('Good', findRichText: true), findsNothing);
      expect(find.byType(AppTopBar), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('asks the reading endpoint in the resolved locale', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      expect(h.readings.asked, <ReadingLanguage>[ReadingLanguage.arabic]);
    });

    testWidgets('does not re-issue on a rebuild, which is not a re-entry', (
      WidgetTester tester,
    ) async {
      // **Half of the old `loads once, on entry, and not again on rebuild`, and it
      // is the half that was true.** A dispatch from `build` — which is what
      // `LoginPage` does, safely, because `AuthStarted` is idempotent against an
      // in-memory fake — would re-issue both requests on **every answer**.
      //
      // What this cannot see is the other half, and that is why the test it
      // replaced was deleted rather than fixed. "A rebuild" and "a re-entry" are
      // different events: the old version forced extra `pump()`s, which do not even
      // rebuild `_HomeBody` — nothing changed — so it certified a `bool _started`
      // guard while `/` never re-fetched after a real push/pop. The re-entry half
      // needs a **router**, so it lives in `home_navigation_test.dart` where one
      // exists, and it asserts the opposite of this line.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(h.readings.calls, 1);
      expect(h.streaks.calls, 1);
      expect(h.auth.calls, 1);

      // Force several frames.
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(h.readings.calls, 1);
      expect(h.streaks.calls, 1);
    });

    testWidgets('and DOES re-issue when the locale changes', (
      WidgetTester tester,
    ) async {
      // **The second trigger, in the same branch as the first.** Phase 9 owns the
      // real language switch; until it lands, `_language` can only be exercised by
      // rebuilding the page at another locale. With the old `bool _started`, this
      // was unrepresentable: the flag was true, so the new arm was never asked for
      // and `/` would render Arabic strings over English scripture — a
      // half-migrated screen, which is the state `home_navigation_test.dart`'s
      // Arabic suite already checks the *other* direction of.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(h.readings.asked, <ReadingLanguage>[ReadingLanguage.english]);

      await pumpHome(
        tester,
        bloc: h.bloc,
        locale: const Locale('ar'),
        frames: 0,
      );

      expect(
        h.readings.asked,
        <ReadingLanguage>[ReadingLanguage.english, ReadingLanguage.arabic],
        reason:
            'a locale change has to re-ask, or the panel shows one arm\'s text '
            'under the other arm\'s labels',
      );
      // And the streak and session are re-asked with it: one `HomeStarted`, three
      // requests. Asserted so a fix that re-asks *only* the reading — which would
      // leave the flame reading the previous arm's numbers — is distinguishable.
      expect(h.streaks.calls, 2);
      expect(h.auth.calls, 2);
    });

    testWidgets('uses the route constants for its own gutter', (
      WidgetTester tester,
    ) async {
      // Named rather than asserted against `HomePage.scaffoldPadding`'s value,
      // because "the page uses the constant" is the claim and reading the constant
      // would be the tautology.
      expect(
        HomePage.scaffoldPadding,
        const EdgeInsets.symmetric(horizontal: 20),
      );
      expect(
        HomePage.scaffoldPadding.left,
        EvaSpacing.screenHorizontal,
        reason: 'the gutter is the token, not a number the page invented',
      );
    });
  });
}
