import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure layout unit behind [WitnessSky].
///
/// ## WHY THIS IS A SEPARATE FILE FROM THE WIDGET SUITE
///
/// AGENT_CONTEXT §6 exempts widget work from red-first ceremony but is explicit
/// that "domain logic must **not** be buried inside a widget — if a widget needs
/// a conditional or calculation, extract it to a pure function and **TDD that**".
/// Everything in this file is that extracted function, and every assertion is a
/// pure call: no `pumpWidget`, no widget tree, no clock.
SkyEntry _entry(String book, int chapter, int verse, {bool flare = false}) =>
    SkyEntry(
      book: book,
      chapter: chapter,
      verse: verse,
      isFlare: flare,
      litAt: DateTime.utc(2026, 10, 14, 9, 30),
    );

/// Forty-four distinct keys — the prototype's own effective maximum
/// (`eva/redesign.html:1147`), and enough that "every star lands on the same
/// spot" cannot pass.
final List<SkyEntry> _fortyFour = <SkyEntry>[
  for (int i = 0; i < 44; i++) _entry('Psalms', 119 + i, 1 + i),
];

void main() {
  group('the transcribed tables are the prototype\'s', () {
    test('the field bands are POSRANGE', () {
      // eva/redesign.html:1133 — `const POSRANGE={crown:[3,17],high:[3,30],full:[3,60]}`.
      expect(skyFieldBands[SkyStarField.crown], (3.0, 17.0));
      expect(skyFieldBands[SkyStarField.high], (3.0, 30.0));
      expect(skyFieldBands[SkyStarField.full], (3.0, 60.0));
    });

    test('the horizontal span is `8 + rand * 84` percent', () {
      // eva/redesign.html:1151 — `left:${8+Math.random()*84}%`.
      expect(kSkyStarLeftStart, 8.0);
      expect(kSkyStarLeftStart + kSkyStarLeftSpan, 92.0);
    });

    test('the size table is 5 for a flare, 3–5 otherwise, ×1.5 off-dot', () {
      // eva/redesign.html:1148 — `(big?5:3+Math.random()*2)*(starShape==='s-dot'?1:1.5)`.
      expect(kSkyStarFlareSize, 5.0);
      expect(kSkyStarSizeMin, 3.0);
      expect(kSkyStarSizeMin + kSkyStarSizeSpan, 5.0);
      expect(kSkyShapeSizeScale, 1.5);
      expect(SkyStarShape.dot.scale, 1.0);
      for (final SkyStarShape shape in SkyStarShape.values.where(
        (SkyStarShape s) => s != SkyStarShape.dot,
      )) {
        expect(shape.scale, 1.5, reason: '${shape.name} is not a dot');
      }
    });

    test('the twinkle period is 3–7 seconds, per star', () {
      // eva/redesign.html:1151 — `--tw:${3+Math.random()*4}s`.
      expect(kSkyTwinkleMin, const Duration(seconds: 3));
      expect(kSkyTwinkleMin + kSkyTwinkleSpan, const Duration(seconds: 7));
    });

    test('`--so` is 0.9 × `--starB`, and the default brightness is 1', () {
      // eva/redesign.html:116 — `--starB:1`; :119 — `--so:calc(.9*var(--starB,1))`;
      // :1488 — the slider writes `value/100` for a 30…150 range.
      expect(kSkyStarBaseOpacity, 0.9);
      expect(kSkyDefaultBrightness, 1.0);
    });

    test('the twinkle keyframes are .35 → 1 and scale 1 → 1.45', () {
      // eva/redesign.html:125 —
      // `0%,100%{opacity:calc(var(--so)*.35);transform:scale(1)}
      //  50%{opacity:var(--so);transform:scale(1.45)}`.
      expect(kSkyTwinkleOpacityLow, 0.35);
      expect(kSkyTwinkleScaleMax, 1.45);
    });

    test('the three polygons carry the prototype\'s eight and four points', () {
      // eva/redesign.html:121-123 — the `clip-path: polygon(…)` declarations.
      expect(skyStarPolygon[SkyStarShape.star], hasLength(8));
      expect(skyStarPolygon[SkyStarShape.cross], hasLength(8));
      expect(skyStarPolygon[SkyStarShape.diamond], hasLength(4));
      expect(
        skyStarPolygon[SkyStarShape.dot],
        isNull,
        reason: 'dot is a circle',
      );
    });
  });

  group('the seed is stable, which String.hashCode is not', () {
    test('the same key hashes the same on every call', () {
      expect(skyStarHash('John:3:16'), skyStarHash('John:3:16'));
      expect(skyStarHash('John:3:16'), isNot(skyStarHash('John:3:17')));
    });

    test('and it is not the key length', () {
      // The obvious one-line implementation, and the reason it is refused:
      // `John:3:16` and `John:3:99` are the same length and would land the same
      // star in the same place — a whole page of identical stars that still
      // passes any test asserting "positions vary".
      expect(skyStarHash('John:3:16'), isNot(skyStarHash('John:3:99')));
    });

    test('the seed is a 32-bit value', () {
      for (final SkyEntry entry in _fortyFour) {
        final int seed = skyStarHash(entry.key);
        expect(seed, inInclusiveRange(0, 0xFFFFFFFF));
      }
    });

    test('every channel is a unit double, and channels disagree', () {
      final int seed = skyStarHash('John:3:16');
      final List<double> units = <double>[
        for (int channel = 0; channel < 4; channel++)
          skyStarUnit(seed, channel),
      ];
      for (final double unit in units) {
        expect(unit, inInclusiveRange(0.0, 1.0));
        expect(unit, lessThan(1.0));
      }
      expect(units.toSet(), hasLength(4), reason: 'one seed, four channels');
    });
  });

  group('skyStarLayoutFor is deterministic in the key', () {
    test('the same key gives the same star, every time', () {
      final SkyStarLayout first = skyStarLayoutFor(
        key: 'Psalms:119:1',
        shape: SkyStarShape.dot,
        field: SkyStarField.crown,
        isFlare: false,
      );
      final SkyStarLayout second = skyStarLayoutFor(
        key: 'Psalms:119:1',
        shape: SkyStarShape.dot,
        field: SkyStarField.crown,
        isFlare: false,
      );
      expect(second.leftPercent, first.leftPercent);
      expect(second.topPercent, first.topPercent);
      expect(second.size, first.size);
      expect(second.twinklePeriod, first.twinklePeriod);
    });

    test('and distinct keys spread across the sky rather than stacking', () {
      final List<SkyStarLayout> layouts = <SkyStarLayout>[
        for (final SkyEntry entry in _fortyFour)
          skyStarLayoutFor(
            key: entry.key,
            shape: SkyStarShape.dot,
            field: SkyStarField.crown,
            isFlare: false,
          ),
      ];
      // A handful of distinct values is the observable; an exact count would be
      // asserting a property of the hash rather than of the layout.
      expect(
        layouts.map((SkyStarLayout l) => l.leftPercent).toSet().length,
        greaterThan(30),
      );
      expect(
        layouts.map((SkyStarLayout l) => l.topPercent).toSet().length,
        greaterThan(10),
      );
    });

    test(
      'every star lands inside the horizontal span the prototype declares',
      () {
        for (final SkyEntry entry in _fortyFour) {
          final SkyStarLayout layout = skyStarLayoutFor(
            key: entry.key,
            shape: SkyStarShape.dot,
            field: SkyStarField.full,
            isFlare: false,
          );
          expect(layout.leftPercent, greaterThanOrEqualTo(kSkyStarLeftStart));
          expect(
            layout.leftPercent,
            lessThanOrEqualTo(kSkyStarLeftStart + kSkyStarLeftSpan),
          );
        }
      },
    );

    test('and inside the band its field names', () {
      for (final SkyStarField field in SkyStarField.values) {
        final (double lo, double hi) = skyFieldBands[field]!;
        for (final SkyEntry entry in _fortyFour) {
          final SkyStarLayout layout = skyStarLayoutFor(
            key: entry.key,
            shape: SkyStarShape.dot,
            field: field,
            isFlare: false,
          );
          expect(
            layout.topPercent,
            inInclusiveRange(lo, hi),
            reason: '${entry.key} under ${field.name}',
          );
        }
      }
    });

    test(
      'a flare is 5px and an ordinary star is 3–5px, before the shape scale',
      () {
        for (final SkyEntry entry in _fortyFour) {
          expect(
            skyStarLayoutFor(
              key: entry.key,
              shape: SkyStarShape.dot,
              field: SkyStarField.crown,
              isFlare: true,
            ).size,
            kSkyStarFlareSize,
          );
          expect(
            skyStarLayoutFor(
              key: entry.key,
              shape: SkyStarShape.dot,
              field: SkyStarField.crown,
              isFlare: false,
            ).size,
            inInclusiveRange(
              kSkyStarSizeMin,
              kSkyStarSizeMin + kSkyStarSizeSpan,
            ),
          );
        }
      },
    );

    test('a non-dot shape is 1.5× the same star', () {
      for (final SkyEntry entry in _fortyFour.take(8)) {
        final double dot = skyStarLayoutFor(
          key: entry.key,
          shape: SkyStarShape.dot,
          field: SkyStarField.crown,
          isFlare: false,
        ).size;
        final double star = skyStarLayoutFor(
          key: entry.key,
          shape: SkyStarShape.star,
          field: SkyStarField.crown,
          isFlare: false,
        ).size;
        expect(star, closeTo(dot * kSkyShapeSizeScale, 1e-9));
      }
    });

    test('the twinkle period is inside the prototype\'s 3–7 seconds', () {
      for (final SkyEntry entry in _fortyFour) {
        expect(
          skyStarLayoutFor(
            key: entry.key,
            shape: SkyStarShape.dot,
            field: SkyStarField.crown,
            isFlare: false,
          ).twinklePeriod.inMilliseconds,
          inInclusiveRange(3000, 7000),
        );
      }
    });
  });

  group('a field switch re-maps the band and NOTHING ELSE', () {
    // eva/redesign.html:1466-1467 — `segp('starPosSeg', …)` writes `top` and
    // nothing else. The handler is the whole claim: a star that moved sideways
    // or changed size when the reader chose "full" would be a second, invisible
    // source of truth for the sky's geometry.
    test('left, size and period are identical across all three fields', () {
      for (final SkyEntry entry in _fortyFour) {
        final List<SkyStarLayout> layouts = <SkyStarLayout>[
          for (final SkyStarField field in SkyStarField.values)
            skyStarLayoutFor(
              key: entry.key,
              shape: SkyStarShape.dot,
              field: field,
              isFlare: false,
            ),
        ];
        for (final SkyStarLayout layout in layouts.skip(1)) {
          expect(layout.leftPercent, layouts.first.leftPercent);
          expect(layout.size, layouts.first.size);
          expect(layout.twinklePeriod, layouts.first.twinklePeriod);
        }
      }
    });

    test('only `top` moves, and it moves inside the new band', () {
      for (final SkyEntry entry in _fortyFour) {
        final SkyStarLayout crown = skyStarLayoutFor(
          key: entry.key,
          shape: SkyStarShape.dot,
          field: SkyStarField.crown,
          isFlare: false,
        );
        final SkyStarLayout full = skyStarLayoutFor(
          key: entry.key,
          shape: SkyStarShape.dot,
          field: SkyStarField.full,
          isFlare: false,
        );
        // Same underlying draw, so a star that happened to draw inside both
        // bands keeps its exact offset rather than being nudged.
        final double unit =
            (crown.topPercent - skyFieldBands[SkyStarField.crown]!.$1) /
            (skyFieldBands[SkyStarField.crown]!.$2 -
                skyFieldBands[SkyStarField.crown]!.$1);
        expect(
          full.topPercent,
          closeTo(
            skyFieldBands[SkyStarField.full]!.$1 +
                unit *
                    (skyFieldBands[SkyStarField.full]!.$2 -
                        skyFieldBands[SkyStarField.full]!.$1),
            1e-9,
          ),
          reason: '${entry.key}: the same draw, re-mapped into the full band',
        );
      }
    });
  });

  group('the twinkle curve', () {
    test('the triangle is 0 at the ends and 1 at the half cycle', () {
      expect(skyTwinkleTriangle(0.0), 0.0);
      expect(skyTwinkleTriangle(0.5), 1.0);
      expect(skyTwinkleTriangle(1.0), 0.0);
      expect(
        skyTwinkleTriangle(1.25),
        closeTo(skyTwinkleTriangle(0.25), 1e-12),
      );
    });

    test('opacity runs `so * .35` → `so` and scale `1` → `1.45`', () {
      expect(
        skyStarOpacity(brightness: 1.0, triangle: 0.0),
        closeTo(0.315, 1e-12),
      );
      expect(
        skyStarOpacity(brightness: 1.0, triangle: 1.0),
        closeTo(0.9, 1e-12),
      );
      expect(skyStarScale(0.0), 1.0);
      expect(skyStarScale(1.0), 1.45);
    });

    test('brightness scales the whole curve and is `--starB`', () {
      expect(
        skyStarOpacity(brightness: 1.5, triangle: 1.0),
        closeTo(1.35, 1e-12),
      );
      expect(
        skyStarOpacity(brightness: 0.3, triangle: 1.0),
        closeTo(0.27, 1e-12),
      );
    });

    test('one star\'s own period fits into one float cycle', () {
      // §13.2's collapse: the shared float clock is 20s and every star twinkles
      // at its OWN 3–7s period, so the phase is the clock scaled by
      // `kFloatPeriod / period` — the same derivation `GoldFlecks` publishes as
      // `flecksPerFloatCycle`, with a per-star divisor instead of a shared one.
      final Duration star = const Duration(seconds: 5);
      final double cycles = kFloatPeriod.inMicroseconds / star.inMicroseconds;
      expect(cycles, closeTo(4.0, 1e-9));
      // A tenth of the float clock is 2 real seconds, which is 0.4 of this
      // star's own 5s cycle.
      expect(skyTwinklePhase(clock: 0.1, period: star), closeTo(0.4, 1e-9));
      // Half a float cycle is 10 real seconds — two whole twinkles.
      expect(skyTwinklePhase(clock: 0.5, period: star), closeTo(0.0, 1e-9));
      // One whole float cycle is four of them: back to the start.
      expect(skyTwinklePhase(clock: 1.0, period: star), closeTo(0.0, 1e-9));
    });

    test('a zero period does not divide by zero', () {
      expect(skyTwinklePhase(clock: 0.5, period: Duration.zero), 0.0);
    });
  });

  group('the four shapes', () {
    const Rect box = Rect.fromLTWH(0, 0, 10, 10);

    test('skyClipsPaint names the prototype\'s TWO mechanisms', () {
      // `eva/redesign.html:120` is `border-radius: 50%` and `:121-123` are
      // `clip-path: polygon(…)`. The two behave differently (a rounded border
      // box keeps its outer shadow; a clip-path inside the border box discards
      // it), so this is not `!= dot` for tidiness — it is the branch the star
      // layer makes, and `WitnessSky`'s suite measures both sides of it.
      expect(skyClipsPaint(SkyStarShape.star), isTrue);
      expect(skyClipsPaint(SkyStarShape.cross), isTrue);
      expect(skyClipsPaint(SkyStarShape.diamond), isTrue);
      expect(
        skyClipsPaint(SkyStarShape.dot),
        isFalse,
        reason: 'the dot is `border-radius: 50%` — a rounded box, not a clip',
      );
      // And it is exactly the complement of "has a polygon", so the two tables
      // cannot disagree.
      for (final SkyStarShape shape in SkyStarShape.values) {
        expect(
          skyClipsPaint(shape),
          skyStarPolygon[shape] != null,
          reason: '${shape.name}: the clip flag and the polygon table',
        );
      }
    });

    test('SkyStarClipper.shouldReclip only on a shape change', () {
      // Trivial by inspection, which is exactly why it needed a witness: the
      // first version of the shape test read the constructor argument and never
      // reached the clipper at all, so `shouldReclip` had no test and the
      // `ClipPath` had no reason to exist in a suite that could see it.
      const SkyStarClipper star = SkyStarClipper(SkyStarShape.star);
      expect(
        star.shouldReclip(const SkyStarClipper(SkyStarShape.star)),
        isFalse,
      );
      expect(
        star.shouldReclip(const SkyStarClipper(SkyStarShape.cross)),
        isTrue,
        reason: 'a different polygon must re-clip',
      );
      // And the clip it produces is that shape's path, at the size it is given.
      // Compared by `getBounds` and by containment rather than by `==`, because
      // `Path` does not implement value equality — two independently built
      // identical paths are `!=`, so `expect(a, b)` here would fail for a
      // correct clipper and pass for nothing.
      const Rect box = Rect.fromLTWH(0, 0, 10, 10);
      final Path clipped = star.getClip(const Size(10, 10));
      final Path direct = skyStarPathFor(SkyStarShape.star, box);
      expect(clipped.getBounds(), direct.getBounds());
      expect(
        clipped.contains(const Offset(0.5, 0.5)),
        direct.contains(const Offset(0.5, 0.5)),
      );
      expect(clipped.contains(box.topLeft), direct.contains(box.topLeft));
    });

    test('the dot is a circle, not a polygon', () {
      // eva/redesign.html:120 — `.star.s-dot{border-radius:50%}`. A polygon here
      // would be an octagon at any size that is not the box it was measured on.
      final Path dot = skyStarPathFor(SkyStarShape.dot, box);
      expect(dot.contains(box.center), isTrue);
      expect(dot.contains(const Offset(0.5, 0.5)), isFalse);
      expect(dot.contains(box.topLeft), isFalse);
    });

    test('each polygon fills its box and reaches all four of its extremes', () {
      // The prototype's three `clip-path` polygons are all inscribed in the same
      // square and all touch its four **edge midpoints** — not its corners,
      // which every one of them cuts. Asserting the corners would fail on the
      // prototype's own geometry; asserting the midpoints is what distinguishes
      // an eight-point star from a rectangle.
      for (final SkyStarShape shape in const <SkyStarShape>[
        SkyStarShape.star,
        SkyStarShape.cross,
        SkyStarShape.diamond,
      ]) {
        final Path path = skyStarPathFor(shape, box);
        expect(
          path.getBounds(),
          box,
          reason: '${shape.name} fills the star box',
        );
        for (final Offset edge in <Offset>[
          const Offset(5, 0),
          const Offset(10, 5),
          const Offset(5, 10),
          const Offset(0, 5),
        ]) {
          expect(
            path.contains(edge),
            isTrue,
            reason:
                '${shape.name} reaches its edge midpoint ${edge.dx},${edge.dy}',
          );
        }
        expect(
          path.contains(box.topLeft),
          isFalse,
          reason:
              '${shape.name} cuts the corner — a shape that reached it would be '
              'a rectangle, which is what a transcription that lost the polygon '
              'would produce',
        );
      }
    });

    test('a polygon scales with the box it is given', () {
      const Rect small = Rect.fromLTWH(0, 0, 4, 4);
      final Path path = skyStarPathFor(SkyStarShape.star, small);
      expect(path.getBounds(), small);
      expect(
        path.contains(const Offset(2, 2)),
        isTrue,
        reason: 'the star\'s waist is its middle',
      );
    });

    test('the eight points of the star are the prototype\'s, in order', () {
      // eva/redesign.html:121.
      expect(skyStarPolygon[SkyStarShape.star], <Offset>[
        const Offset(0.50, 0.00),
        const Offset(0.62, 0.38),
        const Offset(1.00, 0.50),
        const Offset(0.62, 0.62),
        const Offset(0.50, 1.00),
        const Offset(0.38, 0.62),
        const Offset(0.00, 0.50),
        const Offset(0.38, 0.38),
      ]);
    });

    test('the cross and the gem are the prototype\'s too', () {
      // eva/redesign.html:122-123.
      expect(skyStarPolygon[SkyStarShape.cross], <Offset>[
        const Offset(0.50, 0.00),
        const Offset(0.56, 0.44),
        const Offset(1.00, 0.50),
        const Offset(0.56, 0.56),
        const Offset(0.50, 1.00),
        const Offset(0.44, 0.56),
        const Offset(0.00, 0.50),
        const Offset(0.44, 0.44),
      ]);
      expect(skyStarPolygon[SkyStarShape.diamond], <Offset>[
        const Offset(0.50, 0.00),
        const Offset(1.00, 0.50),
        const Offset(0.50, 1.00),
        const Offset(0.00, 0.50),
      ]);
    });
  });

  group('the constellation reads the stars back in lit-event order', () {
    test('fewer than two stars draws no constellation', () {
      // eva/redesign.html:1170 — `if(stars.length<2) return;`.
      expect(
        skyConstellationPoints(
          entries: <SkyEntry>[_entry('John', 3, 16)],
          size: const Size(390, 844),
          shape: SkyStarShape.dot,
          field: SkyStarField.crown,
        ),
        isEmpty,
      );
      expect(
        skyConstellationPoints(
          entries: const <SkyEntry>[],
          size: const Size(390, 844),
          shape: SkyStarShape.dot,
          field: SkyStarField.crown,
        ),
        isEmpty,
      );
    });

    test('the points are the star centres, in the order they were given', () {
      final List<SkyEntry> entries = <SkyEntry>[
        _entry('John', 3, 16),
        _entry('John', 3, 17),
        _entry('John', 3, 18),
      ];
      const Size size = Size(390, 844);
      final List<Offset> points = skyConstellationPoints(
        entries: entries,
        size: size,
        shape: SkyStarShape.dot,
        field: SkyStarField.crown,
      );
      expect(points, hasLength(3));

      for (int i = 0; i < entries.length; i++) {
        final SkyStarLayout layout = skyStarLayoutFor(
          key: entries[i].key,
          shape: SkyStarShape.dot,
          field: SkyStarField.crown,
          isFlare: false,
        );
        // eva/redesign.html:1173 — `offsetLeft + offsetWidth/2`,
        // `offsetTop + offsetHeight/2`.
        expect(
          points[i],
          Offset(
            layout.leftPercent / 100 * size.width + layout.size / 2,
            layout.topPercent / 100 * size.height + layout.size / 2,
          ),
        );
      }
    });

    test('a reversed list reverses the polyline — the order is the claim', () {
      final List<SkyEntry> entries = <SkyEntry>[
        _entry('John', 3, 16),
        _entry('John', 3, 17),
      ];
      const Size size = Size(390, 844);
      final List<Offset> forward = skyConstellationPoints(
        entries: entries,
        size: size,
        shape: SkyStarShape.dot,
        field: SkyStarField.crown,
      );
      final List<Offset> reversed = skyConstellationPoints(
        entries: entries.reversed.toList(),
        size: size,
        shape: SkyStarShape.dot,
        field: SkyStarField.crown,
      );
      expect(reversed, <Offset>[forward[1], forward[0]]);
    });
  });

  group('the ink is a token, because no_colour_literals_test says so', () {
    test(
      'the star fill differs by brightness and resolves through EvaColors',
      () {
        expect(
          skyStarFill(const EvaColors.dark(), Brightness.dark),
          const EvaColors.dark().ink,
        );
        expect(
          skyStarFill(const EvaColors.light(), Brightness.light),
          const EvaColors.light().ink2,
        );
        expect(
          skyStarFill(const EvaColors.dark(), Brightness.dark),
          isNot(skyStarFill(const EvaColors.light(), Brightness.light)),
        );
      },
    );

    test('and so does the glow', () {
      expect(
        skyStarGlow(const EvaColors.dark(), Brightness.dark),
        const EvaColors.dark().ember,
      );
      expect(
        skyStarGlow(const EvaColors.light(), Brightness.light),
        const EvaColors.light().ink2.withValues(alpha: 0.4),
      );
    });

    test('the glow radii are the prototype\'s, small then large', () {
      // eva/redesign.html:1137-1142 — light `6px`/`12px` and `10px`/`20px`;
      // dark `8px`/`16px` and `14px`/`30px`.
      expect(skyStarGlowRadii(isFlare: false, brightness: Brightness.dark), (
        8.0,
        16.0,
      ));
      expect(skyStarGlowRadii(isFlare: true, brightness: Brightness.dark), (
        14.0,
        30.0,
      ));
      expect(skyStarGlowRadii(isFlare: false, brightness: Brightness.light), (
        6.0,
        12.0,
      ));
      expect(skyStarGlowRadii(isFlare: true, brightness: Brightness.light), (
        10.0,
        20.0,
      ));
    });

    test('the polyline stroke is one and thin, per the prototype', () {
      // eva/redesign.html:1178-1179 — `stroke-width 1`, `opacity .45`.
      expect(kSkyConstellationStrokeWidth, 1.0);
      expect(kSkyConstellationOpacity, 0.45);
      expect(
        skyConstellationStroke(const EvaColors.dark(), Brightness.dark),
        const EvaColors.dark().ember.withValues(alpha: 0.8),
      );
      expect(
        skyConstellationStroke(const EvaColors.light(), Brightness.light),
        const EvaColors.light().ink2.withValues(alpha: 0.6),
      );
    });
  });
}
