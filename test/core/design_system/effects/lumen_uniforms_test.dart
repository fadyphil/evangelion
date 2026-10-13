import 'package:evangelion/core/design_system/effects/lumen_uniforms.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sixteen uniforms of `shaders/lumen.frag`, **in the order the shader
/// declares them** (`shaders/lumen.frag:34-49`).
///
/// A transcription, not a derivation. The `.frag` keeps the prototype's
/// declaration order on purpose — that is what makes it a reviewable port — and
/// this list is the same order, written down so the suite can assert that
/// [UniformSlot] follows it: the enum's **slots** are this order, because the
/// runtime uniform buffer is.
const List<String> kShaderDeclarationOrder = <String>[
  'u_res',
  'u_time',
  'u_hue',
  'u_hue2',
  'u_hue3',
  'u_int',
  'u_str',
  'u_spike',
  'u_spread',
  'u_shape',
  'u_melt',
  'u_dots',
  'u_white',
  'u_light',
  'u_ptr',
  'u_ptrI',
];

/// The distinct uniform names in **slot** order, deduplicated.
///
/// Sixteen uniforms occupy twenty-four slots, so this is not
/// `UniformSlot.values.map(…)` — that would yield twenty-four entries with each
/// `vec2`/`vec3` repeated, and comparing that against a sixteen-name list is
/// satisfied by the lengths disagreeing, which proves nothing.
List<String> uniformNamesInSlotOrder() {
  final Set<String> seen = <String>{};
  final List<String> ordered = <String>[];
  for (final UniformSlot slot in UniformSlot.values) {
    if (seen.add(slot.uniform)) ordered.add(slot.uniform);
  }
  return ordered;
}

/// [HslRgb]'s own `==` is exact, and it must be — a value object's equality is
/// not a tolerance.
///
/// Comparing a *conversion* against another *conversion* is a different
/// question: the prototype's branchless `k`/`f` and the sextant reference below
/// do the same arithmetic in a different order, so they agree to about fifteen
/// places and not to sixteen. `expect(a, b)` would report two visibly identical
/// triples as unequal, and the reader would go looking for a bug in the shader.
Matcher closeHslRgb(HslRgb expected) => predicate<HslRgb>(
  (HslRgb actual) =>
      (actual.r - expected.r).abs() < 1e-12 &&
      (actual.g - expected.g).abs() < 1e-12 &&
      (actual.b - expected.b).abs() < 1e-12,
  '≈ $expected (to 1e-12 per channel)',
);

void main() {
  group('UniformSlot — the declaration layout, which is the setFloat order', () {
    const LumenUniforms u = LumenUniforms.identity();

    test('every slot index, as the shader declares it', () {
      expect(u.slot(UniformSlot.uResX), 0);
      expect(u.slot(UniformSlot.uResY), 1);
      expect(u.slot(UniformSlot.uTime), 2);
      expect(u.slot(UniformSlot.uHueX), 3);
      expect(u.slot(UniformSlot.uHueY), 4);
      expect(u.slot(UniformSlot.uHueZ), 5);
      expect(u.slot(UniformSlot.uHue2X), 6);
      expect(u.slot(UniformSlot.uHue2Y), 7);
      expect(u.slot(UniformSlot.uHue2Z), 8);
      expect(u.slot(UniformSlot.uHue3X), 9);
      expect(u.slot(UniformSlot.uHue3Y), 10);
      expect(u.slot(UniformSlot.uHue3Z), 11);
      expect(u.slot(UniformSlot.uInt), 12);
      expect(u.slot(UniformSlot.uStr), 13);
      expect(u.slot(UniformSlot.uSpike), 14);
      expect(u.slot(UniformSlot.uSpread), 15);
      expect(u.slot(UniformSlot.uShape), 16);
      expect(u.slot(UniformSlot.uMelt), 17);
      expect(u.slot(UniformSlot.uDots), 18);
      expect(u.slot(UniformSlot.uWhite), 19);
      expect(u.slot(UniformSlot.uLight), 20);
      expect(u.slot(UniformSlot.uPtrX), 21);
      expect(u.slot(UniformSlot.uPtrY), 22);
      expect(u.slot(UniformSlot.uPtrI), 23);
    });

    test('the member order is the declaration order', () {
      // The reordering gate, and the only one of its kind that CAN fail. Dart
      // guarantees `slot.index == values.indexOf(slot)` for every enum, so the
      // previous version of this test — that loop — was a tautology wearing a
      // gate's name: green under every reordering. Member NAMES in order are
      // guaranteed by nothing, so a swapped pair fails here. The constant
      // assertions above pin the same fact numerically and the declaration
      // ramp below pins it per uniform; this pins it structurally.
      expect(
        UniformSlot.values.map((UniformSlot s) => s.name).toList(),
        <String>[
          'uResX',
          'uResY',
          'uTime',
          'uHueX',
          'uHueY',
          'uHueZ',
          'uHue2X',
          'uHue2Y',
          'uHue2Z',
          'uHue3X',
          'uHue3Y',
          'uHue3Z',
          'uInt',
          'uStr',
          'uSpike',
          'uSpread',
          'uShape',
          'uMelt',
          'uDots',
          'uWhite',
          'uLight',
          'uPtrX',
          'uPtrY',
          'uPtrI',
        ],
      );
    });

    test('twenty-four slots, sixteen uniforms, every slot claimed once', () {
      expect(UniformSlot.values, hasLength(24));
      expect(
        UniformSlot.values.map((UniformSlot s) => s.index).toSet(),
        hasLength(24),
        reason: 'a duplicated index means two names claim one float',
      );
      // No list-equality against `[0..23]` here on purpose: enum indices ARE
      // `0..N-1` by construction, so that assertion is the same tautology the
      // member-order test above replaced. Reordering coverage lives there, in
      // the per-slot constants, and in the declaration ramp below.
    });

    test('each vec3 takes three consecutive slots — GLSL-style padding would '
        'make it four', () {
      // The failure this rules out is quiet rather than loud. std140 aligns a
      // `vec3` to four floats, so a `Float32List` laid out to that rule would
      // put `u_hue2` at 16-19 instead of 15-17 — every colour would be one slot
      // low and `u_white` would land in `u_hue3`'s third channel. Nothing
      // throws; the aurora simply renders in the wrong colours.
      expect(u.slot(UniformSlot.uHueZ) - u.slot(UniformSlot.uHueX), 2);
      expect(u.slot(UniformSlot.uHue2Z) - u.slot(UniformSlot.uHue2X), 2);
      expect(u.slot(UniformSlot.uHue3Z) - u.slot(UniformSlot.uHue3X), 2);
    });

    test('each vec2 takes two consecutive slots', () {
      expect(u.slot(UniformSlot.uResY) - u.slot(UniformSlot.uResX), 1);
      expect(u.slot(UniformSlot.uPtrY) - u.slot(UniformSlot.uPtrX), 1);
    });

    test('the enum names exactly the shader\'s sixteen uniforms, no more and '
        'no fewer', () {
      // The half that must hold. `shaders/lumen.frag` declares sixteen
      // uniforms and every one of them reaches the reflection, so a slot table
      // that dropped one — or invented one the shader does not declare — is
      // wrong in a way no ordering assertion would notice.
      expect(
        UniformSlot.values.map((UniformSlot s) => s.uniform).toSet(),
        kShaderDeclarationOrder.toSet(),
      );
    });

    test('the shader\'s declaration order, turned into slots, is the identity '
        'ramp, not a permutation', () {
      // Read down this list: `0, 2, 3, 6, 9, 12, 13, 14, 15, 16, 17, 18, 19,
      // 20, 21, 23`. That is the slot of the FIRST float of each uniform, in
      // the order `shaders/lumen.frag:34-49` writes them — strictly ascending,
      // because member position IS the `setFloat` index. An earlier revision
      // of this test asserted the opposite (a non-identity permutation pinned
      // against `--reflection-json`'s SPIR-V ID order); the render test proved
      // that order paints garbage, so the assertion was inverted with the enum.
      const List<int> firstSlotByDeclarationOrder = <int>[
        0, // u_res
        2, // u_time
        3, // u_hue
        6, // u_hue2
        9, // u_hue3
        12, // u_int
        13, // u_str
        14, // u_spike
        15, // u_spread
        16, // u_shape
        17, // u_melt
        18, // u_dots
        19, // u_white
        20, // u_light
        21, // u_ptr
        23, // u_ptrI
      ];
      expect(
        kShaderDeclarationOrder
            .map(
              (String name) => UniformSlot.values
                  .firstWhere((UniformSlot s) => s.uniform == name)
                  .index,
            )
            .toList(),
        firstSlotByDeclarationOrder,
      );
    });

    test('and the SLOT order is the SAME order', () {
      // The half that must hold, and the reason this file exists. The runtime
      // uniform buffer follows source declaration order — the engine's own
      // comment says so (`runtime_effect_contents.cc:290-298`), the render
      // test proves it (1 vs 247 levels), and the `shaderIndex` test in
      // `lumen_canvas_test.dart` reads the engine's own bookkeeping. The
      // concrete witness is `u_shape`: tenth of sixteen in the shader, **slot
      // 16**. An earlier revision asserted the opposite against
      // `--reflection-json`'s SPIR-V ID order (`uniform_sorter.cc` was a
      // misread); that order paints the 247-error frame, and the negative
      // control proving it lives in `lumen_canvas_test.dart` as raw indices.
      expect(
        uniformNamesInSlotOrder(),
        kShaderDeclarationOrder,
        reason:
            'if this ever differs, either the engine stopped laying out in '
            'declaration order or the enum stopped mirroring the shader',
      );
      expect(
        u.slot(UniformSlot.uShape),
        16,
        reason: 'declared tenth of sixteen',
      );
      expect(
        u.slot(UniformSlot.uSpike),
        14,
        reason: 'declared eighth of sixteen, and it is a neighbour of u_int',
      );
      expect(u.slot(UniformSlot.uHueX), 3, reason: 'declared THIRD of sixteen');
    });

    test('`slot()` and `.index` cannot disagree, for any member', () {
      for (final UniformSlot slot in UniformSlot.values) {
        expect(u.slot(slot), slot.index, reason: slot.name);
      }
    });

    test('`slot()` is the same for every instance', () {
      // `slot()` is the instance-method twin of `.index`: production call
      // sites write `UniformSlot.uHueX.index` directly (Task 1.3b), and this
      // twin exists so "the slot does not depend on the table's contents" is
      // a claim. It is asserted here: a lookup that read a field would pass
      // every constant above on `identity()` and still be wrong on the table
      // actually painted.
      final LumenUniforms painted = const LumenUniforms.identity().withHue(
        h: 258,
        s: 90,
        l: 66,
      );
      for (final UniformSlot slot in UniformSlot.values) {
        expect(painted.slot(slot), u.slot(slot), reason: slot.name);
      }
    });
  });

  group('hslToRgb — redesign.html:879-880, ported verbatim', () {
    test('matches the prototype at the prototype\'s own starting hue', () {
      // `redesign.html:881` opens at `{h:258,s:90,l:66}`, and these three
      // numbers were measured by running the prototype's own `hsl2rgb` under
      // node — not by reading the formula and not by trusting any table:
      //   $ node -e '…redesign.html:879-880 verbatim…'
      //   258,90,66 -> [ 0.5376, 0.35400000000000004, 0.966 ]
      final HslRgb rgb = hslToRgb(h: 258, s: 90, l: 66);
      expect(rgb.r, closeTo(0.5376, 1e-12));
      expect(rgb.g, closeTo(0.3540, 1e-12));
      expect(rgb.b, closeTo(0.9660, 1e-12));
    });

    test('agrees with the textbook conversion, which is what the port is for', () {
      // The prototype's one-liner is the standard algorithm written without a
      // branch table, and this is the check that it is: an independent
      // implementation of HSL → RGB must produce the same triple. Cross-checked
      // at the three hues Lumen actually derives, which between them cover both
      // sextants of the wheel the prototype's +38/-42 offsets reach.
      for (final (double, double, double) h in <(double, double, double)>[
        (258, 90, 66),
        (296, 90, 72),
        (216, 90, 66),
      ]) {
        expect(
          hslToRgb(h: h.$1, s: h.$2, l: h.$3),
          closeHslRgb(referenceHslToRgb(h: h.$1, s: h.$2 / 100, l: h.$3 / 100)),
          reason: 'hsl(${h.$1}, ${h.$2}, ${h.$3})',
        );
      }
    });

    test('hue is taken modulo the wheel, not clamped', () {
      expect(
        hslToRgb(h: 0, s: 90, l: 66),
        closeHslRgb(hslToRgb(h: 360, s: 90, l: 66)),
      );
      expect(
        hslToRgb(h: 258, s: 90, l: 66),
        closeHslRgb(hslToRgb(h: 258 + 720, s: 90, l: 66)),
      );
      // Negative hue is total here and would NOT be under the prototype's JS:
      // JavaScript's `%` keeps the sign of the dividend, Dart's does not. No
      // prototype call site needs it — every hue it produces is already in
      // `[0, 360)` — so this is a property of the port, not a behaviour change,
      // and it is asserted so nobody "fixes" it back to a JS-shaped remainder.
      expect(
        hslToRgb(h: -102, s: 90, l: 66),
        closeHslRgb(hslToRgb(h: 258, s: 90, l: 66)),
      );
    });

    test('saturation 0 is grey whatever the hue and lightness', () {
      for (final double h in <double>[0, 42, 137, 258, 359]) {
        final HslRgb grey = hslToRgb(h: h, s: 0, l: 66);
        expect(grey.r, closeTo(0.66, 1e-12), reason: 'hue $h');
        expect(grey.g, closeTo(0.66, 1e-12), reason: 'hue $h');
        expect(grey.b, closeTo(0.66, 1e-12), reason: 'hue $h');
      }
    });

    test('every channel stays inside 0..1 across the whole wheel', () {
      // The shader multiplies these straight into `gl_FragColor` with no clamp,
      // so a channel outside the unit interval is a visible wrap rather than a
      // saturate. Sampled on a grid because the failure is a hue-specific one.
      for (int step = 0; step < 360; step += 3) {
        for (final double l in <double>[0, 8, 26, 50, 74, 92, 100]) {
          for (final double s in <double>[0, 45, 90, 100]) {
            final HslRgb rgb = hslToRgb(h: step.toDouble(), s: s, l: l);
            for (final double c in <double>[rgb.r, rgb.g, rgb.b]) {
              expect(
                c,
                inInclusiveRange(0.0, 1.0),
                reason: 'hsl($step, $s, $l) produced $c',
              );
            }
          }
        }
      }
    });

    test('equality is by value, and black equals black', () {
      expect(
        const HslRgb(r: 0.5376, g: 0.354, b: 0.966),
        const HslRgb(r: 0.5376, g: 0.354, b: 0.966),
      );
      expect(
        const HslRgb(r: 0, g: 0, b: 0).hashCode,
        const HslRgb(r: 0, g: 0, b: 0).hashCode,
      );
      expect(
        const HslRgb(r: 1, g: 0, b: 0),
        isNot(const HslRgb(r: 0, g: 1, b: 0)),
      );
    });
  });

  group('the derived hues — redesign.html:902-903', () {
    test('hue2 is +38 degrees and lifted by 6, capped at 88', () {
      // `hsl2rgb((h+38)%360, s, Math.min(l+6, 88))`. The cap is the load-bearing
      // half: at the prototype's own l of 66 the cap never fires, so a port
      // that dropped it would be indistinguishable until someone raised the
      // lightness slider — and then hue2 would silently go to white.
      final LumenUniforms u = const LumenUniforms.identity().withHue(
        h: 258,
        s: 90,
        l: 66,
      );
      expect(
        u.hue2,
        hslToRgb(h: 296, s: 90, l: 72),
        reason: 'the measured value of redesign.html:902 at h=258',
      );
      final LumenUniforms pale = const LumenUniforms.identity().withHue(
        h: 258,
        s: 90,
        l: 90,
      );
      expect(
        pale.hue2,
        hslToRgb(h: 296, s: 90, l: 88),
        reason:
            'min(90 + 6, 88) is 88 — the cap is what stops hue2 going white',
      );
      expect(
        pale.hue2.b,
        lessThan(1.0),
        reason: 'and 88% lightness is not white',
      );
    });

    test('hue3 is -42 degrees at the base lightness', () {
      final LumenUniforms u = const LumenUniforms.identity().withHue(
        h: 258,
        s: 90,
        l: 66,
      );
      expect(
        u.hue3,
        hslToRgb(h: 216, s: 90, l: 66),
        reason: 'the measured value of redesign.html:903 at h=258',
      );
      expect(u.hue3, isNot(hslToRgb(h: 216, s: 90, l: 72)));
      expect(
        u.hue3,
        isNot(u.hue2),
        reason: 'hue2 and hue3 differ by hue AND lightness, not by one of them',
      );
    });

    test('both offsets wrap the wheel rather than clamping', () {
      // Without the modulo, hue2 at h=350 would be hsl(388°) — an out-of-range
      // hue, which this port would still convert (Dart's `%` does not go
      // negative) but to the wrong colour. The failing direction matters: the
      // assertion below is satisfied only by the wrap.
      final LumenUniforms high = const LumenUniforms.identity().withHue(
        h: 350,
        s: 90,
        l: 66,
      );
      expect(high.hue2, hslToRgb(h: 28, s: 90, l: 72));

      final LumenUniforms low = const LumenUniforms.identity().withHue(
        h: 10,
        s: 90,
        l: 66,
      );
      expect(low.hue3, hslToRgb(h: 328, s: 90, l: 66));
    });

    test('hue1 is the requested hue, untouched by the two derivations', () {
      final LumenUniforms u = const LumenUniforms.identity().withHue(
        h: 258,
        s: 90,
        l: 66,
      );
      expect(u.hue, hslToRgb(h: 258, s: 90, l: 66));
    });

    test('withHue keeps every other field it did not ask to change', () {
      // The three hues are a derived triple, so the natural bug is a rebuild
      // that drops something. `copyWith` cannot express this — it deliberately
      // has no hue parameter — so this is the only witness that the rebuild
      // threads the other fifteen fields through.
      final LumenUniforms before = const LumenUniforms.identity().copyWith(
        resX: 400,
        resY: 800,
        time: 12.5,
        shape: 2,
        spread: 0.42,
        rays: 1,
        pointerX: -0.25,
        pointerY: 0.75,
        pointerIntensity: 0.33,
        intensity: 0.61,
        spike: 0.4,
        melt: 1,
        white: 0.22,
        light: 1,
        dots: 1,
      );
      final LumenUniforms after = before.withHue(h: 12, s: 40, l: 30);

      expect(after.resX, 400);
      expect(after.resY, 800);
      expect(after.time, 12.5);
      expect(after.shape, 2);
      expect(after.spread, 0.42);
      expect(after.rays, 1);
      expect(after.pointerX, -0.25);
      expect(after.pointerY, 0.75);
      expect(after.pointerIntensity, 0.33);
      expect(after.intensity, 0.61);
      expect(after.spike, 0.4);
      expect(after.melt, 1);
      expect(after.white, 0.22);
      expect(after.light, 1);
      expect(after.dots, 1);
      expect(after.hue, hslToRgb(h: 12, s: 40, l: 30));
    });
  });

  group('the slider conversions — redesign.html:1469-1471', () {
    test('reach 42 becomes spread 0.42', () {
      expect(spreadFromReach(42), closeTo(0.42, 1e-12));
    });

    test('the reach slider runs 18-110', () {
      // `redesign.html:658` — `min="18" max="110" value="42"`. Transcribed so a
      // caller clamping to the wrong range has a number to check against; the
      // conversion itself is the plain `/100` at `redesign.html:1469`.
      expect(spreadFromReach(18), closeTo(0.18, 1e-12));
      expect(spreadFromReach(110), closeTo(1.10, 1e-12));
      expect(spreadFromReach(42), closeTo(0.42, 1e-12));
    });

    test('glow 100 becomes brightness 1.0', () {
      expect(brightnessFromGlow(100), closeTo(1.0, 1e-12));
      expect(brightnessFromGlow(40), closeTo(0.40, 1e-12));
      expect(brightnessFromGlow(130), closeTo(1.30, 1e-12));
    });

    test('touch 55 becomes ptrI 0.33 — the 0.6 is the whole difference', () {
      // The prototype's default is a slider at 55 (`:660`) sent as
      // `(55/100)*0.6`, which is `0.33` in the prototype's own words at
      // `redesign.html:1504`. `0.6` is not a unit conversion; it is the peak
      // gain the touch glow may reach, so a port that shipped `0.55` would be
      // visibly dimmer on every tap.
      expect(ptrIntensityFromTouch(55), closeTo(0.33, 1e-12));
      expect(ptrIntensityFromTouch(100), closeTo(0.60, 1e-12));
      expect(ptrIntensityFromTouch(0), 0.0);
    });

    test('reach and glow share one conversion and touch does not', () {
      // Two of the three are the identical `/100` and the third is not, which
      // is exactly the fact a shared helper would erase.
      expect(spreadFromReach(42), brightnessFromGlow(42));
      expect(ptrIntensityFromTouch(100), isNot(spreadFromReach(100)));
    });
  });

  group('the spike — redesign.html:900', () {
    test('decays by 0.92 per frame', () {
      expect(decaySpike(1.0), closeTo(0.92, 1e-12));
      expect(decaySpike(0.4), closeTo(0.368, 1e-12));
    });

    test('it decays towards zero and never through it', () {
      double spike = 0.4;
      for (int frame = 0; frame < 400; frame++) {
        spike = decaySpike(spike);
        expect(spike, inInclusiveRange(0.0, 0.4));
      }
      expect(spike, lessThan(1e-9), reason: 'after 400 frames it is invisible');
      expect(decaySpike(0), 0.0, reason: 'zero is a fixed point');
    });

    test('a spike set on a table decays in place, and nothing else moves', () {
      final LumenUniforms u = const LumenUniforms.identity().setTargetHue(
        h: 258,
        s: 90,
        l: 66,
        spike: 0.4,
      );
      expect(u.spike, 0.4);

      final LumenUniforms next = u.copyWith(spike: decaySpike(u.spike));
      expect(next.spike, closeTo(0.368, 1e-12));
      expect(
        next.copyWith(spike: u.spike),
        u,
        reason: 'decay is the only field that moved',
      );
    });
  });

  group('setTargetHue — redesign.html:883', () {
    test('recomputes the derived triple, because :902-903 read curH', () {
      final LumenUniforms u = const LumenUniforms.identity().setTargetHue(
        h: 258,
        s: 90,
        l: 66,
      );
      expect(u.hue, hslToRgb(h: 258, s: 90, l: 66));
      expect(u.hue2, hslToRgb(h: 296, s: 90, l: 72));
      expect(u.hue3, hslToRgb(h: 216, s: 90, l: 66));
    });

    test('a supplied spike is set on the new table', () {
      final LumenUniforms u = const LumenUniforms.identity().setTargetHue(
        h: 296,
        s: 70,
        l: 62,
        spike: 0.4,
      );
      expect(u.spike, 0.4);
      expect(u.hue, hslToRgb(h: 296, s: 70, l: 62));
    });

    test('no spike leaves the one already there alone', () {
      // `setTargetHue`'s prototype signature is `spike?`, and half its call
      // sites omit it: the shape control sets `V.spike` on the next line
      // itself (`redesign.html:1462-1463`). Treating an absent spike as zero
      // would cut a spark the caller had just raised.
      final LumenUniforms lit = const LumenUniforms.identity().copyWith(
        spike: 0.4,
      );
      expect(
        lit.setTargetHue(h: 120, s: 70, l: 62).spike,
        0.4,
        reason: 'an omitted spike is "do not touch", not "set to zero"',
      );
      expect(lit.setTargetHue(h: 120, s: 70, l: 62, spike: 0.3).spike, 0.3);
    });

    test('it snaps where the prototype eases — deliberately, and named', () {
      // `redesign.html:894-896` walks `curH` towards `tgtH` at 4.5% a frame.
      // This object has no frames, so it holds the destination and nothing
      // eases; whoever owns the clock owns the interpolation. The test is here
      // so that claim is a fact about the code rather than a comment: a future
      // easing step must land in that owner, not silently appear here.
      final LumenUniforms u = const LumenUniforms.identity().setTargetHue(
        h: 300,
        s: 70,
        l: 62,
      );
      expect(u.hue, hslToRgb(h: 300, s: 70, l: 62));
    });
  });

  group('identity()', () {
    test('is every scalar at zero and every hue at black', () {
      const LumenUniforms u = LumenUniforms.identity();
      expect(u.resX, 0);
      expect(u.resY, 0);
      expect(u.time, 0);
      expect(u.shape, 0);
      expect(u.spread, 0);
      expect(u.rays, 0);
      expect(u.pointerX, 0);
      expect(u.pointerY, 0);
      expect(u.pointerIntensity, 0);
      expect(u.intensity, 0);
      expect(u.spike, 0);
      expect(u.hue, const HslRgb(r: 0, g: 0, b: 0));
      expect(u.hue2, const HslRgb(r: 0, g: 0, b: 0));
      expect(u.hue3, const HslRgb(r: 0, g: 0, b: 0));
      expect(u.melt, 0);
      expect(u.white, 0);
      expect(u.light, 0);
      expect(u.dots, 0);
    });

    test('is the no-argument constructor — the two cannot drift apart', () {
      expect(const LumenUniforms.identity(), const LumenUniforms());
    });

    test('it is a value: equal tables compare equal', () {
      expect(
        const LumenUniforms.identity().withHue(h: 1, s: 2, l: 3),
        const LumenUniforms.identity().withHue(h: 1, s: 2, l: 3),
      );
      expect(
        const LumenUniforms.identity().withHue(h: 1, s: 2, l: 3).hashCode,
        const LumenUniforms.identity().withHue(h: 1, s: 2, l: 3).hashCode,
      );
      expect(
        const LumenUniforms.identity().withHue(h: 1, s: 2, l: 3),
        isNot(const LumenUniforms.identity().withHue(h: 4, s: 2, l: 3)),
      );
    });

    test('copyWith changes exactly what it is given', () {
      const LumenUniforms before = LumenUniforms.identity();
      expect(before.copyWith(intensity: 0.9).intensity, 0.9);
      expect(before.copyWith(intensity: 0.9).time, 0);
      expect(before.copyWith(), before);
    });
  });
}

/// An independent HSL → RGB implementation, used only by the test above.
///
/// Deliberately the *textbook* form — `C`/`X`/`m` and a sextant table — rather
/// than the prototype's branchless `k`/`f` one-liner. Asserting the port
/// against a transcription of itself would only prove the transcription is
/// faithful; asserting it against a second implementation proves the thing the
/// port exists for, which is that `eva/redesign.html:879-880` *is* HSL → RGB.
HslRgb referenceHslToRgb({
  required double h,
  required double s,
  required double l,
}) {
  assert(
    s >= 0 && s <= 1,
    's is a fraction here, not the prototype\'s percent',
  );
  final double c = (1 - (2 * l - 1).abs()) * s;
  final double sector = h / 60;
  final double x = c * (1 - (sector % 2 - 1).abs());
  final double m = l - c / 2;
  final List<double> rgb = switch (sector.floor() % 6) {
    0 => <double>[c, x, 0],
    1 => <double>[x, c, 0],
    2 => <double>[0, c, x],
    3 => <double>[0, x, c],
    4 => <double>[x, 0, c],
    _ => <double>[c, 0, x],
  };
  return HslRgb(r: rgb[0] + m, g: rgb[1] + m, b: rgb[2] + m);
}
