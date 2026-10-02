import 'package:evangelion/core/design_system/effects/hue_rotate_matrix.dart';
import 'package:evangelion/core/design_system/effects/neural_motion.dart';
import 'package:evangelion/core/design_system/effects/neural_orbs.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:flutter/material.dart';

/// Which screen's ambient background to paint.
///
/// The seven shipped routes. **Not** an index into [OrbGroup] and never to be
/// treated as one — see [orbGroupFor] for the off-by-one that makes it unsafe.
enum NeuralVariant {
  /// `/login`.
  login,

  /// `/` — Home.
  home,

  /// `/reading` in English. Different from the Arabic arm because the prototype
  /// draws a different orb group for each: English opens blue (`ds.tsx:79`) and
  /// has no cyan orb at all.
  readingEn,

  /// `/reading` in Arabic. Opens violet and pairs it with cyan (`ds.tsx:83-84`).
  readingAr,

  /// `/quiz`.
  quiz,

  /// `/result` — the only warm group.
  result,

  /// `/settings`.
  settings,
}

/// How much of the background a device can afford.
///
/// Resolved by [NeuralTiers.resolve] and injectable per call site for tests.
enum NeuralTier {
  /// Aurora, orbs, hue cycling, float and parallax all live.
  high,

  /// Everything [high] draws. Resolved for an ordinary phone viewport.
  mid,

  /// No orbs, no aurora — the canvas and nothing else.
  ///
  /// ## WHY `low` IS "NOTHING" AND NOT "AURORA ONLY"
  ///
  /// `09-quality-gates.md` §13.4 says "drops to `low` on low-end devices: no
  /// orbs, aurora only, at 30% cost". The Tier-2 annotation in
  /// `04-widget-inventory.md` says "low disables orbs + aurora entirely". The
  /// two cannot both hold, and **this implementation follows the inventory and
  /// the Phase-2 task brief**, which agree with each other: `low` is the
  /// canvas. The aurora band is two full-viewport gradient repaints — the
  /// genuinely expensive part of the background — so "aurora only" is not 30%
  /// cost, it is most of it.
  ///
  /// Flagged rather than quietly resolved: §13.4's prose is wrong on this point
  /// and belongs to whoever owns `docs/plans/`.
  low,
}

/// The shortest viewport side, in logical px, below which the tier drops.
///
/// §13.4 says the tier is "derived from `MediaQuery` size and platform frame
/// budget" but names no threshold, so one was chosen. 360dp is the narrowest
/// Android phone width still supported. On such a screen several `ORB_CONFIGS`
/// orbs sit at absolute offsets (`y: 640`) that are entirely off-viewport, so
/// the budget spent animating them buys nothing visible.
const double kNarrowViewport = 360;

/// The shortest viewport side at or above which the tier is [NeuralTier.high].
///
/// The largest orb is 500px across and the furthest offset is `y: 640`
/// (`ds.tsx:74`, `:77`), so a viewport shorter than 640 cannot show a Home orb
/// whole. Above it, the absolute offsets were authored to be seen.
const double kWideViewport = 640;

/// Resolves a [NeuralTier] from what is knowable synchronously.
///
/// ## WHY A PURE FUNCTION AND NOT A DEVICE-TIER SERVICE
///
/// The prototype's low/mid/high came from a "platform frame budget" — a
/// *measured* frame time. Flutter exposes no synchronous frame-timing API, so a
/// service claiming to know would either be lying or reading a stale budget,
/// and a background that repaints itself when a measurement lands is precisely
/// the per-frame churn §13 exists to remove. The two inputs that *are*
/// synchronous — viewport size and the user's animation preference — are the
/// real ones. A later phase that measures frames passes its verdict in as
/// [resolve]'s `override`; nothing here has to change.
abstract final class NeuralTiers {
  /// Resolves the tier for a viewport of [size].
  ///
  /// [override] replaces the *size* decision and nothing else. That is the
  /// injection seam: the goldens and the tier tests pass a tier rather than
  /// arranging a viewport that happens to resolve to the one under test, so a
  /// test never has to reason about device geometry to prove something about
  /// `low`.
  ///
  /// ## REDUCED MOTION IS NOT A TIE-BREAK, IT IS THE LAST WORD
  ///
  /// `animationsEnabled` is `!MediaQuery.disableAnimationsOf(context)`. A reader
  /// who has told the platform to reduce motion gets [NeuralTier.low] whatever
  /// the size says **and whatever [override] says** — including `high`. An
  /// ambient background that drifts forever is the loudest possible violation of
  /// that request, and there is no control anywhere in the UI the reader could
  /// find to stop it, so the only safe place to enforce it is here, at the layer
  /// that owns every animated layer at once. §14's "every animation checks
  /// `MediaQuery.disableAnimationsOf(context)`", applied once instead of eight
  /// times.
  ///
  /// The asymmetry is deliberate and is why `override` is documented as a *cost*
  /// override: the cost budget belongs to the application, the accessibility
  /// budget belongs to the reader.
  static NeuralTier resolve({
    required Size size,
    required bool animationsEnabled,
    NeuralTier? override,
  }) {
    final NeuralTier cost = override ?? _forSize(size);
    if (!animationsEnabled) return NeuralTier.low;
    return cost;
  }

  /// The viewport rule alone, with no accessibility input.
  static NeuralTier _forSize(Size size) {
    final double shortestSide = size.shortestSide;
    if (shortestSide < kNarrowViewport) return NeuralTier.low;
    if (shortestSide < kWideViewport) return NeuralTier.mid;
    return NeuralTier.high;
  }
}

/// The [OrbGroup] behind [variant].
///
/// ## D2 — WHY NOT `variant.index`
///
/// `ORB_CONFIGS` has **eight** groups and [NeuralVariant] has **seven** values,
/// because index 6 is the Profile screen and Profile was cut ([AGENT_CONTEXT] §2,
/// decision 1). `variant.index` therefore hands `settings` — the last enum
/// value, `index == 6` — the **Profile** group: `/settings` would get the
/// `#14B8A6 / #3B5BDB` teal-and-blue pair instead of its own `#6C3FE8 / #06B6D4`
/// violet-and-cyan.
///
/// Nothing about that is visible. Both are plausible dark-background orb sets;
/// the screen still looks deliberate; no golden would fail, because the golden
/// would faithfully capture the wrong orbs. It is wrong only on paper, which is
/// why the mapping is an exhaustive `switch` — a new variant is a *compile error*
/// until it names a group — and why `neural_orbs_test.dart` asserts all seven
/// colour sequences by name.
///
/// There is no cast and no ordinal arithmetic here at all. `OrbGroup` and
/// `NeuralVariant` are deliberately different enumerations: collapsing them
/// would make `variant.index` *compile*, and a compiling wrong answer is the
/// most expensive kind.
OrbGroup orbGroupFor(NeuralVariant variant) => switch (variant) {
  NeuralVariant.login => OrbGroup.login,
  NeuralVariant.home => OrbGroup.home,
  NeuralVariant.readingEn => OrbGroup.readingEn,
  NeuralVariant.readingAr => OrbGroup.readingAr,
  NeuralVariant.quiz => OrbGroup.quiz,
  NeuralVariant.result => OrbGroup.result,
  // `ORB_CONFIGS[7]` — NOT `[6]`. Index 6 is Profile.
  NeuralVariant.settings => OrbGroup.settings,
};

/// [variant]'s orbs, in paint order.
List<OrbSpec> orbsFor(NeuralVariant variant) =>
    orbGroups[orbGroupFor(variant)]!;

/// The identity layer behind every screen.
///
/// A [CustomPaint] inside a [RepaintBoundary], driven by the three shared
/// controllers in [NeuralMotionScope].
///
/// ## THE FIVE MITIGATIONS OF §13, AND WHERE EACH ONE LIVES
///
/// 1. **No `setState` per frame.** This is a [StatelessWidget]; it has no state
///    to set. The motion lives in [EvaNeuralMotion], so the animation cannot
///    reach this class's `build` at all — it reaches its *painter*, via
///    [ListenableBuilder] and via `CustomPainter.repaint`.
///    `neural_background_test.dart` proves it by comparing widget-instance
///    identity across pumped frames rather than by checking that nothing threw.
/// 2. **Shared controllers, not per-orb.** [NeuralMotionScope]. See that class's
///    doc, and its D3 note for what happened to `floatDur` / `hueDur`.
/// 3. **`hue-rotate` without `ImageFilter`.** [hueRotateFilter] over a radial
///    gradient whose wide transparent stop replaces the prototype's 72px blur.
/// 4. **`BackdropFilter` budget.** Not this widget's concern — that is
///    `GlassSurface`, which owns the enum.
/// 5. **Lists.** No list ships here; the orbs are a fixed 2–4 per variant.
///
/// ## WHY THE MOTION IS NOT A PARAMETER
///
/// §13.2: "they live in a single `StatefulWidget` mounted above
/// `MaterialApp.router` … not looked up from `BuildContext` inside each
/// `NeuralBackground`". So this reads [NeuralMotionScope.of] and no call site
/// ever threads a controller through. The interface stays at `variant` plus the
/// test seam [tier], which is what lets a screen swap variants without knowing
/// anything about animation.
///
/// ## [tier]
///
/// The only optional field, and it exists so a test can ask for [NeuralTier.low]
/// without arranging a viewport, and so a future device-tier setting has
/// somewhere to go. `null` means [NeuralTiers.resolve]'s answer for this
/// context.
class NeuralBackground extends StatelessWidget {
  /// Paints the ambient background for [variant].
  const NeuralBackground({required this.variant, this.tier, super.key});

  /// Which screen's orb group and aurora tint to paint.
  final NeuralVariant variant;

  /// Forces a tier instead of resolving one. `null` resolves.
  final NeuralTier? tier;

  @override
  Widget build(BuildContext context) {
    final EvaNeuralMotion motion = NeuralMotionScope.of(context);
    final NeuralTier resolved = NeuralTiers.resolve(
      size: MediaQuery.sizeOf(context),
      animationsEnabled:
          !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
      override: tier,
    );

    void trackPointer(PointerEvent event) {
      final Size? size = context.size;
      // A widget can legitimately have no size yet, and dividing by a zero width
      // would put a NaN into the pointer offset — which then propagates into
      // every orb's transform, silently.
      if (size == null || size.isEmpty) return;
      motion.pointer.value = pointerOffsetFor(
        size: size,
        local: event.localPosition,
      );
    }

    return RepaintBoundary(
      // The boundary is what makes "the page above never rebuilds" true rather
      // than merely intended: the background's per-frame damage stops here
      // instead of dirtying whatever is painted over it.
      child: Listener(
        // `parallax` made live. `ds.tsx:126-137` registers **two** window
        // listeners — `mousemove` and `touchmove` — and both have to be here.
        //
        // `onPointerMove` alone is not enough, and the difference is invisible
        // until you look for it: Flutter routes an un-pressed mouse move to
        // `PointerHoverEvent`, which `Listener` delivers to `onPointerHover` and
        // NOT to `onPointerMove`. With `onPointerMove` only, `parallax` is dead
        // on exactly the platform it was written for — a desktop Linux build —
        // and alive only while the pointer is dragging. The parallax assertion in
        // `neural_background_test.dart` caught this by reading the pointer
        // offset directly, after a pixel comparison had passed with the pointer
        // never moving at all.
        //
        // The handler takes a `PointerEvent`, not a `PointerMoveEvent`, because
        // that is the only supertype both routes share.
        onPointerHover: trackPointer,
        onPointerMove: trackPointer,
        child: ListenableBuilder(
          // §13.1's structure, with the one thing that reference was missing:
          // this listenable actually notifies, because [EvaNeuralMotion]
          // subscribes to the three controllers and forwards. See D1.
          listenable: motion.repaint,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _NeuralPainter(
              variant: variant,
              tier: resolved,
              brightness: Theme.of(context).brightness,
              motion: motion,
              colors: context.colors,
            ),
            isComplex: true,
            willChange: resolved != NeuralTier.low,
          ),
        ),
      ),
    );
  }
}

/// The aurora clock's `0 → 1 → 0` triangle wave, `index.css:79-81`.
///
/// Named rather than inlined because it is used for **two** independent things —
/// the band's opacity pulse and its vertical slide — and a reader who has to
/// re-derive `1 - |2t - 1|` at each use site cannot check that the two agree.
///
/// `clock` is taken modulo 1 inside, so a caller never has to.
double auroraPulse(double clock) =>
    1 - (2 * (clock % 1.0) - 1).abs().clamp(0.0, 1.0);

/// Paints the aurora band, the orbs, and nothing else.
class _NeuralPainter extends CustomPainter {
  _NeuralPainter({
    required this.variant,
    required this.tier,
    required this.brightness,
    required this.motion,
    required this.colors,
  }) : super(repaint: motion.repaint);

  final NeuralVariant variant;
  final NeuralTier tier;
  final Brightness brightness;
  final EvaNeuralMotion motion;
  final EvaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // The canvas is painted at EVERY tier, not only `low`.
    //
    // The prototype gets its backdrop from the screen root's
    // `background: T.canvas` and leaves the background layer transparent
    // (`ds.tsx:168` — the container has no background of its own). A Flutter
    // `CustomPaint` has no such backdrop, so an unfilled painter is transparent
    // and the layer composites over whatever the caller happens to have put
    // underneath. Two consequences, and the second is the one that bit:
    //
    //  1. the widget is not self-contained, so a golden captures the harness's
    //     backdrop rather than the design;
    //  2. `NeuralTier.low` would be the *only* tier that paints anything, which
    //     is a very strange thing for the cheapest tier to be the only complete
    //     one.
    //
    // One opaque fill of a rectangle is also the cheapest thing a painter can
    // do, and §13.1's `RepaintBoundary` means it costs one fill inside the
    // background layer rather than a page-wide repaint.
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.canvas);
    if (tier == NeuralTier.low) {
      // `low` is the canvas and nothing else.
      return;
    }
    _paintAurora(canvas, size);
    _paintOrbs(canvas, size);
  }

  /// The two drifting vertical bands. `ds.tsx:170-190`, `index.css:78-82`.
  ///
  /// ## WHAT IS DROPPED, AND WHY
  ///
  /// The prototype's `filter: blur(16px)` on this layer is **not** reproduced.
  /// It is a full-viewport blur of a full-viewport gradient, every frame — a
  /// second screen-sized render target — and the bands are already gradients,
  /// which means they are already soft. This is the same call §13.3 makes for
  /// the orbs' 72px blur: replace the blur with the gradient's own softness, for
  /// the same reason.
  ///
  /// `background-size: 100% 200%` plus
  /// `background-position: 50% 0% → 50% 100% → 50% 0%` (`index.css:79-81`)
  /// becomes a vertical slide of a twice-height gradient: a `100%`-wide
  /// background has no horizontal slack, so the keyframe's `30% → 70%` leg
  /// (`index.css:79-80`) moves nothing at all and is not reproduced either.
  ///
  /// The opacity leg is `var(--aurora-opacity) → *1.6 → back`. `auroraOpacity` is
  /// applied to the stops' own alphas — which is what CSS `opacity` on the
  /// element does to the gradients inside it — and the 1.6 is the peak of
  /// [auroraPulse] rescaled to `1 → 1.6 → 1`, so the band never fades out at the
  /// half cycle the way a bare `auroraPulse` would.
  void _paintAurora(Canvas canvas, Size size) {
    final double wave = auroraPulse(motion.auroraValue);
    final double alpha =
        colors.auroraOpacity * (1 + (NeuralAurora.peakPulse - 1) * wave);
    final bool dark = brightness == Brightness.dark;
    final List<List<Color>> bands = dark
        ? NeuralAurora.dark
        : NeuralAurora.light;
    final List<double> layerOneStops = dark
        ? NeuralAurora.stopsDark
        : NeuralAurora.stopsLight;

    final Rect band = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    for (int layer = 0; layer < bands.length; layer++) {
      // Layer 2's stops are 0 / 50 / 100 in both palettes, so its stop list is
      // even; only layer 1 differs between them.
      final List<double> stops = layer == 0 ? layerOneStops : _evenStops(3);
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(0, -size.height * wave);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              for (final Color stop in bands[layer])
                stop.withValues(alpha: (stop.a * alpha).clamp(0.0, 1.0)),
            ],
            stops: stops,
          ).createShader(band),
      );
      canvas.restore();
    }
  }

  static List<double> _evenStops(int count) => <double>[
    for (int i = 0; i < count; i++) i / (count - 1),
  ];

  /// The floating orbs. `ds.tsx:194-206`, `index.css:36-67`.
  ///
  /// ## THE 72px BLUR
  ///
  /// §13.3: "The prototype's `blur(72px)` is achieved by a soft radial gradient
  /// with a wide transparent stop — visually equivalent, effectively free." That
  /// is the second stop of [kOrbGradientCenter]'s gradient at alpha 0. The hue
  /// cycle rides on top as a [ColorFilter] rather than as an `ImageFilter`,
  /// because `ImageFilter.hueRotation` is not available on every platform this
  /// app builds for.
  ///
  /// ## THE OPACITY
  ///
  /// `colors.orbOpacity`, not a literal. The prototype's `ds.tsx:160` is
  /// `isDark ? 0.55 : 0.16`; `EvaColors` publishes `0.55 / 0.18`
  /// (`03-design-system.md` §5.1). Dark agrees exactly; **light is 0.18 here and
  /// 0.16 in the prototype**, and the token wins — a design-system token is not
  /// re-derived at a call site. Recorded so a later reader does not "fix" the
  /// divergence in the wrong direction.
  void _paintOrbs(Canvas canvas, Size size) {
    final List<OrbSpec> orbs = orbsFor(variant);
    final Offset pointer = motion.pointer.value;
    for (int i = 0; i < orbs.length; i++) {
      final OrbSpec orb = orbs[i];
      final Offset drift = orbFloatOffset(
        orb.floatPath,
        motion.floatPhaseFor(i, orbs.length),
      );
      final double scale = orbFloatScale(
        orb.floatPath,
        motion.floatPhaseFor(i, orbs.length),
      );

      canvas.save();
      // `parallax`, live: the prototype's `translate(mouse * (parallax / 14))`.
      canvas.translate(
        pointer.dx * orb.parallaxScale,
        pointer.dy * orb.parallaxScale,
      );
      canvas.translate(orb.x + drift.dx, orb.y + drift.dy);

      // `transform: translate(…) scale(…)` scales about the orb's own centre, so
      // the scaled rect is recentred on the orb's unscaled centre.
      final double side = orb.size * scale;
      final Rect rect = Rect.fromCenter(
        center: Offset(orb.size / 2, orb.size / 2),
        width: side,
        height: side,
      );
      // A **circle**, not the rectangle the shader was built for. `ds.tsx:197-198`
      // gives each orb `borderRadius: '50%'` on a square box, so the prototype's
      // orb is a disc and the gradient fades out inside it. Drawing the rect
      // would leave the box's own corners tinted wherever the fade has not
      // finished — see [kOrbGradientRadius] — and the orb would read as a
      // hard-edged square.
      canvas.drawCircle(
        rect.center,
        side / 2,
        Paint()
          ..shader = RadialGradient(
            center: kOrbGradientCenter,
            radius: kOrbGradientRadius,
            colors: <Color>[
              orb.color.withValues(alpha: colors.orbOpacity),
              orb.color.withValues(alpha: 0),
            ],
          ).createShader(rect)
          ..colorFilter = hueRotateFilter(
            huePhaseFor(
                  clock: motion.hueValue,
                  phaseOffset: hueDelayPhase(
                    orb.hueDelaySeconds,
                    orb.hueSeconds,
                  ),
                ) *
                hueDirectionSign(orb.hueDirection),
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_NeuralPainter oldDelegate) =>
      oldDelegate.variant != variant ||
      oldDelegate.tier != tier ||
      oldDelegate.brightness != brightness ||
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.colors != colors;
}
