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
      // `redesign.html:254` — `radial-gradient(ellipse at 50% 100%, …)`. The
      // dispatch spells the centre `FractionalOffset(0.5, 1.0)`, and
      // `Alignment extends FractionalOffset`, so the value is that object; the
      // parameter is typed `AlignmentGeometry`, which is why the constructor name
      // differs.
      expect(g.center, const Alignment(0.5, 1));
      expect(
        FractionalOffset((g.center as Alignment).x, (g.center as Alignment).y),
        const FractionalOffset(0.5, 1.0),
      );
      expect(g.colors.first, const EvaColors.dark().bloom);
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
      expect(
        kGlassSeamAlignment,
        const Alignment(0, -0.6),
        reason: '`bottom:20%`',
      );
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

    testWidgets('a tint surface is the size it was before the Stack existed', (
      WidgetTester tester,
    ) async {
      // The wash is a `Stack` child, and a `Stack` sizes to its largest
      // NON-positioned child. Both decoration layers are `Positioned` and the
      // content is not, so the panel must measure exactly what `Padding` alone
      // measured — which is what lets the existing `glass_surface_tint_*` goldens
      // stand un-recaptured. If this fails, re-record them and say so.
      await tester.pumpWidget(
        _onSurface(const GlassSurface(child: SizedBox(width: 40, height: 20))),
      );
      expect(tester.getSize(find.byType(GlassSurface)), const Size(80, 60));
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
      // which is the CALLER's business, so the token hue is unchanged. Painting
      // a second, lighter bloom here would be a tier-owned opacity that the
      // prototype does not have.
      expect(
        (decorationOf(tester, wash()).gradient! as RadialGradient).colors.first,
        const EvaColors.light().bloom,
      );
      expect(
        const EvaColors.light().bloom,
        const EvaColors.dark().bloom,
        reason: '`redesign.html:73` changes `opacity`, never the `--bh` colour',
      );
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
      expect(kGlassSeamAlignment.y, -1 + 2 * int.parse(bottom.group(1)!) / 100);
      expect(kGlassBloomFadeStop, double.parse(fade.group(1)!) / 100);
      // The seam's radius is the `border-radius` above, and it is NOT the height
      // just because the two read alike today.
      expect(radius.group(1), height.group(1));
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
          final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
          final ByteData data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
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

Future<List<int>> _screenPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final List<int>? bytes = await tester.runAsync<List<int>>(() async {
    final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
    final ByteData data = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    image.dispose();
    return <int>[
      for (int i = 0; i < data.lengthInBytes; i += 997) data.getUint8(i),
    ];
  });
  return bytes ?? const <int>[];
}
