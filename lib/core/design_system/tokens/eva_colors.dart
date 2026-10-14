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
    required this.emberInk,
    required this.okInk,
    required this.errInk,
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
    required this.seam,
    required this.seamGlow,
    required this.bloom,
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
      // Decision 153 — in **dark** the accent inks are the accents. `ember` already
      // measures 6.97:1 on the worst dark surface, so a separate ink would be a second
      // name for the same value. The tokens exist for the *light* theme, where the fill
      // and the ink pull in opposite directions.
      emberInk = const Color(0xFFE8A33D),
      okInk = const Color(0xFF4ECCA3),
      errInk = const Color(0xFFFF6B6B),
      emberDeep = const Color(0xFFC77F1F),
      onEmber = const Color(0xFF0D0A04),
      ok = const Color(0xFF4ECCA3),
      err = const Color(0xFFFF6B6B),
      orbOpacity = 0.55,
      auroraOpacity = 0.18,
      glassFill = const Color(0x0DFFFFFF),
      glassBorder = const Color(0x14FFFFFF),
      glassShadow = const Color(0x59000000),
      seam = const Color(0xD9FFFFFF),
      seamGlow = const Color(0x99FFFFFF),
      bloom = const Color(0x8CE457D6),
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
  ///
  /// ## WHY THE PROTOTYPE'S LIGHT GOLDS WERE NOT ADOPTED (Phase 2 non-repair).
  ///
  /// The LUMEN plan proposed converging four light values toward the prototype
  /// (`eva/redesign.html`, light table at `redesign.html:56-58`) to clear WCAG
  /// AA. Re-measured against the prototype's own light canvas `#F5F2EA`
  /// (`redesign.html:56`, `--void-1`) the four failures reproduce exactly — but
  /// the proposed repairs do not survive either, and the tokens this palette
  /// already ships exceed every one of them. Adopting the table verbatim would
  /// have REGRESSED the palette, so no hex below moved. If a future reader
  /// re-proposes the converge-repair, this table is the answer:
  ///
  /// | role | prototype (redesign.html) | measured vs prototype canvas `#F5F2EA` | plan's repair | repair actually measures | this palette today (vs app canvas `#F0EEFF`; row 4 is a label-on-fill pair) | verdict |
  /// | --- | --- | --- | --- | --- | --- | --- |
  /// | secondary ink | `#707684` (`redesign.html:56` `--ink-2`; rendered at `redesign.html:70` `.segp button`) | 4.069:1 | `#666C7A` | 4.703:1 | `ink2 #5A5480` at 6.10:1 | already better — no change |
  /// | gold ink | `#8a6d15` (`redesign.html:71` `.qcta`, `redesign.html:90` `.mono b`, `redesign.html:100` `.qnext`) | 4.387:1 | `#806615` | 4.902:1 | `emberInk #845610` at 5.54:1 | already better — no change |
  /// | gold fill | `#9A7B19` (`redesign.html:58` `--gold`; `redesign.html:39` rail `h4`) | 3.595:1 | `#8A6D15` | 4.387:1, still under 4.5 | `ember` fills + `emberInk` writes (Decision 153) | the repair fails AA — no change |
  /// | `.cta` label | `#FFFFFF` on `#9A7B19` (`redesign.html:86`) | 4.022:1 | fill `#8A6D15` (claimed 5.30:1) | 4.908:1, not 5.30 | `ember #D4891A` + `onEmber #3A1E00` at 5.41:1 | already better; the parenthetical was wrong — no change |
  ///
  /// The mechanism that beats the converge-repair is Decision 153's split,
  /// documented on [emberInk]: one value cannot be both a fill light enough for
  /// `onEmber` to read on and an ink dark enough to read on a pale surface, so
  /// `ember` fills and `emberInk` writes. The plan's repair tried to make one
  /// value do both and fails exactly where that contradiction bites (row three).
  ///
  /// Focus is the deferred half, not a second non-repair: `redesign.html:177`
  /// sets `.screen.focus .vline.in` to `#d9dfef`. In dark mode nothing overrides
  /// it, so every in-view verse including `.hot` flattens to one colour —
  /// in-focus distinction 1.000:1. In light mode the more specific
  /// `redesign.html:80` (`.screen[data-mode=light] .focus .vline.in`, 0-5-0,
  /// beats `:177`'s 0-4-0) re-points every in-view verse, hot ones included, at
  /// `#2A2F3A`, against out-of-view `#3A3F4B` (`redesign.html:74`) — 1.272:1,
  /// still below any usable focus cue. No `vline`/verse widget exists in `lib/`
  /// yet, so there is nothing to fix here; the rule Phase 5 must honour when it
  /// builds `/reading` is a ≥3:1 distinction between in-view and out-of-view
  /// verses, never a single flattened colour.
  const EvaColors.light()
    : canvas = const Color(0xFFF0EEFF),
      surface = const Color(0xFFFFFFFF),
      raised = const Color(0xFFE8E4FF),
      ink = const Color(0xFF120E28),
      ink2 = const Color(0xFF5A5480),
      ink3 = const Color(0xFF9B97B8),
      line = const Color(0xFFD5D0EF),
      ember = const Color(0xFFD4891A),
      // Decision 153 — in **light** these are darker, and they are the whole reason the
      // tokens exist. `ember` has to stay light enough for `onEmber` to read on it as a
      // button fill, while the same hue has to be dark enough to read as *text* on a
      // pale surface. One value cannot do both: `ember` at 2.05:1 and a fill dark enough
      // for text would put `onEmber` at 2.70:1. So the roles get separate names, and
      // only this theme's values differ.
      emberInk = const Color(0xFF845610),
      okInk = const Color(0xFF146C52),
      errInk = const Color(0xFFB72626),
      emberDeep = const Color(0xFFB56C0C),
      onEmber = const Color(0xFF3A1E00),
      ok = const Color(0xFF1A8C6A),
      err = const Color(0xFFD63B3B),
      orbOpacity = 0.18,
      auroraOpacity = 0.10,
      glassFill = const Color(0x0A000000),
      glassBorder = const Color(0x14000000),
      glassShadow = const Color(0x1F120E28),
      seam = const Color(0xCC9A7B19),
      seamGlow = const Color(0x809A7B19),
      bloom = const Color(0x8CE457D6),
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

  /// The accent as **ink** — for text, meaningful glyphs and focus rings.
  ///
  /// ## WHY THIS IS A SEPARATE TOKEN AND NOT A DARKER `ember`
  ///
  /// Because `ember` does two jobs that pull in opposite directions, and the
  /// disagreement only appears in the light theme. As a **fill** it must stay light
  /// enough that `onEmber` reads on it: `EvaButton`'s whole label is `onEmber` on
  /// `ember`. As **text** on a pale surface it must be dark enough to clear 4.5:1, and
  /// in light `ember` measures **2.05:1** — which is the reader's own name in the
  /// greeting on `/`.
  ///
  /// There is no single value that does both. Darkening `ember` to reach the text floor
  /// gives `#8E5C11`, and `onEmber` (`#3A1E00`) on that is **2.70:1** — the button label
  /// becomes the illegible thing instead. That is not a tuning miss, it is two
  /// contradictory requirements on one token.
  ///
  /// So: **`ember` fills, `emberInk` writes.** In **dark** the two are the same value,
  /// because there the accent already clears 6.97:1 and nothing is being solved. In
  /// **light** they differ, and that difference is the fix.
  final Color emberInk;

  /// `ok` as ink — the same split as [emberInk], for "correct" text and glyphs.
  ///
  /// Light `ok` measures 3.39:1 as text, which reads as *dimmed* rather than *broken*,
  /// which is exactly why nobody caught it by eye.
  final Color okInk;

  /// `err` as ink — the same split as [emberInk], for error text and glyphs.
  ///
  /// Light `err` measures 3.73:1 as text: the error copy on `/login` and `/settings`,
  /// and the "both arms" state of every text field.
  final Color errInk;

  final Color glassFill;

  /// The glass panel's 1px rim.
  final Color glassBorder;

  /// The glass panel's ambient shadow. This is the design system's *only*
  /// shadow: see `eva_elevations.dart` for why every elevation is flat.
  final Color glassShadow;

  /// The `.hor` seam — the hairline of light that crosses a card at 20% of its
  /// height. `GlassTier.bloom`'s other half.
  ///
  /// `redesign.html:257` is `rgba(255,255,255,.85)` in dark, and
  /// `redesign.html:72` re-points it at `rgba(154,123,25,.8)` in light — the
  /// prototype's **gold** (`#9A7B19`, `redesign.html:58`'s `--gold`), not a white
  /// at a lower alpha. So this is two hues, not one value at two opacities, and
  /// [emberInk] is not the light value either: it is that hue at 53% rather than
  /// the 80% the gradient's centre stop declares.
  ///
  /// ## NOT A `03-design-system.md` §5.1 TOKEN
  ///
  /// §5.1 publishes fourteen per brightness and names no seam. This is
  /// transcribed from the redesign reference, which is the design source of truth
  /// for the surfaces that paint it.
  final Color seam;

  /// The seam's glow — `box-shadow:0 0 14px rgba(255,255,255,.6)` in dark and
  /// `0 0 12px rgba(154,123,25,.5)` in light (`redesign.html:257` / `:72`).
  ///
  /// **The two palettes' glow radii differ (14 and 12) and this widget ships 14
  /// in both**, because the radius is a `BoxShadow.blurRadius` on a
  /// `DecoratedBox` — a paint, not a colour — and a per-brightness *float* token
  /// for a 2px difference on a decorative glow would be a token this design
  /// system has no convention for. Stated rather than smoothed over: if a reader
  /// needs the light value, the right home is the widget's geometry constants,
  /// not this table.
  final Color seamGlow;

  /// The `.bloom` wash — the soft radial of colour that rises from a card's
  /// bottom edge. `redesign.html:254`'s `rgba(228,87,214,.55)`, which is also the
  /// `--bh` default and therefore the fallback for every host that does not set
  /// its own.
  ///
  /// ## WHY IT IS THE **SAME VALUE** IN BOTH PALETTES
  ///
  /// `redesign.html:73` dims every `.bloom` in light mode — `.hcard`, `.bcard`,
  /// `.medal` and `.podbar` alike — with `opacity:.55`, and never re-hues the
  /// `--bh` colour. A per-brightness value here would be a second copy of a
  /// decision the prototype makes with an opacity, and it would be a decision
  /// this client cannot take: the dimmer is **caller state**, so it belongs to
  /// whatever puts the wash on a card, not to a token or a tier member.
  /// `eva_colors_test.dart`'s shared-value inventory carries this as a named
  /// exception to "a shared token means one theme ships the wrong colour".
  ///
  /// ## AND WHY IT IS A TOKEN AT ALL, GIVEN THAT `--bh` IS PER-HOST
  ///
  /// Because a token for the *default* is not the same claim as a token for
  /// *every* value. `GlassSurface` reads [bloom] when its caller passes no
  /// `bloomColor`, and that default is what `redesign.html:254` writes in the
  /// `var()` fallback. The per-host values — 13 occurrences of `--bh` in
  /// `redesign.html`, none of them a global definition — are the caller's, and
  /// `glass_surface.dart` records why they cannot be a token table.
  final Color bloom;

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
    Color? emberInk,
    Color? okInk,
    Color? errInk,
    double? orbOpacity,
    double? auroraOpacity,
    Color? glassFill,
    Color? glassBorder,
    Color? glassShadow,
    Color? seam,
    Color? seamGlow,
    Color? bloom,
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
    emberInk: emberInk ?? this.emberInk,
    okInk: okInk ?? this.okInk,
    errInk: errInk ?? this.errInk,
    orbOpacity: orbOpacity ?? this.orbOpacity,
    auroraOpacity: auroraOpacity ?? this.auroraOpacity,
    glassFill: glassFill ?? this.glassFill,
    glassBorder: glassBorder ?? this.glassBorder,
    glassShadow: glassShadow ?? this.glassShadow,
    seam: seam ?? this.seam,
    seamGlow: seamGlow ?? this.seamGlow,
    bloom: bloom ?? this.bloom,
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
      // Decision 153 — the inks interpolate with the palette they belong to, so an
      // animated theme transition carries them rather than snapping at the end.
      emberInk: c(emberInk, other.emberInk),
      okInk: c(okInk, other.okInk),
      errInk: c(errInk, other.errInk),
      emberDeep: c(emberDeep, other.emberDeep),
      onEmber: c(onEmber, other.onEmber),
      ok: c(ok, other.ok),
      err: c(err, other.err),
      orbOpacity: d(orbOpacity, other.orbOpacity),
      auroraOpacity: d(auroraOpacity, other.auroraOpacity),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
      glassShadow: c(glassShadow, other.glassShadow),
      seam: c(seam, other.seam),
      seamGlow: c(seamGlow, other.seamGlow),
      bloom: c(bloom, other.bloom),
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
