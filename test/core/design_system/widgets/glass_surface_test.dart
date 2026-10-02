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
    test('has exactly the two treatments §13.4 budgets', () {
      expect(GlassTier.values, <GlassTier>[GlassTier.tint, GlassTier.blur]);
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
      expect(kGlassBlurSigma, 20.0);
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
    }
  });
}

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
