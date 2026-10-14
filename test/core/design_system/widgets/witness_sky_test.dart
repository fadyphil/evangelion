import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The surface every capture in this file is taken at.
///
/// 390×844 is `kAmbientSurface` — the phone the prototype's own numbers were
/// authored against — and the sky is full-bleed by design (`#sky` is
/// `position:absolute; inset:0`, `eva/redesign.html:116`), so there is no
/// narrower surface it would be honest to test at.
const Size _surface = kAmbientSurface;

/// Our own repaint boundary. `find.byType(RepaintBoundary).first` is
/// `MaterialApp`'s, and capturing that yields a transparent buffer — which
/// reads as "the sky painted nothing" and looks exactly like a real regression.
const Key _layerKey = ValueKey<String>('witness-sky-layer');

SkyEntry _entry(String book, int chapter, int verse, {bool flare = false}) =>
    SkyEntry(
      book: book,
      chapter: chapter,
      verse: verse,
      isFlare: flare,
      litAt: DateTime.utc(2026, 10, 14, 9, 30),
    );

final List<SkyEntry> _three = <SkyEntry>[
  _entry('John', 3, 16),
  _entry('John', 3, 17),
  _entry('John', 3, 18, flare: true),
];

Widget _sky({
  List<SkyEntry>? entries,
  double brightness = kSkyDefaultBrightness,
  bool twinkle = true,
  SkyStarShape shape = SkyStarShape.dot,
  SkyStarField field = SkyStarField.crown,
  bool showConstellation = true,
  ThemeData? theme,
  bool disableAnimations = false,
  bool animationsEnabled = false,
}) => evaAmbientHarness(
  theme: theme,
  disableAnimations: disableAnimations,
  animationsEnabled: animationsEnabled,
  child: RepaintBoundary(
    key: _layerKey,
    child: WitnessSky(
      entries: entries ?? _three,
      brightness: brightness,
      twinkle: twinkle,
      shape: shape,
      field: field,
      showConstellation: showConstellation,
    ),
  ),
);

Future<void> _pumpSky(
  WidgetTester tester,
  Widget child, {
  Duration settle = const Duration(milliseconds: 100),
}) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(child);
  await tester.pump();
  await tester.pump(settle);
}

Future<List<int>> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_layerKey));
  final List<int>? bytes = await tester.runAsync<List<int>>(() async {
    final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
    final ByteData? data = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ));
    image.dispose();
    if (data == null) {
      throw StateError('the witness-sky layer produced no byte data');
    }
    return <int>[for (int i = 0; i < data.lengthInBytes; i++) data.getUint8(i)];
  });
  // Failing closed: an empty buffer satisfies every "the pixels differ" and
  // "the pixels are identical" comparison in this file vacuously.
  if (bytes == null || bytes.isEmpty) {
    throw StateError(
      'the witness-sky layer produced ${bytes?.length ?? 0} bytes; a capture '
      'that returned nothing cannot support any assertion in this file',
    );
  }
  return bytes;
}

/// The box of every star under the sky — one per entry.
///
/// **The keyed [SizedBox], not the [ClipPath].** A `ClipPath` finder reads the
/// widget's internals, and this widget's internals changed under it when
/// `skyClipsPaint` was corrected: `s-dot` reaches its circle through
/// `border-radius: 50%` (`eva/redesign.html:120`) and is therefore **not**
/// clip-pathed at all, so a `ClipPath` finder reported **zero** stars for the
/// default shape and four suites went red for a change that was correct.
///
/// A painter cannot answer "how many stars are on screen" either — which is why
/// the shapes are widgets rather than paths in one canvas, and why the key is
/// on the box rather than on the clip.
Finder get _starClips => find.descendant(
  of: find.byType(WitnessSky),
  matching: find.byType(SizedBox),
);

/// The inked bounding box of a capture, in logical px.
///
/// Alpha and not colour: the sky is painted over a transparent layer, so the
/// alpha channel is the only thing that says where the ink is. (There is no
/// halo in these captures — see the shadow note on the shape test below.)
class _Box {
  _Box(this.minX, this.maxX, this.minY, this.maxY, this.lit);

  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
  final int lit;

  int get width => maxX - minX + 1;

  int get height => maxY - minY + 1;
}

/// The bounding box of every non-zero-alpha pixel in [rgba].
_Box _inkBounds(List<int> rgba, int width) {
  int lit = 0;
  int minX = width, maxX = -1, minY = width, maxY = -1;
  for (int y = 0; y < _shapeSurface.height; y++) {
    for (int x = 0; x < width; x++) {
      if (rgba[((y * width) + x) * 4 + 3] == 0) continue;
      lit++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return _Box(minX, maxX, minY, maxY, lit);
}

/// How many pixels of row [y] between [x0] and [x1] carry ink.
int _litOnRow(List<int> rgba, int width, int x0, int x1, int y) {
  int n = 0;
  for (int x = x0; x <= x1; x++) {
    if (rgba[((y * width) + x) * 4 + 3] != 0) n++;
  }
  return n;
}

/// The surface the four-shape measurements are taken at.
///
/// Small on purpose: one star at 200×200 keeps a capture to a fraction of the
/// ambient goldens' 390×844 while leaving every polygon well above one pixel,
/// and the numbers are only ever compared with numbers from this same surface.
const Size _shapeSurface = Size(200, 200);

/// The constellation's painter, found by its two-point minimum.
Finder get _constellation => find.descendant(
  of: find.byType(WitnessSky),
  matching: find.byType(CustomPaint),
);

void main() {
  group('the star layer', () {
    testWidgets('renders one star per entry, and holds no cap of its own', (
      WidgetTester tester,
    ) async {
      // 50 and 60 are **past** every number the prototype knows: the default
      // `starCap` is 44 (`:1131`) and the Star-count slider tops out at 60
      // (`:669`). `sky_star_cap.dart` is where the 44 lives and `SkyCubit` is
      // what applies it — a cap here would be a second implementation of a
      // number that already has one. Testing only up to 44 left the widget's own
      // doc claim ("it holds no cap") with no witness: `.take(44)` passed the
      // whole suite, and that is the assertion this loop now exists for.
      for (final int count in <int>[0, 1, 2, 7, 44, 50, 60]) {
        await _pumpSky(
          tester,
          _sky(
            entries: <SkyEntry>[
              for (int i = 0; i < count; i++) _entry('Psalms', 1, i + 1),
            ],
          ),
        );
        expect(
          _starClips,
          findsNWidgets(count),
          reason: '$count entries must paint $count stars',
        );
      }
    });

    testWidgets('an unbounded box THROWS and names the fix', (
      WidgetTester tester,
    ) async {
      // The corrected half of I3. The widget's doc once promised the sky
      // "paints nothing rather than throwing" in an unbounded box, and carried a
      // `size.isFinite` guard to make that true. Both were false: `Stack`
      // asserts on unbounded constraints **before** any child of it builds, so
      // the guard was unreachable and the promise was unfalsifiable. Measured
      // before the fix: 25 cascading `FlutterError`s; after: the framework's one
      // assertion, which names the remedy.
      //
      // The behaviour is the correct one and is asserted rather than tolerated:
      // a caller who has put a full-bleed layer in a `Column` has a wiring
      // mistake, and a silent empty sky would hide it.

      // Captured through `FlutterError.onError` and NOT `tester.takeException()`,
      // and that is mechanical rather than stylistic: once a second exception
      // lands, the test framework **replaces** the pending exception with an
      // aggregate whose message is "Multiple exceptions (24) were detected…"
      // (`flutter_test/lib/src/binding.dart:1785-1790`), so every assertion on
      // `takeException().toString()` would be reading the wrapper rather than
      // what went wrong. That is a whole class of test that can only fail
      // vacuously, and it is why the assertion is on `caught.first`.
      final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails d) {
        if (caught.isEmpty) caught.add(d);
        // **Forwarded, and that is load-bearing.** Swallowing the error keeps
        // the framework's own bookkeeping out of step and the test hangs to the
        // ten-minute timeout (measured: "Cannot close sink while adding stream",
        // with `binding.dart:1773-1790` left believing no exception landed).
        previous?.call(d);
      };
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        evaAmbientHarness(
          animationsEnabled: false,
          child: Column(
            children: <Widget>[
              WitnessSky(entries: <SkyEntry>[_entry('John', 3, 16)]),
            ],
          ),
        ),
      );

      int total = 0;
      while (tester.takeException() != null) {
        total++;
      }

      expect(
        caught,
        isNotEmpty,
        reason: 'an unbounded box must not pass silently',
      );
      expect(
        caught.first.exception.toString(),
        contains('bounded constraints'),
        reason:
            'the framework names the fix in the message, and that is the whole '
            'reason this behaviour is worth keeping over a silent nothing',
      );
      // The cascade is the framework's own, and the count is RECORDED rather
      // than asserted as an ideal: the old `size.isFinite` guard lived below the
      // assert and so could not prevent any of them, which is exactly why the
      // promise it was written to keep was false.
      expect(total, greaterThan(0));
    });

    testWidgets('an empty sky is the container and nothing else', (
      WidgetTester tester,
    ) async {
      await _pumpSky(tester, _sky(entries: const <SkyEntry>[]));
      expect(find.byType(WitnessSky), findsOneWidget);
      expect(_starClips, findsNothing);
      expect(_constellation, findsNothing, reason: '`:1170` needs two stars');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a flare is 5px and an ordinary star is not', (
      WidgetTester tester,
    ) async {
      await _pumpSky(
        tester,
        _sky(entries: <SkyEntry>[_entry('John', 3, 16, flare: true)]),
      );
      final SizedBox box = tester.widget<SizedBox>(_starClips.first);
      expect(box.width, kSkyStarFlareSize);
      expect(box.height, kSkyStarFlareSize);
    });

    testWidgets('the shape switch changes the MECHANISM and the size', (
      WidgetTester tester,
    ) async {
      // The first version of this test asserted
      // `(ClipPath.clipper as SkyStarClipper).shape == SkyStarShape.dot` — a
      // restatement of the value handed to the constructor, which cannot fail
      // however the widget paints. It stayed green through a tree in which the
      // clip was **inside** the decoration and all three polygons rendered as
      // identical solid squares (measured: `lit=72 box=[131..138]x[16..24]` for
      // star, cross and diamond alike, top row 8/8 lit where an apex should be
      // one pixel). The pixels are the witness; see "the four shapes are four
      // shapes" below.
      //
      // What is left here is the half that is about the tree rather than the
      // paint, and it is the half [skyClipsPaint] decides: the dot has **no**
      // `ClipPath` at all.
      Finder clipsInSky() => find.descendant(
        of: find.byType(WitnessSky),
        matching: find.byType(ClipPath),
      );

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          shape: SkyStarShape.dot,
        ),
      );
      expect(
        clipsInSky(),
        findsNothing,
        reason:
            '`:120` is `border-radius: 50%`, not a `clip-path`. On a device a '
            '`ClipPath` here would round the fill AND the halo — a different '
            'star. (In this suite the halo is not rasterised at all, so the '
            'witness for the dot is its fill, in the shape test below.)',
      );

      for (final SkyStarShape shape in const <SkyStarShape>[
        SkyStarShape.star,
        SkyStarShape.cross,
        SkyStarShape.diamond,
      ]) {
        await _pumpSky(
          tester,
          _sky(entries: <SkyEntry>[_entry('John', 3, 16)], shape: shape),
        );
        expect(
          (tester.widget<ClipPath>(clipsInSky()).clipper! as SkyStarClipper)
              .shape,
          shape,
          reason: '${shape.name} is `clip-path: polygon(…)`',
        );
      }
    });

    testWidgets('a non-dot shape paints a bigger star for the same key', (
      WidgetTester tester,
    ) async {
      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          shape: SkyStarShape.dot,
        ),
      );
      final double dot = tester.widget<SizedBox>(_starClips.first).width!;
      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          shape: SkyStarShape.diamond,
        ),
      );
      final double gem = tester.widget<SizedBox>(_starClips.first).width!;
      expect(gem, closeTo(dot * kSkyShapeSizeScale, 1e-9));
    });

    testWidgets('the field switch moves the star and keeps its size', (
      WidgetTester tester,
    ) async {
      Rect boxOf(WidgetTester t) => t.getRect(_starClips.first);

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          field: SkyStarField.crown,
        ),
      );
      final Rect crown = boxOf(tester);

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          field: SkyStarField.full,
        ),
      );
      final Rect full = boxOf(tester);

      expect(
        full.width,
        crown.width,
        reason: 'the size does not follow the band',
      );
      expect(full.left, crown.left, reason: 'neither does the column');
      expect(full.top, greaterThan(crown.top));
      expect(full.top, lessThanOrEqualTo(60 / 100 * _surface.height));
    });

    testWidgets('brightness paints, and 0 is refused rather than erased', (
      WidgetTester tester,
    ) async {
      await _pumpSky(tester, _sky(brightness: 1.0));
      final List<int> normal = await _pixels(tester);
      await _pumpSky(tester, _sky(brightness: 0.3));
      expect((await _pixels(tester)).toString(), isNot(normal.toString()));

      expect(
        () => WitnessSky(entries: _three, brightness: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('the four shapes are four shapes, measured in PIXELS', () {
    // THE B1 REGRESSION GROUP. Three of the four shapes rendered as a solid
    // square, byte-identical to one another, and every assertion in the suite
    // was green — because the only shape assertion read back the constructor
    // argument. What follows reads the rendered pixels, which is the only
    // instrument that can see a clip that is not clipping.
    Future<List<int>> shapePixels(
      WidgetTester tester,
      SkyStarShape shape,
    ) async {
      // A small surface: one star, no twinkle (so nothing moves between the two
      // captures a comparison needs), no constellation.
      tester.view.physicalSize = _shapeSurface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        evaAmbientHarness(
          animationsEnabled: false,
          child: RepaintBoundary(
            key: _layerKey,
            child: WitnessSky(
              entries: <SkyEntry>[_entry('John', 3, 16)],
              shape: shape,
              twinkle: false,
              showConstellation: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return _pixels(tester);
    }

    testWidgets('each silhouette paints a different set of pixels', (
      WidgetTester tester,
    ) async {
      final Map<SkyStarShape, List<int>> painted = <SkyStarShape, List<int>>{};
      for (final SkyStarShape shape in SkyStarShape.values) {
        painted[shape] = await shapePixels(tester, shape);
      }

      for (int i = 0; i < SkyStarShape.values.length; i++) {
        for (int j = i + 1; j < SkyStarShape.values.length; j++) {
          final SkyStarShape a = SkyStarShape.values[i];
          final SkyStarShape b = SkyStarShape.values[j];
          expect(
            painted[a]!.toString(),
            isNot(painted[b]!.toString()),
            reason:
                '${a.name} and ${b.name} render identically. Measured on the '
                'pre-fix tree: all three polygons were lit=72 over '
                '[131..138]x[16..24] with the top row 8/8 lit — a solid square.',
          );
        }
      }
    });

    testWidgets("a star's top row is an APEX flanked by zero, not a lit edge", (
      WidgetTester tester,
    ) async {
      // The sharpest single reading of "the polygon cuts the box". `s-star`'s
      // first polygon point is `50% 0` and its second is `62% 38%`
      // (eva/redesign.html:121), so on the topmost lit row only the middle of
      // the box can be inked. A full row means the fill is the whole rectangle.
      final List<int> px = await shapePixels(tester, SkyStarShape.star);
      final _Box box = _inkBounds(px, 200);

      final int topRow = _litOnRow(px, 200, box.minX, box.maxX, box.minY);
      expect(
        topRow,
        lessThan(box.width),
        reason:
            'the topmost lit row runs ${box.width}px wide. An eight-point star '
            'begins at a single apex (50% 0) and widens to 62% by 38% of the '
            'height, so the first row can only be a point or two.',
      );
      // And the same row is not empty either — the apex is genuinely there, so
      // this is not satisfied by a star that painted nothing at all.
      expect(topRow, greaterThan(0));
      expect(box.lit, greaterThan(0));
    });

    testWidgets("the dot's fill fills its box, the polygons' is cut to it", (
      WidgetTester tester,
    ) async {
      // ## WHAT IS ACTUALLY MEASURED HERE, AND WHAT IS NOT
      //
      // **Not a halo.** `AutomatedTestWidgetsFlutterBinding.disableShadows` is
      // `true` (`flutter_test/lib/src/binding.dart:2234`, assigned to
      // `debugDisableShadows` at `:1079` — set in `flutter test`'s own
      // `setupAll`, measured `true` here), so **`BoxShadow` is not rasterised
      // anywhere in this suite**. Every pixel in these captures is the FILL.
      // The previous name of this test said the dot "keeps its halo", and its
      // reason strings said the halo is "what puts ink outside" — a mechanism
      // the pixels do not contain, and a claim a reader would reasonably take
      // for a witness. The name and the strings now say what the numbers are.
      //
      // The CSS reasoning that motivates the two trees is still true and is
      // recorded below, but it is **reasoning, not measurement**: an **outer**
      // `box-shadow` is drawn outside the border edge only — "it is clipped
      // inside the border-box of the element" (CSS Backgrounds 3 §6.1.1) — and
      // `clip-path` clips the element's whole rendering, background and border
      // included (MDN, `clip-path`). The prototype gives all four classes a
      // `box-shadow` (`:1152`) but reaches it through `border-radius` for the dot
      // (`:120`) and `clip-path: polygon(…)` for the rest (`:121-123`):
      //
      // | mechanism | what it clips | what survives (on a device) |
      // | --- | --- | --- |
      // | `border-radius: 50%` | rounds the **border box**; the shadow follows it | a visible ring outside the disc |
      // | `clip-path: polygon(…)` | the whole rendering to a region **inside** the border box | nothing — the shadow is already outside it |
      //
      // **What the pixels DO see is the other half of that table, and it is
      // enough:** the dot is a filled disc sized to its whole box, while the
      // polygons are filled only where their polygon is, and `clip-path` is what
      // makes that true. That is the B1 regression, and it is what these two
      // assertions read.
      final _Box dot = _inkBounds(
        await shapePixels(tester, SkyStarShape.dot),
        200,
      );
      final _Box star = _inkBounds(
        await shapePixels(tester, SkyStarShape.star),
        200,
      );

      // Each shape's OWN box, and the sizes genuinely differ: `:1148` multiplies a
      // non-dot by 1.5. Comparing the dot against the star's box would measure
      // the scale factor rather than the clip, so each is read from the layout
      // that produced it.
      int boxOf(SkyStarShape shape) => skyStarLayoutFor(
        key: 'John:3:16',
        shape: shape,
        field: SkyStarField.crown,
        isFlare: false,
      ).size.ceil();

      // The dot's fill covers the box's **full fractional extent**: a 4.968px box
      // starting at x = 131.05 runs to 136.02, and a rectangle that size inks six
      // columns, not `ceil(4.968) == 5`. That is the signature of a fill that is
      // not cut, and it is the assertion that fails when the dot is clip-pathed.
      expect(
        dot.width,
        greaterThan(boxOf(SkyStarShape.dot)),
        reason:
            'the dot\'s fill inks ${dot.width}px across a box whose size is '
            '${boxOf(SkyStarShape.dot)}px. `ceil(4.968) == 5`, and an '
            'uncut box starting at 131.05 ends at 136.02, so six columns are '
            'correct for a full fill. Five would mean it was cut.',
      );
      // The polygons' fill is cut to the polygon, which is inscribed in the box,
      // so the ink can never exceed the box. Measured: 7.452px box → 8 columns.
      expect(
        star.width,
        lessThanOrEqualTo(boxOf(SkyStarShape.star)),
        reason:
            'the star\'s fill inks ${star.width}px across a box of '
            '${boxOf(SkyStarShape.star)}px. The polygon is inscribed in the box, '
            'so it cannot ink more than the box; anything wider would mean the '
            'box itself is being filled.',
      );
      expect(
        star.height,
        lessThanOrEqualTo(boxOf(SkyStarShape.star)),
        reason: 'and the same holds vertically — the fill is the whole story',
      );
    });
  });

  group('the constellation', () {
    testWidgets('appears at the second star and not before', (
      WidgetTester tester,
    ) async {
      await _pumpSky(tester, _sky(entries: <SkyEntry>[_entry('John', 3, 16)]));
      expect(
        _constellation,
        findsNothing,
        reason: '`:1170` — `stars.length < 2`',
      );

      await _pumpSky(
        tester,
        _sky(entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)]),
      );
      expect(_constellation, findsOneWidget);
    });

    testWidgets('the switch removes it outright rather than hiding it', (
      WidgetTester tester,
    ) async {
      // eva/redesign.html:1484-1485 — `if(!constOn){ … svg.remove() }`.
      await _pumpSky(tester, _sky(showConstellation: false));
      expect(_constellation, findsNothing);
      expect(_starClips, findsNWidgets(3), reason: 'the stars are unaffected');
    });

    testWidgets('the line on screen is the lit-event order, not a sort of it', (
      WidgetTester tester,
    ) async {
      // The exact points are asserted in `witness_sky_layout_test.dart`, against
      // `skyConstellationPoints` — the same function the painter is fed. What is
      // left for the widget is the one thing the pure suite cannot see: that the
      // ORDER the caller hands over survives the trip to the canvas.
      //
      // Three permutations of the same three stars. A polyline through three
      // points has three distinct shapes, so if any one of these renders like
      // another the order is not being carried — and "the line exists" (asserted
      // above) is satisfied by all three.
      //
      // **The pixels, not the painter's field.** The painter is private, and
      // `sky_local_data_source.dart:67` records the house rule for that case: a
      // member that exists only for a test is worse than the doc comment, and a
      // `dynamic` cast to reach a private field is worse still. What a reader
      // can see is the constellation.
      final List<SkyEntry> entries = <SkyEntry>[
        _entry('John', 3, 16),
        _entry('John', 3, 17),
        _entry('John', 3, 18),
      ];
      final List<SkyEntry> rotated = <SkyEntry>[
        entries[1],
        entries[2],
        entries[0],
      ];

      await _pumpSky(tester, _sky(entries: entries));
      final List<int> forward = await _pixels(tester);
      await _pumpSky(tester, _sky(entries: entries.reversed.toList()));
      final List<int> reversed = await _pixels(tester);
      await _pumpSky(tester, _sky(entries: rotated));
      final List<int> turned = await _pixels(tester);

      expect(
        forward.toString(),
        isNot(reversed.toString()),
        reason:
            'a constellation drawn back-to-front is a different line — the '
            'prototype reads the stars back in DOM order (`:1169`, `:1173`)',
      );
      expect(
        forward.toString(),
        isNot(turned.toString()),
        reason: 'and a third permutation is a third shape',
      );
      expect(
        turned.toString(),
        isNot(reversed.toString()),
        reason:
            'all three are the same three stars, so a pair agreeing means the '
            'order collapsed somewhere between the caller and the canvas',
      );
    });
  });

  group('the draw-on', () {
    testWidgets('it is one controller for the whole sky, not one per star', (
      WidgetTester tester,
    ) async {
      // §13.2's collapse, and the reason the flare's one-shot is not ported.
      // Four ambient clocks is the app's whole ambient budget.
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _sky(
          entries: _three,
          showConstellation: false,
          animationsEnabled: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        4,
        reason:
            'four shared ambient clocks and no controller of its own when '
            'there is no constellation to draw',
      );

      await tester.pumpWidget(_sky(entries: _three, animationsEnabled: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        5,
        reason: 'exactly one more: the single draw-on, for 3 stars and for 44',
      );
    });

    testWidgets('the line is off the canvas and arrives over 1.2s', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_sky(entries: _three, animationsEnabled: true));
      await tester.pump();
      // The post-frame callback has forwarded but no frame has been produced yet.
      await tester.pump(const Duration(milliseconds: 600));
      final List<int> half = await _pixels(tester);

      await tester.pump(kSkyConstellationDrawDuration);
      final List<int> done = await _pixels(tester);

      expect(
        half.toString(),
        isNot(done.toString()),
        reason: 'the draw-on has to move pixels, or it is not drawing anything',
      );
    });

    testWidgets('THE B2 CASE: lighting the 2nd star after mount DRAWS the line', (
      WidgetTester tester,
    ) async {
      // The defect this commit fixed. `/reading` lights verses as they scroll
      // into view (`eva/redesign.html:1208-1221`), so the real arrival order is
      // one star at mount and two (then three) afterwards. Arming the draw-on
      // only in `initState` left the controller at 0 forever and
      // `extractPath(0, 0)` drew an empty path: measured, growing 1 → 2 entries
      // produced a buffer **byte-identical** to a sky built with
      // `showConstellation: false`.
      //
      // The two captures are the same tree at the same clock phase with the
      // constellation the only variable, so the difference is the line itself.
      await _pumpSky(tester, _sky(entries: <SkyEntry>[_entry('John', 3, 16)]));
      expect(
        _constellation,
        findsNothing,
        reason: '`:1170` — one star is not a constellation',
      );

      await _pumpSky(
        tester,
        _sky(entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)]),
      );
      // Past the 1.2s draw-on, so a finished line is compared and not a frame
      // of a moving one.
      await tester.pump(kSkyConstellationDrawDuration);
      final List<int> grown = await _pixels(tester);

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)],
          showConstellation: false,
        ),
      );
      await tester.pump(kSkyConstellationDrawDuration);
      final List<int> without = await _pixels(tester);

      expect(
        grown.toString(),
        isNot(without.toString()),
        reason:
            'the grown sky must have painted the line. Byte-identical buffers '
            'are the exact signature of the B2 defect.',
      );
    });

    testWidgets('a third star EXTENDS the line and does not replay it', (
      WidgetTester tester,
    ) async {
      // The deliberate half of the replay rule. `:1156-1158` draws once per book,
      // not once per star, so growth extends rather than restarts — a line a
      // reader is watching is not yanked back to nothing because they scrolled.
      //
      // Measured by the controller's own value: at `1.0` the draw-on is over,
      // and adding a star must leave it there.
      await _pumpSky(
        tester,
        _sky(entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)]),
      );
      await tester.pump(kSkyConstellationDrawDuration);
      final List<int> twoStars = await _pixels(tester);

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[
            _entry('John', 3, 16),
            _entry('John', 3, 17),
            _entry('John', 3, 18),
          ],
        ),
      );
      final List<int> threeStars = await _pixels(tester);

      expect(
        threeStars.toString(),
        isNot(twoStars.toString()),
        reason: 'the third star is on screen, so the sky changed',
      );
      // And the extension is visible immediately: had the third star restarted
      // the draw-on, the line would be mostly *absent* on this very frame.
      await tester.pump(const Duration(milliseconds: 100));
      final List<int> stillThere = await _pixels(tester);
      expect(
        stillThere.toString(),
        threeStars.toString(),
        reason:
            '100ms after the third star the line is unchanged, which is what '
            '"extended" means. A restart would have erased most of it.',
      );
    });

    testWidgets('the Constellations switch replays on ONE tree', (
      WidgetTester tester,
    ) async {
      // `:1484-1485` removes the `svg` and a later draw appends a fresh one that
      // draws itself on again. Tested on a single mounted tree rather than by
      // pumping a second widget, because "two mounts each arm in `initState`"
      // and "one tree re-arms on the switch" are different mechanisms and only
      // the second is this widget's rule.
      await _pumpSky(
        tester,
        _sky(entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)]),
      );
      await tester.pump(kSkyConstellationDrawDuration);

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)],
          showConstellation: false,
        ),
      );
      expect(_constellation, findsNothing);

      // Back on, mid-draw-on: the line must be PARTLY drawn, which is only
      // true of a controller that restarted from 0.
      await _pumpSky(
        tester,
        _sky(entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)]),
      );
      await tester.pump();
      final List<int> startOfReplay = await _pixels(tester);
      await tester.pump(kSkyConstellationDrawDuration);
      final List<int> endOfReplay = await _pixels(tester);

      expect(
        startOfReplay.toString(),
        isNot(endOfReplay.toString()),
        reason:
            'the switch coming back must draw the line on again — identical '
            'buffers mean it reappeared already finished, or not at all',
      );
    });

    testWidgets('reduced motion draws the line FINISHED and ticks nothing', (
      WidgetTester tester,
    ) async {
      // §14's "jump straight to the end state", and the half that is easy to get
      // wrong: `forward()` reaches the end state too, and leaves a fifth
      // transient callback running under a sky that has already finished. §13.2's
      // budget is four, app-wide.
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)],
          disableAnimations: true,
          animationsEnabled: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        4,
        reason:
            'the four shared ambient clocks. A fifth is the draw-on still '
            'ticking after it has reached its end state — measured at 5 on the '
            'pre-fix tree.',
      );

      // And the end state is the FINISHED line, not an absent one. The control
      // is the same reduced-motion sky with the constellation switched off — not
      // the animated sky, whose stars are mid-twinkle at `--so * .35` and would
      // differ for a dozen reasons that have nothing to do with the line.
      final List<int> reduced = await _pixels(tester);
      await tester.pumpWidget(
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16), _entry('John', 3, 17)],
          showConstellation: false,
          disableAnimations: true,
          animationsEnabled: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        reduced.toString(),
        isNot((await _pixels(tester)).toString()),
        reason:
            'reduced motion is the end state, and the end state of a draw-on is '
            'a fully drawn line. Matching the constellation-off build would mean '
            '"no motion" was achieved by deleting the thing.',
      );
    });

    testWidgets('and it finishes, rather than running forever', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_sky(entries: _three, animationsEnabled: true));
      await tester.pump();
      await tester.pump(kSkyConstellationDrawDuration);
      await tester.pump(const Duration(seconds: 5));
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        4,
        reason: 'the four ambient clocks — the draw-on has completed',
      );
    });
  });

  group('reduced motion — §14', () {
    testWidgets('disableAnimations freezes the sky', (
      WidgetTester tester,
    ) async {
      await _pumpSky(
        tester,
        _sky(disableAnimations: true, animationsEnabled: true),
        settle: const Duration(milliseconds: 100),
      );
      final List<int> before = await _pixels(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(
        before.toString(),
        (await _pixels(tester)).toString(),
        reason: 'a reader who asked for reduced motion gets a still sky',
      );
    });

    testWidgets('and the frozen star is at full --so and UNSCALED', (
      WidgetTester tester,
    ) async {
      // The two frozen endpoints are the top of one range and the bottom of
      // another, so they need two assertions. `#sky.notwinkle` (`:117`) and
      // `.screen.rm .star` (`:51`) both say `opacity: var(--so)` with no
      // transform — so a frozen star is the BRIGHTEST it ever is and the
      // SMALLEST it ever is, at once.
      //
      // The opacity half was added because the first version of this test
      // asserted only the scale, and mutating the frozen triangle from `1.0` to
      // `0.0` — which dims every frozen star to `--so * .35` — left all 21 tests
      // green. §7's "a gate that cannot fail", found by planting the defect
      // rather than by reading the assertion.
      await _pumpSky(tester, _sky(disableAnimations: true));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: _starClips.first,
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        closeTo(kSkyStarBaseOpacity * kSkyDefaultBrightness, 1e-9),
        reason: 'a still star is at `--so`, not at `--so * .35`',
      );
      expect(
        tester
            .widget<Transform>(
              // `Transform.scale` and `Opacity` are the star's **parents**, not
              // its children, so this walks up. A descendant finder would match
              // nothing and `find.first` on it is the assertion this file must
              // not contain.
              find
                  .ancestor(
                    of: _starClips.first,
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .getMaxScaleOnAxis(),
        kSkyTwinkleScaleRest,
      );
    });

    testWidgets('and a twinkling star IS at the dim end of the same range', (
      WidgetTester tester,
    ) async {
      // The control for the assertion above: with the clocks stopped the shared
      // float clock reads 0, so a twinkling star sits at its dimmest — and the
      // two must not be able to agree.
      await _pumpSky(tester, _sky());
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: _starClips.first,
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        closeTo(
          skyStarOpacity(brightness: kSkyDefaultBrightness, triangle: 0.0),
          1e-9,
        ),
      );
    });

    testWidgets('the Twinkle switch off freezes the STARS the same way', (
      WidgetTester tester,
    ) async {
      // eva/redesign.html:117 — `#sky.notwinkle .star{animation:none;opacity:var(--so,.9)}`.
      //
      // `showConstellation: false` is load-bearing: the Twinkle switch governs
      // `.star` and not the `svg`, so leaving the constellation on would assert
      // "frozen" against a line that is legitimately still drawing itself on.
      await _pumpSky(
        tester,
        _sky(twinkle: false, showConstellation: false, animationsEnabled: true),
      );
      final List<int> before = await _pixels(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(before.toString(), (await _pixels(tester)).toString());
    });

    testWidgets('and a moving sky does move, so the freeze means something', (
      WidgetTester tester,
    ) async {
      await _pumpSky(
        tester,
        _sky(animationsEnabled: true),
        settle: const Duration(milliseconds: 400),
      );
      final List<int> before = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        before.toString(),
        isNot((await _pixels(tester)).toString()),
        reason:
            'the control for the three freezes above — without it, "the pixels '
            'did not move" would be satisfied by a sky that never animates',
      );
    });
  });

  group('the sky is inert', () {
    testWidgets('it never takes a pointer and says nothing', (
      WidgetTester tester,
    ) async {
      await _pumpSky(tester, _sky());
      expect(
        find.descendant(
          of: find.byType(WitnessSky),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(WitnessSky),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tap passes straight through it', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pumpSky(
        tester,
        evaAmbientHarness(
          animationsEnabled: false,
          child: SizedBox(
            width: _surface.width,
            height: _surface.height,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => taps++,
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
                Positioned.fill(child: WitnessSky(entries: _three)),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byType(WitnessSky)));
      await tester.pump();
      expect(
        taps,
        1,
        reason: 'a full-bleed layer that ate taps would be a bug',
      );
    });
  });

  group('the four shapes in the goldens, not only in the dot', () {
    // The goldens captured only `SkyStarShape.dot` — the **default** shape, and
    // the one of the four the prototype's `clip-path` never touches (`:120` is
    // `border-radius`). So the B1 regression was invisible in the goldens too:
    // three of the four silhouettes had no reference image at all. A golden per
    // theme is cheap here, and the shapes are the part most likely to be wrong
    // again, so all four are captured in one strip per theme.
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('all four silhouettes on $label', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = _shapeSurface;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Four small skies side by side, one per shape, each pinned to a known
        // entry so the strip is deterministic: `twinkle: false` freezes the
        // stars at full `--so` and unscaled, and the entries are the same key
        // in each so the shapes are the only variable.
        await tester.pumpWidget(
          evaAmbientHarness(
            theme: theme,
            animationsEnabled: false,
            child: RepaintBoundary(
              key: _layerKey,
              child: Row(
                children: <Widget>[
                  for (final SkyStarShape shape in SkyStarShape.values)
                    SizedBox(
                      width: _shapeSurface.width / 4,
                      height: _shapeSurface.height,
                      child: WitnessSky(
                        entries: <SkyEntry>[_entry('John', 3, 16)],
                        shape: shape,
                        twinkle: false,
                        showConstellation: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await expectLater(
          find.byKey(_layerKey),
          matchesGoldenFile('goldens/witness_sky_shapes_$label.png'),
        );
      });
    }
  });

  group('theming', () {
    for (final (String label, ThemeData theme) in kEvaThemes) {
      testWidgets('goldens on $label', (WidgetTester tester) async {
        await _pumpSky(
          tester,
          _sky(theme: theme, animationsEnabled: true),
          settle: const Duration(milliseconds: 400),
        );
        await expectLater(
          find.byKey(_layerKey),
          matchesGoldenFile('goldens/witness_sky_$label.png'),
        );
      });
    }
  });
}
