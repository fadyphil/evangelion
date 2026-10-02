import 'package:evangelion/core/design_system/tokens/sticker_palette.dart';
import 'package:flutter/material.dart';

/// The Eva colour system as a [ThemeExtension].
///
/// WHY AN EXTENSION RATHER THAN A [ColorScheme]. `docs/plans/03-design-system.md`
/// §5.1 names **fourteen** tokens per brightness — `canvas`, `surface`, `raised`,
/// three inks, `line`, `ember`, `emberDeep`, `onEmber`, `ok`, `err`, plus the two
/// opacity scalars and the three glass values. Material's `ColorScheme` has no
/// field for a third surface, no field for a muted third ink, no field for a
/// hairline that is not an outline, and no field for a translucent white fill on
/// a coloured backdrop. A `ColorScheme` therefore cannot hold this system; the
/// extension can, and `ColorScheme` is derived from these tokens in
/// `theme/eva_theme.dart` so stock Material widgets still get sensible defaults.
///
/// Reads as `Theme.of(context).extension<EvaColors>()!` — see [EvaColorsX].
///
/// `@immutable` covers the *fields*, not what they point at: [sticker] is a
/// `Map` and therefore mutable. The annotation is inherited from spec §5.4 and
/// is accurate as far as it goes — nothing here reassigns a field — but it is
/// not a deep-immutability claim. The map it does guard against sharing is
/// handled where the hazard is: `EvaStickerPalette.colors` is unmodifiable, and
/// `lerp` builds a fresh map rather than reusing an endpoint's, both of which
/// are asserted in `eva_colors_test.dart`.
@immutable
class EvaColors extends ThemeExtension<EvaColors> {
  /// Creates a palette from explicit values.
  ///
  /// Every field is required rather than defaulted. A default here would be a
  /// token invented outside `03-design-system.md`, and a palette that silently
  /// picks up a default is a palette where "which colour is this?" has two
  /// answers.
  const EvaColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.ember,
    required this.emberDeep,
    required this.onEmber,
    required this.ok,
    required this.err,
    required this.orbOpacity,
    required this.auroraOpacity,
    required this.glassFill,
    required this.glassBorder,
    required this.glassShadow,
    required this.sticker,
  });

  /// The dark palette — `03-design-system.md` §5.1, dark table.
  ///
  /// `canvas` #05081A · `surface` #0D1224 · `raised` #141A2E · `ink` #EAE8F5 ·
  /// `ink2` #8A8FAD · `ink3` #424669 · `line` #1C2238 · `ember` #E8A33D ·
  /// `emberDeep` #C77F1F · `onEmber` #0D0A04 · `ok` #4ECCA3 · `err` #FF6B6B ·
  /// `orbOpacity` 0.55 · `auroraOpacity` 0.18.
  const EvaColors.dark()
    : canvas = const Color(0xFF05081A),
      surface = const Color(0xFF0D1224),
      raised = const Color(0xFF141A2E),
      ink = const Color(0xFFEAE8F5),
      ink2 = const Color(0xFF8A8FAD),
      ink3 = const Color(0xFF424669),
      line = const Color(0xFF1C2238),
      ember = const Color(0xFFE8A33D),
      emberDeep = const Color(0xFFC77F1F),
      onEmber = const Color(0xFF0D0A04),
      ok = const Color(0xFF4ECCA3),
      err = const Color(0xFFFF6B6B),
      orbOpacity = 0.55,
      auroraOpacity = 0.18,
      glassFill = const Color(0x0DFFFFFF),
      glassBorder = const Color(0x14FFFFFF),
      glassShadow = const Color(0x59000000),
      sticker = EvaStickerPalette.colors;

  /// The light palette — `03-design-system.md` §5.1, light table.
  ///
  /// `canvas` #F0EEFF · `surface` #FFFFFF · `raised` #E8E4FF · `ink` #120E28 ·
  /// `ink2` #5A5480 · `ink3` #9B97B8 · `line` #D5D0EF · `ember` #D4891A ·
  /// `emberDeep` #B56C0C · `ok` #1A8C6A · `err` #D63B3B ·
  /// `orbOpacity` 0.18 · `auroraOpacity` 0.10.
  ///
  /// **`onEmber` is #3A1E00, NOT the spec's #FFF8EE.** This is the one token in
  /// the file that deliberately diverges from `03-design-system.md`, and the
  /// divergence was the user's ruling. The spec's value measures **2.69:1**
  /// against this palette's own `ember` (#D4891A) — below WCAG AA (4.5:1) *and*
  /// below AA-large (3:1), so it fails at every text size and is not a
  /// large-text-only concession. Darkening it while it stays light makes it worse,
  /// not better: the ratio falls monotonically to ~1.05:1 as the value approaches
  /// `ember`'s own luminance (#D09040), then climbs back on the far side. It has
  /// to cross over to a dark ink, which is also the role the token has in dark
  /// mode (#0D0A04 is dark text on ember there too).
  ///
  /// The light glass shadow is `#120E28` at 12% — the built code's light `ink`.
  /// The brief's `#221C15` is explicitly NOT used: that value belongs to the
  /// discarded warm-paper palette (`01-source-analysis.md` §1.2).
  const EvaColors.light()
    : canvas = const Color(0xFFF0EEFF),
      surface = const Color(0xFFFFFFFF),
      raised = const Color(0xFFE8E4FF),
      ink = const Color(0xFF120E28),
      ink2 = const Color(0xFF5A5480),
      ink3 = const Color(0xFF9B97B8),
      line = const Color(0xFFD5D0EF),
      ember = const Color(0xFFD4891A),
      emberDeep = const Color(0xFFB56C0C),
      onEmber = const Color(0xFF3A1E00),
      ok = const Color(0xFF1A8C6A),
      err = const Color(0xFFD63B3B),
      orbOpacity = 0.18,
      auroraOpacity = 0.10,
      glassFill = const Color(0x0A000000),
      glassBorder = const Color(0x14000000),
      glassShadow = const Color(0x1F120E28),
      sticker = EvaStickerPalette.colors;

  /// The page backdrop — the bottom-most layer of the three.
  final Color canvas;

  /// The second layer. `03-design-system.md` §5.1 wires `surface`/`raised` to the
  /// base layers of `GlassSurface`.
  final Color surface;

  /// The third, most-forwarded opaque layer.
  final Color raised;

  /// Primary ink — body and headline text.
  final Color ink;

  /// Secondary ink — captions, de-emphasised labels.
  final Color ink2;

  /// Tertiary ink — disabled text and the faintest decoration.
  final Color ink3;

  /// The hairline colour. §5.1: "`line` becomes the hairline colour".
  final Color line;

  /// The single accent. §5.1: "`onEmber` becomes `EvaButton.primary`'s
  /// foreground; `emberDeep` is the pressed fill".
  final Color ember;

  /// The pressed state of [ember].
  final Color emberDeep;

  /// Legible ink on top of [ember], in both modes.
  ///
  /// Dark in **both** palettes — #0D0A04 in dark, #3A1E00 in light — because
  /// `ember` is a light amber in each. Measured against WCAG 2.x relative
  /// luminance, and asserted that way rather than restated here, in
  /// `eva_colors_test.dart`:
  ///
  /// | palette | ember | onEmber | ratio |
  /// | --- | --- | --- | --- |
  /// | dark | #E8A33D | #0D0A04 | **9.17:1** |
  /// | light | #D4891A | #3A1E00 | **5.41:1** |
  ///
  /// The light value is the one that diverges from `03-design-system.md` §5.1;
  /// see the [EvaColors.light] doc for the measurement and the reasoning. The
  /// ratios above are a record, not the guarantee — the guarantee is the test,
  /// which recomputes them from the palette so a future edit to either colour
  /// cannot quietly break the pairing.
  final Color onEmber;

  /// The success semantic. §5.1: "`ok`/`err` are the quiz/feedback semantic
  /// pair". Never the only signal — pair with an icon and a semantics label.
  final Color ok;

  /// The error semantic, and the mirror of [ok].
  final Color err;

  /// Peak alpha of a `NeuralBackground` orb. §5.1 marked this token "(was dead —
  /// wire it)".
  final double orbOpacity;

  /// Peak alpha of the aurora band. Also "(was dead — wire it)".
  final double auroraOpacity;

  /// Translucent white on dark / translucent black on light — the tint behind a
  /// glass panel.
  final Color glassFill;

  /// The glass panel's 1px rim.
  final Color glassBorder;

  /// The glass panel's ambient shadow. This is the design system's *only*
  /// shadow: see `eva_elevations.dart` for why every elevation is flat.
  final Color glassShadow;

  /// The seven decorative sticker slots, keyed by slot.
  final Map<StickerSlot, Color> sticker;

  @override
  EvaColors copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? ember,
    Color? emberDeep,
    Color? onEmber,
    Color? ok,
    Color? err,
    double? orbOpacity,
    double? auroraOpacity,
    Color? glassFill,
    Color? glassBorder,
    Color? glassShadow,
    Map<StickerSlot, Color>? sticker,
  }) => EvaColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    line: line ?? this.line,
    ember: ember ?? this.ember,
    emberDeep: emberDeep ?? this.emberDeep,
    onEmber: onEmber ?? this.onEmber,
    ok: ok ?? this.ok,
    err: err ?? this.err,
    orbOpacity: orbOpacity ?? this.orbOpacity,
    auroraOpacity: auroraOpacity ?? this.auroraOpacity,
    glassFill: glassFill ?? this.glassFill,
    glassBorder: glassBorder ?? this.glassBorder,
    glassShadow: glassShadow ?? this.glassShadow,
    sticker: sticker ?? this.sticker,
  );

  @override
  EvaColors lerp(covariant EvaColors? other, double t) {
    // `covariant` is required, not stylistic. `ThemeExtension.lerp` declares
    // `ThemeExtension<EvaColors>?`, and narrowing a parameter type is only legal
    // on a covariant parameter. The spec's reference implementation omits the
    // keyword; with it, the class does not override the base method.
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    // `this.sticker` is read through `EvaStickerPalette.of` rather than by
    // force-unwrapping `sticker[slot]!`. `of` is the exhaustive switch that makes
    // a missing entry a compile error rather than a null, and using it here is
    // what gives it a caller: an unused public function with an exhaustive switch
    // behind it looks like a completeness guarantee and is not one, because
    // nothing walks it. `other.sticker` is a caller-supplied map and can genuinely
    // be partial, so its `!` is the one place here that can still throw — a
    // `copyWith(sticker: …)` handed a map missing a slot throws at the next
    // theme transition rather than rendering a transparent sticker. That is the
    // intended outcome and `eva_colors_test.dart` asserts the key set on both
    // stock palettes so a gap in a shipped palette cannot reach it.
    return EvaColors(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      line: c(line, other.line),
      ember: c(ember, other.ember),
      emberDeep: c(emberDeep, other.emberDeep),
      onEmber: c(onEmber, other.onEmber),
      ok: c(ok, other.ok),
      err: c(err, other.err),
      orbOpacity: d(orbOpacity, other.orbOpacity),
      auroraOpacity: d(auroraOpacity, other.auroraOpacity),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
      glassShadow: c(glassShadow, other.glassShadow),
      sticker: {
        for (final StickerSlot slot in StickerSlot.values)
          slot: c(EvaStickerPalette.of(slot), other.sticker[slot]!),
      },
    );
  }
}

/// Reads the Eva palette off the ambient [Theme].
///
/// `Theme.of(context)` rather than a `BuildContext` extension getter on a
/// nullable: a missing extension is a programming error (Phase 1 installs it on
/// both themes), so the assertion is the correct answer rather than a null the
/// whole widget tree has to thread.
extension EvaColorsX on BuildContext {
  EvaColors get colors {
    final ThemeData theme = Theme.of(this);
    assert(
      theme.extension<EvaColors>() != null,
      'EvaColors is missing from this ThemeData — see EvaTheme.build',
    );
    return theme.extension<EvaColors>()!;
  }
}
