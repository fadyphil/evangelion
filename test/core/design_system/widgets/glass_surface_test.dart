import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

Widget _onSurface(
  Widget child, {
  ThemeData? theme,
  Size size = const Size(320, 240),
}) => evaAmbientHarness(
  theme: theme,
  child: SizedBox(
    width: size.width,
    height: size.height,
    child: Center(child: child),
  ),
);

/// A busy backdrop, so a `.blur` surface has something to blur.
///
/// A flat fill behind a `BackdropFilter` blurs to the same flat fill, and
/// `GlassTier.blur` would then be indistinguishable from [GlassTier.tint] — which
/// is precisely the mistake the "the two goldens must differ" requirement exists
/// to catch. Every blur assertion here therefore runs over [Backdrop].
const Widget _busy = _BusyBackdrop();

class _BusyBackdrop extends StatelessWidget {
  const _BusyBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF000000),
          Color(0xFFFFFFFF),
          Color(0xFFFF0000),
        ],
        stops: <double>[0, 0.5, 1],
      ),
    ),
    child: SizedBox.expand(),
  );
}

/// ## WHY THERE IS NO `tester.ensureSemantics()` HERE
///
/// `09-quality-gates.md` §14's correction says the working pattern per page is
/// `final handle = tester.ensureSemantics(); … handle.dispose();`, and it is
/// right that a handle must not leak. It is not needed for these assertions:
/// `AutomatedTestWidgetsFlutterBinding` turns the semantics tree **on** for every
/// `testWidgets`, so `find.bySemanticsLabel` and `tester.getSemantics` work
/// without one. Asking for a handle anyway is not harmless in both directions —
/// leaving it to `addTearDown` trips "a SemanticsHandle was active at the end of
/// the test", and disposing it in the body trips
/// `'_outstandingHandles > 0': is not true`, because the framework already
/// balanced the one it was holding.

/// A glass panel whose content **shrink-wraps**, which is what makes the
/// `Stack`'s fit observable at all.
///
/// The sibling tests in `GlassSurface.tint` pass `SizedBox(width: 40, height: 20)`
/// as the content and therefore cannot see a loosened constraint: a `SizedBox` is
/// `additionalConstraints`, and `BoxConstraints.enforce` collapses it back to
/// whatever cell it is in. [kNarrowSurface]-wide `Row` + `Expanded` gives this one
/// a *tight* width while the `Column` below shrink-wraps to its own child, so
/// `passthrough` (160 × 20), `loose` (20 × 20) and `expand` (160 × 568) are three
/// different answers.
///
/// `EdgeInsets.zero` so the numbers are the cell rather than the cell minus 40 —
/// the padding is asserted by the test beside it, and two things at once would be
/// two things to reason about.
const Widget _shrinkWrappingPanel = GlassSurface(
  padding: EdgeInsets.zero,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[SizedBox(width: 20, height: 20)],
  ),
);

void main() {
  group('GlassTier is an enum, not a bool', () {
    test('has exactly the three treatments §13.4 budgets', () {
      // The name says "three" and the list has three. `glass_blur_budget_test.dart`
      // records why a correction to a gate has to reach every string the gate can
      // print, and this is the same rule one layer up: a test named "the two
      // treatments" that enumerates three is the kind of mismatch a reader trusts
      // the name over.
      expect(GlassTier.values, <GlassTier>[
        GlassTier.tint,
        GlassTier.blur,
        GlassTier.bloom,
      ]);
    });

    test('tint is the default, because it is right on four of six screens', () {
      const GlassSurface surface = GlassSurface(child: SizedBox.shrink());
      expect(surface.tier, GlassTier.tint);
    });
  });

  group('GlassSurface.tint', () {
    testWidgets('paints the fill, rim and ambient from tokens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      const EvaColors colors = EvaColors.dark();
      expect(decoration.color, colors.glassFill);
      expect((decoration.border! as Border).top.color, colors.glassBorder);
      expect((decoration.border! as Border).top.width, 1);
      expect(decoration.boxShadow!.single.color, colors.glassShadow);
      expect(decoration.boxShadow!.single.offset, const Offset(0, 4));
      expect(decoration.boxShadow!.single.blurRadius, 24);
    });

    testWidgets('has no BackdropFilter anywhere in its subtree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
        reason: '§13.4 — a tint is not a saveLayer',
      );
    });

    testWidgets('rounds its corners to EvaRadii.card by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(EvaRadii.card),
      );
    });

    testWidgets('pads to EvaSpacing.card', (WidgetTester tester) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox.shrink())),
      );
      final Padding padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(EvaSpacing.card));
      expect(EvaSpacing.card, 20.0);
    });

    testWidgets('can drop the rim', (WidgetTester tester) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(border: false, child: SizedBox.shrink())),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).border, isNull);
    });

    // -------------------------------------------------------------------------
    // THE SIZING CONTRACT, MEASURED ON THE CONTENT.
    //
    // Both tests below exist because the one test that used to state this was
    // structurally blind: it read `tester.getSize(find.byType(GlassSurface))`,
    // the OUTER box, under a fixture whose answer is the same whatever the
    // `Stack`'s fit is. So it was green while `StatTile` had lost 109px of width
    // per tile. The property is the INNER box — the widget inside the `Padding`
    // — because that is the one the `Stack` moved.
    // -------------------------------------------------------------------------

    testWidgets('the content gets the panel\'s OWN constraints, not loosened ones', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS FIXTURE, AND WHY NOT THE ONE THE TINT GOLDENS USE
      //
      // A child that *fills* what it is handed cannot see a loosened
      // constraint. `SizedBox` is `additionalConstraints`, so
      // `SizedBox(width: 40, height: 20)` inside an `Expanded` is collapsed
      // back to the cell by `BoxConstraints.enforce` — which is precisely why
      // `goldens/glass_surface_tint_*.png` stayed byte-identical when
      // 143dc56 slipped a `Stack` in at its default `StackFit.loose`, and why
      // the test that guarded those goldens could not go red.
      //
      // So the child here **shrink-wraps**: a `Column` whose own child is 20
      // wide. The parent is a `Row` of two `Expanded`, which makes the width
      // **tight** — 160 each at [kNarrowSurface] — and leaves the height
      // **loose**. Under `passthrough` the `Padding` is therefore `160 × 20`;
      // under `loose` it would be `20 × 20` (the child shrink-wrapped); under
      // `expand` it would be `160 × 568` (the whole cell). Three different
      // numbers, so no fit other than the right one can satisfy this.
      await pumpPrimitive(
        tester,
        const Row(
          children: <Widget>[
            Expanded(child: _shrinkWrappingPanel),
            Expanded(child: _shrinkWrappingPanel),
          ],
        ),
      );

      final Finder padding = find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(Padding),
      );
      expect(
        padding,
        findsNWidgets(2),
        reason:
            'one content `Padding` per surface, found as a descendant of '
            'GlassSurface so an unrelated `Padding` higher in the harness '
            'cannot be measured instead',
      );

      for (int i = 0; i < 2; i++) {
        // Read as two numbers, never as a `Size`: a constrained size is a
        // `_DebugSize` and `Size` equality requires an identical `runtimeType`,
        // so `expect(size, const Size(…))` can never pass.
        final Size size = tester.getSize(padding.at(i));
        expect(
          size.width,
          closeTo(kNarrowSurface.width / 2, 1e-9),
          reason:
              'the tight width of the cell must reach the content unchanged. '
              'Measured at `StackFit.loose`, this was 20 — the panel measured '
              'the width of its own content instead of the width it was given, '
              'which is the regression `StatTile` shipped.',
        );
        expect(
          size.height,
          closeTo(20, 1e-9),
          reason:
              'the height was already loose and must stay loose, so this also '
              'rules out `StackFit.expand` — a gate that only pinned the width '
              'would be satisfied by a `Stack` that fills instead of one that '
              'passes its constraints through',
        );
      }
    });

    testWidgets(
      'StatTile — the consumer this actually broke — measures its whole cell',
      (WidgetTester tester) async {
        // The same fixture as `goldens/stat_tile_{dark,light}.png`
        // (`surfaces_test.dart`'s), because those two goldens are the *evidence*:
        // at `StackFit.loose` they diffed by 2177px (1.20%) — the three panels
        // had been re-drawn to the width of their own text.
        //
        // `StatTile` is the interesting consumer because it is the one shape
        // that can see the difference: an `Expanded` in a `Row` (a **tight**
        // width, which is the contract) wrapping a
        // `Column(mainAxisSize: MainAxisSize.min)` (which **shrink-wraps**, so
        // the contract is observable). A consumer that filled its box would
        // pass either way, and that is the whole reason a shipped regression got
        // through.
        await pumpPrimitive(
          tester,
          const Align(
            alignment: Alignment.topCenter,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(value: '14', label: 'Read'),
                ),
                Expanded(
                  child: StatTile(value: '9', label: 'Reflected'),
                ),
                Expanded(
                  child: StatTile(value: '5/5', label: 'Best'),
                ),
              ],
            ),
          ),
        );

        final Finder padding = find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Padding),
        );
        expect(padding, findsNWidgets(3));

        for (int i = 0; i < 3; i++) {
          final Size size = tester.getSize(padding.at(i));
          expect(
            size.width,
            closeTo(kNarrowSurface.width / 3, 1e-9),
            reason:
                'tile $i must be as wide as the cell its `Expanded` gives it. '
                'Measured at `StackFit.loose` the three read 50.8, 89.3 and '
                '54.3 — each tile the width of its own caption.',
          );
        }
        // The height is a "nothing **else** moved" guard: a fix that made the content
        // fill the cell would satisfy the widths above and break this, which is
        // what caught nothing before.
        //
        // **Was 72, now 58, and the type change is the only reason.** The old
        // tile drew its figure in the display serif at 24 (`ds.tsx:474`);
        // `redesign.html:407-408` replaced it with mono 11 over a mono 8.5
        // caption, so the content is 14px shorter and the row is 14px shorter.
        // The width above is untouched, which is the part of this test that was
        // written to catch `StackFit.loose` — the whole cell is still filled.
        expect(
          tester.getSize(padding.at(0)).height,
          closeTo(58, 1e-9),
          reason:
              '11 (`:407`\'s value) + 4 + the `:408` caption line, plus 14 of '
              'padding above and below',
        );
      },
    );
  });

  group('GlassSurface.blur', () {
    testWidgets('puts exactly one BackdropFilter in the subtree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(tier: GlassTier.blur, child: SizedBox.shrink()),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
        reason:
            '§13.4 — every blur is one saveLayer, so the count is the budget',
      );
    });

    testWidgets('publishes the sigma, as far as the SDK can be asked', (
      WidgetTester tester,
    ) async {
      // `ImageFilter.blur` exposes no getter for its sigma, so the *number*
      // cannot be read back off the filter: `kGlassBlurSigma` is asserted here as
      // a constant and the filter as an `ImageFilter`, and the sigma itself is
      // pinned by the golden pair below. The name says so rather than claiming a
      // round trip that does not exist.
      //
      // **`24`, and it is the prototype's own number for this surface.** It used to
      // be `20`, justified as "the median of the eight prototype radii" — which was
      // false of the list it gave (the median of `8, 12, 12, 16, 16, 20, 20, 24` is
      // 16) and of the sites it named (Home's panel is `HomeScreen.tsx:39`'s
      // `blur(24px)`, not `20`). Only one site blurs, so there was never a
      // compromise to make; `glass_surface.dart`'s doc carries the whole correction.
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(tier: GlassTier.blur, child: SizedBox.shrink()),
        ),
      );
      final BackdropFilter filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(kGlassBlurSigma, 24.0);
      expect(filter.filter, isA<ui.ImageFilter>());
    });

    testWidgets('the tint and blur goldens DIFFER over a busy backdrop', (
      WidgetTester tester,
    ) async {
      // Two captures in one body, and that is safe **here**: swapping a
      // `GlassTier` is not a theme change, so there is no `AnimatedTheme` lerp
      // to out-run. `streak_flame_test.dart` documents the mechanism and the
      // case where the same arrangement is not safe.
      tester.view.physicalSize = const Size(240, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pump(GlassTier tier, String name) async {
        await tester.pumpWidget(
          evaAmbientHarness(
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: _busy),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassSurface(
                      tier: tier,
                      padding: EdgeInsets.zero,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(GlassSurface),
          matchesGoldenFile('goldens/glass_surface_$name.png'),
        );
      }

      await pump(GlassTier.tint, 'tint');
      await pump(GlassTier.blur, 'blur');
    });

    testWidgets('the two surfaces differ in pixels, not just in the tree', (
      WidgetTester tester,
    ) async {
      // The golden pair above is the record; this is the reason it must differ.
      // Without a busy backdrop a blur of a flat fill is the fill, and the pair
      // would be two identical images.
      tester.view.physicalSize = const Size(240, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget surface(GlassTier tier) => evaAmbientHarness(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _busy),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GlassSurface(
                  tier: tier,
                  padding: EdgeInsets.zero,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(surface(GlassTier.tint));
      await tester.pump();
      final List<int> tint = await _screenPixels(tester);

      await tester.pumpWidget(surface(GlassTier.blur));
      await tester.pump();
      final List<int> blur = await _screenPixels(tester);

      expect(tint.length, blur.length);
      expect(
        tint.toString(),
        isNot(blur.toString()),
        reason: 'a BackdropFilter over a gradient must change the pixels',
      );
    });
  });

  group('GlassSurface.bloom', () {
    // The `.bloom` wash is the only [RadialGradient] this widget builds and the
    // `.hor` seam the only [LinearGradient], so both are found *by their gradient
    // type* rather than by index or position. An index would go stale the moment a
    // layer is inserted, and a positional finder would still pass if the wash were
    // painted on top of the content.
    Finder wash() => find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is RadialGradient,
      ),
    );

    Finder seam() => find.descendant(
      of: find.byType(GlassSurface),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is LinearGradient,
      ),
    );

    BoxDecoration decorationOf(WidgetTester tester, Finder f) =>
        tester.widget<DecoratedBox>(f).decoration as BoxDecoration;

    /// A surface big enough that 72% of it is not the same number as 2.
    const Widget panel = SizedBox.expand();

    testWidgets('paints ONE radial gradient, centred at 50% 100%', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(tier: GlassTier.bloom, child: panel)),
      );
      expect(wash(), findsOneWidget, reason: 'one wash, or it is a smear');
      final RadialGradient g =
          decorationOf(tester, wash()).gradient! as RadialGradient;

      // `redesign.html:254` — `radial-gradient(ellipse at 50% 100%, …)`.
      //
      // ## WHY THIS COMPARES AGAINST A `FractionalOffset` AND NOT AN `Alignment`
      //
      // The constant is typed `Alignment` because `RadialGradient.center` is
      // `AlignmentGeometry`, and the previous version of this test re-read the
      // `Alignment`'s own `x`/`y` back into a `FractionalOffset` to "prove" they
      // were the same. That round trip is the exact operation that **manufactured**
      // the bug it was checking: `FractionalOffset extends Alignment` *converting*
      // on the way in (`painting/fractional_offset.dart:56`,
      // `super(dx * 2.0 - 1.0, dy * 2.0 - 1.0)`), so it is not an identity, and
      // the assertion compared `Alignment(0.5, 1)` to `FractionalOffset(1.0, 2.0)`
      // — a value to itself, and green while the wash sat at 75% of the width.
      //
      // This compares the two constants directly, which is the only comparison
      // that can fail:
      expect(kGlassBloomCenter, const FractionalOffset(0.5, 1.0));
      expect(g.center, kGlassBloomCenter);
      // …and the two conventions disagree, pinned so the equality above cannot be
      // satisfied by accident by a value that happens to be both.
      expect(kGlassBloomCenter, isNot(const Alignment(0.5, 1)));

      expect(g.colors.first, const EvaColors.dark().bloom);
    });

    testWidgets('the wash renders horizontally CENTRED, not three-quarters across', (
      WidgetTester tester,
    ) async {
      // The rendered half of the claim, because a constant comparison only proves
      // the widget holds the constant it holds. Measured off the pixels: the wash
      // is the only magenta thing on the panel (`EvaColors.dark().bloom` is
      // `0x8CE457D6` — R = B ≫ G; the seam is white and the glass fill is
      // neutral), so a magenta-weighted centroid is the wash's own centre of mass.
      tester.view.physicalSize = const Size(280, 180);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        evaAmbientHarness(
          child: const RepaintBoundary(
            child: SizedBox(
              width: 280,
              height: 180,
              child: GlassSurface(
                tier: GlassTier.bloom,
                padding: EdgeInsets.zero,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final Offset centroid = await _washCentroid(
        tester,
        find.byType(RepaintBoundary).first,
        const Size(280, 180),
      );
      // `at 50% 100%` — half of 280 is 140. A gradient centred at `x = 0.5` in
      // `Alignment` coordinates is at 0.75 of the width, i.e. **210**, and that is
      // the number the shipped constant produced.
      expect(centroid.dx, closeTo(140, 1.5));
      // Tolerance is 1.5px, and it is here because the centroid is a *pixel*
      // measurement of a sample that excludes the seam: the seam's own white bar
      // sits across the gradient's midline and is rejected by the magenta test,
      // so what is left is not quite symmetric about `x = 140`. Measured on the
      // fixed constant: `Offset(139.5, 152.5)`, i.e. **49.8%** of 280. (The y is
      // not asserted: the gradient's centre is the panel's **bottom edge**
      // (`at … 100%`), so an intensity-weighted centroid sitting at 85% of the
      // height is a property of the fade stop, not a position worth pinning.)
      //
      // `lessThan(0.6 × width)` is the belt to that `closeTo`'s braces: the two
      // are redundant for the right constant, and only the second one can tell a
      // reader that the failure is a *centre* failure rather than a rounding one.
      expect(centroid.dx, lessThan(const Size(280, 180).width * 0.6));
    });

    testWidgets('the wash fades to nothing at 68%, clamped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(tier: GlassTier.bloom, child: panel)),
      );
      final RadialGradient g =
          decorationOf(tester, wash()).gradient! as RadialGradient;

      // `redesign.html:254` — `… var(--bh, rgba(228,87,214,.55)), transparent 68%`
      // and `redesign.html:161` of `09-quality-gates.md` — "The prototype's
      // `blur(72px)` is achieved by a soft radial gradient with a wide transparent
      // stop". The wide stop is what stands in for `filter: blur(18px)`, so the
      // 68% is load-bearing and not a default.
      expect(g.stops, <double>[0, 0.68]);
      expect(g.stops!.last, kGlassBloomFadeStop);
      expect(g.colors.last, Colors.transparent);
      expect(
        g.tileMode,
        TileMode.clamp,
        reason:
            'clamp is what holds the transparent stop past the last stop instead '
            'of tiling the colour back over the panel',
      );
      // The wash reaches the full height of the surface and no further: a radius
      // of 1.0 is the whole of `rect.shortestSide`, and CSS's default radial
      // extent is `farthest-corner`.
      expect(g.radius, kGlassBloomRadius);
    });

    testWidgets('the wash is behind the content, inside the existing clip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(tier: GlassTier.bloom, child: panel)),
      );

      // Inside the SAME `ClipRRect` that rounds the panel — that is what makes the
      // prototype's `bottom:-46%` overflow a non-event.
      expect(
        find.descendant(of: find.byType(ClipRRect), matching: wash()),
        findsOneWidget,
      );
      final Stack stack = tester.widget<Stack>(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(Stack),
        ),
      );
      expect(stack.children.length, 3, reason: 'wash, seam, then the content');
      expect(stack.children.first, isA<Positioned>());
      expect(stack.children[1], isA<Positioned>());
      expect(
        stack.children.last,
        isA<Padding>(),
        reason:
            'the content is last, so it paints over the wash rather than under '
            'it — a `Stack` paints in order and this is the whole of "behind"',
      );
    });

    testWidgets('the seam is a 2px bar at 72% of the width, glowing at 14', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _onSurface(const GlassSurface(tier: GlassTier.bloom, child: panel)),
      );
      expect(tester.getSize(find.byType(GlassSurface)), const Size(320, 240));

      final BoxDecoration d = decorationOf(tester, seam());
      const EvaColors colors = EvaColors.dark();

      // `redesign.html:256-257` —
      // `left:14%;right:14%;bottom:20%;height:2px;border-radius:2px` and
      // `linear-gradient(90deg,transparent,rgba(255,255,255,.85),transparent)`
      final LinearGradient g = d.gradient! as LinearGradient;
      expect(g.begin, Alignment.centerLeft, reason: '`90deg` is left to right');
      expect(g.end, Alignment.centerRight);
      expect(g.colors, <Color>[
        Colors.transparent,
        colors.seam,
        Colors.transparent,
      ]);
      expect(g.stops, <double>[
        0,
        0.5,
        1,
      ], reason: 'three stops, evenly spaced');
      expect(d.borderRadius, const BorderRadius.all(Radius.circular(2)));

      // `box-shadow:0 0 14px rgba(255,255,255,.6)` — a PAINT. It is a shadow on
      // a `DecoratedBox`, not a `saveLayer`, so it costs nothing against §13.4's
      // budget, which is the reason the seam is allowed to glow at all.
      expect(d.boxShadow!.single.color, colors.seamGlow);
      expect(d.boxShadow!.single.blurRadius, 14);
      expect(d.boxShadow!.single.offset, Offset.zero);
      expect(d.boxShadow!.single.spreadRadius, 0);

      // …and the RENDERED box is the prototype's, not just the declared one:
      // 72% of 320 wide, 2 tall. Read as numbers: `Size` equality requires an
      // identical `runtimeType` and a `constrain`ed size is a `_DebugSize`, so
      // `expect(size, const Size(…))` can never pass.
      final Size seamSize = tester.getSize(seam());
      expect(seamSize.width, closeTo(230.4, 1e-9));
      expect(seamSize.height, 2.0);
      expect(kGlassSeamWidthFactor, 0.72);
      expect(kGlassSeamHeight, 2.0);
      expect(kGlassSeamCornerRadius, 2.0);

      // ## AND IT SITS AT `bottom:20%` — FROM THE **BOTTOM**
      //
      // Width and height are the two numbers that happened to be right while the
      // seam was mirrored, because neither depends on the alignment. The
      // alignment is the whole of `bottom:20%`, so it is asserted here on the
      // **rendered rect** and from the edge CSS names, not by re-deriving the
      // constant from the percentage the way the transcription test below used
      // to (`-1 + 2 × bottom/100` re-applied the same inverted arithmetic, so it
      // could not fail for any `bottom` value at all).
      final Size surface = tester.getSize(find.byType(GlassSurface));
      final Rect rect = tester.getRect(seam());
      final double fromBottom = surface.height - rect.bottom;
      expect(
        fromBottom,
        closeTo(surface.height * 0.20, 0.5),
        reason:
            '`redesign.html:256` says `bottom:20%` — the seam\'s bottom edge is '
            '20% of the panel height above the panel\'s bottom edge. 0.5px of '
            'tolerance is `b · h` — `Align` maps its alignment onto the FREE '
            'space, not onto the full height, so a `bottom`-derived constant '
            'lands 0.2 × 2 = 0.4px below the CSS position on any panel. '
            'Measured: $fromBottom of ${surface.height}.',
      );
      expect(
        rect.center.dy,
        greaterThan(surface.height / 2),
        reason:
            'the mirror of this bug is the same number read from the other '
            'edge: at `Alignment(0, -0.6)` the seam rendered 19.8% from the '
            'TOP, which also reads as "20%" if you never say which edge. This '
            'assertion names the half of the panel it has to be in.',
      );
      expect(
        kGlassSeamAlignment,
        const Alignment(0, 0.6),
        reason:
            'an `Alignment` y is centre-origin and +1 is the BOTTOM '
            '(`painting/alignment.dart:367`, `Alignment.bottomCenter`), so a '
            'CSS `bottom` fraction b is `y = 1 − 2b`. The `Alignment` doc for '
            'the subclass that made this confusing: `FractionalOffset extends '
            'Alignment` CONVERTING (`painting/fractional_offset.dart:56`).',
      );
      // …and the constant is NOT the CSS-convention translation of the same
      // number, so this cannot be satisfied by re-introducing the mirror.
      expect(kGlassSeamAlignment, isNot(const Alignment(0, -0.6)));
    });

    testWidgets('the caller\'s `--bh` reaches the gradient', (
      WidgetTester tester,
    ) async {
      const Color bh = Color(0xFF4FD1C5);
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(
            tier: GlassTier.bloom,
            bloomColor: bh,
            child: panel,
          ),
        ),
      );
      expect(
        (decorationOf(tester, wash()).gradient! as RadialGradient).colors.first,
        bh,
        reason:
            '`--bh` is set inline per host element — `redesign.html:519` puts '
            '`rgba(228,87,214,.55)` on `#votdCard` and `:524` a different '
            '`rgba(232,176,75,.35)` on `#lastCard`, so the colour cannot be a '
            'token',
      );
      // …and `null` means the prototype's own default, not "no colour".
      await tester.pumpWidget(
        _onSurface(const GlassSurface(tier: GlassTier.bloom, child: panel)),
      );
      expect(
        (decorationOf(tester, wash()).gradient! as RadialGradient).colors.first,
        const EvaColors.dark().bloom,
      );
    });

    testWidgets('the defaults did not move, and bloom spends no budget', (
      WidgetTester tester,
    ) async {
      const GlassSurface plain = GlassSurface(child: SizedBox.shrink());
      expect(plain.tier, GlassTier.tint);
      expect(
        plain.bloomColor,
        isNull,
        reason:
            'the TIER is the switch. A colour on its own paints nothing, so '
            '`GlassTier.bloom` cannot be un-reached by passing one',
      );

      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(bloomColor: Color(0xFF4FD1C5), child: SizedBox()),
        ),
      );
      expect(
        wash(),
        findsNothing,
        reason: 'the tier, not the colour, is the switch',
      );
      expect(seam(), findsNothing);

      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(tier: GlassTier.bloom, child: SizedBox()),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
        reason:
            '§13.4 budgets saveLayers and a wash is not one. `GlassTier.bloom` '
            'exists so the wash cannot be bought with a backdrop read-back',
      );
    });

    testWidgets('neither layer appears on a tint or a blur surface', (
      WidgetTester tester,
    ) async {
      for (final GlassTier tier in <GlassTier>[
        GlassTier.tint,
        GlassTier.blur,
      ]) {
        await tester.pumpWidget(
          _onSurface(GlassSurface(tier: tier, child: const SizedBox.expand())),
        );
        expect(wash(), findsNothing, reason: '$tier must not wash');
        expect(seam(), findsNothing, reason: '$tier must not seam');
      }
    });

    testWidgets('a bloom surface survives an unbounded height', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS SHAPE AND NOT THE THREE THAT WERE ALREADY COVERED
      //
      // Bounded, bounded, tight and `SizedBox.expand` all size the same, because
      // they all end up with finite constraints by the time they reach the
      // `Stack`. An **unbounded height** — what a `Column` hands a non-flexible
      // child — is the one shape that can reach `RenderStack` with
      // `maxHeight == double.infinity`, and `RenderStack._computeSize` asserts
      // `size.isFinite` there ("A Stack requires bounded constraints from its
      // parent"). The pre-bloom tree was `DecoratedBox > ClipRRect > Padding` and
      // `RenderDecoratedBox` has no such assert, so **the bloom's `Stack` is what
      // introduced the possibility of a debug crash here** — and a panel dropped
      // into a `Column` with no `SizedBox` around it is the most ordinary thing a
      // caller does.
      //
      // The tint path is not at risk (`it has no positioned children, so
      // `constraints.biggest` is never consulted), which is why this asserts the
      // bloom tier specifically: that is where the two `Positioned.fill` layers
      // are.
      await tester.pumpWidget(
        _onSurface(
          const Column(
            children: <Widget>[
              GlassSurface(
                tier: GlassTier.bloom,
                padding: EdgeInsets.zero,
                child: SizedBox(width: 100, height: 30),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason:
            'a `Column` gives a non-flexible child an unbounded height, and '
            '`RenderStack` asserts `size.isFinite` on one — so a bloom panel in a '
            'Column would be a debug-mode crash, not a layout that looks wrong',
      );
      // It also has to still be laid out *correctly*, not merely not throw: the
      // content sizes itself, and the two `Positioned.fill` layers fill the panel
      // they actually got rather than reaching for infinity.
      expect(tester.getSize(find.byType(GlassSurface)), const Size(100, 30));
      // It also has to still be laid out *correctly*, not merely not throw: the
      // content sizes itself, and the two `Positioned.fill` layers fill the panel
      // they actually got rather than reaching for infinity.
      final Rect seamRect = tester.getRect(seam());
      expect(seamRect.width, closeTo(72, 1e-9), reason: '72% of 100');
      // `Align` maps its alignment onto the FREE space: `0.8 × (30 − 2) = 22.4`.
      // The seam stays 6px above this panel's bottom edge (`30 − 24.4`), which is
      // the 20% the constant is for — and it is still **below the midpoint**,
      // which is the property the mirrored constant broke.
      expect(seamRect.top, closeTo(22.4, 1e-9));
      expect(seamRect.bottom, closeTo(24.4, 1e-9));
      expect(
        seamRect.center.dy,
        greaterThan(tester.getSize(find.byType(GlassSurface)).height / 2),
        reason: 'the seam belongs in the lower half of its panel, at any size',
      );
    });

    testWidgets('light seams gold and washes the same hue dark does', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(tier: GlassTier.bloom, child: panel),
          theme: EvaThemeLight.theme,
        ),
      );

      // `redesign.html:72` re-points `.hor` at the gold `rgba(154,123,25,.8)`
      // and its glow at `rgba(154,123,25,.5)`.
      final BoxDecoration d = decorationOf(tester, seam());
      expect(
        (d.gradient! as LinearGradient).colors[1],
        const EvaColors.light().seam,
      );
      expect(d.boxShadow!.single.color, const EvaColors.light().seamGlow);
      expect(d.boxShadow!.single.color, isNot(const EvaColors.dark().seamGlow));

      // …and light mode dims the wash with `opacity:.55` (`redesign.html:73`),
      // which since Phase 4.2 is [EvaColors.bloomOpacity] — a **token the widget
      // applies**, not caller state.
      //
      // **Multiply.** `redesign.html:254`'s gradient stop is itself
      // `rgba(228,87,214,.55)` — which is the alpha `EvaColors.bloom` carries as
      // `0x8C` — and `:73`'s `opacity:.55` is a *second* factor on the element.
      // A CSS opacity multiplies, so light is `.55 × .55 ≈ .302`, not `.55` and
      // not `.302` of a replaced channel. Replacing rather than multiplying is
      // what painted dark at 1.0 and diffed `glass_surface_bloom_dark.png` by
      // 46.07% on the first attempt; this test is the regression for it.
      expect(
        (decorationOf(tester, wash()).gradient! as RadialGradient).colors.first,
        const Color(0x8CE457D6).withValues(alpha: 0x8C / 255 * 0.55),
      );
      expect(
        const EvaColors.light().bloomOpacity,
        0.55,
        reason: '`redesign.html:73` — `opacity:.55`, on all four washes',
      );
      expect(
        const EvaColors.light().bloom,
        const EvaColors.dark().bloom,
        reason: '`redesign.html:73` changes `opacity`, never the `--bh` colour',
      );
    });

    testWidgets('the wash is undimmed in dark — `.55` is light\'s alone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(tier: GlassTier.bloom, child: panel)),
      );
      expect(const EvaColors.dark().bloomOpacity, 1.0);
      expect(
        (decorationOf(tester, wash()).gradient! as RadialGradient).colors.first,
        const EvaColors.dark().bloom,
        reason: 'at `bloomOpacity` 1.0 the alpha multiply is a no-op',
      );
    });

    // -----------------------------------------------------------------------
    // The seam's three parameters (Phase 4.2, decision 3).
    //
    // `.hor` is one of TWO prototype seams: `.opt::after` (`redesign.html:348-349`)
    // is at `bottom:0`, 84% wide and gold. A quiz option cannot draw `.hor`
    // unchanged, and a fifth `GlassTier` member would break
    // `glass_blur_budget_test`'s counting model — so the seam takes parameters.
    //
    // The claim under test is **two-sided and both halves matter**: the defaults
    // are `.hor`, and a caller who passes them produces the same pixels. The
    // second half is the one a parameter set can quietly fail — a default that
    // *approximates* `.hor` (say 0.70 rather than 0.72) is still "the default", and
    // the goldens would simply move with nobody reading a diff. That is why
    // `goldens/glass_surface_bloom_{dark,light}.png` were run unmodified after
    // these three parameters landed, and that is also what the first test below
    // pins by reading the constants rather than the pixels.
    // -----------------------------------------------------------------------
    group('the seam takes parameters, and its defaults are `.hor`', () {
      test(
        'the defaults are the prototype\'s `.hor` numbers, not near-misses',
        () {
          expect(
            kGlassSeamAlignment,
            const Alignment(0, 0.6),
            reason: 'bottom:20%',
          );
          expect(kGlassSeamWidthFactor, 0.72, reason: 'left:14%;right:14%');
          expect(
            const GlassSurface(child: SizedBox.shrink()).seamAlignment,
            isNull,
          );
          expect(
            const GlassSurface(child: SizedBox.shrink()).seamWidthFactor,
            isNull,
          );
          expect(const GlassSurface(child: SizedBox.shrink()).seamTint, isNull);
        },
      );

      testWidgets('a surface that names nothing resolves to `.hor`', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _onSurface(
            const GlassSurface(
              tier: GlassTier.bloom,
              padding: EdgeInsets.zero,
              child: SizedBox(width: 100, height: 30),
            ),
          ),
        );
        final Rect on = tester.getRect(find.byType(GlassSurface));
        expect(
          tester.getRect(seam()).width,
          closeTo(72, 1e-9),
          reason: '72% of 100',
        );
        // Measured against the surface, not the window — `_onSurface` centres the
        // panel, so an absolute `y` says which test harness this file uses and
        // nothing about the seam.
        expect(tester.getRect(seam()).top - on.top, closeTo(22.4, 1e-9));
        expect(
          (decorationOf(tester, seam()).gradient! as LinearGradient).colors[1],
          const EvaColors.dark().seam,
        );
      });

      testWidgets('`.opt::after` is expressible: bottom edge, 84%, gold', (
        WidgetTester tester,
      ) async {
        // `redesign.html:348` — `left:8%;right:8%;bottom:0`, and `:349`'s
        // `linear-gradient(90deg,transparent,var(--gold),transparent)`.
        await tester.pumpWidget(
          _onSurface(
            const GlassSurface(
              tier: GlassTier.bloom,
              padding: EdgeInsets.zero,
              seamAlignment: Alignment(0, 1),
              seamWidthFactor: 0.84,
              seamTint: Color(0xFFE8B04B),
              child: SizedBox(width: 100, height: 30),
            ),
          ),
        );

        final Rect rect = tester.getRect(seam());
        final Rect surface = tester.getRect(find.byType(GlassSurface));
        expect(
          rect.width,
          closeTo(84, 1e-9),
          reason: 'left:8%;right:8% of 100',
        );
        expect(
          rect.bottom,
          closeTo(surface.bottom, 1e-9),
          reason: '`bottom:0` is the surface\'s own bottom edge',
        );
        expect(
          rect.height,
          closeTo(2, 1e-9),
          reason:
              'the seam is still `height:2px` — the parameters move it, '
              'they do not resize it',
        );
        expect(
          (decorationOf(tester, seam()).gradient! as LinearGradient).colors[1],
          const Color(0xFFE8B04B),
          reason: 'the centre stop, and only the centre stop, takes the hue',
        );
        // Both outer stops stay transparent whichever hue the middle takes — both
        // prototype rules are `transparent, X, transparent`.
        final LinearGradient g =
            decorationOf(tester, seam()).gradient! as LinearGradient;
        expect(g.colors.first, Colors.transparent);
        expect(g.colors.last, Colors.transparent);
      });

      testWidgets('the parameters reach nothing but the bloom', (
        WidgetTester tester,
      ) async {
        // A tint surface has no seam at all, so no combination of the three can
        // make it grow one — the guard that keeps them from becoming a second
        // tier's worth of surface.
        await tester.pumpWidget(
          _onSurface(
            const GlassSurface(
              seamAlignment: Alignment(0, 1),
              seamWidthFactor: 0.84,
              seamTint: Color(0xFFE8B04B),
              child: panel,
            ),
          ),
        );
        expect(seam(), findsNothing);
      });
    });

    // -----------------------------------------------------------------------
    // The transcription claims, against the prototype they are transcribed from.
    //
    // AGENT_CONTEXT decision 8: "every transcription claim in this repository is a
    // claim a human verified by reading `eva/`". The prototype's own numbers are
    // parsed here rather than copied into a table, which is the mechanical half of
    // what `login_geometry_test.dart` does for `/login`.
    // -----------------------------------------------------------------------
    test('the wash and the seam numbers are the prototype\'s, read from it', () {
      final List<String> html = File('eva/redesign.html').readAsLinesSync();

      // `readAsLinesSync` is zero-based and every citation is one-based, so the
      // indices below are `line - 1`. Said once here rather than as six chances to
      // be wrong.
      expect(html[252], contains('.hcard .bloom{'));
      expect(html[252], contains('opacity:.85'));
      expect(html[253], contains('at 50% 100%'));
      expect(html[253], contains('var(--bh,'));
      expect(html[253], contains('transparent 68%'));
      expect(html[253], contains('filter:blur(18px)'));

      expect(html[255], contains('left:14%;right:14%;bottom:20%'));
      expect(html[255], contains('height:2px;border-radius:2px'));
      expect(html[256], contains('linear-gradient(90deg,transparent,'));
      expect(html[256], contains('rgba(255,255,255,.85)'));
      expect(html[256], contains('box-shadow:0 0 14px rgba(255,255,255,.6)'));

      // The light override, `redesign.html:72`.
      expect(html[71], contains('.hcard .hor'));
      expect(html[71], contains('rgba(154,123,25,.8)'));
      expect(html[71], contains('0 0 12px rgba(154,123,25,.5)'));
    });

    test('and the numbers the widget ships are those numbers', () {
      final List<String> html = File('eva/redesign.html').readAsLinesSync();

      // `height:2px` and `border-radius:2px` are two separate declarations on
      // `redesign.html:256` and they happen to be the same number — so they are
      // read as two, not as one.
      final RegExpMatch height = RegExp(r'height:(\d+)px')
          .firstMatch(html[255])!;
      final RegExpMatch radius = RegExp(r'border-radius:(\d+)px')
          .firstMatch(html[255])!;
      final RegExpMatch bottom = RegExp(r'bottom:(\d+)%')
          .firstMatch(html[255])!;
      final RegExpMatch left = RegExp(r'left:(\d+)%').firstMatch(html[255])!;
      final RegExpMatch right = RegExp(r'right:(\d+)%').firstMatch(html[255])!;
      final RegExpMatch fade = RegExp(r'transparent (\d+)%')
          .firstMatch(html[253])!;

      expect(kGlassSeamHeight, double.parse(height.group(1)!));
      expect(
        kGlassSeamWidthFactor,
        1 - (int.parse(left.group(1)!) + int.parse(right.group(1)!)) / 100,
      );
      expect(kGlassBloomFadeStop, double.parse(fade.group(1)!) / 100);
      // The seam's radius is the `border-radius` above, and it is NOT the height
      // just because the two read alike today.
      expect(radius.group(1), height.group(1));

      // ## `bottom:` IS NOT TRANSLATED HERE, AND THAT IS THE POINT
      //
      // The previous line was
      // `expect(kGlassSeamAlignment.y, -1 + 2 * int.parse(bottom.group(1)!) / 100)`
      // and it could not fail for **any** value of `bottom`: it re-applied the
      // very arithmetic that produced the bug, to the very number it was
      // supposed to check against, so the constant and the formula were the same
      // statement twice. It passed with `Alignment(0, -0.6)` — the seam rendered
      // 19.8% from the **top** — and it passes now for the same reason.
      //
      // So `bottom:20%` is asserted as the two things it can be asserted as, and
      // neither is a re-derivation:
      //
      // - as **text**, above: `expect(html[255], contains('bottom:20%'))`, which
      //   pins that the prototype still says what this widget is transcribing;
      // - as **rendered geometry**, in the seam test above: the rect's distance
      //   from the panel's bottom edge.
      //
      // What is left in this test is only the arithmetic with no convention
      // inside it: `left`/`right`/`height`/`border-radius`/`transparent N%` are
      // unit-ful declarations that need no origin, so re-deriving them from the
      // CSS text is a genuine check rather than a tautology.
      expect(
        bottom.group(1),
        '20',
        reason:
            'recorded so a change to the prototype\'s `bottom` shows up HERE, in '
            'the transcription test, rather than only as a mysterious failure in '
            'the rendered-geometry test — which would be the gate firing, but a '
            'gate whose failure names a constant instead of a source line is '
            'one step removed from being diagnosable',
      );
    });

    test(
      'the dimmers are caller state — the prototype declares them as opacity',
      () {
        final List<String> html = File('eva/redesign.html').readAsLinesSync();

        // `redesign.html:73` (light) and `:285` (`.bcard.sealed`) both dim the wash
        // with `opacity`, never by re-colouring it — which is why neither became a
        // tier member or a token.
        expect(html[72], contains('.bloom{opacity:.55}'));
        expect(html[284], contains('.bcard.sealed .bloom{opacity:.35}'));
        expect(html[283], contains('.bcard.sealed{opacity:.8}'));
      },
    );

    test('`--bh` is per-host inline, and there is no global definition', () {
      final String html = File('eva/redesign.html').readAsStringSync();
      // 24 characters of lookbehind covers `style="` (7) and
      // `setProperty('` (12) — the two ways this file sets the property, and the
      // only two it uses.
      final Iterable<RegExpMatch> uses = RegExp(r'.{0,24}--bh.{0,3}')
          .allMatches(html);

      // Recorded so a change is visible: 13 occurrences, and every one is either
      // the `var(--bh, …)` default, a `var(--bh)` read, or an inline declaration
      // on a host element. There is no fourth category.
      expect(
        uses.length,
        13,
        reason:
            'the count behind the `bloomColor` parameter. If it moved, the '
            'decision that a token cannot express `--bh` needs re-deriving',
      );

      final List<String> reads = <String>[
        for (final RegExpMatch use in uses)
          if (use.group(0)!.contains('var(--bh')) use.group(0)!,
      ];
      final List<String> inline = <String>[
        for (final RegExpMatch use in uses)
          if (use.group(0)!.contains('style="--bh') ||
              use.group(0)!.contains("setProperty('--bh'"))
            use.group(0)!,
      ];
      final List<String> offenders = <String>[
        for (final RegExpMatch use in uses)
          if (!use.group(0)!.contains('var(--bh') &&
              !use.group(0)!.contains('style="--bh') &&
              !use.group(0)!.contains("setProperty('--bh'"))
            use.group(0)!,
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'a `--bh` that is neither read nor set inline on a host would be a '
            'global definition, and a global definition is something a token COULD '
            'express — which is the premise `bloomColor` is built on:\n'
            '${offenders.join('\n')}',
      );
      expect(reads, isNotEmpty, reason: 'the `var(--bh)` reads must exist');
      expect(
        reads.length + inline.length,
        uses.length,
        reason: 'every occurrence is one of the two accounted-for shapes',
      );
    });
  });

  group('interaction and semantics', () {
    testWidgets('a plain surface adds no semantics node of its own', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: Text('John 3:1-5'))),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Semantics),
        ),
        findsNothing,
        reason:
            'a panel the reader cannot act on must not appear in the '
            'semantics tree at all',
      );
      expect(find.text('John 3:1-5'), findsOneWidget);
    });

    testWidgets('a tappable surface is an InkWell in a Material', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          GlassSurface(
            onTap: () {},
            semanticLabel: 'Today\'s reading',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('a tappable surface announces itself as a button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          GlassSurface(
            onTap: () {},
            semanticLabel: 'Today\'s reading',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Today\'s reading'), findsOneWidget);
      final SemanticsNode node = tester.getSemantics(find.byType(GlassSurface));
      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('a tappable surface fires onTap', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _onSurface(
          GlassSurface(
            onTap: () => taps++,
            semanticLabel: 'Today\'s reading',
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.tap(find.byType(GlassSurface));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the rim is the same pixel with and without `onTap`', (
      WidgetTester tester,
    ) async {
      // M4. Phase 3 passed `idleBorder: Border.all(colors.glassBorder, width: 1)`
      // to the `EvaFocusRing`, which is *the same border at the same 1px inset*
      // the inner `DecoratedBox` already paints — so `onTap: null` → `() {}`
      // double-drew the rim on every interactive panel. Measured over a 320-wide
      // dark canvas: the left-edge rim read R=32 without `onTap` and **R=43** with
      // it (43 = 32 + (255 − 32) × 0.078 — the same `glassBorder` alpha, laid down
      // twice), and 2272 of the panel's 12000 sampled bytes differed.
      //
      // The golden pair could not see any of it: `goldens/glass_surface_tint_*` is
      // captured from the **non-interactive** form, so the interactive variant had
      // no reference image at all. Hence a pixel assertion.
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<List<int>> rim(VoidCallback? onTap) async {
        await tester.pumpWidget(
          evaAmbientHarness(
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                child: GlassSurface(
                  onTap: onTap,
                  semanticLabel: "Today's reading",
                  padding: EdgeInsets.zero,
                  child: const SizedBox(width: 200, height: 60),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final RenderRepaintBoundary boundary = tester
            .renderObject<RenderRepaintBoundary>(
              find.descendant(
                of: find.byType(Align),
                matching: find.byType(RepaintBoundary),
              ),
            );
        final List<int>? bytes = await tester.runAsync<List<int>>(() async {
          final ui.Image image = boundary.toImageSync();
          final ByteData data = (await image.toByteData())!;
          image.dispose();
          return data.buffer.asUint8List();
        });
        expect(bytes, isNotNull, reason: 'the panel produced no pixels at all');
        return bytes!;
      }

      final List<int> plain = await rim(null);
      final List<int> tappable = await rim(() {});

      // Read as **R of the left-edge pixel on the middle row**, which is the rim
      // and not the fill. `image.toByteData(format: rawRgba)` is premultiplied, so
      // over the harness's transparent backdrop `glassFill` (`#0DFFFFFF`) reads 13
      // and the rim over it (`#14FFFFFF`) reads 32. Both numbers are derived, not
      // asserted as literals — a gate that pinned 32 would fail the day the token
      // moved for a reason that has nothing to do with `onTap`.
      int leftRim(List<int> px) => px[(30 * 200) * 4];
      int fillR(List<int> px) => px[(30 * 200 + 1) * 4];
      expect(fillR(plain), 13, reason: 'glassFill over a transparent backdrop');
      expect(leftRim(plain), 32, reason: 'one glassBorder over that fill');

      expect(
        leftRim(tappable),
        leftRim(plain),
        reason:
            '§14 / M4 — `onTap` must not change the resting rim by one pixel. The '
            'ring REPLACES the idle border in the same band, and this surface '
            'already owns its resting border in its own decoration, so the ring\'s '
            'idle state has nothing to add.',
      );
      // The whole panel, not one pixel: a second draw anywhere — a corner arc, a
      // rounded edge — is the same defect wearing a smaller hat.
      expect(
        tappable.toString(),
        plain.toString(),
        reason: 'an interactive glass panel is pixel-identical to an inert one',
      );
    });

    testWidgets('a tappable surface without a label is a programming error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(GlassSurface(onTap: () {}, child: const SizedBox.shrink())),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('theming', () {
    testWidgets('light mode uses the light glass triple', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _onSurface(
          const GlassSurface(child: SizedBox.shrink()),
          theme: EvaThemeLight.theme,
        ),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      const EvaColors colors = EvaColors.light();
      expect(decoration.color, colors.glassFill);
      expect(decoration.boxShadow!.single.color, colors.glassShadow);
    });

    // The theme loop is deliberately OUTSIDE `testWidgets`, one test per theme:
    // `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
    // `kThemeAnimationDuration`, and the single zero-duration `pump()` after
    // `pumpWidget` does not advance it — so two captures in one body wrote the
    // first palette into the second file and
    // `goldens/glass_surface_tint_light.png` was a byte-identical copy of the
    // dark one. See `streak_flame_test.dart`'s "why the goldens are one test per
    // theme" group, which pins the mechanism.
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      testWidgets('a golden per theme — $label', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(280, 180);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _onSurface(
            const GlassSurface(child: SizedBox(width: 40, height: 20)),
            theme: theme,
            size: const Size(280, 180),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(GlassSurface),
          matchesGoldenFile('goldens/glass_surface_tint_$label.png'),
        );
      });

      // The bloom pair, and it is a pair for a reason a structural assertion
      // cannot see: `.hor` is white in dark (`rgba(255,255,255,.85)`) and gold in
      // light (`rgba(154,123,25,.8)`, `redesign.html:72`). Reading that off the
      // `DecoratedBox` proves the token reached the paint; the pixels prove the
      // wash, the seam and the content composited together — order, clipping and
      // all — which is what AGENT_CONTEXT decision 33's sentinel lesson is about.
      // `golden_pairs_test.dart` then refuses the two files being byte-identical.
      testWidgets('a bloom golden per theme — $label', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(280, 180);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _onSurface(
            const GlassSurface(
              tier: GlassTier.bloom,
              padding: EdgeInsets.zero,
              child: SizedBox.expand(),
            ),
            theme: theme,
            size: const Size(280, 180),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byType(GlassSurface),
          matchesGoldenFile('goldens/glass_surface_bloom_$label.png'),
        );
      });
    }
  });

  group('the sigma doc table, against the prototype it transcribes', () {
    // The rows of `kGlassBlurSigma`'s doc table: name, prototype file, line, radius.
    // Parsed out of the doc comment itself, so the table is the subject and not a
    // second copy of it living here.
    //
    // The name is matched as **anything up to the parenthesis**, not as a backticked
    // token, and that is not looseness for its own sake: four of the nine rows are not
    // a single backticked name (`` `SealFAB` dock item ``, `` Login form ``), and a
    // parser that only understood the tidy five would have quietly covered five of
    // nine — which is the failure this group exists to prevent, one level up. The
    // first version of this pattern allowed backticks but not a space-separated name
    // and matched **two** of nine, which is why the anti-vacuity test below asserts a
    // count and not merely a non-empty list: a parser change is a silent coverage
    // change otherwise.
    final List<RegExpMatch> rows =
        RegExp(
              r'\|\s*([^|]+?)\s*\(`([^`]+):(\d+)`\)\s*\|\s*(\d+)\s*\|',
              multiLine: true,
            )
            .allMatches(
              File('lib/core/design_system/widgets/glass_surface.dart')
                  .readAsStringSync(),
            )
            .toList();

    test('the table is parsed out of the doc, and is not empty', () {
      // Anti-vacuity. Every check below iterates `rows`, so a reformat of the table
      // would otherwise turn this whole group into a green walk over nothing — which
      // is the exact shape of the failure this table already had once.
      expect(
        rows,
        hasLength(9),
        reason:
            'the table must list all nine prototype sites — seven in `ds.tsx` plus '
            'the two inline. Found ${rows.length}. A smaller number means a row was '
            'dropped or the table was reformatted, and every check below silently '
            'stopped covering it.',
      );
    });

    for (final RegExpMatch row in rows) {
      // Backticks stripped, so `_cutSites` spells a site the way a reader would.
      final String name = row.group(1)!.replaceAll('`', '').trim();
      final String file = row.group(2)!;
      final int line = int.parse(row.group(3)!);
      final int radius = int.parse(row.group(4)!);

      test('$name is really blur(${radius}px) at $file:$line', () {
        final File source = File('eva/src/${_prototypePath(file)}');
        expect(source.existsSync(), isTrue, reason: '$file does not exist');

        final List<String> lines = source.readAsLinesSync();
        expect(
          line - 1,
          lessThan(lines.length),
          reason: '$file has ${lines.length} lines, so `$line` is past the end',
        );

        expect(
          lines[line - 1],
          contains('blur(${radius}px)'),
          reason:
              '`glass_surface.dart` says `$name` is `blur(${radius}px)` at '
              '`$file:$line`, and that line says:\n${lines[line - 1]}\n\n'
              'A table of another repository numbers is a claim until something '
              'checks it, and this is what checks it.',
        );
      });
    }

    test('and the shipped sigma is the radius of the ONE site that blurs', () {
      // The claim the whole correction rests on: `HomeScreen.tsx:39` writes
      // `blur(24px)`, Home panel is the only `GlassTier.blur` site, and therefore
      // the sigma is `24` and not a compromise between eight radii. Read against the
      // prototype rather than against the constant, so a change that moved the
      // number and left the argument is red.
      final List<String> home = File('eva/src/screens/HomeScreen.tsx')
          .readAsLinesSync();

      expect(home[38], contains('blur(24px)'));
      expect(
        kGlassBlurSigma,
        24.0,
        reason:
            'only one site blurs, so there is no median to take: the sigma is the '
            'prototype own radius for that site',
      );
    });

    test('and NO surviving site is a 20, which is what the old median missed', () {
      // The falsifying check, and the one the old doc made impossible to write. The
      // two `20` sites are `PassageCard` and the `SealFAB` button, both cut — so `20`
      // was the median of a list in which the relevant entries are not present.
      final Set<int> shipping = <int>{
        for (final RegExpMatch row in rows)
          if (!_cutSites.contains(row.group(1)!.replaceAll('`', '').trim()))
            int.parse(row.group(4)!),
      };

      expect(
        shipping,
        <int>{8, 12, 16, 24},
        reason:
            'the radii of the sites that survive into the shipped app. If a cut '
            'screen is restored this list changes, and the sigma justification has '
            'to be re-derived rather than inherited.',
      );
      expect(
        shipping.contains(20),
        isFalse,
        reason:
            'a surviving `20` site is exactly the premise decision 34 relied on and '
            'the measurement showed does not exist',
      );
    });
  });
}

/// The prototype file a doc row names, relative to `eva/src`.
String _prototypePath(String name) => switch (name) {
  'ds.tsx' => 'components/ds.tsx',
  'HomeScreen.tsx' => 'screens/HomeScreen.tsx',
  'LoginScreen.tsx' => 'screens/LoginScreen.tsx',
  _ => throw StateError(
    'the sigma doc names a prototype file this test cannot find: $name. Add it to '
    '_prototypePath rather than skipping the row — an unmapped file means an '
    'unchecked claim.',
  ),
};

/// The doc-table sites that do **not** ship, and why.
///
/// A hard-coded set, and the reason it is *not* read from the table's third column is
/// that a self-certifying table proves nothing: the check has to live outside the
/// thing it checks. Adding a row here is a deliberate act with a reason attached.
const Set<String> _cutSites = <String>{
  'SealFAB dock item',
  'PassageCard',
  'SealFAB button',
};

/// The magenta-weighted centre of mass of the [GlassTier.bloom] wash inside
/// [boundary], in logical px.
///
/// ## WHY A PIXEL MEASUREMENT AND NOT A CONSTANT COMPARISON
///
/// Comparing `kGlassBloomCenter` against a literal can only prove the widget
/// holds the constant it holds — the same reason a `StackFit` read back off the
/// widget would not have caught the sizing regression. The wash's rendered
/// position is a different claim from its declared position, and it is the one
/// the prototype is about.
///
/// `EvaColors.dark().bloom` is `0x8CE457D6`: R = B = 228 against G = 87, so
/// "red and blue both well above green" is the wash and nothing else on the
/// panel — the seam is white (`R = G = B`) and the glass fill is neutral. The
/// weight is `mean(R, B) − G` so the centroid follows the gradient's intensity
/// rather than the bounding box of "anything at all magenta".
///
/// Fails closed. A centroid over an empty sample would be `Offset.zero`, which
/// is also a position a wrong constant could produce, so an empty sample throws
/// naming itself instead of returning a number that reads like a measurement.
Future<Offset> _washCentroid(
  WidgetTester tester,
  Finder boundary,
  Size size,
) async {
  final RenderRepaintBoundary layer = tester
      .renderObject<RenderRepaintBoundary>(boundary);
  final List<int>? bytes = await tester.runAsync<List<int>>(() async {
    final ui.Image image = layer.toImageSync();
    final ByteData data = (await image.toByteData())!;
    image.dispose();
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('the bloom layer produced no pixels to measure');
  }

  double sumX = 0;
  double sumY = 0;
  double weight = 0;
  for (int y = 0; y < size.height; y++) {
    for (int x = 0; x < size.width; x++) {
      final int i = (y * size.width.toInt() + x) * 4;
      final int r = bytes[i];
      final int g = bytes[i + 1];
      final int b = bytes[i + 2];
      if (r > g + 8 && b > g + 8) {
        final double m = (r + b) / 2 - g;
        sumX += x * m;
        sumY += y * m;
        weight += m;
      }
    }
  }
  if (weight == 0) {
    throw StateError(
      'no magenta pixels in the sampled layer — the wash did not paint, so a '
      'centroid here would be a measurement of nothing',
    );
  }
  return Offset(sumX / weight, sumY / weight);
}

Future<List<int>> _screenPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final List<int>? bytes = await tester.runAsync<List<int>>(() async {
    final ui.Image image = boundary.toImageSync();
    final ByteData data = (await image.toByteData())!;
    image.dispose();
    return <int>[
      for (int i = 0; i < data.lengthInBytes; i += 997) data.getUint8(i),
    ];
  });
  return bytes ?? const <int>[];
}
