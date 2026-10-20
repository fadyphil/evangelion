import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';

/// The streak flame that sits beside a day count.
///
/// ## THE PATH IS THE PROTOTYPE'S, CHARACTER FOR CHARACTER
///
/// `eva/src/components/ds.tsx:514` draws a `<svg viewBox="0 0 16 20">` with
/// one `<path>` and no other element. The `d` attribute is transcribed into
/// [flamePath] unchanged — every curve command, every coordinate. Re-deriving a
/// flame shape from a description would be a different flame.
///
/// **That citation is KEPT, and it now owns only the shape.** The redesign's
/// `.flame` is a *different* mark with the same job, and the two are cited
/// separately rather than merged: `ds.tsx:514` says what the flame **is**,
/// `redesign.html:242-244` says what it is lit like.
///
/// ## SIZE
///
/// [size] is the **height**, and the width follows the viewBox's `16:20` ratio,
/// so the whole box scales uniformly and the path cannot be distorted. The
/// prototype renders the svg at `width="14" height="18"`
/// (`ds.tsx:514`) — 0.778 of its height rather than the viewBox's 0.8. The 2%
/// difference is the viewBox's own horizontal padding (the path spans x 2…14 of
/// a 16-wide box), and scaling the box uniformly rather than reproducing the
/// element's pixel box is the choice that keeps the shape honest at any size.
///
/// ## THE GLOW — `redesign.html:243`, ADOPTED
///
/// `eva/redesign.html:243` ends `.flame` with
/// `box-shadow: 0 0 14px rgba(232,176,75,.85), 0 0 30px rgba(255,122,24,.35)`.
/// The **first** shadow is transcribed: a blurred copy of the silhouette in
/// [EvaColors.ember] at [flameGlowAlpha] with a Gaussian of [flameGlowSigma],
/// painted *underneath* the solid fill. `rgba(232,176,75, …)` is the prototype's
/// `--gold`, which §5.1 publishes as `ember`.
///
/// A CSS blur *radius* is two standard deviations, so a 14px radius is a sigma of
/// 7 — that division is the one arithmetic step between `:243`'s number and
/// [MaskFilter.blur]'s, and it is a division rather than a copy because copying
/// would give a 28px radius.
///
/// ## WHAT `:242-246` SAYS AND THIS WIDGET DOES **NOT** DO
///
/// Four things are declined, each for its own reason. None of them is a
/// transcription slip.
///
/// | `:242-246` | why it is not here |
/// | --- | --- |
/// | `width: 13px; height: 17px` | **The blob is not adopted; the box's HEIGHT is.** Phase 5.2's decision, and it is two halves rather than one. `:242-243` draws the flame as a `border-radius: 50% 50% 46% 46%/62% 62% 38% 38%` box — two radii per axis on a rounded rectangle, which is a *CSS shape* and not a path, and `ds.tsx:514`'s `<path>` is still the only flame outline in the prototype that is data. The **height** is adopted anyway, because the redesign's streak chip (`:516`) is the only place `.flame` is drawn (`:242` has two other mentions and both are selectors) and it is 17 tall, so `/`'s chip renders `StreakFlame(size: 17)`. The **width** is `17 × 16/20 = 13.6` where CSS says `13`: 0.6px, and the ratio is this viewBox's own. Reproducing `13` exactly would mean a `width` parameter and a 4.6% anisotropic stretch of the path, which is the distortion this widget's [aspect] doc declines at any size. `/result`'s card still asks for `size: 18` (`result_sheet.dart`), so `result_sheet_geometry_test.dart`'s `width ≤ 14.5` is untouched. |
/// | `rgba(255,122,24,.35)` at `0 0 30px` | **`#ff7a18` is not in the palette.** Publishing it — or substituting a token for it — is a Phase-2 palette decision, and a palette decision made inside a decorative widget is exactly the failure `eva_colors.dart`'s header forbids. Recorded here rather than added. |
/// | `radial-gradient(circle at 50% 78%, #fff 0%, --gold 42%, #ff7a18 72%, rgba(255,122,24,0) 100%)` | the same third stop, twice over: `rgba(255,122,24,0)` **is** `#ff7a18`, and `#fff 0%` has no token either. A half-adopted ramp — gold to nothing with the middle stop missing — is a different flame than either prototype, and it would take the readable silhouette with it; see the next section. |
/// | `@keyframes flick` (`:246`) and `.flame.burst`'s one-shot `flare` (`:245`) | **motion, not paint.** Task 4.2's Decision 5 scopes this batch to *paint only*, and a second ambient controller is barred twice over: §13.2 collapses the app's ambient motion to four shared clocks, and `NeuralBackground`'s orbs already spend them. `EvaMotion.achievementSpring`'s doc names `StreakFlame`'s flare as its own case — the **one-shot** `flare`, not the ambient `flick`. The one-shot belongs to "your streak went up", which is a moment this widget is not told about. |
///
/// ## WHY THE FILL STAYS A SOLID SILHOUETTE
///
/// The prototype's fill is a *gradient that fades to nothing at its own edge*, so
/// the flame's outline is only as visible as the gradient makes it. Here it is a
/// flat fill at full alpha under the glow — and the reason is not conservatism:
///
/// `streak_flame_test.dart`'s proof that [flamePath] was transcribed character for
/// character is a **pixel** measurement — it reads the painted bounds and asks
/// them to cover `12/16` of the box horizontally and all of it vertically, because
/// a path rescaled to fill its box measures `1.0` and `1.0`. With an outward
/// [flameGlowSigma] halo the ink reaches the box's corners, and with a
/// transparent-edged gradient there is **no alpha threshold anywhere that
/// separates the silhouette from the light around it** — at the path's own edge the
/// composite is the same whether the sample fell just inside or just outside.
///
/// Adopting the ramp would delete the only test that can see the transcription.
/// That is a worse outcome than a subtler flame, so the fill stays solid and the
/// glow is drawn around it. The glow and the ramp are separable: one is a shadow
/// on the element, the other is its background.
///
/// ## THE SIGMA SCALES WITH THE WIDGET, AND CSS'S DOES NOT
///
/// CSS's `14px` is an absolute length: a 13×17 element and a 130×170 element get
/// the same halo. [flameGlowSigma] is in **viewBox units**, and this painter
/// scales the canvas by the widget's size before drawing, so the halo grows with
/// the flame. That is the one deliberate difference, and it is this widget's
/// existing convention rather than a new one: [flamePath] is in viewBox units and
/// scales the same way, and a halo that stayed fixed while its silhouette doubled
/// would be a different mark at every size.
///
/// ## SEMANTICS
///
/// The flame is not decoration: it is the icon for a streak, and it sits next to
/// a number that means "days". It therefore carries a label, unlike
/// [SunBurst] or [GoldFlecks]. The default is English because Phase 2 has no
/// string table; Phase 3 and Phase 6 pass a localised one.
class StreakFlame extends StatelessWidget {
  /// A flame of [size] logical px tall, filled with `ember`.
  const StreakFlame({this.size = 18, this.semanticLabel = 'Streak', super.key});

  /// Height in logical px. Width is [size] × `16 / 20`.
  final double size;

  /// The accessible name. See the class doc for why this is not decoration.
  final String semanticLabel;

  /// The prototype's box width-to-height ratio, `viewBox="0 0 16 20"`.
  static const double aspect = 16 / 20;

  /// The width [size] implies.
  double get width => size * aspect;

  /// `redesign.html:243`'s glow radius — `0 0 14px rgba(232,176,75,.85)`.
  ///
  /// A CSS blur radius, kept as the prototype wrote it. [flameGlowSigma] is the
  /// number this painter draws with.
  static const double flameGlowBlur = 14;

  /// The Gaussian sigma [flameGlowBlur] denotes — `14 / 2 = 7`.
  ///
  /// CSS's `blur()` radius is defined as *twice* the standard deviation of the
  /// Gaussian (CSS Backgrounds 3 §3.3, "the resulting shadow edge is a standard
  /// deviation blur"), and [MaskFilter.blur] takes the standard deviation. In
  /// viewBox units, so the halo scales with [size]; see the class doc.
  static const double flameGlowSigma = flameGlowBlur / 2;

  /// The glow's alpha — `rgba(232,176,75,.85)` at `:243`.
  static const double flameGlowAlpha = 0.85;

  /// The alpha above which a pixel is the **solid fill** rather than the glow.
  ///
  /// ## THE THRESHOLD, MEASURED, AND WHY IT IS NOT A NUMBER ANYONE GUESSED
  ///
  /// The glow is the silhouette blurred by [flameGlowSigma] and drawn at
  /// [flameGlowAlpha], so **inside the widget's own box** — the only region a
  /// pixel test can read — the halo is a *tail*, not a halo. Measured over the
  /// whole box, and **the answer is not the same at both sizes**, which is what
  /// this paragraph used to get wrong:
  ///
  /// | size | box | brightest pixel **below** [flameSolidAlpha] | clearance |
  /// | --- | --- | --- | --- |
  /// | 20 | 16×20 | **0.2353** | 0.0147 |
  /// | 64 | 51×64 | **0.2431** | **0.0069** |
  ///
  /// **Why the two differ.** At `size: 20` the path leaves two units of gutter
  /// either side, so the outer columns are pure halo and the brightest of them is
  /// `0.1529`. At `size: 64` the flame is 51.2 logical px wide in a 51px box —
  /// **there is no gutter at all** — so the brightest pixel under the floor is one
  /// lying *against* the fill's antialiased edge, and it is higher.
  ///
  /// This doc used to say "the brightest halo pixel is `0.1529` **at both**". The
  /// `0.1529` is a `size: 20` **gutter** measurement, stated as a both-sizes fact
  /// about a quantity that is a different quantity at `size: 64` — the same shape
  /// as a citation that resolves and is about the wrong line.
  ///
  /// **And the 0.0069 is the real cost of not choosing `0.5`.** The floor clears
  /// the halo, but at `size: 64` by two thirds of one percent: raise
  /// [flameGlowAlpha] or [flameGlowBlur] far enough for the tail to cross `0.25`
  /// and every silhouette measurement in `streak_flame_test.dart` silently starts
  /// counting halo. That is why the constant sits next to both inputs rather than
  /// at a call site, and why the test that guards it asserts the **0.2431** figure
  /// rather than the older, looser `0.1529`.
  ///
  /// It is `0.25` and not the more obvious `0.5` because `0.5` is **not** safe
  /// here: measured at `size: 20`, a threshold of `0.5` clips the flame's apex —
  /// the top row is 19% alpha there — and the vertical ratio reads `0.95` rather
  /// than `1.0`. That failure is silent, a row late, and it is exactly what a
  /// threshold exists to prevent.
  ///
  /// Published rather than written at the call site because it is a property of
  /// [flameGlowAlpha] and [flameGlowBlur] **together**: raise either and the
  /// measurement above has to be taken again, which is why it sits next to both.
  static const double flameSolidAlpha = 0.25;

  @override
  Widget build(BuildContext context) {
    final EvaColors colors = context.colors;
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: size,
        child: CustomPaint(painter: _FlamePainter(colors.ember)),
      ),
    );
  }
}

/// The flame's outline, in the prototype's own viewBox units.
///
/// Transcribed from `ds.tsx:514`'s `d` attribute. Kept in viewBox units so the
/// painter can scale the canvas rather than rescale 40 numbers — a rescale is
/// where a transcription goes wrong.
///
/// Its bounds are `x 2…14`, `y 0…20` of the 16×20 viewBox, and
/// `streak_flame_test.dart` asserts that as a **literal** — which is a tighter
/// transcription pin than reading it back off the screen, because the screen
/// cannot say *which* numbers were intended.
final Path flamePath = Path()
  ..moveTo(8, 0)
  ..cubicTo(8, 0, 4, 5, 4, 9)
  ..cubicTo(4, 10.5, 4.5, 12, 6, 13)
  ..cubicTo(5.5, 11, 6.5, 9, 8, 8)
  ..cubicTo(9, 10, 9.5, 11, 9, 13)
  ..cubicTo(10.5, 12, 11, 10.5, 11, 9)
  ..cubicTo(11, 7, 10, 5, 10, 5)
  ..cubicTo(11.5, 6.5, 12, 9, 12, 11)
  ..cubicTo(12, 14.5, 10.5, 17, 8, 19)
  ..cubicTo(5.5, 17, 4, 14.5, 4, 11)
  ..cubicTo(4, 10.5, 4.05, 10, 4.1, 9.5)
  ..cubicTo(2.5, 11, 2, 13, 2, 15)
  ..cubicTo(2, 17.8, 4.7, 20, 8, 20)
  ..cubicTo(11.3, 20, 14, 17.8, 14, 15)
  ..cubicTo(14, 10, 8, 0, 8, 0)
  ..close();

class _FlamePainter extends CustomPainter {
  const _FlamePainter(this.color);

  /// The silhouette's own fill — §5.1's `ember`, which is `--gold`.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 20);

    // ## THE GLOW FIRST, AND IT IS **NOT** A `BoxShadow`
    //
    // `redesign.html:243`'s `box-shadow` is a shadow of the *border box*; with a
    // `border-radius` that is a shadow of the rounded box. What this widget has is
    // a path, so the faithful spelling is a blurred copy of the **path** — which
    // is what `MaskFilter` does: it replaces the geometry with a blurred version
    // and fills it with the paint's colour, so no second path is built and no
    // `saveLayer` is taken. §13.4's budget is spent on `BackdropFilter`s, which
    // read back the frame; this reads nothing.
    //
    // Drawn *before* the fill so the fill sits on top, exactly as a CSS
    // `box-shadow` sits behind its element's own background.
    canvas.drawPath(
      flamePath,
      Paint()
        ..color = color.withValues(alpha: StreakFlame.flameGlowAlpha)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          StreakFlame.flameGlowSigma,
        ),
    );

    canvas.drawPath(flamePath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.color != color;
}
