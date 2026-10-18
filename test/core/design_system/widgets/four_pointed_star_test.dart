import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// ## WHAT THIS SUITE IS ACTUALLY ABOUT
///
/// `FourPointedStar` exists because U+2726 is in **no** bundled family, which is
/// a measurement and not a preference — its own file's doc carries the method,
/// the reader (`test/support/font_coverage.dart`'s `cmap` parser), the shipped
/// count and the gate that caught the typed version
/// (`arabic_typography_test.dart`'s `expectNoTofuInAnyRun`, `Actual: [10022]`).
/// This file does **not** re-argue any of that. What it claims is the four
/// things a painted shape can be wrong about without anything turning red:
///
/// 1. it is the size it claims, measured off the **rendered** box;
/// 2. it paints **inside** that box — measured off the **rasterised ink**, in a
///    container four times the star's size, so the claim cannot be satisfied by
///    definition;
/// 3. it repaints on an ink change and not otherwise, in **both** directions;
/// 4. it contributes **no accessible name**, which is what makes it decorative
///    and safe to put inside a control that names itself.
///
/// ## AND THE ANTI-VACUITY HALF, WHICH IS THE POINT
///
/// **A shape painted into a canvas is invisible to every finder that looks for
/// text, and invisible to any assertion that only counts widgets.** §7's rule —
/// "a gate that cannot fail is worse than no gate" — has almost no teeth here:
/// delete `paint`'s only statement and the star is still in the tree, still the
/// right size, still returns the right `shouldRepaint`, and `find.byType` still
/// finds it. So every paint claim below is read off **pixels**, and the last
/// group plants the negative control that proves the pixel reader can say
/// "nothing was painted" at all — without it, "there is ink here" is a claim
/// about a reader that has never once said otherwise.

/// The star under test, centred in a box [_inkBoxFactor] times its own size.
///
/// **The padding is the whole design of this helper.** A `RepaintBoundary`
/// drawn tight around the star would make "the ink is inside the star" true by
/// construction — the boundary *is* the star's box, so a path that overflowed by
/// twenty pixels would still be measured as contained. So the boundary is four
/// times the star, the star is centred inside it, and containment is asserted
/// against the star's own rect translated into the boundary's coordinates.
const double _inkBoxFactor = 4;

/// `RepaintBoundary` for the capture. Anchored by key because
/// `find.byType(RepaintBoundary)` would resolve to `MaterialApp`'s own, and the
/// capture would then include the harness surface.
const Key _inkKey = ValueKey<String>('four-pointed-star-ink');

/// The star alone, in a box [_inkBoxFactor] times [size] to measure.
Widget _measured({required double size, required Color color}) =>
    evaAmbientHarness(
      child: Center(
        child: RepaintBoundary(
          key: _inkKey,
          child: SizedBox.square(
            dimension: size * _inkBoxFactor,
            child: Center(
              child: FourPointedStar(size: size, color: color),
            ),
          ),
        ),
      ),
    );

/// The same harness with **no star**, for the negative control.
///
/// Deliberately a `SizedBox` of the same size rather than "the widget with a
/// transparent colour": a transparent star still *runs* `paint` and still draws a
/// path, so it would prove the reader can see a shape rather than that it can
/// see nothing.
Widget _emptyControl({required double size}) => evaAmbientHarness(
  child: Center(
    child: RepaintBoundary(
      key: _inkKey,
      child: SizedBox.square(dimension: size * _inkBoxFactor),
    ),
  ),
);

/// The colour the shape is inked in for every measurement.
///
/// A token rather than a literal, because §4 and `no_colour_literals_test.dart`
/// make a colour that did not go through `EvaColors` a **production** violation —
/// and a test that reached for `const Color(0xFFE8B04B)` would be a reader
/// quietly picking a fourth name for the same gold.
final Color _ember = const EvaColors.dark().ember;

/// A second token ink, so the repaint claim cannot be satisfied by two colours
/// that happen to compare equal on one palette.
final Color _ink = const EvaColors.dark().ink;

/// Pins the surface so the capture's dimensions are the star's, not the default's.
///
/// `addTearDown` rather than a teardown at the end of the body, for
/// `streak_flame_test.dart`'s reason: a test that leaves `tester.view` overridden
/// makes every later test in the file non-deterministic, and that reads exactly
/// like a flaky golden.
void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(240, 240);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The capture's raw RGBA bytes.
///
/// **`toImageSync`, and `runAsync` around `toByteData` only.** `toImage` resolves
/// after the *next* frame, which never arrives inside `testWidgets`' fake-async
/// zone — the await does not fail, it hangs, and the suite dies at the
/// ten-minute timeout with nothing in the output to explain it. This is
/// `design_system_harness.dart`'s `backgroundPixels` mechanism and
/// `streak_flame_test.dart`'s `_inkPixels`, for the same reason.
Future<Uint8List> _inkPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_inkKey));
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = boundary.toImageSync();
    final ByteData? data = await image.toByteData();
    image.dispose();
    if (data == null) throw StateError('the ink layer produced no pixels');
    return data.buffer.asUint8List();
  });
  if (bytes == null) throw StateError('runAsync returned no pixels');
  return bytes;
}

/// The capture's pixel dimensions, cross-checked against its buffer.
///
/// Both come from the render object rather than being assumed. A mismatch means
/// the capture and the geometry describe different things and every bound below
/// is silently wrong at the edges.
({int width, int height}) _inkSize(WidgetTester tester, Uint8List rgba) {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_inkKey));
  final int width = boundary.size.width.ceil();
  final int height = boundary.size.height.ceil();
  if (width <= 0 || height <= 0) {
    throw StateError('the ink boundary has no area: ${boundary.size}');
  }
  if (rgba.length != width * height * 4) {
    throw StateError(
      'the ink buffer is ${rgba.length} bytes but ${width}x$height needs '
      '${width * height * 4}',
    );
  }
  return (width: width, height: height);
}

/// How much of the capture carries any ink at all.
///
/// **Alpha, not colour**, and the threshold is one 8-bit step rather than zero:
/// a shape whose extreme point lands exactly on a pixel boundary antialiases to
/// values of 1 there, and counting those as ink is correct — they are pixels the
/// rasteriser filled. Anything genuinely absent is exactly `0`.
///
/// The count is the anti-vacuity claim. Zero is a failure the caller cannot
/// explain away, which is the point.
int _litPixels(Uint8List rgba, {int minAlpha = 1}) {
  int lit = 0;
  for (int i = 3; i < rgba.length; i += 4) {
    if (rgba[i] >= minAlpha) lit++;
  }
  return lit;
}

/// The box every inked pixel falls inside, or `null` when there is no ink.
///
/// **`null` rather than a throw**, because "nothing was painted" is a legitimate
/// answer here and the negative control has to be able to *say* it. The
/// containment assertions below require non-null, so a widget that paints nothing
/// fails them with a message about the missing ink rather than about a geometry.
Rect? _inkBounds(Uint8List rgba, int width, int height, {int minAlpha = 1}) {
  int minX = width, minY = height, maxX = -1, maxY = -1;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (rgba[((y * width) + x) * 4 + 3] < minAlpha) continue;
      // Written as four `if`s rather than the four ternaries
      // `streak_flame_test.dart` uses, for a reason that cost this file's first
      // run: a transposed ternary (`maxX = maxX < x ? maxX : x`) keeps the
      // **smaller** of the two and never leaves its `-1` seed, so it reports "no
      // ink" on a canvas that is covered in it — and the first version of this
      // helper said `null` while `_litPixels` said `840`. The comparison and the
      // assignment are on separate lines here so they cannot be transposed
      // silently again.
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX + 1, maxY + 1);
}

/// The most common **fully opaque** colour in [rgba].
///
/// The modal colour rather than the first ink pixel: the star's edge is
/// antialiased, so whichever pixel happens to come first is whatever partial
/// blend the rasteriser produced there. The interior is the fill, exactly.
/// `streak_flame_test.dart` reads the same way for the same reason.
Color _modalOpaqueColour(Uint8List rgba) {
  final Map<int, int> counts = <int, int>{};
  for (int i = 0; i < rgba.length; i += 4) {
    if (rgba[i + 3] != 0xFF) continue;
    final int argb =
        (0xFF << 24) | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    counts[argb] = (counts[argb] ?? 0) + 1;
  }
  if (counts.isEmpty) throw StateError('no opaque pixel was painted at all');
  final List<MapEntry<int, int>> ranked = counts.entries.toList()
    ..sort(
      (MapEntry<int, int> a, MapEntry<int, int> b) =>
          b.value.compareTo(a.value),
    );
  return Color(ranked.first.key);
}

/// The [CustomPainter] the star's own `CustomPaint` is holding.
///
/// Reached through the widget rather than through a type name, because the
/// painter is **private to `four_pointed_star.dart`** on purpose — a public
/// `CustomPainter` would put a second spelling of the shape in the design system's
/// public surface. `CustomPaint.painter` is the framework's own handle on it and
/// needs no name here.
CustomPainter _painterOf(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(FourPointedStar),
      matching: find.byType(CustomPaint),
    ),
  );
  final CustomPainter? painter = paint.painter;
  if (painter == null) {
    throw StateError('the star carries no painter, so it paints nothing');
  }
  return painter;
}

void _noop() {}

void main() {
  group('the star is a paint, and the paint has a painter', () {
    // Everything else in this file reads pixels; this row is the *precondition*
    // for that reading being about this widget at all. It is the cheapest
    // possible statement that the shape is a `CustomPaint` and carries a
    // painter — and the one assertion that survives `paint` being emptied, which
    // is exactly why the ink rows below exist.
    testWidgets('the widget is one `CustomPaint` with a painter and no text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_measured(size: 40, color: _ember));

      expect(find.byType(FourPointedStar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FourPointedStar),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      // **No `Text` anywhere under it.** This is the assertion that keeps the
      // recorded correction true: U+2726 is in no bundled family, so a `Text`
      // here would be a tofu box, and `expectNoTofuInAnyRun` cannot see a string
      // that is never typed.
      expect(
        find.descendant(
          of: find.byType(FourPointedStar),
          matching: find.byType(Text),
        ),
        findsNothing,
        reason:
            'U+2726 is in no bundled family. A `Text` under this widget would '
            'render as a tofu box on every screen that places it.',
      );
      expect(_painterOf(tester), isNotNull);
    });
  });

  group('the size is the box the em box would have occupied', () {
    // **Off the rendered `RenderBox`, not off the constructor.** The selah
    // circle's own suite records the version of this that got it wrong: a
    // predicate matching `CustomPaint.size == const Size.square(11.0)` asserts
    // the widget's *declaration*, so it keeps passing after the box stops being
    // laid out at that size. `tester.getSize` is the engine's answer.
    //
    // Two sizes, because one size is satisfied by a hard-coded `11` as easily as
    // by `size` — and the selah circle and `/reading`'s bookmark button need
    // different ones, which is why `size` is a parameter.
    for (final double size in <double>[11, 40]) {
      testWidgets('it renders $size square when asked for $size', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_measured(size: size, color: _ember));

        expect(tester.getSize(find.byType(FourPointedStar)), Size.square(size));
        expect(
          tester.getSize(
            find.descendant(
              of: find.byType(FourPointedStar),
              matching: find.byType(CustomPaint),
            ),
          ),
          Size.square(size),
          reason: 'the `CustomPaint` is the star; there is no other box in it',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('and a zero size is laid out, not thrown on', (
      WidgetTester tester,
    ) async {
      // **A decision, not a requirement.** `:269` and `:544` both declare a
      // positive `font-size`, so `0` is a state no call site produces. It is
      // pinned anyway because `Size.square(0)` is the degenerate input a
      // design-system widget is most likely to be handed by a future caller
      // deriving its size from a measurement, and a `CustomPainter` that divides
      // by its size would throw out of `build` rather than draw nothing.
      await tester.pumpWidget(_measured(size: 0, color: _ember));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(FourPointedStar)), Size.zero);
    });
  });

  group('the paint is inside the box, and it is ink', () {
    // ## THE MEASUREMENT IS **THE RASTERISED INK**, NOT THE `CustomPaint`
    //
    // The other thing available is `CustomPaint.size`, which is the widget's
    // declaration — and saying the shape is inside the widget's own declared
    // box is close to saying nothing. `Picture.computeBounds()` would answer it
    // directly and **does not exist in this SDK's `dart:ui`** (measured: the
    // method is undefined, so it is not an option that was declined). So the
    // claim is measured where a shape can actually be wrong: on the pixels, in a
    // box four times the star's size, with the star's own rect translated into
    // it. A path drawn at twice its size, given a `MaskFilter` glow, or offset by
    // a translation error all fail this; none of them could fail the declaration.
    testWidgets('the ink is inside the box and reaches its edges', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(_measured(size: 40, color: _ember));
      await tester.pump();

      final Uint8List rgba = await _inkPixels(tester);
      final ({int height, int width}) box = _inkSize(tester, rgba);

      // The anti-vacuity row, first and unconditional: **an empty canvas makes
      // every geometry assertion below trivially true**, so the shape has to be
      // shown to have put something down before "the something is contained" is
      // worth reading.
      expect(
        _litPixels(rgba),
        greaterThan(0),
        reason:
            'no pixel carries any ink. Everything below would then hold over an '
            'empty canvas, which is the shape of test §7 calls a gate that '
            'cannot fail.',
      );

      final Rect painted = _inkBounds(rgba, box.width, box.height)!;

      // Where the star's own box sits inside the capture.
      final Rect boundary = tester.getRect(find.byKey(_inkKey));
      final Rect star = tester
          .getRect(find.byType(FourPointedStar))
          .shift(-boundary.topLeft);

      expect(
        boundary.size,
        const Size.square(40 * _inkBoxFactor),
        reason:
            'the capture is four times the star, so containment means '
            'something — a tight boundary would make it true by definition',
      );
      expect(star.size, const Size.square(40));
      expect(star.topLeft, const Offset(60, 60), reason: 'and it is centred');

      expect(
        boundary.contains(painted.topLeft) &&
            boundary.contains(painted.bottomRight),
        isTrue,
        reason:
            'the ink is somewhere in the capture — this is the precondition '
            'for the containment claim below to be about the right box',
      );
      // **THE CLAIM.** One pixel of slack, because the rasteriser's antialiased
      // coverage on the outermost row of a shape whose edge is exactly on a
      // pixel boundary is what makes the last column lit at all; zero slack
      // would be asserting the rasteriser's rounding as well as the path's.
      expect(
        painted.left >= star.left - 1 && painted.right <= star.right + 1,
        isTrue,
        reason:
            'the shape painted outside its own box horizontally: ink '
            '${painted.left}…${painted.right} against a box '
            '${star.left}…${star.right}',
      );
      expect(
        painted.top >= star.top - 1 && painted.bottom <= star.bottom + 1,
        isTrue,
        reason:
            'the shape painted outside its own box vertically: ink '
            '${painted.top}…${painted.bottom} against a box '
            '${star.top}…${star.bottom}',
      );

      // And the star's points are at the **midpoints of its four edges**, which
      // is why "sized to the em box" means what it says: the shape uses the box
      // it was given rather than sitting inside it with a gutter. A ratio, so it
      // is a statement about the path and not about 40.
      // **Measured exact** at `size: 40` — the ink's box is
      // `60.0, 60.0, 100.0, 100.0` in a 160 capture, the star's own box to the
      // pixel — and the tolerance is one rasterised pixel of slack for sizes
      // where the edges do not land on whole pixels. Ratios rather than pixels,
      // so the row is about the path and not about 40.
      expect(painted.width / star.width, closeTo(1.0, 1 / 40));
      expect(painted.height / star.height, closeTo(1.0, 1 / 40));
    });

    testWidgets('and it is inked in the colour it was handed', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(_measured(size: 40, color: _ember));
      await tester.pump();

      expect(_modalOpaqueColour(await _inkPixels(tester)), _ember);
    });
  });

  group('repaint is decided by the ink and by nothing else', () {
    // **Both directions, in one body, from three pumps.** `shouldRepaint` is
    // public `CustomPainter` API, so this needs no name for the private class —
    // but the reason it is worth pinning at all is that the obvious wrong
    // implementation is `=> true`, which is a green widget and a battery drain
    // on an ambient screen, and `find.byType` cannot see the difference.
    testWidgets('a changed ink repaints, an unchanged one does not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_measured(size: 40, color: _ember));
      final CustomPainter ember = _painterOf(tester);

      // Same ink, a fresh build. `build` constructs a **new** painter every call,
      // so the two instances are never identical — which is exactly why
      // `shouldRepaint` must compare the ink and not the object.
      await tester.pumpWidget(_measured(size: 40, color: _ember));
      final CustomPainter emberAgain = _painterOf(tester);

      expect(
        emberAgain.shouldRepaint(ember),
        isFalse,
        reason: 'the ink is unchanged, so the layer is already correct',
      );

      // A different ink.
      await tester.pumpWidget(_measured(size: 40, color: _ink));
      final CustomPainter dark = _painterOf(tester);

      expect(
        dark.shouldRepaint(emberAgain),
        isTrue,
        reason: 'a different ink is the one thing that changes the output',
      );
    });

    // `shouldRepaint` is the mechanism; this is the consequence a reader sees,
    // and it is asserted on **pixels** for the same reason the containment rows
    // are. A painter that returned the right answer and painted the wrong colour
    // would pass the rows above.
    testWidgets('and the pixels change with it', (WidgetTester tester) async {
      _pinSurface(tester);
      await tester.pumpWidget(_measured(size: 40, color: _ember));
      await tester.pump();
      final Uint8List before = await _inkPixels(tester);

      await tester.pumpWidget(_measured(size: 40, color: _ink));
      await tester.pump();
      final Uint8List after = await _inkPixels(tester);

      expect(_modalOpaqueColour(before), _ember);
      expect(_modalOpaqueColour(after), _ink);
      expect(
        _inkBounds(before, 160, 160),
        _inkBounds(after, 160, 160),
        reason:
            'the silhouette must not move when the ink does — a painter that '
            'grew a glow for the dark ink would keep every other row in this '
            'file green while changing the shape',
      );
    });
  });

  group('it is decorative, and that is asserted rather than promised', () {
    // The class doc claims the shape carries **no accessible name**, because both
    // call sites put it inside a control that names itself. A decorative shape
    // with a name of its own would be announced twice; one with no name inside an
    // unnamed control would be announced as nothing, which is why the *positive*
    // half lives at a call site — `home_page_test.dart`'s `'the circle announces
    // that it cannot be pressed, and why'` reads the selah circle's node, and
    // `/reading`'s bookmark button is Task 5.3's. What is provable here, and what
    // would otherwise be prose, is the negative half.
    testWidgets('mounted alone it names nothing and offers nothing', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_measured(size: 40, color: _ember));

      final List<SemanticsData> nodes = semanticsTree(tester);
      // The walk itself is asserted first: `semanticsTree` fails closed on a
      // disabled tree, and a reader that found nothing would make the filter
      // below trivially empty.
      expect(nodes, isNotEmpty);
      expect(
        nodes.where((SemanticsData node) => node.label.isNotEmpty).toList(),
        isEmpty,
        reason:
            'a decorative shape must contribute no accessible name. Its meaning '
            'lives on the control that contains it, and a name here would be a '
            'second, competing announcement.',
      );
      expect(
        nodesOffering(tester, SemanticsAction.tap),
        isEmpty,
        reason: 'and it is not a control — it has nothing to press',
      );

      // `ensureSemantics` is disposed in the body and not in `addTearDown`:
      // recorded decision 38, and the framework compares the live handle count
      // against the one it took itself *before* a teardown would run.
      handle.dispose();
    });

    // The complement, mounted the way a call site mounts it. It does not assert
    // the call site exists — `/reading`'s is Task 5.3's — it asserts that this
    // widget **survives** being wrapped in a named control without either the
    // control's name or the shape leaking into the other's node.
    testWidgets('and a call site\'s name is what a reader meets', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        evaAmbientHarness(
          child: Semantics(
            button: true,
            // **`onTap` and not just `button: true`.** `button: true` sets the
            // *flag* and adds no action, which is the selah circle's own
            // arrangement (it is deliberately inert). The star's call sites are
            // live controls — `/reading`'s bookmark button is a button a reader
            // presses — so the fixture carries the action a reader would perform,
            // and the row asserts the node a reader actually lands on.
            onTap: _noop,
            label: 'Bookmark',
            excludeSemantics: true,
            child: const FourPointedStar(size: 40, color: Color(0xFFFFFFFF)),
          ),
        ),
      );

      final List<SemanticsData> named = semanticsTree(tester)
          .where((SemanticsData node) => node.label.isNotEmpty)
          .toList();
      expect(named, hasLength(1));
      expect(named.single.label, 'Bookmark');
      expect(named.single.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });
  });

  group('the reader this file leans on can also say "nothing"', () {
    // The negative control, and the reason the ink rows are trustworthy. The
    // same `RepaintBoundary`, the same `toImageSync`, the same scan, with a
    // `SizedBox` where the star would be.
    //
    // Without this row every assertion above is compatible with an instrument
    // that reports a full box of ink for **any** input — which is the same
    // failure as a gate that cannot fail, wearing a different hat, and it is
    // invisible because all of them are passing.
    testWidgets('an empty box measures zero ink and has no bounds', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(_emptyControl(size: 40));
      await tester.pump();

      final Uint8List rgba = await _inkPixels(tester);
      final ({int height, int width}) box = _inkSize(tester, rgba);

      expect(box.width, 160);
      expect(box.height, 160);
      expect(
        _litPixels(rgba),
        0,
        reason:
            'if this is not zero, the reader reports ink for an empty box and '
            'every containment row above is measuring the reader.',
      );
      expect(_inkBounds(rgba, box.width, box.height), isNull);
    });
  });
}
