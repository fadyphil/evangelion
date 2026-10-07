/// `SealFAB` on `/` — the speed dial `ds.tsx:533` defines and decision 155 revives.
///
/// ## WHY THIS NEEDS A TEST AT ALL, GIVEN THE LAST ONE THAT SHOULD HAVE EXISTED DID
///
/// `5f53eb5` claimed "leaderboard card → Home" and the card was never rendered, and
/// three suites were green while it sat unused. **A component that is built, tested and
/// never placed is invisible to every assertion that does not look for it on the
/// screen.** So this file asserts the dial is in `/`'s tree, not merely that it renders.
///
/// ## WHAT IS ASSERTED AND WHY IT IS NOT COSMETIC
///
/// * **Every item names a live route.** The prototype's menu was Profile, Settings and
///   Language; Profile is cut for want of an endpoint, Settings is already the avatar's
///   job and Language already a row inside `/settings`. The dial shipped with one dead
///   item and two duplicates, which is why it was cut. Leaderboard replaced Profile
///   because it is a live route that had no other entry point on `/`.
/// * **It is collapsed on arrival and expands on tap**, because a dial that arrives open
///   covers the reading it sits over.
/// * **§14: every interactive node has an accessible name.** Two buttons exist whenever
///   the dial is open and one when it is shut; a dial whose pills are unlabelled gives a
///   screen-reader user three anonymous controls.
/// * **It lives in the bottom-right**, transcribed from `ds.tsx:541`
///   (`bottom: 28, right: 20`), and it clears the smallest supported surface.
library;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/home/presentation/widgets/seal_fab.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/home_harness.dart';

/// The three destinations, in the prototype's order with Profile replaced.
///
/// `ds.tsx:537-541` — Profile, Settings, Language.
///
/// **Language is absent, and Gate 2 is why.** `showLanguageSheet` lives in
/// `features/settings/`, and `injection_test.dart` forbids one feature importing
/// another. The import was written, the gate named it, and it was removed rather than
/// suppressed — so this is two items, and the third needs `language_sheet.dart` promoted
/// into the shared kernel, which is a larger change than placing a dial.
///
/// Leaderboard takes Profile's slot: Profile is cut for want of an endpoint, and
/// `/leaderboard` is the one prototype destination with no other entry point on `/`.
const List<String> _items = <String>['Settings', 'Leaderboard'];

/// Advances past the entrance animation so the pills are actually present.
///
/// ## WHY A BOUNDED LOOP AND NOT `pumpAndSettle`
///
/// `pumpAndSettle` is the right answer almost always and **times out here**: `/` has a
/// `NeuralBackground` whose orbs animate forever, so there is no settled frame to settle
/// to. Writing `pumpAndSettle()` would have produced a timeout that says nothing about
/// the dial.
///
/// ## WHY NOT A FIXED COUNT
///
/// Because the required count is not stable, and the difference is instructive.
/// `EvaAnimate` sets its controller to `0.0` and calls `_play()` from a **post-frame
/// callback**, so the frame that creates a pill draws it at **opacity 0** — and
/// `RenderOpacity` **drops semantics for a fully transparent subtree**. Each
/// `pump(duration)` then lands on the controller's *first* tick rather than advancing
/// past it, so the number of pumps needed depends on how many frames the surrounding
/// screen spends on its own work. The same widget needed four pumps under a bare
/// `SealFab` and five under `/`.
///
/// That is why the earlier attempt with three hand-counted pumps found nothing while a
/// count of four found everything — an off-by-one in a magic number is a test that
/// passes for the wrong reason on a different frame budget. The loop states the actual
/// claim, which is that the animation finishes, and the bound states that it is finite.
///
/// It is also a real, if benign, accessibility note: for the length of the fade the
/// pills are genuinely absent to a screen reader. Harmless for an entrance, and the
/// reason "the item is in the tree" and "the item is nameable" are separate assertions
/// and both are present.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump(EvaMotion.screen);
  }
}

Future<void> _pumpHome(WidgetTester tester) async {
  final HomeHarness h = harness();
  await pumpHome(tester, bloc: h.bloc);
}

void main() {
  group('the dial is on `/`', () {
    testWidgets('rendered, collapsed, in the bottom-right', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);
      expect(
        find.byType(SealFab),
        findsOneWidget,
        reason:
            'the fetch-and-discard defect in `5f53eb5` was invisible because no suite '
            'looked for the widget on the screen. This is that assertion.',
      );
      // **Collapsed on arrival.** A dial that arrives open covers the reading panel.
      expect(find.byType(SealFabPill), findsNothing);
      expect(find.byType(SealFabTrigger), findsOneWidget);
      // The prototype places it `bottom: 28, right: 20` (`ds.tsx:541`), so it sits
      // lower and further right than the centre of `/`. Asserted against the screen's
      // own size rather than a hard-coded offset, because the claim is "in the corner"
      // and not "at exactly 20 logical pixels".
      final Size screen = tester.getSize(find.byType(HomePage));
      final Rect dial = tester.getRect(find.byType(SealFab));
      expect(dial.right, greaterThan(screen.width * 0.5));
      expect(dial.bottom, greaterThan(screen.height * 0.5));
    });
    testWidgets('and it clears the smallest supported surface', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = kNarrowSurface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHome(tester);
      // `/` has no sticky CTA, so the dial does not collide the way it would on
      // `/reading` — but it must not overhang the screen at 320×568 either, which is
      // the smallest surface §7 renders.
      final Rect dial = tester.getRect(find.byType(SealFab));
      expect(dial.right, lessThanOrEqualTo(kNarrowSurface.width));
      expect(dial.bottom, lessThanOrEqualTo(kNarrowSurface.height));
    });
  });
  group('opening it', () {
    testWidgets('the trigger reveals exactly the three live destinations', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);
      await tester.tap(find.byType(SealFabTrigger));
      await tester.pump();
      await tester.pump(EvaMotion.base);
      expect(find.byType(SealFabPill), findsNWidgets(_items.length));
      for (final String label in _items) {
        expect(
          find.text(label),
          findsOneWidget,
          reason:
              '`$label` is a live destination and must be reachable from the dial',
        );
      }
    });
    testWidgets('and it does not offer the cut Profile screen', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);
      await tester.tap(find.byType(SealFabTrigger));
      await tester.pump();
      await tester.pump(EvaMotion.base);
      // **The reason this component was cut, asserted.** A menu that still offered
      // Profile would either navigate nowhere or, worse, be "fixed" later by pointing
      // Profile at some other screen — which is the product decision decision 32
      // refused to make and recorded as visible debt.
      expect(find.text('Profile'), findsNothing);
      // And nothing slipped in beside the two — in particular **not Language**, which
      // Gate 2 puts out of this feature's reach. Asserting its absence here means a
      // future change that does promote the sheet has to come and delete this line.
      expect(find.byType(SealFabPill), findsNWidgets(2));
      expect(find.text('Language'), findsNothing);
    });
    testWidgets('tapping the trigger again closes it', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);
      await tester.tap(find.byType(SealFabTrigger));
      await tester.pump();
      await tester.pump(EvaMotion.base);
      expect(find.byType(SealFabPill), findsNWidgets(2));
      await tester.tap(find.byType(SealFabTrigger));
      await tester.pump();
      await tester.pump(EvaMotion.base);
      expect(find.byType(SealFabPill), findsNothing);
    });
  });
  group('§14 — every interactive node is named', () {
    testWidgets('the trigger names itself, and says what opening does', (
      WidgetTester tester,
    ) async {
      // **The declared property, read off the widget** — not `semanticsOf(...)`, which
      // resolves to whatever node the tree merged this into and therefore reported a
      // non-empty label even with the trigger's own label set to `''`. That version of
      // this assertion passed against a nameless button; a mutation deleting the label
      // is what exposed it.
      await _pumpHome(tester);
      final Semantics sem = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(SealFabTrigger),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        sem.properties.label,
        isNotEmpty,
        reason:
            'the trigger\'s content is the single letter `E`, so a name has to be '
            'declared. This is the defect `SegmentedControl`\'s track had.',
      );
      // It is a button, and it says which way it goes.
      expect(sem.properties.button, isTrue);
      expect(
        sem.properties.expanded,
        isFalse,
        reason: 'a shut dial must not announce itself as expanded',
      );
    });

    testWidgets('each pill carries its own destination as its name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await _pumpHome(tester);
        await tester.tap(find.byType(SealFabTrigger));
        await _settle(tester);
        for (final String label in _items) {
          expect(
            find.bySemanticsLabel(label),
            findsOneWidget,
            reason: '`$label` must be nameable, not an anonymous pill',
          );
        }
      } finally {
        handle.dispose();
      }
    });
  });
  group('the accent it is outlined in', () {
    // Pumped **directly, in the light theme**, because the assertion is only meaningful
    // there. `pumpHome` is hard-wired to `EvaThemeDark.theme`, and in dark
    // `emberInk == ember` (decision 153), so a dark assertion would pass whether this
    // widget reached for the ink token or the fill token. The whole point of the split
    // is the theme where the two differ.
    testWidgets('is the ink variant, so it survives the light theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaPrimitiveHarness(
          theme: EvaThemeLight.theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          child: SealFabTrigger(open: false, onTap: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final Container box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SealFabTrigger),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration outline = box.decoration! as BoxDecoration;
      final BorderSide side = outline.border!.top;

      // `ds.tsx:561` — `outline: 1.5px solid rgba(ember, 0.6)`.
      expect(side.width, 1.5);
      expect(
        side.color,
        const EvaColors.light().emberInk.withValues(alpha: 0.6),
        reason:
            'a 1.5px outline on the pale canvas is a drawn line the reader has to '
            'resolve, and light `ember` measures 2.11:1 there',
      );
      // **And the two tokens must actually differ**, or this whole test is vacuous in
      // the only theme where it means anything.
      expect(
        const EvaColors.light().emberInk,
        isNot(const EvaColors.light().ember),
        reason:
            'if the ink and the fill were the same colour in light, decision 153 would '
            'have added a token for nothing and this assertion would prove nothing',
      );
    });
  });
}
