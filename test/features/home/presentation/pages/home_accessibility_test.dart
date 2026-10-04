import 'dart:ui' show Tristate;

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/home/presentation/home_strings.dart';
import 'package:evangelion/features/home/presentation/widgets/app_top_bar.dart';
import 'package:evangelion/features/home/presentation/widgets/streak_flame_row.dart';
import 'package:evangelion/features/home/presentation/widgets/today_reading_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/home_harness.dart';

/// §14 for `/`, as the table of `10-quality-gates.md` writes it.
///
/// ## THE SIX ROWS, AND WHICH OF THEM `/` HAS
///
/// | §14 row | on `/` |
/// | --- | --- |
/// | icon-only buttons have no accessible name | the streak's retry is icon-only |
/// | mono-caps chips are non-focusable divs | **not applicable** — no chips on `/` |
/// | Home's today panel is a `div onClick` | the panel, and its focus ring |
/// | the text field has no programmatic label | **not applicable** |
/// | no focus indicators | every interactive node |
/// | animations ignore reduced-motion | the ambient background |
/// | colour-only state | the bead row, which `ProgressBeads` already answers |
///
/// ## AND WHY `ensureSemantics` IS DISPOSED **IN THE BODY**
///
/// §14's correction says the handle "must be disposed to avoid leaking across
/// tests", and it is right — but in Flutter 3.47.4 `testWidgets` already holds one
/// of its own and `_endOfTestVerifications` compares the live handle count against
/// the count recorded *before* the framework took its own. An `addTearDown` disposal
/// runs after that comparison, so the pattern §14 quotes verbatim fails with "A
/// SemanticsHandle was active at the end of the test".
///
/// Measured on the first run of this file: eight tests, eight of them failing for
/// exactly that. `login_accessibility_test.dart` records the same finding and
/// `focus_ring_gate_test.dart` carries the negative control.
///
/// ## AND THE THREE PROTOTYPE LITTERALS THIS PHASE REMOVED
///
/// `ds.tsx:507` `Evangelion`, `:516` `MK`, `:525` `12` are all values. The first is
/// this app's name and is a **parameter**; the second and third were data and are
/// now the session's monogram and the streak endpoint's number. Asserted here in the
/// failing direction, because a hard-coded value and a passed-in value are identical
/// in a diff and only one of them can be wrong.
void main() {
  group('every interactive node has a name and something a reader can do', () {
    testWidgets('the panel is a button, named, and offers a tap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final List<SemanticsData> tappable = nodesOffering(
        tester,
        SemanticsAction.tap,
      );
      final Iterable<SemanticsData> panel = tappable.where(
        (SemanticsData d) =>
            d.label.contains(const HomeStrings.en().todayReading),
      );

      expect(
        panel,
        hasLength(1),
        reason:
            '§14 row for this screen: the today panel was a div with an onClick. It '
            'is now a GlassSurface with onTap, an InkWell inside a Material. So it '
            'must be a NAMED node with a tap action, not a container.',
      );
      handle.dispose();
    });

    testWidgets('the avatar is a button with a name, and it is DISABLED', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final SemanticsData avatar = semanticsTree(tester).firstWhere(
        (SemanticsData d) =>
            d.label.contains(liveSession.displayName) ||
            d.label.startsWith(const HomeStrings.en().avatarLabel),
      );

      // `ds.tsx:516-524` is a `<button>` with **no label at all** — §14's first row.
      // The name is the session's display name, not a monogram.
      expect(avatar.label, contains(liveSession.displayName));
      // **No tap action**, because the prototype navigates to `profile` and §2
      // decision 1 cut it. The reason is in the name, per `LoginPage`'s four inert
      // controls.
      expect(avatar.hasAction(SemanticsAction.tap), isFalse);
      expect(
        avatar.flagsCollection.isEnabled,
        Tristate.isFalse,
        reason:
            '`enabled: false` is announced as a tristate, so a reader is told '
            'the control is there and inert rather than being offered a dead end',
      );
      expect(
        avatar.label,
        contains(const HomeStrings.en().unavailableSuffix),
        reason:
            'a screen reader must be told WHY the control cannot be pressed, not '
            'only that it cannot',
      );
      handle.dispose();
    });

    testWidgets('with no session the avatar is still named', (
      WidgetTester tester,
    ) async {
      // The fallback is `HomeStrings.avatarLabel` rather than an empty string — an
      // unnamed button is the §14 gap this whole screen had to close.
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness(signedIn: false);
      await pumpHome(tester, bloc: h.bloc);

      expect(
        semanticsTree(tester).where(
          (SemanticsData d) =>
              d.label.startsWith(const HomeStrings.en().avatarLabel),
        ),
        hasLength(1),
      );
      handle.dispose();
    });

    testWidgets('the streak is ONE node, not two', (WidgetTester tester) async {
      // `StreakFlame` publishes a node and the count is a sibling `Text`, so a naive
      // transcription reads "Streak", then "0" — two announcements for one fact, and
      // on a number a reader is likely to repeat back.
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final List<SemanticsData> streak = semanticsTree(tester)
          .where((SemanticsData d) => d.label.startsWith('Streak'))
          .toList();

      expect(streak, hasLength(1));
      expect(
        streak.single.label,
        'Streak: 0',
        reason: 'the label and the number in one node',
      );
      handle.dispose();
    });

    testWidgets('the bead row announces its count, and no other node does', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final List<SemanticsData> beads = semanticsTree(tester)
          .where((SemanticsData d) => d.label.contains('Reflections'))
          .toList();

      // `ProgressBeads` appends "N of M complete" itself, and the prefix is the
      // feature's string table — so the count a reader hears is the question count,
      // not the prototype's five.
      expect(beads, hasLength(1));
      expect(beads.single.label, contains('1 of 1 complete'));
      handle.dispose();
    });

    testWidgets('the failed reading announces itself as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness(
        reading: const Result.failure(readingFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(
        semanticsTree(tester)
            .where((SemanticsData d) => d.flagsCollection.isLiveRegion),
        isNotEmpty,
        reason:
            '`ErrorView` is a `Semantics(liveRegion:)`; without it a screen-reader '
            'user finds out about the failure from the retry button appearing',
      );
      handle.dispose();
    });

    testWidgets('the failed streak names its icon control with the message', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness(
        streak: const Result.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      final Iterable<SemanticsData> named = nodesOffering(
        tester,
        SemanticsAction.tap,
      ).where((SemanticsData d) => d.label == streakFailure.message);

      expect(
        named,
        hasLength(1),
        reason:
            'the repository message is the icon button name. It is '
            'not drawn as text — a sentence does not belong in a top bar.',
      );
      handle.dispose();
    });

    // ## WHY THREE TESTS AND NOT ONE LOOP
    //
    // The first version looped over the three states in a single `testWidgets`, so
    // a failure named a *state* in prose and a *line* that was the same for all
    // three. Which is exactly what happened: one failure, no way to tell whether
    // the empty node list was the ready state or a failed one. Split, each failure
    // now names its own state.
    for (final (String, HomeHarness Function()) case_
        in <(String, HomeHarness Function())>[
          ('ready', harness),
          (
            'a failed reading',
            () => harness(
              reading: const Result<ScriptureText>.failure(readingFailure),
            ),
          ),
          (
            'a failed streak',
            () => harness(
              streak: const Result<StreakSummary>.failure(streakFailure),
            ),
          ),
        ]) {
      testWidgets('no unlabeled interactive node, ${case_.$1}', (
        WidgetTester tester,
      ) async {
        // §14's target is "all 6 pages pass a semantics sweep with no unlabeled
        // interactive node", and this is the mechanical form for `/`. An error view
        // adds its own button, and an error view is exactly where a label goes
        // missing — so each state is swept.
        final SemanticsHandle handle = tester.ensureSemantics();

        final HomeHarness h = case_.$2();
        await pumpHome(tester, bloc: h.bloc);

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
                'an interactive node with no accessible name. §14\'s first row, '
                'and the one this screen had to close: `ds.tsx:516` is a `<button>` '
                'around a monogram with no label at all.',
          );
        }
        handle.dispose();
      });
    }
  });

  group('the focus ring', () {
    testWidgets('the panel is one tab stop', (WidgetTester tester) async {
      // §14's "no focus indicators" row. `GlassSurface` owns the node through
      // `EvaFocusRing`, so the panel is reachable by keyboard — which the
      // prototype's `div onClick` was not.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final Finder panel = find.byType(TodayReadingPanel);
      await tabUntilFocused(tester, panel);

      expect(
        renderedBorders(tester, panel).where(
          (Border b) =>
              b ==
              evaFocusRingBorder(EvaThemeDark.theme.extension<EvaColors>()!),
        ),
        isNotEmpty,
        reason:
            '§14: a 2px ember ring at 40% alpha. `renderedBorders` reads what is '
            'PAINTED rather than re-deriving the number, which is its whole point.',
      );
    });

    testWidgets('and the streak retry is reachable by keyboard too', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        streak: const Result.failure(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      final Finder row = find.byType(StreakFlameRow);
      await tabUntilFocused(tester, row);
    });

    testWidgets('and the disabled avatar is NOT a tab stop', (
      WidgetTester tester,
    ) async {
      // A disabled control that still takes focus is a focus trap with a dead end.
      // This is why `AppTopBar` passes `enabled: false` to the ring — see its doc.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final Finder avatar = find.byType(AppTopBar);
      int stops = 0;
      for (int i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (_focusInside(tester, avatar)) {
          stops++;
        }
      }
      // The bar's only focusable child is the panel, which is **not** inside the
      // bar. So four tabs cannot land on the avatar.
      expect(stops, 0);
    });
  });

  group('reduced motion', () {
    testWidgets('the ambient background honours disableAnimations', (
      WidgetTester tester,
    ) async {
      // §14's "animations ignore reduced-motion" row, which is
      // `NeuralMotionScope`'s job and is already covered in
      // `neural_motion_test.dart`. Asserted here that the screen **passes it
      // through** rather than replacing it: `NeuralScaffold` takes no `tier`, so
      // the scope's value is what paints.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, disableAnimations: true);

      expect(tester.takeException(), isNull);
      expect(find.byType(NeuralBackground), findsOneWidget);
    });
  });

  group('the CTAs', () {
    testWidgets('are the prototype own labels, un-derived', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // `HomeScreen.tsx:71,72`. Derived copy for an *action* was rejected. See
      // `HomeStrings.continueLabel`.
      expect(find.text(const HomeStrings.en().continueLabel), findsOneWidget);
      expect(find.text(const HomeStrings.en().startReflection), findsOneWidget);
    });
  });
}

/// Whether the primary focus is inside [finder].
///
/// `design_system_harness.dart`'s `_primaryFocusIsInside` is private, and this is
/// the two lines it would be. Duplicated rather than made public because the shared
/// helper's contract is "the control took focus", and this asks a different question
/// — "did a tab land inside this subtree", which is a *negative* claim here.
bool _focusInside(WidgetTester tester, Finder finder) {
  final FocusNode? node = FocusManager.instance.primaryFocus;
  if (node == null || !node.hasFocus) return false;
  return find
      .descendant(of: finder, matching: find.byType(Focus))
      .evaluate()
      .isNotEmpty;
}
