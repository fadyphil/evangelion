import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Applies a set of pre-timed effects to a subtree, with §14's reduced-motion rule
/// enforced in one place.
///
/// ## WHY THIS EXISTS RATHER THAN CALLING `.animate()` AT EACH SITE
///
/// `flutter_animate` 4.5.2 is good at the declarative part — `fadeIn`, `slideY`,
/// `shake`, `desaturate` are one line each instead of a controller and a `Tween` — and
/// it is missing two things this app treats as non-negotiable.
///
/// ### 1. IT READS NO ACCESSIBILITY FLAG
///
/// `grep -r disableAnimations` over the whole package returns nothing. §14 says every
/// animation must check `MediaQuery.disableAnimationsOf(context)` and, when disabled,
/// jump straight to the end state; decision 124 was recorded for a single site that
/// forgot. Using the package directly therefore makes **every** call site a fresh
/// violation, and the failure is invisible — an animation that should not have played
/// plays, and it looks like a design choice.
///
/// ### 2. ITS DEFAULTS ARE VALUES THIS APP HAS ALREADY REJECTED
///
/// `Animate.defaultDuration` is a literal `300ms` and `Animate.defaultCurve` is
/// `Curves.linear`. A call site that omits a timing therefore gets a magic number and
/// a *linear* curve — which is neither [EvaMotion.interactiveCurve] nor
/// [EvaMotion.achievementCurve], and which `motion-consistency` exists to prevent.
/// [installPackageDefaults] rewrites both statics so even a forgotten wrapper degrades
/// to the app's own curve instead of linear.
///
/// ## TIMINGS COME FROM [MotionMoment], NOT FROM HERE
///
/// There is no `duration` or `curve` parameter on this widget, deliberately. Effects
/// are built by [MotionMoment]'s own factories, which stamp the tokens on, so a call
/// site cannot pass a literal even by accident:
///
/// ```dart
/// EvaAnimate(
///   effects: <Effect<dynamic>>[MotionMoment.routine.fadeIn()],
///   child: content,
/// )
/// ```
///
/// ## AND WHAT IT CANNOT DO
///
/// [EvaMotion.achievementSpring] does **not** go through here. A spring's value leaves
/// `[0,1]`, and this package wraps its controller in an `Interval` that asserts
/// `t >= 0.0 && t <= 1.0` — measured, it throws. A widget that wants real physics
/// drives its own controller with `animateWith`; see [EvaMotion.achievementSpring]'s
/// doc for where that applies and [EvaMotion.achievementCurve] for here.
class EvaAnimate extends StatefulWidget {
  /// Runs [effects] on [child].
  ///
  /// Build the effects with [MotionMoment]'s factories so their timings are the
  /// app's tokens rather than literals.
  const EvaAnimate({
    required this.effects,
    required this.child,
    this.trigger,
    super.key,
  });

  /// What to animate, already carrying its duration and curve.
  final List<Effect<dynamic>> effects;

  /// The subtree.
  final Widget child;

  /// Change this to replay the animation.
  ///
  /// ## WHY NOT "REPLAY EVERY BUILD"
  ///
  /// The obvious implementation — restart in `didUpdateWidget` — replays on every
  /// rebuild, and Home rebuilds on every keystroke-driven state change and on every
  /// `didPopNext`. A streak celebration that fires each time a child walks back from
  /// `/reading` stops being a celebration and becomes a flicker. The caller therefore
  /// says *what changed*: pass the direction, the reading id, or the new value.
  ///
  /// `null` means "never replay", so a one-shot entrance stays one-shot.
  final Object? trigger;

  @override
  State<EvaAnimate> createState() => _EvaAnimateState();
}

class _EvaAnimateState extends State<EvaAnimate>
    with SingleTickerProviderStateMixin {
  /// The controller handed to [Animate], which this state owns.
  ///
  /// ## STABLE ACROSS BUILDS, DELIBERATELY
  ///
  /// `Animate.didUpdateWidget` disposes and re-initialises whenever
  /// `oldWidget.controller != widget.controller` — **by identity**. Handing it a
  /// freshly-built controller each build would restart every animation on every
  /// rebuild and churn a `Ticker` each time, so it is created once here.
  late final AnimationController _controller;

  /// The longest time any of [EvaAnimate.effects] runs for.
  ///
  /// The controller's `duration` is not cosmetic: the package computes each effect's
  /// `Interval` as `begin / controller.duration`, so a controller shorter than an
  /// effect would divide by the wrong total and the effect would finish early.
  /// `null` for an empty list, since there is nothing to divide by.
  Duration? get _longest {
    Duration? longest;
    for (final Effect<dynamic> effect in widget.effects) {
      final Duration duration = effect.duration ?? EvaMotion.base;
      if (longest == null || duration > longest) longest = duration;
    }
    return longest;
  }

  /// Whether this subtree may animate at all.
  ///
  /// §14's flag. `UserSettings.reducedMotion` is deliberately **not** consulted: a
  /// reader who has reduced motion switched on at the OS level must not be shown
  /// motion because the in-app setting says otherwise, and the in-app setting only
  /// ever adds restraint, never removes it.
  bool get _enabled => !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _longest ?? EvaMotion.base,
    );
    // From 0, not left at the default 1.0: an entrance effect should begin at its
    // `begin` value, and a controller starting at 1.0 would show the end state for a
    // frame and then jump.
    _controller.value = 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(EvaAnimate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs the animation, or jumps to the end when motion is reduced.
  ///
  /// Post-frame rather than inline, because the effects read the controller's value
  /// while the first frame is composed.
  void _play() {
    if (!mounted) return;
    if (!_enabled) {
      // §14: "jump straight to the end state". `1.0` is the end every effect here
      // agrees on, because `Interval` and every curve in `EvaMotion` terminates
      // there — which is the same reasoning decision 124 used when it substituted
      // `kAlwaysCompleteAnimation` on the route transition.
      _controller.value = 1.0;
      return;
    }
    // ## FROM ZERO, EVERY TIME — INCLUDING A REPLAY
    //
    // The first version only reset in `initState`, so a [EvaAnimate.trigger] change
    // called `animateTo(1.0)` on a controller already sitting at 1.0. That completes
    // instantly and moves nothing: the replay was a **no-op**, caught by
    // `trigger replays when it changes` asserting the value had gone back below 1.0.
    // Resetting here makes "replay" mean replay on the first play and every one after.
    _controller.value = 0.0;
    final Duration? longest = _longest;
    if (longest != null) _controller.duration = longest;
    // Left at `Curves.linear` — Flutter's own default — because the easing belongs
    // on the *effect*, and putting [EvaMotion.interactiveCurve] here as well would
    // apply it twice.
    _controller.animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      controller: _controller,
      // The controller is ours. `Animate._play` only calls `forward()` when
      // `autoPlay` is true, so leaving it false is what stops the package driving a
      // controller it knows nothing about.
      autoPlay: false,
      effects: widget.effects,
      child: widget.child,
    );
  }
}

/// One timing family, and the factories that stamp it onto effects.
///
/// A **closed set** on purpose. "easeOutExpo for most things" is the kind of comment
/// that outlives its author and stops describing anything; four named cases can be
/// listed, tested and argued about, and a fifth has to be added here to exist.
///
/// Every factory takes its **shape** from the caller and its **timing** from this
/// enum. There is no `duration` or `curve` argument anywhere below, so a literal
/// cannot reach an effect even by accident.
enum MotionMoment {
  /// A control answering a tap — press, toggle, option select.
  ///
  /// [EvaMotion.base] on [EvaMotion.interactiveCurve].
  routine(EvaMotion.base, EvaMotion.interactiveCurve),

  /// A whole surface arriving.
  ///
  /// [EvaMotion.screen] on [EvaMotion.interactiveCurve]. Distinct from [routine]
  /// because a 250ms surface transition and a 200ms button are different amounts of
  /// time, not the same one rounded.
  screen(EvaMotion.screen, EvaMotion.interactiveCurve),

  /// Something was achieved — a streak went up, a milestone landed.
  ///
  /// [EvaMotion.achievementSettle] on [EvaMotion.achievementCurve]. **Not** the
  /// spring, and **not** [EvaMotion.achievementDuration] either: that is the spring
  /// factory's *nominal* stiffness dial, and a curve handed 180ms would finish in half
  /// the time of the spring's real ~344ms. See the class doc.
  achievement(EvaMotion.achievementSettle, EvaMotion.achievementCurve),

  /// The same moment on its way out.
  ///
  /// [EvaMotion.achievementExit] on [EvaMotion.achievementCurve] — the curve stays, so
  /// the departure is recognisably the same event, and only the time changes.
  achievementExit(EvaMotion.achievementExit, EvaMotion.achievementCurve);

  const MotionMoment(this.duration, this.curve);

  /// How long these effects run.
  final Duration duration;

  /// The easing. Always one of the two [EvaMotion] curves.
  final Curve curve;

  /// `opacity 0 → 1`.
  FadeEffect fadeIn({double begin = 0.0}) =>
      FadeEffect(duration: duration, curve: curve, begin: begin, end: 1.0);

  /// `opacity 1 → 0`.
  FadeEffect fadeOut({double end = 0.0}) =>
      FadeEffect(duration: duration, curve: curve, begin: 1.0, end: end);

  /// Translates from [begin] to [end].
  ///
  /// [begin] and [end] are absolute offsets, so a caller choosing a travel distance
  /// still cannot choose a duration.
  SlideEffect slide(Offset begin, {Offset? end}) => SlideEffect(
    duration: duration,
    curve: curve,
    begin: begin,
    end: end ?? Offset.zero,
  );

  /// Scales from [from] to 1.0.
  ///
  /// `ScaleEffect` maps its `begin` through `_normalizeScale`, which floors at
  /// `minScale` — so `0.0` is not a usable `from`.
  ScaleEffect scaleFrom(double from, {Alignment? alignment}) => ScaleEffect(
    duration: duration,
    curve: curve,
    begin: Offset(from, from),
    end: const Offset(1.0, 1.0),
    alignment: alignment,
  );

  /// Shakes — the "that did not happen" motion.
  ///
  /// Paired with [desaturate] on a broken streak. [rotation] is in radians; the
  /// package's own default is `pi / 36`.
  ShakeEffect shake({
    double hz = ShakeEffect.defaultHz,
    Offset offset = Offset.zero,
    double rotation = 0.0,
  }) => ShakeEffect(
    duration: duration,
    curve: curve,
    hz: hz,
    offset: offset,
    rotation: rotation,
  );

  /// Colour saturation `begin → end`.
  ///
  /// `0.0` is fully desaturated and `1.0` is the colour as authored. The broken-streak
  /// flame drops to [desaturated] rather than to 0, because a fully grey flame reads
  /// as disabled rather than as lost.
  SaturateEffect saturate({double end = 1.0, double? begin}) =>
      SaturateEffect(duration: duration, curve: curve, begin: begin, end: end);

  /// How far a broken streak's flame drops to.
  ///
  /// `0.25`, not `0.0` — see [saturate].
  static const double desaturated = 0.25;
}

/// Whether [moment] would overshoot its target.
///
/// The achievement moments do; [MotionMoment.routine] and [MotionMoment.screen] do
/// not. A caller needing one family-agnostic decision — "is this allowed past 1.0?" —
/// reads this rather than comparing curves, which would break the day a second
/// achievement curve is added.
bool momentOvershoots(MotionMoment moment) {
  double peak = 0.0;
  for (double t = 0.0; t <= 1.0; t += 0.01) {
    final double y = moment.curve.transform(t);
    if (y > peak) peak = y;
  }
  // `1e-6` because `easeOutExpo` evaluates to 1.0 minus ~1.2e-10 at t=1, which is
  // float noise in a bezier, not an undershoot.
  return peak > 1.0 + 1e-6;
}

/// Overwrites `flutter_animate`'s own defaults with this app's tokens.
///
/// **Call once**, from the composition root, before any `Animate` exists.
///
/// Both statics are mutable, which is the only reason this is possible at all, and
/// leaving them alone means any call site that forgets a timing gets `Curves.linear` —
/// a curve this app uses nowhere else, and which reads as mechanical rather than
/// considered.
void installPackageDefaults() {
  Animate.defaultDuration = EvaMotion.base;
  Animate.defaultCurve = EvaMotion.interactiveCurve;
}
