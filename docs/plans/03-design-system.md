# Design System

Tokens, typography, spacing, motion, and the `EvaColors` theme extension that replaces the prototype’s dual source of truth.

**Contains §5** of the original plan. Section numbers are preserved so existing cross-references keep resolving.

> [Index](README.md) · [Widget inventory](04-widget-inventory.md)

---

## 5. Design system

### 5.1 Tokens

Source of truth = the built React code (`HEX` in `ds.tsx`, mirrored in `index.css`).

**Dark**

| Token | Value | Replaces |
| --- | --- | --- |
| `canvas` | `#05081A` | `--canvas` |
| `surface` | `#0D1224` | `--surface` |
| `raised` | `#141A2E` | `--raised` |
| `ink` | `#EAE8F5` | `--ink` |
| `ink2` | `#8A8FAD` | `--ink2` |
| `ink3` | `#424669` | `--ink3` |
| `line` | `#1C2238` | `--line` |
| `ember` | `#E8A33D` | `--ember` |
| `emberDeep` | `#C77F1F` | `--ember-deep` |
| `onEmber` | `#0D0A04` | `--on-ember` |
| `ok` | `#4ECCA3` | `--ok` |
| `err` | `#FF6B6B` | `--err` |
| `orbOpacity` | `0.55` | `--orb-opacity` (was dead — wire it) |
| `auroraOpacity` | `0.18` | `--aurora-opacity` (was dead — wire it) |

**Light**

| Token | Value |
| --- | --- |
| `canvas` | `#F0EEFF` |
| `surface` | `#FFFFFF` |
| `raised` | `#E8E4FF` |
| `ink` | `#120E28` |
| `ink2` | `#5A5480` |
| `ink3` | `#9B97B8` |
| `line` | `#D5D0EF` |
| `ember` | `#D4891A` |
| `emberDeep` | `#B56C0C` |
| `onEmber` | `#FFF8EE` |
| `ok` | `#1A8C6A` |
| `err` | `#D63B3B` |
| `orbOpacity` | `0.18` |
| `auroraOpacity` | `0.10` |

**Sticker palette** (decorative only — chips, dots, celebration): `sky #7CC4F0` · `lavender #B79CF0` · `pink #F58FC4` · `coral #F4836B` · `teal #4EC9BD` · `leaf #7FC96B` · `sun #F5C84C`

**All 12 tokens ship.** The 7 dead tokens ([01-source-analysis.md](01-source-analysis.md) §2 #4) are wired to their real consumers rather than deleted — `surface`/`raised` become the base layers of `GlassSurface`; `line` becomes the hairline colour; `onEmber` becomes `EvaButton.primary`'s foreground; `emberDeep` is the pressed fill; `ok`/`err` are the quiz/feedback semantic pair.

### 5.2 Typography

Five families, mapped to `TextTheme` slots plus scripture-specific styles (scripture has no Material slot).

| Role | Family | Source |
| --- | --- | --- |
| `display` | Cormorant Garamond 400/500/600/700 + italics | `F.display` |
| `scripture` | EB Garamond 400/500 + italic | `F.scripture` |
| `arabic` | Amiri 400/700 + italic | `F.arabic` |
| `ui` | DM Sans 300–800 + italics | `F.ui` |
| `mono` | Space Mono 400/700 + italic | `F.mono` |

Wire via `google_fonts` (`GoogleFonts.cormorantGaramondTextTheme` etc.) with fonts bundled at build time so first paint is not blocked on a network fetch.

**Font-size steps** map the Settings slider (`1..5`) onto a `TextScaler`:

```dart
TextScaler evaScalerFor(int step) => switch (step) {
  1 => const TextScaler.linear(0.90),
  2 => const TextScaler.linear(0.95),
  3 => const TextScaler.linear(1.00),
  4 => const TextScaler.linear(1.10),
  _ => const TextScaler.linear(1.22),
};
```

**Glyph-coverage guard (fixes #2):** `mono` must never be applied to Arabic. Assert this in a widget test — see [[09-quality-gates.md](09-quality-gates.md) §11](09-quality-gates.md#11-test-strategy).

### 5.3 Spacing, radii, motion

- **Spacing (4px base):** `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40` → `EvaSpacing.xs/sm/md/lg/xl/xxl/xxxl/huge`. Screen horizontal padding = 20; card padding = 20.
- **Radii:** buttons `14` · inputs `14` · cards `18` · quiz options `18` · chips `999` (`Radius.circular(999)`) · hero panel `24` · glass form `28`
- **Motion** (`EvaMotion`):

| Token | Duration | Curve |
| --- | --- | --- |
| `fast` | 150ms | `easeOut` |
| `base` | 200ms | `easeOut` |
| `screen` | 250ms | `easeOutCubic` |
| `fleck` | 2000ms | `alternate` |
| `orbFloat` | 14–28s per orb | `easeInOut` |
| `orbHue` | 7–14s per orb | `linear` |
| `aurora` | 14s | `easeInOut` |

All curves are ease-out. No bounce, no spring — matching the brief's motion rule.

### 5.4 Token access

```dart
// lib/core/design_system/tokens/eva_colors.dart
@immutable
class EvaColors extends ThemeExtension<EvaColors> {
  const EvaColors({
    required this.canvas, required this.surface, required this.raised,
    required this.ink, required this.ink2, required this.ink3, required this.line,
    required this.ember, required this.emberDeep, required this.onEmber,
    required this.ok, required this.err,
    required this.orbOpacity, required this.auroraOpacity,
    required this.glassFill, required this.glassBorder,
    required this.glassShadow, required this.sticker,
  });

  final Color canvas, surface, raised, ink, ink2, ink3, line;
  final Color ember, emberDeep, onEmber, ok, err;
  final double orbOpacity, auroraOpacity;
  final Color glassFill, glassBorder, glassShadow;
  final Map<StickerSlot, Color> sticker;

  @override
  EvaColors copyWith({
    Color? canvas, Color? surface, Color? raised,
    Color? ink, Color? ink2, Color? ink3, Color? line,
    Color? ember, Color? emberDeep, Color? onEmber,
    Color? ok, Color? err,
    double? orbOpacity, double? auroraOpacity,
    Color? glassFill, Color? glassBorder, Color? glassShadow,
    Map<StickerSlot, Color>? sticker,
  }) => EvaColors(
    canvas: canvas ?? this.canvas, surface: surface ?? this.surface,
    raised: raised ?? this.raised, ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2, ink3: ink3 ?? this.ink3,
    line: line ?? this.line, ember: ember ?? this.ember,
    emberDeep: emberDeep ?? this.emberDeep,
    onEmber: onEmber ?? this.onEmber, ok: ok ?? this.ok,
    err: err ?? this.err, orbOpacity: orbOpacity ?? this.orbOpacity,
    auroraOpacity: auroraOpacity ?? this.auroraOpacity,
    glassFill: glassFill ?? this.glassFill,
    glassBorder: glassBorder ?? this.glassBorder,
    glassShadow: glassShadow ?? this.glassShadow,
    sticker: sticker ?? this.sticker,
  );

  @override
  EvaColors lerp(EvaColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return EvaColors(
      canvas: c(canvas, other.canvas), surface: c(surface, other.surface),
      raised: c(raised, other.raised), ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2), ink3: c(ink3, other.ink3),
      line: c(line, other.line), ember: c(ember, other.ember),
      emberDeep: c(emberDeep, other.emberDeep),
      onEmber: c(onEmber, other.onEmber), ok: c(ok, other.ok),
      err: c(err, other.err),
      orbOpacity: d(orbOpacity, other.orbOpacity),
      auroraOpacity: d(auroraOpacity, other.auroraOpacity),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
      glassShadow: c(glassShadow, other.glassShadow),
      sticker: {
        for (final slot in StickerSlot.values)
          slot: c(sticker[slot]!, other.sticker[slot]!),
      },
    );
  }
}

extension EvaColorsX on BuildContext {
  EvaColors get colors => Theme.of(this).extension<EvaColors>()!;
}
```

`glassFill` / `glassBorder` / `glassShadow` are the three values the React prototype recomputes inline in 10 places:

- dark: fill `Color(0x0DFFFFFF)` (≈`rgba(255,255,255,0.05)`) · border `Color(0x14FFFFFF)` (≈`0.08`) · shadow `Color(0x59000000)` (≈`0.35`)
- light: fill `Color(0x0A000000)` (≈`rgba(0,0,0,0.03)`) · border `Color(0x14000000)` (≈`0.07`) · shadow `Color(0x1F120E28)` (≈`rgba(18,14,40,0.12)`, `ProfileScreen.tsx:15`)

The light shadow colour is `#120E28` — the built code's light `ink`. Do **not** substitute the brief's `#221C15`; that value belongs to the discarded warm-paper palette ([01-source-analysis.md](01-source-analysis.md) [01-source-analysis.md](01-source-analysis.md) §1.2).

`sticker` is a `Map<StickerSlot, Color>` rather than free-floating hex so a slot → colour lookup is a type-checked read. `StickerSlot` is **decorative only** — the category enum it was keyed to was cut with the library ([AGENT_CONTEXT](../agents/AGENT_CONTEXT.md) §2, decision 1), and nothing in `domain/` refers to it. Its seven slots serve chips, dots, and the celebration burst.

---
