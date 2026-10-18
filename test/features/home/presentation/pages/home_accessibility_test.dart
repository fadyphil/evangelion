import 'dart:ui' show Tristate;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/home/presentation/widgets/greeting_block.dart';
import 'package:evangelion/features/home/presentation/widgets/last_light_card.dart';
import 'package:evangelion/features/home/presentation/widgets/library_carousel.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/home/presentation/widgets/streak_chip.dart';
import 'package:evangelion/features/home/presentation/widgets/verse_of_the_day_card.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/home_harness.dart';

/// §14 for `/`, as the table of `10-quality-gates.md` writes it.
///
/// ## THE SIX ROWS, AND WHICH OF THEM `/` HAS **NOW**
///
/// | §14 row | on `/` |
/// | --- | --- |
/// | icon-only buttons have no accessible name | the streak's retry, named with the repository's message |
/// | mono-caps chips are non-focusable divs | **not applicable** — the streak chip is not interactive at all |
/// | Home's today panel is a `div onClick` | the day's card, its focus ring, and the last-light card beside it |
/// | the text field has no programmatic label | **not applicable** |
/// | no focus indicators | every interactive node |
/// | animations ignore reduced-motion | the ambient background |
/// | colour-only state | **gone with the panel** — the redesign draws no state by colour |
///
/// ## AND WHAT THE REDESIGN ADDED, WHICH §14 HAS NO ROW FOR
///
/// Two of this screen's controls are **inert by design**: the selah circle (its
/// timer is Phase 7's) and every book card (`/reading` has no passage parameter).
/// §14's table cannot judge them — it is written for controls that *are* live — so
/// this file holds them to the rule `SocialAuthButton` and the login ghosts follow:
/// **a disabled button whose name says why**, so a screen-reader user is told the
/// control exists and that pressing it does nothing. A control that vanished would
/// satisfy §14 and inform nobody.
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
/// Measured on the first run of the previous version of this file: eight tests, eight
/// of them failing for exactly that. `login_accessibility_test.dart` records the same
/// finding and `focus_ring_gate_test.dart` carries the negative control.
void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();

  group('every interactive node has a name and something a reader can do', () {
    testWidgets("the day's card is a button, named, and offers a tap", (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final Iterable<SemanticsData>
      card = nodesOffering(tester, SemanticsAction.tap).where(
        // **`contains` and `toUpperCase()`, and both halves matter.** The card's
        // accessible name is the **merged** one — `VerseOfTheDayCard` passes
        // `semanticLabel: ''` so the node reads the eyebrow, the reference and
        // the verse (`:521-522`) and nothing else — and a merged label is the
        // *rendered* text, which `[dir=rtl] .mono{text-transform:none}` (`:136`)
        // leaves uppercased on the LTR arm. The name is `VERSE OF THE DAY …`
        // where the table says `verse of the day`.
        //
        // Worth stating rather than working around: a suite asserting against
        // the table's casing would read this card's accessibility as a function
        // of a CSS text-transform, which is a coupling this file's subject does
        // not want. `GlassSurface.semanticLabel` says why the empty string is a
        // statement rather than a sentinel.
        (SemanticsData d) =>
            d.label.contains(en.homeVerseOfTheDay.toUpperCase()),
      );

      expect(
        card,
        hasLength(1),
        reason:
            '§14 row for this screen: `#votdCard` (`:519`) is a `div` with an '
            "`onclick` and no name at all — the prototype's own line `:1318` binds "
            '`el(\'votdCard\').onclick` and the element has no text beyond two '
            'spans. It is now a `GlassSurface` with `onTap`, an `InkWell` inside a '
            '`Material` and a name.',
      );
      expect(
        card.single.flagsCollection.isEnabled,
        isNot(Tristate.isFalse),
        reason: 'and it is enabled, because there is a reading to open',
      );
      handle.dispose();
    });

    testWidgets(
      'the last-light card is the second named tap, and only when lit',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc);

        expect(
          nodesOffering(tester, SemanticsAction.tap).where(
            (SemanticsData d) =>
                d.label.contains(en.homeLastLight.toUpperCase()),
          ),
          hasLength(1),
          reason:
              '`:524` is a `.hcard` with a tap too, so §14 has two of them on this '
              'screen and both must be named.',
        );
        handle.dispose();
      },
    );

    testWidgets('an EMPTY last light is not a button at all', (
      WidgetTester tester,
    ) async {
      // `redesign.html:1197` — `cursor: default` when there is no `lastRead`. The
      // tap is removed, so the node is removed with it; **not** a disabled button,
      // because there is nothing a reader could be told to do.
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness(
        history: const Right<Failure, List<StreakHistoryEntry>>(
          <StreakHistoryEntry>[],
        ),
      );
      await pumpHome(tester, bloc: h.bloc);

      expect(
        nodesOffering(tester, SemanticsAction.tap).where(
          (SemanticsData d) => d.label.contains(en.homeLastLight.toUpperCase()),
        ),
        isEmpty,
      );
      // And the sentence that replaces it is real text, so the state is announced
      // by reading rather than by an absence.
      expect(find.text(en.homeNoLight), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the streak is ONE node, not three', (
      WidgetTester tester,
    ) async {
      // `StreakFlame` publishes its own node and the count and the unit are sibling
      // `Text`s, so a naive transcription reads "Streak", then "0", then "days" —
      // three announcements for one fact, and on a number a reader is likely to
      // repeat back.
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final List<SemanticsData> streak = semanticsTree(tester)
          .where((SemanticsData d) => d.label.startsWith(en.homeStreakLabel))
          .toList();

      expect(
        streak,
        hasLength(1),
        reason:
            'one node, and it is not a button — nothing on `/` opens a streak '
            '(`:1320` gives the prototype a haptic and a toast, not a route, and '
            'the redesign gives this screen no streak screen at all)',
      );
      // The label **and** the number and the unit, in that order: the unit is inside
      // the node because `excludeSemantics` drops the painted `.sl`, and a bare
      // "Streak: 0" is a number with no unit.
      expect(streak.single.label, '${en.homeStreakLabel}: 0 ${en.homeDays}');
      handle.dispose();
    });

    testWidgets('the failed reading announces itself as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness(
        reading: const Left<Failure, ScriptureText>(homeReadingFailure),
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
        streak: const Left<Failure, StreakSummary>(streakFailure),
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
            'the repository message is the icon button\'s name. It is not drawn as '
            'text — a sentence does not belong in a 33px pill.',
      );
      handle.dispose();
    });

    // ## WHY THREE TESTS AND NOT ONE LOOP
    //
    // The first version looped over the states in a single `testWidgets`, so a
    // failure named a *state* in prose and a *line* that was the same for all of
    // them. Which is exactly what happened: one failure, no way to tell whether the
    // empty node list was the ready state or a failed one. Split, each failure now
    // names its own state.
    for (final (String, HomeHarness Function()) case_
        in <(String, HomeHarness Function())>[
          ('ready', harness),
          (
            'a failed reading',
            () => harness(
              reading: const Left<Failure, ScriptureText>(homeReadingFailure),
            ),
          ),
          (
            'a failed streak',
            () => harness(
              streak: const Left<Failure, StreakSummary>(streakFailure),
            ),
          ),
          (
            'an empty last light',
            () => harness(
              history: const Right<Failure, List<StreakHistoryEntry>>(
                <StreakHistoryEntry>[],
              ),
            ),
          ),
        ]) {
      testWidgets('no unlabeled interactive node, ${case_.$1}', (
        WidgetTester tester,
      ) async {
        // §14's target is "all 7 pages pass a semantics sweep with no unlabeled
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
                "an interactive node with no accessible name. §14's first row, and "
                'the one this screen has to keep closed: `:519` is a `<div>` with '
                'an `onclick` and no text of its own beyond two spans.',
          );
        }
        handle.dispose();
      });
    }
  });

  group('the inert controls say why', () {
    testWidgets('the selah circle is a disabled button, named with the reason', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final SemanticsData circle = _named(
        tester,
        '${en.homeSelah} — ${en.homeUnavailableSuffix}',
      );
      expect(circle.flagsCollection.isButton, isTrue);
      // **Disabled, not absent**: a screen-reader user is told the control exists
      // and that it is inert. `SocialAuthButton`'s rule, and the login ghosts'.
      expect(circle.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        circle.hasAction(SemanticsAction.tap),
        isFalse,
        reason:
            'and it offers no tap, because there is nothing behind one until Phase 7 '
            'brings the timer',
      );
      handle.dispose();
    });

    testWidgets('every book card is a disabled button, named with its caption', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // The strip builds what fits, so this reads **psalms** and not all six —
      // `home_page_test.dart` is the suite that counts them, and it drags.
      final SemanticsData card = _named(
        tester,
        'psalms · ${en.homeCategoryPoetry} · 6 ${en.homeVerses} — '
        '${en.homeUnavailableSuffix}',
      );
      expect(card.flagsCollection.isButton, isTrue);
      expect(card.flagsCollection.isEnabled, Tristate.isFalse);
      // **The caption is in the name**, because `excludeSemantics` drops the two
      // painted runs and a reader who cannot see them would hear only the name.
      expect(card.label, contains('6 ${en.homeVerses}'));
      handle.dispose();
    });

    testWidgets(
      'and a card with no name would fail, so the reason is asserted',
      (WidgetTester tester) async {
        // The negative control, and the reason this file has it: a `Semantics(button:
        // true, enabled: false)` with no `label` publishes a node whose only content
        // is "button, disabled" — which passes §14's sweep (the node is not empty,
        // because its flags are not text) and tells a reader nothing. Asserting the
        // label's *content* is what closes that.
        final SemanticsHandle handle = tester.ensureSemantics();

        final HomeHarness h = harness();
        await pumpHome(tester, bloc: h.bloc);

        for (final SemanticsData node in semanticsTree(tester).where(
          (SemanticsData d) => d.flagsCollection.isEnabled == Tristate.isFalse,
        )) {
          expect(
            node.label,
            contains(en.homeUnavailableSuffix),
            reason:
                'every disabled node on this screen carries the reason it is '
                'disabled. A disabled node without one is the failure mode §14 cannot '
                'see.',
          );
        }
        handle.dispose();
      },
    );
  });

  group('the focus ring', () {
    testWidgets("the day's card is one tab stop with a painted ring", (
      WidgetTester tester,
    ) async {
      // §14's "no focus indicators" row. `GlassSurface` owns the node through
      // `EvaFocusRing`, so the card is reachable by keyboard — which the
      // prototype's `div onClick` was not.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      final Finder card = find.byType(VerseOfTheDayCard);
      await tabUntilFocused(tester, card);

      expect(
        renderedBorders(tester, card).where(
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

    testWidgets('and the last-light card is a tab stop for the same reason', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      await tabUntilFocused(tester, find.byType(LastLightCard));
    });

    testWidgets('and the streak retry is reachable by keyboard too', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        streak: const Left<Failure, StreakSummary>(streakFailure),
      );
      await pumpHome(tester, bloc: h.bloc);

      await tabUntilFocused(tester, find.byType(StreakChip));
    });

    testWidgets('and the inert controls are **not** tab stops', (
      WidgetTester tester,
    ) async {
      // §14's rule for a disabled control, and the reason it is asserted here
      // rather than only implied: "a disabled control that still takes focus is a
      // focus trap with a dead end". The selah circle and the book cards are both
      // inert, so neither may appear in the tab order — the inverse of the avatar
      // case the previous version of this file recorded, and the same rule read
      // from the other side.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      expect(
        find.byType(SelahCard),
        findsOneWidget,
        reason: 'and the card is on screen, so this is not vacuous',
      );
      for (int i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final FocusNode? node = FocusManager.instance.primaryFocus;
        if (node == null || !node.hasFocus) continue;
        expect(
          _focusInside(tester, find.text('✦')),
          isFalse,
          reason: 'press $i landed inside the inert circle',
        );
      }
    });

    testWidgets('and the greeting is one focus-free block', (
      WidgetTester tester,
    ) async {
      // The greeting holds no control, so it must not be a stop — asserted because a
      // `Text` inside an `Expanded` inside a `Row` is a place a stray `Focus` could
      // hide, and `GreetingBlock` is a public widget now.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      for (int i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          _focusInside(tester, find.byType(GreetingBlock)),
          isFalse,
          reason: 'press $i landed inside the greeting block',
        );
      }
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

    testWidgets('and the carousel\'s strip does not animate on its own', (
      WidgetTester tester,
    ) async {
      // `.bcard:hover{transform: translateY(-5px)}` (`:283`) and
      // `.selah .breathing{animation: breatheRing 8s …}` (`:269`) are **CSS
      // animations this client does not reproduce**: the first is a hover the
      // design system already owns through `EvaInk`, and the second belongs to
      // Phase 7's timer. The assertion is that mounting the strip with animations
      // disabled produces no exception and no ticker, which is the form §14 takes.
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc, disableAnimations: true);

      expect(find.byType(LibraryCarousel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("the day's card is the prototype's own words", () {
    testWidgets('and the eyebrow and the reference are one announcement', (
      WidgetTester tester,
    ) async {
      // `:521` writes three children — a `<span>`, a text ` · ` and a `<b>` — inside
      // one `.mono` div. Three siblings would be three runs; the card joins them
      // into one `Text.rich`, and a screen reader reads the sentence.
      final SemanticsHandle handle = tester.ensureSemantics();

      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);

      // **Uppercase, because the merged label is the *rendered* text.** The eyebrow
      // is a `.mono` run and `[dir=rtl] .mono{text-transform:none}` (`:136`) leaves
      // LTR uppercasing in force, so the label says `JOHN 3:1-5` where the table says
      // `John 3:1-5`. Searching for the table's casing finds nothing — which is what
      // the first version of this row did, and why this comment exists.
      final Iterable<SemanticsData> naming = semanticsTree(tester)
          .where((SemanticsData d) => d.label.contains('JOHN 3:1-5'));
      expect(
        naming,
        hasLength(2),
        reason:
            "exactly two: the day's card and the last-light card, because both "
            'name the same reading. One per card would be an assertion about the '
            'fixture rather than about the widget.',
      );
      // And **neither announces its own eyebrow twice**, which is what
      // `semanticLabel: ''` buys: the merged name begins with the rendered eyebrow
      // rather than carrying the table's lowercase one in front of it.
      for (final SemanticsData node in naming) {
        expect(
          node.label.trimLeft(),
          anyOf(
            startsWith(en.homeVerseOfTheDay.toUpperCase()),
            startsWith(en.homeLastLight.toUpperCase()),
          ),
          reason:
              'a card named twice announces its eyebrow twice. `GlassSurface`\'s '
              'doc says which gate catches that, and it is this suite.',
        );
      }
      handle.dispose();
    });
  });
}

/// The one [SemanticsData] whose label is [label].
///
/// Read through the shared `semanticsTree` walk rather than `getSemantics`: this
/// file asserts on a *label*, and `getSemantics` needs a `SemanticsNode` that is
/// uniquely findable by type.
SemanticsData _named(WidgetTester tester, String label) {
  final Iterable<SemanticsData> matches = semanticsTree(tester)
      .where((SemanticsData data) => data.label == label);
  expect(matches, hasLength(1), reason: 'exactly one node announces `$label`');
  return matches.single;
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
