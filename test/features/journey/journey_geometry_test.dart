import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/presentation/journey_colours.dart';
import 'package:evangelion/features/journey/presentation/journey_l10n.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_medals_strip.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_orb.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_rings_row.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/design_system_harness.dart';

/// The geometry of `/journey` — the numbers this screen owns, **measured off
/// the rendered tree**.
///
/// ## WHY THE PAINTED BOX AND NOT THE LAYOUT BOX
///
/// `RenderBox.size` is the **layout** size, and it is not always what a reader
/// sees: a `Transform.scale` paints its child smaller than it lays it out, so
/// a measurement taken from the layout size would report a widget's final size
/// while the reader is looking at one that is still growing.
///
/// `communion_page_test.dart`'s `_paintedSize` walks the whole ancestor
/// transform chain through `localToGlobal`, and that is the helper below.
/// Every number this file asserts is read through it, so a widget that is
/// scaled, translated or otherwise transformed cannot pass this suite by
/// reporting a layout size it is not painting.
///
/// ## AND THE NUMBERS ARE THE PROTOTYPE'S, WRITTEN OUT
///
/// Every expected value below is **spelled out in the test**, not read back out
/// of a constant the widget also reads. A test that asserted
/// `expect(box.size.width, JourneyRingsRow.ringSize)` would pass even if the
/// constant were wrong; a test that asserts `64` fails the moment the
/// constant and the prototype disagree.
void main() {
  group('the orb', () {
    testWidgets('is 74 by 74 — the prototype\'s `.jorb`', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JourneyOrb(monogram: 'DM', semanticLabel: 'David Mina'),
      );

      // `eva/redesign.html:392` — `.jorb{width:74px;height:74px}`.
      expect(
        _paintedSize(tester, find.byType(SealMonogram)),
        const Size(74, 74),
      );
    });

    testWidgets('draws the reader\'s own monogram, not the prototype\'s M', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JourneyOrb(monogram: 'DM', semanticLabel: 'David Mina'),
      );

      // `eva/redesign.html:586` — `<div class="jorb">M</div>`, the initial of
      // the prototype's literal "Mariam Hanna". Ours is the session's.
      expect(find.text('DM'), findsOneWidget);
      expect(find.text('M'), findsNothing);
    });
  });

  group('the rings', () {
    testWidgets('each ring is 64 by 64', (WidgetTester tester) async {
      await _pump(tester, _rings());

      // `eva/redesign.html:592` — `<svg width="64" height="64">`.
      final List<CustomPaint> rings = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .toList();
      expect(rings, hasLength(3));
      for (final CustomPaint ring in rings) {
        expect(_paintedSize(tester, find.byWidget(ring)), const Size(64, 64));
      }
    });

    testWidgets('the gap between two rings is 26', (WidgetTester tester) async {
      await _pump(tester, _rings());

      // `eva/redesign.html:401` — `.rings{… gap:26px …}`.
      final List<CustomPaint> rings = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .toList();
      final Rect first = tester.getRect(find.byWidget(rings[0]));
      final Rect second = tester.getRect(find.byWidget(rings[1]));
      final Rect third = tester.getRect(find.byWidget(rings[2]));

      expect(second.left - first.right, closeTo(26, 0.01));
      expect(third.left - second.right, closeTo(26, 0.01));
    });

    testWidgets('the arc starts at twelve o\'clock and sweeps clockwise', (
      WidgetTester tester,
    ) async {
      // A quarter of a ring, painted alone and read off the pixels.
      final List<Offset> ink = await _arcPixels(
        tester,
        fraction: 0.25,
        size: 64,
      );

      // **Angles and not four probe points.** The arc's ends carry a 3px round
      // cap, so the ink at 12 and 3 o'clock is the cap's half-disc rather than
      // a full pixel of the arc's colour, and a probe at exactly 3 o'clock
      // lands on a pixel that is a quarter covered. The **angular extent** of
      // the ink is the measurement that does not depend on the cap.
      //
      // 0° is 3 o'clock and the angles grow clockwise, so 12 o'clock is −90°.
      expect(
        _minAngle(ink),
        closeTo(-90, 12),
        reason:
            'the arc starts at 12 o\'clock, and the round cap reaches about 6° '
            'past it',
      );
      expect(
        _maxAngle(ink),
        closeTo(0, 12),
        reason: 'and a quarter of the circle later it is at 3 o\'clock',
      );
      expect(
        ink.any((Offset pixel) => _angle(pixel) > 12 && _angle(pixel) < 78),
        isFalse,
        reason: 'and it has not reached 6 o\'clock',
      );
      expect(
        ink.any((Offset pixel) => _angle(pixel) > 168 && _angle(pixel) < 192),
        isFalse,
        reason: 'nor 9 o\'clock',
      );
    });

    testWidgets('half a ring reaches six o\'clock', (
      WidgetTester tester,
    ) async {
      final List<Offset> ink = await _arcPixels(
        tester,
        fraction: 0.5,
        size: 64,
      );

      expect(_minAngle(ink), closeTo(-90, 12));
      expect(
        _maxAngle(ink),
        closeTo(90, 12),
        reason:
            'half of the circle, measured clockwise from 12 o\'clock, is 6 '
            'o\'clock',
      );
    });

    testWidgets('the stroke is 6 wide on a radius of 26', (
      WidgetTester tester,
    ) async {
      final List<Offset> ink = await _arcPixels(tester, fraction: 1, size: 64);

      // `eva/redesign.html:592` — `<circle cx="32" cy="32" r="26">` and `:404`
      // — `stroke-width:6`. So the painted band runs from r = 23 to r = 29.
      //
      // **The OPAQUE core is 56×56 and not 58×58**, because the band's two
      // boundary pixels are antialiased and are therefore not the arc's exact
      // colour. A pixel row `y` above the centre covers the radii
      // `(32-(y+1), 32-y]`, so the rows that are wholly inside the band are 4
      // through 8 — 56 pixels — and the two rows that straddle the edges (3 and
      // 9) are the antialiased ones.
      final Rect bounds = _bounds(ink);
      expect(bounds.width, closeTo(56, 0.5));
      expect(bounds.height, closeTo(56, 0.5));
      expect(bounds.center.dx, closeTo(32, 0.5));
      expect(bounds.center.dy, closeTo(32, 0.5));

      for (final int row in <int>[4, 6, 8]) {
        expect(
          _isInked(ink, Offset(32, row.toDouble())),
          isTrue,
          reason:
              'row $row covers the radii (${32 - row - 1}, ${32 - row}] and is '
              'inside the band r ∈ [23, 29]',
        );
      }
      for (final int row in <int>[3, 9, 10]) {
        expect(
          _isInked(ink, Offset(32, row.toDouble())),
          isFalse,
          reason:
              'row $row covers the radii (${32 - row - 1}, ${32 - row}] and is '
              'outside the band r ∈ [23, 29] — row 3 straddles the outer edge '
              'and row 9 the inner one, so both are antialiased rather than '
              'opaque',
        );
      }
    });
  });

  group('the medals strip', () {
    testWidgets('each medal is 104 by 104', (WidgetTester tester) async {
      await _pump(tester, _strip());

      // `eva/redesign.html:412` — `.medal{flex:0 0 104px;height:104px}`.
      final List<GlassSurface> medals = tester
          .widgetList<GlassSurface>(find.byType(GlassSurface))
          .toList();
      expect(medals, hasLength(4));
      for (final GlassSurface medal in medals) {
        expect(
          _paintedSize(tester, find.byWidget(medal)),
          const Size(104, 104),
        );
      }
    });

    testWidgets('the gap between two medals is 12', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _strip());

      // `eva/redesign.html:410` — `.medals{… gap:12px …}`.
      final List<GlassSurface> medals = tester
          .widgetList<GlassSurface>(find.byType(GlassSurface))
          .toList();
      final Rect first = tester.getRect(find.byWidget(medals[0]));
      final Rect second = tester.getRect(find.byWidget(medals[1]));
      expect(second.left - first.right, closeTo(12, 0.01));
    });

    testWidgets('the strip is padded 4 over, 18 in and 12 under', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _strip());

      // `eva/redesign.html:410` — `.medals{… padding:4px 18px 12px …}`.
      final ListView strip = tester.widget<ListView>(find.byType(ListView));
      expect(strip.padding, const EdgeInsets.fromLTRB(18, 4, 18, 12));

      // And the **rendered** consequence of that padding, which is the number a
      // reader sees: the first medal starts 18 in and 4 down, and stops 12
      // short of the strip's bottom.
      final Rect list = tester.getRect(find.byType(ListView));
      final Rect first = tester.getRect(
        find.byWidget(
          tester.widgetList<GlassSurface>(find.byType(GlassSurface)).first,
        ),
      );
      expect(first.left - list.left, closeTo(18, 0.01));
      expect(first.top - list.top, closeTo(4, 0.01));
      expect(list.bottom - first.bottom, closeTo(12, 0.01));
    });
  });
}

/// The three rings, at the prototype's fractions.
Widget _rings() => JourneyRingsRow(
  rings: <JourneyRing>[
    JourneyRing(
      label: 'verses',
      value: '83%',
      fraction: 0.83,
      stroke: journeyRingTeal,
    ),
    JourneyRing(
      label: 'quizzes',
      value: '86',
      fraction: 0.86,
      stroke: const EvaColors.dark().bloom,
    ),
    JourneyRing(
      label: 'accuracy',
      value: '92%',
      fraction: 0.92,
      stroke: journeyRingBlue,
    ),
  ],
);

/// The four medals, at the prototype's emblems and blooms.
Widget _strip() => JourneyMedalsStrip(
  tiles: <JourneyMedalTile>[
    for (final Medal medal in Medal.values)
      JourneyMedalTile(
        label: medal.label(_strings),
        emblem: medal.emblem,
        bloom: medal.bloom,
      ),
  ],
);

/// The strings, for a widget built outside a `BuildContext`.
///
/// The medals' names are the table's own rows, and the table is reached
/// through a `BuildContext` — so this is the one place a test needs a
/// `BuildContext` it does not have. `AppLocalizationsEn` is the generated
/// English arm, which is what `arabic_typography_test.dart` does for the
/// Arabic one.
final AppLocalizations _strings = AppLocalizationsEn();

/// Pumps [child] on the ambient surface.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      // **A `Center`, and it is load-bearing.** `MaterialApp`'s `home` gets
      // **tight** constraints, and a tight parent cannot be shrunk: a
      // `SizedBox(height: 120)` inside one is laid out at the parent's height
      // and its child is painted at the top-left corner. The page's own scroll
      // view gives loose constraints, so the widget is right there and wrong
      // only in this harness.
      child: Center(child: child),
    ),
  );
  await tester.pump();
}

/// The box a reader sees, after any ancestor `Transform` has scaled it.
///
/// `communion_page_test.dart`'s `_paintedSize`, and for the reason its doc
/// gives: the layout size and the painted size are different things, and only
/// the painted one is what the reader is looking at.
Size _paintedSize(WidgetTester tester, Finder finder) {
  final RenderBox box = tester.renderObject<RenderBox>(finder);
  final Offset topLeft = box.localToGlobal(Offset.zero);
  final Offset bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
  );
  return Size(bottomRight.dx - topLeft.dx, bottomRight.dy - topLeft.dy);
}

/// The arc's ink, read off the pixels.
///
/// The ring is painted alone, in a box [size] across, with **two opaque
/// colours** so the arc and the track can be told apart: the arc is the
/// stroke's colour and the track is the other's. A translucent track would be
/// indistinguishable from the background, and "there is ink at 12 o'clock"
/// would be satisfied by the track alone.
Future<List<Offset>> _arcPixels(
  WidgetTester tester, {
  required double fraction,
  required int size,
}) async {
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      child: Center(
        child: RepaintBoundary(
          key: _inkKey,
          child: SizedBox.square(
            dimension: size.toDouble(),
            child: CustomPaint(
              painter: JourneyRingPainter(
                fraction: fraction,
                stroke: _arcColour,
                track: _trackColour,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

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

  final List<Offset> ink = <Offset>[];
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int offset = ((y * size) + x) * 4;
      if (_isArcColour(bytes, offset)) {
        ink.add(Offset(x.toDouble(), y.toDouble()));
      }
    }
  }
  return ink;
}

/// The key for the arc's capture.
const Key _inkKey = ValueKey<String>('journey-ring-ink');

/// The arc's ink — an opaque token so the pixels can be told apart.
final Color _arcColour = const EvaColors.dark().ember;

/// The track's ink — a **different** opaque token.
final Color _trackColour = const EvaColors.dark().ink3;

/// Whether the pixel at [offset] carries the arc's colour.
///
/// **The packed ARGB and not the three channels**, because `Color.r` and its
/// siblings are **doubles** in this SDK — they are the 0..1 wide-gamut
/// channels — so comparing them against a byte is a comparison that is always
/// false. `toARGB32()` is the sanctioned spelling (`AGENT_CONTEXT` §4's table
/// puts `color.value` behind it).
bool _isArcColour(Uint8List rgba, int offset) {
  final int argb =
      (rgba[offset + 3] << 24) |
      (rgba[offset] << 16) |
      (rgba[offset + 1] << 8) |
      rgba[offset + 2];
  return argb == _arcColour.toARGB32();
}

/// Whether [point] is one of the inked pixels.
///
/// **An exact match and not a tolerance**, because the questions this file
/// asks are about *which* pixel is inked — a row of the band, a row outside it
/// — and a tolerance of one pixel would answer a neighbouring row's question.
bool _isInked(List<Offset> ink, Offset point) =>
    ink.any((Offset pixel) => pixel == point);

/// The angle of [pixel] about the ring's centre, in degrees.
///
/// **0° is 3 o'clock and the angles grow clockwise**, which is the screen's
/// convention: `atan2` on `(dx, dy)` with the y axis pointing down.
double _angle(Offset pixel) =>
    math.atan2(pixel.dy - 32, pixel.dx - 32) * 180 / math.pi;

/// The smallest angle the ink reaches.
double _minAngle(List<Offset> ink) =>
    ink.map(_angle).reduce((double a, double b) => a < b ? a : b);

/// The largest angle the ink reaches.
double _maxAngle(List<Offset> ink) =>
    ink.map(_angle).reduce((double a, double b) => a > b ? a : b);

/// The box every inked pixel falls inside.
Rect _bounds(List<Offset> ink) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;
  for (final Offset pixel in ink) {
    if (pixel.dx < minX) minX = pixel.dx;
    if (pixel.dy < minY) minY = pixel.dy;
    if (pixel.dx > maxX) maxX = pixel.dx;
    if (pixel.dy > maxY) maxY = pixel.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX + 1, maxY + 1);
}
