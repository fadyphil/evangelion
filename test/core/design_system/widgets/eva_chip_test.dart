import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// RED-FIRST — `EvaChip`'s variant-to-style mapping.
///
/// The inventory collapses **four** prototype pill definitions into one widget
/// (`04-widget-inventory.md` §3): `CategoryChip` (`ds.tsx:326-347`), the
/// `App.tsx` screen chips (`App.tsx:70-84`, defect #12 scaffolding), the
/// `QuizScreen` frame toggle (`QuizScreen.tsx:30-38`, also defect #12) and the
/// Settings language pills (`SettingsScreen.tsx:77-90`). They disagree on fill,
/// rim width, ink and glow, so the mapping is a table and the table is tested.
///
/// ## WHAT IS **NOT** BEING TRANSCRIBED, AND WHY
///
/// Defect #12 names `App.tsx`'s switcher and `QuizScreen`'s "Frame A/B" toggle
/// as dev scaffolding that must not be ported. So `EvaChip` is **not** given a
/// frame-toggle UI and no test here builds one. What is transcribed is the pill
/// *recipe* those definitions share, because the Settings language pills and the
/// real theme toggle are genuine call sites.
void main() {
  group('filter — CategoryChip, ds.tsx:326-347', () {
    test('unselected takes the sticker colour on all three channels', () {
      const EvaColors colors = EvaColors.dark();
      final EvaChipStyle style = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: colors,
        selected: false,
        sticker: EvaStickerPalette.of(StickerSlot.sky),
      );
      // `background: rgba(color, 0.12)` · `border: 1px solid rgba(color, 0.28)`
      // · `color: color`.
      expect(style.background, style.foreground.withValues(alpha: 0.12));
      expect(style.border, isNotNull);
      expect(style.border.top.width, 1.0);
      expect(style.border.top.color, style.foreground.withValues(alpha: 0.28));
    });

    test('selected overrides all three with ember and thickens the rim', () {
      const EvaColors colors = EvaColors.dark();
      final EvaChipStyle style = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: colors,
        selected: true,
        sticker: EvaStickerPalette.of(StickerSlot.sky),
      );
      // `rgba(ember, 0.14)` fill · `1.5px solid rgba(ember, 0.45)` rim · ember ink.
      expect(style.background, colors.ember.withValues(alpha: 0.14));
      expect(style.border.top.width, 1.5);
      expect(style.border.top.color, colors.ember.withValues(alpha: 0.45));
      expect(style.foreground, colors.ember);
    });

    test('the dot glows in the same colour it is filled with', () {
      // `ds.tsx:338` — `active ? 0 0 6px rgba(ember,.7) : 0 0 5px rgba(color,.6)`.
      const EvaColors colors = EvaColors.dark();
      final Color sky = EvaStickerPalette.colors[StickerSlot.sky]!;
      final EvaChipStyle idle = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: colors,
        selected: false,
        sticker: sky,
      );
      final EvaChipStyle active = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: colors,
        selected: true,
        sticker: sky,
      );
      expect(idle.dot, sky);
      expect(idle.dotGlow!.blurRadius, 5);
      expect(idle.dotGlow!.color, sky.withValues(alpha: 0.60));
      expect(active.dot, colors.ember);
      expect(active.dotGlow!.blurRadius, 6);
      expect(active.dotGlow!.color, colors.ember.withValues(alpha: 0.70));
    });

    test('without a sticker colour it falls back to ember, never to ink', () {
      // The library screen that owned sticker colours was cut, so a `filter`
      // chip with no colour is now the shape a caller can reach by accident.
      // Falling back to `ink` would render a chip indistinguishable from body
      // text; ember is the only accent this system has.
      const EvaColors colors = EvaColors.dark();
      final EvaChipStyle style = resolveChipStyle(
        variant: EvaChipVariant.filter,
        colors: colors,
        selected: false,
        sticker: null,
      );
      expect(style.foreground, colors.ember);
      expect(style.dot, colors.ember);
    });
  });

  group('toggle — the App.tsx chips and the Settings pills', () {
    test('unselected is transparent with a faint rim and ink3', () {
      // `App.tsx:75-76` — `1.5px solid rgba(#fff | #000, 0.1)`, transparent
      // background, `ink3`-class ink. The prototype's literal `'#6B6F94'` /
      // `'#7A75A0'` are not token values; `ink3` is the token that means
      // "disabled text and the faintest decoration" (`eva_colors.dart`).
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaChipStyle style = resolveChipStyle(
          variant: EvaChipVariant.toggle,
          colors: colors,
          selected: false,
          sticker: null,
        );
        expect(style.background, Colors.transparent);
        expect(style.border.top.width, 1.5);
        expect(style.border.top.color, colors.glassBorder);
        expect(style.foreground, colors.ink3);
      }
    });

    test('selected is an ember rim on an ember-at-13% fill', () {
      // `App.tsx:74,78` — rim `1.5px solid ember` (no alpha) on `#E8A33D22`,
      // which is ember at 0x22/0xFF = 13%. `SettingsScreen.tsx:81-84` agrees on
      // the rim and says `rgba(ember, 0.12)` for the fill, so the two prototypes
      // differ by one percentage point; the named token form (0.12) wins and
      // the disagreement is recorded here rather than silently averaged.
      const EvaColors colors = EvaColors.dark();
      final EvaChipStyle style = resolveChipStyle(
        variant: EvaChipVariant.toggle,
        colors: colors,
        selected: true,
        sticker: null,
      );
      expect(style.background, colors.ember.withValues(alpha: 0.12));
      expect(style.border.top.width, 1.5);
      expect(style.border.top.color, colors.ember);
      expect(style.foreground, colors.ember);
      expect(style.dot, colors.ember);
      expect(style.dotGlow!.color, colors.ember.withValues(alpha: 0.70));
    });

    test('the selected toggle glows; the idle one does not', () {
      // `SettingsScreen.tsx:84` — `boxShadow: lang === l ? 0 0 12px rgba(ember,.25) : none`.
      const EvaColors colors = EvaColors.dark();
      expect(
        resolveChipStyle(
          variant: EvaChipVariant.toggle,
          colors: colors,
          selected: false,
          sticker: null,
        ).glow,
        isEmpty,
      );
      final EvaChipStyle selected = resolveChipStyle(
        variant: EvaChipVariant.toggle,
        colors: colors,
        selected: true,
        sticker: null,
      );
      expect(selected.glow, hasLength(1));
      expect(selected.glow.single.color, colors.ember.withValues(alpha: 0.25));
      expect(selected.glow.single.blurRadius, 12);
    });

    test('a sticker colour cannot leak into a toggle chip', () {
      // `App.tsx`'s chips have no `color` prop at all. If `sticker` were honoured
      // here, the route chips and the Settings language pills would pick up a
      // hue nobody chose.
      final EvaChipStyle withColour = resolveChipStyle(
        variant: EvaChipVariant.toggle,
        colors: const EvaColors.dark(),
        selected: true,
        sticker: EvaStickerPalette.of(StickerSlot.pink),
      );
      final EvaChipStyle without = resolveChipStyle(
        variant: EvaChipVariant.toggle,
        colors: const EvaColors.dark(),
        selected: true,
        sticker: null,
      );
      expect(withColour, without);
    });
  });

  group('static — the SealFAB dock item, ds.tsx:545-555', () {
    test('is tinted glass with a 1px rim and no selection', () {
      // `background: rgba(#fff | #000, 0.08)` · `border: 1px solid rgba(#fff | #000, 0.12)`
      // · `boxShadow: 0 8px 24px rgba(#000, 0.35)`.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaChipStyle idle = resolveChipStyle(
          variant: EvaChipVariant.static,
          colors: colors,
          selected: false,
          sticker: null,
        );
        expect(idle.background.a, moreOrLessEquals(0.08, epsilon: 0.001));
        expect(idle.border.top.width, 1.0);
        expect(idle.border.top.color.a, moreOrLessEquals(0.12, epsilon: 0.001));
        expect(idle.foreground, colors.ink);
        expect(idle.glow.single.offset, const Offset(0, 8));
        expect(idle.glow.single.blurRadius, 24);
      }
    });

    test('`selected` is inert — the dock has no selected state', () {
      const EvaColors colors = EvaColors.dark();
      expect(
        resolveChipStyle(
          variant: EvaChipVariant.static,
          colors: colors,
          selected: true,
          sticker: null,
        ),
        resolveChipStyle(
          variant: EvaChipVariant.static,
          colors: colors,
          selected: false,
          sticker: null,
        ),
        reason:
            'a static chip is a menu item, not an option; honouring `selected` '
            'would invent a state the prototype does not have',
      );
    });
  });

  group('the enum and the defaults', () {
    test('has exactly the three prototype pill families', () {
      expect(EvaChipVariant.values, <EvaChipVariant>[
        EvaChipVariant.filter,
        EvaChipVariant.static,
        EvaChipVariant.toggle,
      ]);
    });

    test('the inventory default is `toggle` with a leading dot', () {
      const EvaChip chip = EvaChip(label: 'Dark');
      expect(chip.variant, EvaChipVariant.toggle);
      expect(chip.leadingDot, isTrue);
      expect(chip.selected, isFalse);
      expect(chip.onSelected, isNull);
      expect(chip.color, isNull);
    });

    test('style is a value, so the two palettes cannot drift', () {
      expect(
        resolveChipStyle(
          variant: EvaChipVariant.toggle,
          colors: const EvaColors.dark(),
          selected: true,
          sticker: null,
        ),
        resolveChipStyle(
          variant: EvaChipVariant.toggle,
          colors: const EvaColors.dark(),
          selected: true,
          sticker: null,
        ),
      );
    });
  });
}
