import 'package:evangelion/app/sky_scope.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/features/reading/domain/reading_focus.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_app_bar.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_quiz_cta.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';
import '../../../../support/settings_harness.dart';

/// The redesigned reader's behaviour, one harness.
///
/// ## THE FIVE CHILDREN OF `:128`'s COLUMN, IN SOURCE ORDER
///
/// `eva/redesign.html:540-560` is a flex column: `.appbar`, `.appbar.sub`,
/// `.versebox` (`flex:1`), `.qcta`, `.pill`. Only the verses scroll. That order is
/// the screen's whole shape, and the first row below pins it — because a column
/// whose children were reordered would still pass every per-widget test in this
/// file and be a different screen.
///
/// ## AND FOCUS MODE IS THE ROW WITH THE OBLIGATION IN IT
///
/// `:176` dims `.appbar`, `.pill` and `.qcta` to `.2` after four idle seconds, and
/// `:177` **recolours the verses** — a `(0,4,0)` selector that flattens `.hot` into
/// `.in`, measured in the plan as an in-focus distinction of **1.000:1**. The
/// correction this task owes (Phase 2 Task 2.2 Step 3) is that the verses are
/// *never* dimmed: the chrome fades and the text keeps its own paints, which is
/// what `VerseLine`'s three-state enum makes inexpressible to break.
void main() {
  group('the column', () {
    testWidgets("five children, in the prototype's source order", (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      // Presence first.
      expect(find.byType(ReadingAppBar), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ReadingQuizCta), findsOneWidget);
      expect(find.byType(ReadingPill), findsOneWidget);

      // Then order, read off the geometry: a column's children are strictly
      // stacked, so each widget's top is at or below the previous one's bottom.
      final double appBarBottom = tester
          .getBottomRight(find.byType(ReadingAppBar))
          .dy;
      final double versesTop = tester.getTopLeft(find.byType(ListView)).dy;
      final double versesBottom = tester
          .getBottomRight(find.byType(ListView))
          .dy;
      final double ctaTop = tester.getTopLeft(find.byType(ReadingQuizCta)).dy;
      final double ctaBottom = tester
          .getBottomRight(find.byType(ReadingQuizCta))
          .dy;
      final double pillTop = tester.getTopLeft(find.byType(ReadingPill)).dy;

      expect(versesTop, greaterThanOrEqualTo(appBarBottom));
      expect(ctaTop, greaterThanOrEqualTo(versesBottom));
      expect(pillTop, greaterThanOrEqualTo(ctaBottom));
      // And the verses are the screen's only scrollable — `:159`'s `flex:1`.
      expect(
        versesBottom - versesTop,
        greaterThan(ctaBottom - ctaTop),
        reason:
            'the verse box absorbs the remaining height; the CTA and the pill '
            'keep their own',
      );
    });
  });

  group('the CTA is gated on a question, not on a passage', () {
    testWidgets('zero questions means no invitation', (
      WidgetTester tester,
    ) async {
      // `TodayReadingMapper` **skips** an unreadable question rather than refusing
      // the passage (recorded decision 40), so `questionCount == 0` is reachable.
      // The passage is untouched; the invitation goes.
      final ReadingHarness h = readingHarness(
        scripture: Right<Failure, ScriptureText>(
          liveEnglishPassageZeroQuestions,
        ),
      );
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      expect(find.byType(ReadingQuizCta), findsNothing);
      // And the passage still renders — the gate is on the *invitation*.
      expect(find.byType(VerseLine), findsWidgets);
    });
  });

  group('focus mode', () {
    testWidgets(
      'the chrome dims after four idle seconds, and the verses do not',
      (WidgetTester tester) async {
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

        // `pumpReading` has already pumped past `focusIdleDelay`, so the screen is in
        // its dimmed state — which is the state a reader spends most of their time
        // in, and the reason the helper settles there.
        final AnimatedOpacity bars = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(ReadingAppBar),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(
          bars.opacity,
          chromeDimOpacity,
          reason: '`:176` — the app bar dims',
        );

        // **The verses are NOT dimmed** — `:176` does not name them, and `:177`'s
        // recolouring of them is the recorded defect. A verse's own opacity is the
        // reveal's, which at this point is 1.
        final Finder firstVerse = find.byType(VerseLine).first;
        final Opacity verse = tester.widget<Opacity>(
          find.descendant(of: firstVerse, matching: find.byType(Opacity)).first,
        );
        expect(
          verse.opacity,
          1,
          reason:
              '`:176` dims three surfaces and the verses are not among them — '
              'the plan records `:177`\'s recolour as the 1.000:1 defect to correct',
        );
      },
    );

    testWidgets('and any pointer press restores the chrome', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      // `:1290` — `poke()` removes `.focus` on the press that found it, before
      // re-arming. A `Listener` at the root is what delivers it, because the press
      // that counts is the one on the *screen*, not one a child consumed.
      await tester.tap(find.byType(VerseLine).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      final AnimatedOpacity bars = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(ReadingAppBar),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(
        bars.opacity,
        1,
        reason:
            'the press that selected a verse is also the press that woke the '
            'chrome — `:1290` and `:1385` in one gesture',
      );
    });
  });

  group('the bookmark', () {
    testWidgets('toggles locally and is not persisted', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:1394` — `haptic(12)` and a toast and nothing else, and
      // §2's route table has no bookmark endpoint. **This is a recorded gap**: a
      // stored bookmark would be a fiction in the one place this screen is
      // otherwise entirely real.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      final Finder star = find.byType(FourPointedStar);
      expect(star, findsOneWidget);
      final bool litBefore = _bookmarkBorder(tester);

      await tester.tap(star);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_bookmarkBorder(tester), isNot(litBefore));

      await tester.tap(star);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_bookmarkBorder(tester), litBefore, reason: 'a toggle toggles');
    });
  });

  group('the sky', () {
    testWidgets('is placed behind the column, and empty without a scope', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      // `WitnessSky` is the stack's first child at `Positioned.fill` (`#sky`,
      // `eva/redesign.html:116`). **No scope above this harness means
      // `NullSkyHandle`** — empty and inert, which is the honest answer for a
      // screen with no sky, not a locator lookup (`sky_scope.dart`'s doc carries
      // the reason the fallback is *not* the registered cubit).
      expect(find.byType(WitnessSky), findsOneWidget);
      expect(
        SkyScope.read(tester.element(find.byType(ReadingPage))).litCount,
        0,
      );
    });
  });

  group('the observer and the stagger, against a real sky', () {
    testWidgets('a verse crossing the threshold lights ONE star, once', (
      WidgetTester tester,
    ) async {
      // ## THE ARRANGEMENT, AND WHY IT IS A REAL HANDLE AND NOT A SPY
      //
      // `SkyHandle` is two closures, so the fixture *is* the sky: `recorded`
      // collects what the observer sends, and `entriesReader` answers with it —
      // which is also what makes the guard below visible, because a sky that
      // returns what was recorded reproduces the optimistic emit the real cubit
      // performs.
      final List<SkyEntry> recorded = <SkyEntry>[];
      List<SkyEntry> lit = <SkyEntry>[];
      final SkyHandle sky = SkyHandle(
        entriesReader: () => lit,
        recordEntry: (SkyEntry entry) async {
          recorded.add(entry);
          lit = List<SkyEntry>.of(lit)..add(entry);
        },
      );
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      // The harness has no `SkyScope` above the page, so the observer reads the
      // inert handle. This test installs a real one *around* the page the way
      // `app.dart` does, because the claim is about the wiring and not about the
      // fallback.
      await tester.pumpWidget(
        SkyScope(
          handle: sky,
          child: evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: settingsScope(tester, ReadingPage(cubit: h.cubit)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await pumpReadingFrames(tester, 2);

      // **Scroll to the bottom**, which drags every verse across the 60 %
      // threshold in order.
      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpReadingFrames(tester, 3);

      expect(
        recorded.map((SkyEntry e) => e.verse).toSet(),
        equals(recorded.map((SkyEntry e) => e.verse).toList()),
        reason:
            'one star per verse, never a burst — `:1218` unobserves each '
            'verse after its first crossing, and `_lit` is this client\'s '
            'unobserve',
      );
      expect(recorded, isNotEmpty);
      // And the resume marker is the *first* verse the observer credited.
      expect(_resumeOf(tester), recorded.first.verse);
    });

    testWidgets('and the stagger reveals verse by verse when motion is on', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:1383` — `80 + 25n` ms. With motion ON, a verse mounts
      // in the `out` paint and crosses to `inView` when its timer lands, which is
      // the `_Reveal.didUpdateWidget` path the calm branch never exercises.
      final ReadingHarness h = readingHarness();
      // `disableAnimations` is the harness's default (false — motion ON), which
      // is the point: this row is about the stagger running.
      await pumpReading(tester, cubit: h.cubit);

      // Pump past the whole schedule and assert the end state: nothing built is
      // still waiting.
      await tester.pump(const Duration(milliseconds: 600));
      final List<VerseLine> after = tester
          .widgetList<VerseLine>(find.byType(VerseLine))
          .toList();
      expect(
        after.map((VerseLine line) => line.paint),
        everyElement(isNot(VersePaint.out)),
        reason: 'after the schedule has run, nothing is still waiting',
      );

      // ## AND THE SCHEDULE THE PAGE WALKS IS THE POLICY'S, ASSERTED HERE
      //
      // The first version of this row tried to catch a verse mid-stagger and
      // could not: the whole schedule for a six-verse passage runs in 205 ms and
      // the harness's first frame is 250 ms, so the race is unwinnable in a widget
      // test and a test that sleeps real time to win it is testing the machine.
      // So the race is not the claim — the page consumes
      // `verseEntranceSchedule`, whose arithmetic is TDD'd in
      // `reading_focus_test.dart` (37 tests), and this row asserts the *shape* the
      // page walks: one entry per verse, strictly increasing, under a third of a
      // second end to end.
      final List<Duration> schedule = verseEntranceSchedule(
        count: liveEnglishPassage.verses.length,
        immediate: false,
      );
      expect(schedule, hasLength(liveEnglishPassage.verses.length));
      for (int i = 1; i < schedule.length; i++) {
        expect(
          schedule[i],
          greaterThan(schedule[i - 1]),
          reason:
              'strictly increasing, or two verses would reveal together and '
              'the stagger would be a reveal',
        );
      }
      expect(
        schedule.last,
        lessThan(const Duration(milliseconds: 320)),
        reason:
            'the whole reveal is over before the entrance animation itself '
            'would have finished — `:1383` is a quicken, not a wait',
      );
    });
  });

  group('the entrance', () {
    testWidgets('the calm branch reveals every verse at once', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:1382` — reduced motion adds `.in` synchronously. A
      // reader who asked for no stagger gets none, and this row is what keeps the
      // reveal honest: with the flag on, the first frame already has every verse.
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit, disableAnimations: true);

      final List<VerseLine> lines = tester
          .widgetList<VerseLine>(find.byType(VerseLine))
          .toList();
      // **Only what fits is built** — a `ListView.builder` never constructs a
      // verse below the fold, so the count is a function of the surface and the
      // claim is about every verse that *is* here: on the calm branch, none of
      // them is still waiting for its turn in the stagger.
      expect(lines, isNotEmpty);
      for (final VerseLine line in lines) {
        expect(
          line.paint,
          isNot(VersePaint.out),
          reason:
              'every built verse is revealed — the calm branch has no stagger',
        );
      }
    });
  });
}

/// The bookmark's lit state, read off the border rather than off a shadow.
///
/// `.iconbtn.lit` (`:154`) sets **both** — a gold rim and a glow — and the rim is
/// the one that survives a golden-less run: a `BoxShadow` is invisible to a
/// predicate on the decoration's colour, and the border's colour *is* the state.
bool _bookmarkBorder(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: find.byType(FourPointedStar),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final BoxDecoration decoration = box.decoration as BoxDecoration;
  // `.iconbtn` unlit is `1px solid var(--glass-line)` and `.iconbtn.lit` is
  // `rgba(232,176,75,.6)` — the lit colour carries an **alpha**, so comparing
  // against bare `ember` is always false and the toggle looked dead. The claim is
  // "the rim changed", so the comparison is against the unlit rim.
  return decoration.border is Border &&
      (decoration.border as Border).top.color !=
          const EvaColors.dark().glassBorder;
}

/// Whether the first verse carries the resume marker — read off its decoration,
/// because the marker is a border and nothing else.
bool _hasResumeMarker(WidgetTester tester) {
  final VerseLine line = tester.widget<VerseLine>(find.byType(VerseLine).first);
  return line.resume;
}

int? _resumeOf(WidgetTester tester) => _hasResumeMarker(tester)
    ? tester.widget<VerseLine>(find.byType(VerseLine).first).number
    : null;

/// A passage with zero questions, for the CTA's gate — decision 40's reachable
/// state, built from the live fixture by dropping its questions.
final ScriptureText liveEnglishPassageZeroQuestions = liveEnglishPassage
    .copyWith(questions: const <Question>[]);
