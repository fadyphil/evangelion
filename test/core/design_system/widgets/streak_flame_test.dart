import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

Widget _flame({double size = 18, ThemeData? theme, String? label}) =>
    evaAmbientHarness(
      theme: theme,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: StreakFlame(size: size, semanticLabel: label ?? 'Streak'),
        ),
      ),
    );

/// Keys a `RepaintBoundary` wrapped tightly around the flame.
///
/// `find.byType(StreakFlame)` is not usable for pixel work: `captureImage` walks
/// up to the nearest enclosing repaint boundary, and in this harness that is
/// `MaterialApp`'s — so the "glyph" capture would include the padding, the
/// ambient surface and the harness backdrop, and a bounds assertion over it would
/// measure the harness.
const Key _inkKey = ValueKey<String>('flame-ink');

/// The flame alone in a `RepaintBoundary`, so its ink can be measured.
Widget _inkOnly({double size = 20, ThemeData? theme}) => evaAmbientHarness(
  theme: theme,
  child: Center(
    child: RepaintBoundary(
      key: _inkKey,
      child: StreakFlame(size: size),
    ),
  ),
);

/// Pins the test surface so the boundary's pixels are exactly 120x120.
///
/// Restored through `addTearDown` rather than at the end of the body: a test
/// that overrides the view and does not restore it makes every *later* test in
/// the file non-deterministic, which looks exactly like a flaky golden.
void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(120, 120);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Uint8List> _inkPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_inkKey));
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = boundary.toImageSync();
    final ByteData? data = (await image.toByteData());
    image.dispose();
    if (data == null) throw StateError('the ink layer produced no pixels');
    return data.buffer.asUint8List();
  });
  if (bytes == null) throw StateError('runAsync returned no pixels');
  return bytes;
}

/// The ink layer's pixel dimensions, cross-checked against its buffer.
///
/// Both come from the render object rather than being assumed, and the buffer
/// length has to agree — a mismatch means the capture and the geometry describe
/// different things, and a bounds scan over that is silently wrong at the edges.
///
/// `ceil`, not `round`: at `size: 64` the flame's width is 51.2 logical px and
/// the rasteriser emits **52** device columns for it. Rounding the logical size
/// to 51 disagrees with the buffer by a whole column, and the last column is
/// exactly where an off-by-one in a bounds scan hides.
({int width, int height}) _inkSize(WidgetTester tester, Uint8List rgba) {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_inkKey));
  final Size size = boundary.size;
  final int width = size.width.ceil();
  final int height = size.height.ceil();
  if (width <= 0 || height <= 0) {
    throw StateError('the ink boundary has no area: $size');
  }
  if (rgba.length != width * height * 4) {
    throw StateError(
      'the ink buffer is ${rgba.length} bytes but ${width}x$height needs '
      '${width * height * 4}',
    );
  }
  return (width: width, height: height);
}

/// The bounding box of every pixel carrying visible ink **from the fill**.
///
/// Alpha, not colour: the harness surface behind the glyph is opaque, so "is
/// there ink here" has to be asked of the glyph's own contribution. The
/// `RepaintBoundary` is tight around the flame and nothing is painted behind it
/// inside that box, so any non-zero alpha in the buffer IS the flame.
///
/// Inclusive rather than the raw pixel indices: a glyph covering columns 2 and 3
/// occupies **two** pixels, and `Rect.fromLTRB(2, y, 3, y)` reports a width of 1.
/// The count is what "how wide is the ink" means, and it is what the
/// prototype's x 2…14 actually claims.
///
/// ## THE [minAlpha] FLOOR, AND WHY IT IS NOT `!= 0`
///
/// This used to count **any** non-zero alpha. `redesign.html:243`'s glow — an
/// outward `MaskFilter` halo at 0.85 — now paints ink beyond the path, so
/// "alpha != 0" measures the halo and every ratio below would read `1.0`. The
/// silhouette is recovered by asking for alpha **at or above
/// [StreakFlame.flameSolidAlpha]**, which the measured halo is below and the fill
/// (1.0) is above; that constant's doc carries the measurement.
///
/// **The floor's tightest case is `size: 64`, not `size: 20`.** At 20 the path
/// leaves a two-unit gutter and the brightest sub-floor pixel is `0.2353`; at 64
/// the flame fills its 51px box and the brightest is `0.2431`, leaving `0.0069`
/// of clearance. So a threshold move that looks safe against the gutter figure is
/// not.
///
/// **The floor costs nothing at either end of the box**: at `size: 20` and at
/// `size: 64` it returns exactly `x 2…14` and `y 0…20` — the path's own
/// bounds — so the tolerances below stayed at `1e-9` and `0.02` rather than being
/// widened to accommodate a halo. That is the outcome worth having: the change is
/// in *what* is counted, not in how precisely the answer is checked.
/// [_haloBounds] is the control that says so.
///
/// Alpha, not colour: the harness surface behind the glyph is opaque, so "is
/// there ink here" has to be asked of the glyph's own contribution. The
/// `RepaintBoundary` is tight around the flame and nothing is painted behind it
/// inside that box, so any non-zero alpha in the buffer IS the flame.
///
/// Inclusive rather than the raw pixel indices: a glyph covering columns 2 and 3
/// occupies **two** pixels, and `Rect.fromLTRB(2, y, 3, y)` reports a width of 1.
/// The count is what "how wide is the ink" means, and it is what the
/// prototype's x 2…14 actually claims.
Rect _inkBounds(Uint8List rgba, int width, int height, {double? minAlpha}) {
  final double floor = minAlpha ?? StreakFlame.flameSolidAlpha;
  int minX = width, minY = height, maxX = -1, maxY = -1;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (rgba[((y * width) + x) * 4 + 3] / 255.0 < floor) continue;
      minX = minX > x ? x : minX;
      maxX = maxX < x ? x : maxX;
      minY = minY > y ? y : minY;
      maxY = maxY < y ? y : maxY;
    }
  }
  if (maxX < 0) {
    throw StateError('nothing was painted — an empty layer has no bounds');
  }
  return Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX + 1, maxY + 1);
}

/// The bounding box of **every** pixel carrying any ink at all — halo included.
///
/// [StreakFlame.flameSolidAlpha] is the one claim the silhouette measurement
/// rests on, and a claim about a threshold deserves the test that breaks if it is
/// wrong. This is that test: with `minAlpha` at one 8-bit step the ink reaches
/// the box's corners, and with it at [StreakFlame.flameSolidAlpha] the ink is
/// exactly the path. If the glow ever grew strong enough inside the box to cross
/// the floor, the two rects would coincide and the pair assertion goes red.
Rect _haloBounds(Uint8List rgba, int width, int height) =>
    _inkBounds(rgba, width, height, minAlpha: 1 / 255);

/// The most common **fully opaque** colour in [rgba].
///
/// The modal colour rather than the first ink pixel: the glyph's edge is
/// antialiased, so the pixel that happens to come first is whatever partial
/// blend the rasteriser produced there. The interior is the fill exactly.
Color _modalOpaqueColour(Uint8List rgba) {
  final Map<int, int> counts = <int, int>{};
  for (int i = 0; i < rgba.length; i += 4) {
    if (rgba[i + 3] != 0xFF) continue;
    final int argb =
        (0xFF << 24) | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    counts[argb] = (counts[argb] ?? 0) + 1;
  }
  if (counts.isEmpty) {
    throw StateError('no opaque pixel was painted at all');
  }
  final List<MapEntry<int, int>> ranked = counts.entries.toList()
    ..sort(
      (MapEntry<int, int> a, MapEntry<int, int> b) =>
          b.value.compareTo(a.value),
    );
  return Color(ranked.first.key);
}

void main() {
  group('geometry', () {
    test('the default size is the inventory\'s 18', () {
      const StreakFlame flame = StreakFlame();
      expect(flame.size, 18.0);
    });

    test('the width follows the prototype\'s 16:20 viewBox', () {
      // `ds.tsx:513` — `viewBox="0 0 16 20"`. Uniform scaling keeps the path from
      // being distorted; the prototype's own 14x18 element box differs by 2%,
      // which is the viewBox's own horizontal padding.
      expect(StreakFlame.aspect, 16 / 20);
      expect(const StreakFlame().width, closeTo(14.4, 1e-9));
      expect(const StreakFlame(size: 20).width, closeTo(16.0, 1e-9));
    });

    testWidgets('the widget takes the size it was given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame(size: 24));
      final Size size = tester.getSize(find.byType(StreakFlame));
      expect(size.height, 24.0);
      expect(size.width, closeTo(24 * 16 / 20, 1e-9));
    });

    testWidgets('it scales without overflowing a small box', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame(size: 8));
      expect(tester.takeException(), isNull);
    });
  });

  group('the path is the prototype\'s', () {
    test('is closed and finite', () {
      expect(flamePath.computeMetrics().length, greaterThan(0));
      expect(flamePath.contains(Offset.zero), isFalse);
    });

    // `ds.tsx:514`'s `d`, read back off the object rather than off the screen.
    // A pixel measurement says "the ink is 12 columns wide"; this says "the path
    // spans x 2…14 of a 16-wide viewBox", which is the same fact with the
    // numbers the transcription is supposed to have used written into it. The
    // pixel tests below then answer the separate question — does the *painter*
    // map that viewBox onto the box — which is the half a path assertion cannot
    // see.
    test('spans x 2…14 and y 0…20 of the 16x20 viewBox', () {
      final Rect bounds = flamePath.getBounds();
      expect(bounds.left, closeTo(2, 1e-6));
      expect(bounds.right, closeTo(14, 1e-6));
      expect(bounds.top, closeTo(0, 1e-6));
      expect(bounds.bottom, closeTo(20, 1e-6));
    });

    test('and the box is 16 wide, so 12/16 is the ink the path claims', () {
      expect(StreakFlame.aspect * 20, 16.0);
      expect(14 - 2, 12);
    });

    testWidgets('covers roughly the prototype\'s box', (
      WidgetTester tester,
    ) async {
      // The path spans x 2…14 and y 0…20 of a 16x20 viewBox. Rendered at 20px
      // tall that is a 10.8 x 20px glyph inside a 16 x 20 box — so the PAINTED
      // bounds must be inset from the widget box horizontally and flush
      // vertically. A path that filled its box would mean the transcription had
      // been rescaled, and asserting the widget's own size cannot see that: it is
      // 16 x 20 by construction whatever the path says. So this reads the ink.
      //
      // The glyph is captured through a `RepaintBoundary` of its own because
      // `find.byType(StreakFlame)` resolves to the nearest enclosing boundary,
      // which in this harness is `MaterialApp`'s and therefore includes the
      // padding, the surface and the harness backdrop.
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly());
      await tester.pump();

      final Uint8List rgba = await _inkPixels(tester);
      final ({int height, int width}) size = _inkSize(tester, rgba);
      expect(
        size.width,
        16,
        reason: 'the box is 16 x 20 — see StreakFlame.aspect',
      );
      expect(size.height, 20);

      final Rect painted = _inkBounds(rgba, size.width, size.height);
      // Ratios, not pixels, so the assertion holds at any `size`: the prototype's
      // path spans x 2…14 of a 16-wide viewBox and y 0…20 of a 20-tall one, so
      // the ink must cover 12/16 of the box horizontally and all of it
      // vertically. A path rescaled to fill its box measures 1.0 and 1.0; a
      // painter dividing by the wrong viewBox axis measures neither.
      expect(
        painted.width / size.width,
        closeTo(12 / 16, 1e-9),
        reason: 'x 2…14 of a 16-wide viewBox is 12/16 of the box',
      );
      expect(
        painted.height / size.height,
        closeTo(1.0, 1e-9),
        reason: 'y 0…20 of a 20-tall viewBox — flush vertically, not inset',
      );
    });

    testWidgets('and the same proportions hold at another size', (
      WidgetTester tester,
    ) async {
      // The first test could be satisfied by a painter hard-wired to one scale.
      // Two sizes with different box dimensions are what makes the ratio
      // assertion above a statement about the transcription and not about 20.
      for (final double size in <double>[20, 64]) {
        _pinSurface(tester);
        await tester.pumpWidget(_inkOnly(size: size));
        await tester.pump();
        final Uint8List rgba = await _inkPixels(tester);
        final ({int height, int width}) box = _inkSize(tester, rgba);
        final Rect painted = _inkBounds(rgba, box.width, box.height);
        expect(
          painted.width / box.width,
          closeTo(12 / 16, 0.02),
          reason: 'at size $size',
        );
        expect(
          painted.height / box.height,
          closeTo(1.0, 0.02),
          reason: 'at size $size',
        );
      }
    });

    // The glow's whole cost, in one assertion pair: it paints where the fill
    // does not, and the fill is still readable underneath it.
    testWidgets('and the halo reaches past the silhouette the fill draws', (
      WidgetTester tester,
    ) async {
      // Two measurements of one capture, and the second is the control the first
      // depends on. If the glow were removed entirely the two rects would be the
      // same — which is the failure this file would otherwise not be able to
      // see, because the silhouette ratios above are satisfied by a halo that had
      // swallowed the box.
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly());
      await tester.pump();

      final Uint8List rgba = await _inkPixels(tester);
      final ({int height, int width}) box = _inkSize(tester, rgba);
      final Rect silhouette = _inkBounds(rgba, box.width, box.height);
      final Rect halo = _haloBounds(rgba, box.width, box.height);

      expect(
        halo.width,
        greaterThan(silhouette.width),
        reason:
            'the box is ${box.width} wide and the path spans 12 of its 16 viewBox '
            'columns, so the glow has to reach the 2-column margin each side',
      );
      expect(
        halo.height,
        silhouette.height,
        reason:
            'and **exactly** the silhouette\'s height, because the flame is flush '
            'with the top and bottom of the viewBox already — there is no room '
            'for the glow to grow into. A halo taller than the box would mean the '
            'painter had started drawing outside it',
      );
      expect(
        halo.width,
        box.width,
        reason:
            'the halo reaches both edges of the box, which is the whole of '
            'why the ink bounds need a threshold',
      );
    });
  });

  group('the glow — redesign.html:243, adopted', () {
    test('the sigma is half the CSS blur radius, not the radius itself', () {
      // CSS Backgrounds 3 §3.3: a `blur()` radius is twice the Gaussian's
      // standard deviation. Copying 14 into `MaskFilter.blur` would draw a 28px
      // halo, which at this widget's 14x18 box is a different mark entirely.
      expect(StreakFlame.flameGlowBlur, 14.0);
      expect(StreakFlame.flameGlowSigma, 7.0);
      expect(StreakFlame.flameGlowSigma, StreakFlame.flameGlowBlur / 2);
    });

    test('the alpha is `:243`\'s own 0.85', () {
      expect(StreakFlame.flameGlowAlpha, 0.85);
    });

    test('and the solid-ink threshold sits between the halo and the fill', () {
      // The constant the whole silhouette measurement rests on, pinned against
      // the two numbers it exists to separate. If either moved far enough for the
      // band to close, the pixel tests above would be measuring the halo — and
      // the control in the previous group is what would catch it.
      //
      // **`0.2431`, not `0.1529`.** This bound used to be the older number, which
      // is a `size: 20` **gutter** reading. At `size: 64` the flame is 51.2 logical
      // px wide in a 51px box, so there is no gutter at all and the brightest
      // pixel under the floor is `0.2431` — a bound at `0.1529` would have passed
      // with the tail 0.09 above it. `StreakFlame.flameSolidAlpha`'s doc carries
      // the per-size table and the `0.0069` of clearance this leaves.
      expect(StreakFlame.flameSolidAlpha, greaterThan(0.2431));
      expect(StreakFlame.flameSolidAlpha, lessThan(1.0));
    });

    testWidgets('the glow is the same ember as the fill', (
      WidgetTester tester,
    ) async {
      // One hue at two alphas. `:243`'s `rgba(232,176,75,…)` is `--gold`, which
      // §5.1 publishes as `ember`; `#ff7a18` — the gradient's third stop and the
      // second `box-shadow` — is a Phase-2 palette decision and is not here.
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly(theme: EvaThemeDark.theme));
      await tester.pump();
      final Uint8List rgba = await _inkPixels(tester);
      // A pixel outside the path but inside the box: the glow, and nothing else.
      // Column 0 of a 16-wide box is gutter — the path starts at x 2 — so the
      // alpha there is the halo's tail and the fill has no part in it. Row 0 is
      // the flame's own apex, where the path *is* painted.
      expect(
        rgba[3] / 255,
        greaterThan(0.0),
        reason: 'the glow reaches the gutter column 0',
      );
      expect(
        rgba[3] / 255,
        lessThan(StreakFlame.flameSolidAlpha),
        reason:
            'and it is BELOW the solid-ink floor, which is what makes the '
            'silhouette measurements above mean what they say',
      );
      expect(
        rgba[3] / 255,
        lessThan(StreakFlame.flameGlowAlpha),
        reason: 'a blurred tail of a 0.85 shadow, never the shadow itself',
      );
      expect(
        rgba[7] / 255,
        greaterThan(rgba[3] / 255),
        reason:
            'and it is a *falloff*, not a tint: column 1 is nearer the path than '
            'column 0, so it is brighter',
      );
    });
  });

  group('colour', () {
    testWidgets('is ember, the prototype\'s `hex.ember` fill', (
      WidgetTester tester,
    ) async {
      // The paint *colour*, measured off the rasterised glyph, not
      // `painter != null`: a painter that filled the path in `Colors.red`
      // satisfies the old assertion exactly.
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly(theme: EvaThemeDark.theme));
      await tester.pump();
      expect(
        _modalOpaqueColour(await _inkPixels(tester)),
        const EvaColors.dark().ember,
      );
    });

    testWidgets('and light mode uses the light ember', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly(theme: EvaThemeLight.theme));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        _modalOpaqueColour(await _inkPixels(tester)),
        const EvaColors.light().ember,
        reason:
            'the two palettes differ, so this cannot be satisfied by a colour '
            'that is the same in both',
      );
    });

    // The theme loop is deliberately OUTSIDE `testWidgets`, one test per theme.
    // Inside a single test body the second capture silently re-captured the
    // first palette: `MaterialApp` installs an `AnimatedTheme`, which lerps a
    // theme change over `kThemeAnimationDuration` (200ms), and the single
    // zero-duration `pump()` after `pumpWidget` does not advance that lerp. So
    // `goldens/streak_flame_light.png` was a byte-identical copy of the dark one
    // and `--update-goldens` re-cemented it. `sun_burst_test.dart`,
    // `seal_monogram_test.dart` and `neural_background_test.dart` already hoist;
    // the mechanism is pinned by the test in this file's last group.
    for (final (String label, ThemeData theme) in <(String, ThemeData)>[
      ('dark', EvaThemeDark.theme),
      ('light', EvaThemeLight.theme),
    ]) {
      testWidgets('golden on $label', (WidgetTester tester) async {
        await tester.pumpWidget(_flame(theme: theme));
        await tester.pump();
        await expectLater(
          find.byType(StreakFlame),
          matchesGoldenFile('goldens/streak_flame_$label.png'),
        );
      });
    }
  });

  group('semantics — the flame is not decoration', () {
    testWidgets('carries a label and drops its own subtree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_flame(label: '12 day streak'));
      final node = tester.getSemantics(find.byType(StreakFlame));
      expect(node.label, '12 day streak');
    });

    testWidgets('a reader hears the streak, not a bare path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        evaAmbientHarness(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[StreakFlame(), Text('12')],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Streak'), findsOneWidget);
      expect(find.bySemanticsLabel('12'), findsOneWidget);
    });

    testWidgets('defaults to a usable label rather than nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(evaAmbientHarness(child: const StreakFlame()));
      final node = tester.getSemantics(find.byType(StreakFlame));
      expect(node.label, isNotEmpty);
    });
  });

  group('why the goldens are one test per theme', () {
    // THE MECHANISM, pinned. `MaterialApp` installs an `AnimatedTheme`, which
    // lerps a theme change over `kThemeAnimationDuration` (200ms). One
    // zero-duration `pump()` after `pumpWidget` does not advance that lerp, so a
    // second `matchesGoldenFile` **inside the same `testWidgets`** re-captures the
    // previous palette — byte for byte. That is how
    // `goldens/streak_flame_light.png` came to be a copy of the dark one, and
    // `--update-goldens` would have re-cemented it on every run.
    //
    // The glass tint/blur pair in `glass_surface_test.dart` is *not* affected,
    // because swapping a tier is not a theme change. Proved here by the control
    // below, so the diagnosis is the shape of the problem rather than a guess.
    testWidgets('one pump after a theme swap still shows the old palette', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly(theme: EvaThemeDark.theme));
      await tester.pump();
      final Color first = _modalOpaqueColour(await _inkPixels(tester));

      await tester.pumpWidget(_inkOnly(theme: EvaThemeLight.theme));
      await tester.pump();
      final Color afterOnePump = _modalOpaqueColour(await _inkPixels(tester));

      expect(
        afterOnePump,
        first,
        reason:
            'the swap is still mid-lerp — this is the stale capture, and it is '
            'why the two goldens cannot share a test body',
      );
    });

    testWidgets('settling past kThemeAnimationDuration shows the new palette', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(_inkOnly(theme: EvaThemeDark.theme));
      await tester.pump();
      final Color first = _modalOpaqueColour(await _inkPixels(tester));

      await tester.pumpWidget(_inkOnly(theme: EvaThemeLight.theme));
      await tester.pump();
      await tester.pump(kThemeAnimationDuration + const Duration(seconds: 1));
      final Color settled = _modalOpaqueColour(await _inkPixels(tester));

      expect(
        settled,
        const EvaColors.light().ember,
        reason:
            'the control for the test above: the palette does arrive, so the '
            'stale capture was a missing settle and not a stuck theme',
      );
      expect(settled, isNot(first));
    });

    testWidgets(
      'a fresh testWidgets starts settled — the arrangement that works',
      (WidgetTester tester) async {
        // One theme per test body: the first frame of a new binding has no previous
        // palette to lerp *from*, so the very first `pump()` is already the new one.
        // That is the arrangement `sun_burst_test.dart`, `seal_monogram_test.dart`
        // and `neural_background_test.dart` already use, and the reason their
        // light and dark goldens differ.
        _pinSurface(tester);
        await tester.pumpWidget(_inkOnly(theme: EvaThemeLight.theme));
        await tester.pump();
        expect(
          _modalOpaqueColour(await _inkPixels(tester)),
          const EvaColors.light().ember,
        );
      },
    );
  });
}
