import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The "E" seal — the wordmark mark beside the Login wordmark and on the FAB.
///
/// ## TWO PROTOTYPE MARKS, AND WHICH ONE OWNS WHICH HALF
///
/// The redesign has **two** circular ember marks and they are not the same mark.
/// `.lmark` (`:370-371`) is the **wordmark** — `EVANGELION` in 800 weight with a
/// blurred `::after` wash behind it — and it is what `/login` draws today
/// (`:504`). `.jorb` (`:392-395`) is the **orb**: 74px, a 30px scripture glyph in
/// `#1c1608`, a 34px glow, and a 1.5px rim — the Journey profile's avatar, which
/// at `:586` is `<div class="jorb">M</div>`.
///
/// This widget is the orb's counterpart, so `:392-395` owns the **treatment**:
/// the wash's centre ([sealGlowCenter]) and the glyph's ink
/// ([EvaColors.onEmber]). The superseded prototype's own login seal still owns
/// **`defaultSize = 60`** — a value **the redesign has no counterpart for**,
/// because its `/login` draws no seal at all — and that is a recorded divergence
/// rather than an oversight — see below.
///
/// ## WHAT IS ADOPTED FROM `:392-395`, AND WHAT IS NOT
///
/// | `.jorb` | here | |
/// | --- | --- | --- |
/// | `circle at 35% 30%` (`:393`) | [sealGlowCenter] | **adopted** |
/// | `color: #1c1608` (`:394`) | [EvaColors.onEmber] | **adopted** — the same role `.cta`'s own `#1c1608` has (`:387`) |
/// | `width/height: 74` (`:392`) | [defaultSize] = 60 | **not adopted** — see below |
/// | `radial-gradient(circle at 35% 30%, rgba(255,255,255,.5), rgba(232,176,75,.85) 50%, #8a6417 90%)` (`:393`) | [sealGlowAlpha] → [EvaColors.ember] → 0 | **not adopted** — two of its three stops are not tokens |
/// | `box-shadow: 0 0 34px rgba(232,176,75,.5)` (`:394`) | the two 40/80 `BoxShadow`s from the prototype's own login seal | kept — the orb has one shadow, this widget has the old pair |
/// | `font-size: 30px` at 74px wide (`:394`) | 28px at 60px, [glyphRatio] | kept — see below |
///
/// **The size.** `:392` is `width: 74px`. **This widget stays at 60**, and the
/// reason is a harness, not a preference: `login_geometry_test.dart` asserts the
/// **painted** `SealMonogram` is 60×60, by literal and with a comment saying it
/// must not be compared to `defaultSize` (change both and the assertion stays
/// green). 74 is the orb's number *in a screen that does not exist* — the
/// redesign's `/login` (`:503-511`) draws `.lmark` + `.field` + `.cta` and **no
/// seal at all**, and the seal survives only as the Journey orb's counterpart.
/// Resizing to match a mark on a screen that was cut is Phase 5.6's number, not
/// this widget's.
///
/// **The wash's ramp.** `:393`'s three-stop `radial-gradient` starts at `rgba(255,255,255,.5)`
/// and ends at `#8a6417`. Neither end is a token, and a three-stop wash whose two
/// outer stops are un-tokenised is a **palette** decision — the same one that
/// blocked `.flame`'s `#ff7a18` in `streak_flame.dart`. What `:393` contributes
/// unambiguously is the **centre**, and the centre is what this widget adopts.
/// The ramp's shape (peak → nothing at [sealGlowStop]) is the `.lmark::after`
/// wash's (`rgba(232,176,75,.28)` → `transparent 70%`), which is why `:370-371`
/// is cited here at all: it is the closest ember wash the redesign has, and this
/// widget's peak alpha ([sealGlowAlpha]) sits between its `.28` and `.jorb`'s
/// `.85`. The `ellipse` geometry and the `filter: blur(10px)` are **not**
/// adopted — a Flutter widget has no `::after` and no pseudo-element to blur.
///
/// **The glyph's size.** `:394` is `font-size: 30px` on a 74px orb — a ratio of
/// 0.405. This widget's 28px on 60px is 0.4667, which is the prototype's own
/// login seal's ratio.
/// Two different marks at two different sizes have two different ratios, and
/// changing the ratio would move the glyph inside a box the login harness holds
/// at 60.
///
/// ## THE GLOW IS NOT AN ELEVATION
///
/// [AGENT_CONTEXT] §9 decision 7: the prototype has no z-axis, and every
/// `box-shadow` in it is either a zero-offset ember glow or the single glass
/// ambient. These are the first kind — a zero-offset glow with no spread and no
/// direction — and they are why `EvaElevations` can still be all zeros. Every
/// elevation-bearing `ThemeData` field stays `0`.
///
/// ## SEMANTICS
///
/// Not decoration: it is the app's mark and it stands where a logo would. It gets
/// [semanticLabel] and drops its own subtree, so the "E" glyph is read as the
/// mark rather than as the letter E on its own.
class SealMonogram extends StatelessWidget {
  /// A seal of [size] logical px, optionally with a different [letter].
  const SealMonogram({
    this.size = defaultSize,
    this.letter = 'E',
    this.semanticLabel = 'Evangelion',
    super.key,
  });

  /// The prototype's own login seal — `width: 60, height: 60` — and **the
  /// redesign has no counterpart for it**: its `/login` draws no seal at all.
  ///
  /// ## KEPT, AND IT IS A RECORDED DIVERGENCE FROM `:392`
  ///
  /// `eva/redesign.html:392` writes `width: 74px; height: 74px` — but 74 is the
  /// **orb's** size on the **Journey** screen, and the redesign's `/login`
  /// (`:503-511`) draws no orb at all. `login_geometry_test.dart` asserts the
  /// painted seal is `60` by literal, precisely so that this constant and the
  /// assertion cannot drift together. Resizing is Phase 5.6's decision; see the
  /// class doc.
  static const double defaultSize = 60;

  /// Diameter in logical px.
  final double size;

  /// The glyph in the middle. The prototype's is `E`.
  final String letter;

  /// The accessible name for the mark.
  final String semanticLabel;

  /// The radial wash's peak alpha — `.lmark::after`'s `rgba(232,176,75,.28)`
  /// softened toward the old `${ember}33`.
  ///
  /// **Named as a value between two prototypes' numbers, not as either of
  /// them.** `.lmark::after` (`eva/redesign.html:371`) peaks at `.28` and
  /// `.jorb` (`:393`) at `.85`; the transcription this widget replaced peaked at
  /// `0.2`. It stays where it was because the wash's *ramp* was not adopted — see
  /// the class doc — and moving one end of a gradient without the other produces
  /// a wash that is neither.
  static const double sealGlowAlpha = 0.2;

  /// Where the wash starts — **`circle at 35% 30%`**, `eva/redesign.html:393`.
  ///
  /// 35% from the left, **30% from the top**. The `y` moved: the wash used to
  /// sit at `35% 35%` and `.jorb` raises its centre by five points, which is the
  /// whole paint change this widget takes from `:393`.
  ///
  /// Flutter's [Alignment] measures both axes from the **top** — `Alignment(-1, -1)`
  /// is `topLeft` — so the conversion is `fraction-from-the-top × 2 - 1`, and
  /// `0.35` gives `-0.3` while `0.30` gives `-0.4`. An earlier version of this
  /// doc said `y` is measured "from the bottom", which contradicts the value on
  /// the next line and would move the wash to the bottom-left for a maintainer
  /// who believed it. Same arithmetic as the orbs' [kOrbGradientCenter]; both are
  /// wrong in the same way in review comments and right in the value.
  static const Alignment sealGlowCenter = Alignment(-0.3, -0.4);

  /// Where the wash ends, `transparent 70%` — `.lmark::after` at `:371`.
  ///
  /// ## THE UNITS DO NOT MATCH CSS'S, AND IT IS HARMLESS ONLY BY ACCIDENT
  ///
  /// A CSS radial-gradient stop is a fraction of the gradient **ray** — with the
  /// default `farthest-corner`, `0.70` here is `0.70 × 0.65 × √2 ≈ 0.643` of the
  /// seal's width. Flutter's `RadialGradient.radius` is a fraction of the
  /// **shortest side** instead, so passing `0.7` straight through fades out at
  /// 0.7 × size rather than 0.643 × size.
  ///
  /// [kOrbGradientRadius] is the converted value, and `neural_orbs.dart` carries
  /// the long version of why the conversion matters: copy CSS's number across and
  /// the fade never finishes inside the box, leaving every corner tinted. Here it
  /// does not, and the reason is in the next sentence.
  static const double sealGlowStop = 0.7;

  /// The rim's alpha — the prototype's `${ember}66`.
  static const double sealBorderAlpha = 0.4;

  /// The rim's width, `1.5px solid`.
  static const double sealBorderWidth = 1.5;

  /// The glyph's em size as a fraction of the seal's diameter — `0.4667`.
  ///
  /// The prototype's 28 on a 60px seal. **Not** `:394`'s 0.405 (30 on
  /// 74): those are two marks at two sizes, and the seal's box is held at 60 by
  /// `login_geometry_test.dart`. See the class doc.
  static const double glyphRatio = 0.4667;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    final Color ember = colors.ember;

    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: sealGlowCenter,
            radius: sealGlowStop,
            colors: <Color>[
              ember.withValues(alpha: sealGlowAlpha),
              ember.withValues(alpha: 0),
            ],
          ),
          border: Border.all(
            color: ember.withValues(alpha: sealBorderAlpha),
            width: sealBorderWidth,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: ember.withValues(alpha: 0.267), blurRadius: 40),
            BoxShadow(color: ember.withValues(alpha: 0.133), blurRadius: 80),
          ],
        ),
        alignment: Alignment.center,
        // The prototype's `fontSize: 28` is absolute while the seal is
        // `size`-parameterised here, so the glyph scales with the seal — see
        // [glyphRatio], which is where the number and its reason live.
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: EvaTypography.displayFamily,
            fontSize: size * glyphRatio,
            fontWeight: FontWeight.w600,
            // `eva/redesign.html:394` — `color: #1c1608`, the ink a **gold** mark
            // writes in. Decision 153's split names the two halves of that
            // sentence: gold *fills*, `onEmber` *writes*. This widget is a gold
            // disc with a letter on it, so it is the writing half, and `onEmber`
            // is the token that role already has — the same ink
            // `EvaButton.primary` writes from `:387`'s own `color: #1c1608`.
            //
            // This used to be `ember` — the same token as the wash two lines up.
            // On the **light** palette that is `#D4891A` inside an ember wash:
            // 2.0:1. That was a legibility defect rather than a restyle, and the
            // fix is the same one `EvaButton.primary` made in Batch C.
            color: colors.onEmber,
          ),
        ),
      ),
    );
  }
}
