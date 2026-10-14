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

/// Every [ClipPath] under the sky — one per star, and nothing else.
///
/// The count is the observable for "renders N stars for N entries". A painter
/// cannot answer it, which is the whole reason the four shapes are `ClipPath`s
/// rather than paths drawn into one canvas.
Finder get _starClips => find.descendant(
  of: find.byType(WitnessSky),
  matching: find.byType(ClipPath),
);

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
      final SizedBox box = tester.widget<SizedBox>(
        find.descendant(of: _starClips, matching: find.byType(SizedBox)).first,
      );
      expect(box.width, kSkyStarFlareSize);
      expect(box.height, kSkyStarFlareSize);
    });

    testWidgets('the shape switch changes the clipper and the size', (
      WidgetTester tester,
    ) async {
      // `SkyStarClipper` is a `CustomClipper`, not a `Widget`, so it is read off
      // the `ClipPath` that carries it rather than through `tester.widget`.
      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          shape: SkyStarShape.dot,
        ),
      );
      expect(
        (tester.widget<ClipPath>(_starClips).clipper! as SkyStarClipper).shape,
        SkyStarShape.dot,
      );

      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          shape: SkyStarShape.cross,
        ),
      );
      expect(
        (tester.widget<ClipPath>(_starClips).clipper! as SkyStarClipper).shape,
        SkyStarShape.cross,
      );
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
      final double dot = tester
          .widget<SizedBox>(
            find
                .descendant(of: _starClips, matching: find.byType(SizedBox))
                .first,
          )
          .width!;
      await _pumpSky(
        tester,
        _sky(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          shape: SkyStarShape.diamond,
        ),
      );
      final double gem = tester
          .widget<SizedBox>(
            find
                .descendant(of: _starClips, matching: find.byType(SizedBox))
                .first,
          )
          .width!;
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
