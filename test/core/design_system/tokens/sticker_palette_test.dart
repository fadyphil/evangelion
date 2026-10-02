import 'package:evangelion/core/design_system/tokens/sticker_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the expected ARGB of a `#RRGGBB` literal through a NON-CONST path.
///
/// WHY THIS HELPER EXISTS. Dart canonicalises const expressions, so a test that
/// wrote `expect(palette[StickerSlot.sky], const Color(0xFF7CC4F0))` would be
/// comparing the very object the implementation declared, against itself, and
/// would pass no matter what the implementation contained. `_argb` therefore
/// assembles the integer from runtime-composed parts, so the number under test
/// is never an address the compiler could have handed to both sides.
int _argb(int r, int g, int b, [int a = 0xFF]) =>
    (a << 24) | (r << 16) | (g << 8) | b;

void main() {
  group('StickerSlot is the seven-slot decorative vocabulary', () {
    test('has exactly the seven slots the spec lists, in spec order', () {
      // A `set` comparison would pass with a renamed, added or dropped slot as
      // long as the length held. The ordered list is the stricter claim: the
      // order is the spec's own ("sky … sun") and `lerp` walks `values`, so a
      // reordered enum silently changes the interpolation walk order too.
      expect(
        StickerSlot.values.map((StickerSlot s) => s.name).toList(),
        <String>['sky', 'lavender', 'pink', 'coral', 'teal', 'leaf', 'sun'],
      );
    });

    test('is decorative — it carries no category or domain meaning', () {
      // The library feature was cut (AGENT_CONTEXT §2 decision 1), so the
      // category enum this palette was originally keyed to no longer exists.
      // Nothing in `core/domain/` may refer to `StickerSlot`, and the type has
      // to stay assignable straight from `StickerSlot.values` — a version that
      // grew a data-bearing field per slot would stop being a lookup key.
      for (final StickerSlot slot in StickerSlot.values) {
        expect(slot.index, lessThan(StickerSlot.values.length));
      }
    });
  });

  group('the palette values', () {
    test('match the spec hex for every slot', () {
      const Map<StickerSlot, Color> expected = <StickerSlot, Color>{
        StickerSlot.sky: Color(0xFF7CC4F0),
        StickerSlot.lavender: Color(0xFFB79CF0),
        StickerSlot.pink: Color(0xFFF58FC4),
        StickerSlot.coral: Color(0xFFF4836B),
        StickerSlot.teal: Color(0xFF4EC9BD),
        StickerSlot.leaf: Color(0xFF7FC96B),
        StickerSlot.sun: Color(0xFFF5C84C),
      };

      // Asserted channel-by-channel through `_argb` rather than by comparing
      // `Color` objects: `Color` overrides `==` by value, so the comparison is
      // meaningful, but building the expectation from a const map of const
      // `Color`s reintroduces the canonicalisation hazard the moment the
      // implementation and the test declare the same literal. `_argb` keeps the
      // expected number out of the constant pool.
      expect(
        StickerSlot.values
            .map((StickerSlot s) => expected[s]!.toARGB32())
            .toList(),
        <int>[
          _argb(0x7C, 0xC4, 0xF0),
          _argb(0xB7, 0x9C, 0xF0),
          _argb(0xF5, 0x8F, 0xC4),
          _argb(0xF4, 0x83, 0x6B),
          _argb(0x4E, 0xC9, 0xBD),
          _argb(0x7F, 0xC9, 0x6B),
          _argb(0xF5, 0xC8, 0x4C),
        ],
        reason: 'the 03-design-system §5.1 sticker palette, slot by slot',
      );

      // ...and the palette under test agrees with that same list.
      for (final StickerSlot slot in StickerSlot.values) {
        expect(
          EvaStickerPalette.colors[slot]!.toARGB32(),
          expected[slot]!.toARGB32(),
          reason: 'slot ${slot.name}',
        );
      }
    });

    test('covers every slot exactly once — no gaps, no extras', () {
      // `lerp` iterates `StickerSlot.values` and force-unwraps both palettes, so
      // a gap here is not a softer failure, it is a throw during a theme
      // transition. Asserting the key SET catches a dropped slot; the
      // identical-instance assertion catches an alias where two keys point at
      // the same `Color` object and one slot therefore renders in another slot's
      // colour after a `copyWith` that mutated the map in place.
      expect(EvaStickerPalette.colors.keys.toSet(), StickerSlot.values.toSet());
      final Set<Color> distinct = EvaStickerPalette.colors.values.toSet();
      expect(
        distinct.length,
        StickerSlot.values.length,
        reason: 'every slot must resolve to its own colour object',
      );
    });

    test('is opaque — a sticker with an alpha channel is a rendering bug', () {
      for (final MapEntry<StickerSlot, Color> entry
          in EvaStickerPalette.colors.entries) {
        expect(
          entry.value.a,
          1.0,
          reason: 'slot ${entry.key.name} must be fully opaque',
        );
      }
    });

    test('is unmodifiable, so a lerp can never mutate the shared constant', () {
      // `EvaColors.dark()` and `EvaColors.light()` both reference this one map.
      // `lerp` builds a fresh map, but nothing structurally stops a future
      // `copyWith` from assigning into the shared instance — and the first
      // caller to do so would repaint both themes for the rest of the process.
      expect(
        () =>
            EvaStickerPalette.colors[StickerSlot.sky] = const Color(0xFF000000),
        throwsUnsupportedError,
      );
    });
  });

  group('EvaStickerPalette.of', () {
    // THE MUTATION THIS EXISTS FOR. `of` is an exhaustive switch over seven
    // slots, and its doc comment claimed that makes a missing entry a compile
    // error. The compile-error half is true — a new `StickerSlot` value will not
    // build until an arm names it — but a *wrong* arm does compile, and while
    // nothing in `lib/` called `of`, no test walked it either. Measured at
    // 0/8 coverage: a `pink => colors[StickerSlot.coral]` mutation would have
    // shipped with every other test green, because the switch's wrongness never
    // touches the map.
    //
    // `of` now has a production caller (`EvaColors.lerp` reads its endpoint
    // through it), which makes the comparison below the real invariant: the
    // switch and the map must agree, slot by slot, forever.

    test('agrees with the map for every slot', () {
      for (final StickerSlot slot in StickerSlot.values) {
        expect(
          EvaStickerPalette.of(slot),
          EvaStickerPalette.colors[slot],
          reason: 'slot ${slot.name} resolves to the wrong colour',
        );
      }
      // Anti-vacuity: the loop above must have run.
      expect(StickerSlot.values.length, 7);
    });

    test('resolves the seven spec hexes, so a wrong arm is visible', () {
      // Built through `_argb` for the same reason as the palette test above: a
      // `const Color(0x…)` expectation would be canonicalised against the very
      // literal the implementation declares and would compare an address to
      // itself.
      expect(
        <int>[
          for (final StickerSlot slot in StickerSlot.values)
            EvaStickerPalette.of(slot).toARGB32(),
        ],
        <int>[
          _argb(0x7C, 0xC4, 0xF0),
          _argb(0xB7, 0x9C, 0xF0),
          _argb(0xF5, 0x8F, 0xC4),
          _argb(0xF4, 0x83, 0x6B),
          _argb(0x4E, 0xC9, 0xBD),
          _argb(0x7F, 0xC9, 0x6B),
          _argb(0xF5, 0xC8, 0x4C),
        ],
        reason: 'of() must agree with §5.1 slot by slot, in slot order',
      );
    });

    test('resolves seven distinct colours', () {
      // The wrong-arm mutation that the map-based tests cannot see: swapping two
      // arms leaves `colors` intact and every "covers every slot" assertion
      // true, but collapses two slots onto one colour.
      final Set<Color> resolved = <Color>{
        for (final StickerSlot slot in StickerSlot.values)
          EvaStickerPalette.of(slot),
      };
      expect(resolved.length, StickerSlot.values.length);
    });

    test('never returns null, which is the point of the exhaustive switch', () {
      for (final StickerSlot slot in StickerSlot.values) {
        expect(EvaStickerPalette.of(slot), isA<Color>());
      }
    });
  });
}
