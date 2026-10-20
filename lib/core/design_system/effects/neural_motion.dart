import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_scene.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// The four shared controllers app-wide, plus the pointer offset.
///
/// §13.2, mitigation 2: the prototype declares 3–4 orbs per screen each with
/// independent `floatDur` / `hueDur`, which is eight screens × 4 orbs × 2
/// animations = **64** animations. This collapses to **four**
/// [AnimationController]s — float, hue, aurora, and the LUMEN shader clock —
/// created once, above `MaterialApp`, published by [NeuralMotionScope] and
/// never recreated per screen.
///
/// ## WHY IT IS A `ChangeNotifier` AND NOT JUST A BAG OF CONTROLLERS
///
/// §13.1's reference reads `ListenableBuilder(listenable: motion)` where `motion`
/// is this class, and nothing in that reference ever calls `notifyListeners()`.
/// So the builder never rebuilds, the painter paints once at construction, and
/// the entire mitigation — a background that is *alive* without re-rendering the
/// page — silently degrades into a static gradient while every test still
/// passes. That is the D1 defect, and it is the same failure mode §13 exists to
/// kill, so the notification is wired here at the source instead: one listener on
/// each of the five sources, one [notifyListeners] per change, and
/// `ListenableBuilder(listenable: motion.repaint)` in `neural_background.dart`
/// therefore rebuilds because the controllers actually moved.
///
/// ## WHY `repaint` IS A SEPARATE GETTER
///
/// It returns `this`, which sounds redundant and is not. `CustomPainter.repaint`
/// and `ListenableBuilder.listenable` both want "the thing to listen to", and
/// naming it keeps the two call sites from each inventing their own merge — a
/// per-build `Listenable.merge([...])` would allocate every frame and re-subscribe
/// the builder every frame, which is the allocation churn the collapse to three
/// controllers was meant to remove.
///
/// ## D3 — WHAT HAPPENED TO `floatDur` AND `hueDur`
///
/// The prototype's `floatDur` (14–28s) and `hueDur` (7–14s) are **per-orb
/// periods**, and a period is a property of a controller. With three orb
/// controllers there is no way to honour twenty-two of them, and no amount of
/// cleverness changes that: one clock has one rate. §13.2 anticipates exactly this and
/// prescribes the replacement — "derive per-orb phase from `i / orbCount`" — so
/// that is what [floatPhaseFor] does and what the painter reads.
///
/// What survives, and is tested:
///
/// - **shape** — the `orb-float-a/b/c` keyframes per orb ([OrbFloatPath]), which
///   is what actually makes the orbs look like different orbs rather than the
///   same one at different offsets;
/// - **phase** — `i / orbCount` ([floatPhaseFor]), so orbs never pulse in
///   lockstep;
/// - **direction** — `hue-cycle` vs `hue-cycle-rev` as a sign
///   ([OrbHueDirection] → `hueDirectionSign`), so half the orbs sweep the wheel
///   the other way;
/// - **hue delay** — the prototype's negative `animation-delay`, expressed as a
///   fraction of that orb's own `hueDur` ([OrbSpec.hueDelaySeconds]), which is
///   what makes orb 2 start a third of the way round instead of in lockstep;
/// - **parallax** — the mouse-response amplitude, as a multiplier of the
///   pointer offset.
///
/// What does not survive is the *rate*: every orb now shares the float
/// controller's 20s period and the hue controller's 12s period. The cost is
/// real and worth naming — the prototype's Home group has a 200px amber orb
/// drifting at 19s next to a 500px blue one at 16s, and here they drift
/// together. The saving is the point of §13.2: 64 animations become 3.
///
/// Both numbers are still transcribed into [OrbSpec] so the table stays
/// auditable and restoring them is a data change. `EvaMotion.orbFloatFor` /
/// `orbHueFor` — which spread §5.3's `14–28s` and `7–14s` ranges — have **no
/// production caller left** as a consequence. They still have their Phase-1
/// tests, and this doc is the note that says why.
class EvaNeuralMotion extends ChangeNotifier {
  /// Creates the bundle and wires the notification.
  ///
  /// Takes its controllers rather than creating them: the vsync belongs to the
  /// [TickerProviderStateMixin] in [NeuralMotionScope]'s `State`, and a
  /// `TickerProvider` handed in as a constructor parameter would put the
  /// lifetime decision back in the hands of every caller — the exact
  /// per-controller explosion this class removes.
  EvaNeuralMotion({
    required this.float,
    required this.hue,
    required this.aurora,
    required this.pointer,
    required this.lumen,
  }) : lumenScene = LumenScene(clock: lumen) {
    _sources = Listenable.merge(<Listenable>[
      float,
      hue,
      aurora,
      pointer,
      lumen,
    ]);
    _sources.addListener(_onSourceChanged);
  }

  late final Listenable _sources;

  bool _notifiedThisFrame = false;
  bool _disposed = false;

  /// Coalesces the five sources into **one** notification per frame.
  ///
  /// ## WHY COALESCING IS NOT OPTIONAL HERE
  ///
  /// Four `repeat()`ing controllers each fire their own listener every frame,
  /// so a naive forward fires `notifyListeners` **four times per frame** and the
  /// `ListenableBuilder` in `neural_background.dart` rebuilds the painter four
  /// times for one visual update. That is the churn §13's collapse to three
  /// controllers was supposed to *remove*, reintroduced one layer up.
  ///
  /// Nothing is lost by dropping the second, third and fourth. All four tickers
  /// run in the same `transientCallbacks` pass, before the build and paint
  /// phases, so by the time the painter reads `floatValue` / `hueValue` /
  /// `auroraValue` / `lumen.seconds` every clock has already advanced. The
  /// first notification is therefore a complete one, and the flag is cleared
  /// in a post-frame callback — the end of the same frame, not the start of
  /// the next.
  ///
  /// `addPostFrameCallback` rather than a microtask: the scheduler's frame
  /// callback is synchronous from transient callbacks through paint, so a
  /// microtask would also land "after the frame", but it would land after the
  /// *next* frame's scheduling decisions in a way that is much harder to reason
  /// about. Post-frame is the boundary that means what it says.
  void _onSourceChanged() {
    if (_disposed || _notifiedThisFrame) return;
    _notifiedThisFrame = true;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _notifiedThisFrame = false;
    });
  }

  /// The orb float clock. §13.2's reference duration: 20s.
  final AnimationController float;

  /// The orb hue clock. §13.2's reference duration: 12s.
  final AnimationController hue;

  /// The aurora band clock. §13.2's reference duration: 14s.
  ///
  /// Runs **forwards**, not `reverse: true` — see [setAnimationsEnabled] for why
  /// the reference snippet's `reverse` halves the wave's rate.
  final AnimationController aurora;

  /// The pointer offset that drives orb parallax, normalised to the ±16 / ±12
  /// box the prototype uses.
  ///
  /// A [ValueNotifier] rather than a controller: it is not a clock, it is
  /// a position, and it settles. The prototype lerps it towards the target at
  /// 0.05 per frame (`ds.tsx:143-144`); Flutter's [Listener] reports a pointer
  /// position directly, so the smoothing would be the *only* thing missing and
  /// it is deliberately not added — see the D3 note in this class's doc for the
  /// same reason the durations are not honoured.
  final ValueNotifier<Offset> pointer;

  /// The LUMEN shader's clock — `u_time`, in unwrapped elapsed seconds.
  ///
  /// A [TickedLumenClock] and not a [LumenClock] because this bundle **runs**
  /// clocks: `setAnimationsEnabled` has to stop and start this one with the
  /// other three, and the only way to do that through an abstraction is to
  /// reach past it. Holding the concrete type is the honest trade — a painter
  /// takes a [LumenClock] and nothing else about the two needs to differ, and a
  /// test that wants a frozen one does not build an `EvaNeuralMotion` at all.
  ///
  /// ## WHY IT IS A SEPARATE OBJECT AND NOT A FIFTH ACCESSOR
  ///
  /// Because it is the one field in the bundle that a **test** needs to hold
  /// still. Every other field is read from an `AnimationController` whose
  /// `value` is a pure function of elapsed time and can be sampled at any point;
  /// the aurora's 240 goldens are captured through a rasterised frame and can
  /// only be made reproducible by controlling the clock itself. See
  /// `lumen_clock.dart` for why it is monotonic by construction.
  final TickedLumenClock lumen;

  /// The aurora's **animated state** — the prototype's render loop, ported.
  ///
  /// ## WHY IT LIVES HERE AND NOT IN THE BACKGROUND WIDGET
  ///
  /// Because the state is **app-global** and the painter is per-screen.
  ///
  /// The prototype's eased values (the hue, the ambient intensity, the spike)
  /// live in one JS closure behind one canvas (`eva/redesign.html:881-912`),
  /// so they survive a screen change: leaving `/settings` and coming back
  /// does not restart the aurora's transition.
  ///
  /// And because Phase 6's `AutoTabsRouter` keeps three tab screens alive at
  /// once. Per-screen state would put the three tabs at three different
  /// phases of the same aurora, and the tab swap would visibly jump. One
  /// scene, one phase.
  ///
  /// The scene is created here because it ticks from [lumen] — the clock that
  /// is already in this bundle — and a second ticker would be a second way
  /// for the app to burn frames.
  final LumenScene lumenScene;

  /// The listenable that fires whenever any of the four clocks advances or the
  /// pointer moves.
  ///
  /// This object. See the class doc for why the reference implementation's
  /// version of this never fired.
  Listenable get repaint => this;

  /// [float]'s position in `0..1`.
  double get floatValue => float.value;

  /// [hue]'s position in `0..1`.
  double get hueValue => hue.value;

  /// [aurora]'s position in `0..1`.
  double get auroraValue => aurora.value;

  /// The [index]-th of [count] orbs' float phase, offset so orbs never pulse in
  /// lockstep.
  ///
  /// §13.2's own prescription, verbatim: `(index / count) % 1.0`. Orb 0 is at
  /// rest when the clock starts, orb 1 is already a third of the way along, and
  /// `count == 1` — a real configuration, since a narrow window can leave
  /// exactly one orb — collapses to `0` rather than dividing by zero.
  double floatPhaseFor(int index, int count) {
    assert(count > 0, 'orb count must be positive, got $count');
    if (count <= 1) return 0;
    return (index / count) % 1.0;
  }

  /// Starts or stops all four clocks together.
  ///
  /// ## WHY THIS IS HERE AND NOT ONLY A TIER DECISION
  ///
  /// [NeuralTiers.resolve] drops the *painted* layers to nothing when the user
  /// has asked for reduced motion, and that is the requirement. This is the
  /// other half: four controllers left `repeat()`ing under a background that
  /// draws none of them are four tickers burning frames for a decision that has
  /// already been made. [NeuralMotionScope] exposes it so the composition root
  /// can turn the clock off outright rather than pay for a background it will
  /// not show.
  ///
  /// Stopping rather than setting `value` to zero: a reduced-motion user should
  /// get a still background, not one snapped to the top of its cycle, and
  /// `stop(canceled: false)` leaves each clock wherever it had got to.
  ///
  /// **The shader clock is included, and stopping it is what makes `u_time`
  /// freeze rather than rewind.** `TickedLumenClock` reads
  /// `lastElapsedDuration`, which `stop()` nulls and `repeat()` resets to zero —
  /// so this method is also the thing that exercises the clock's offset
  /// arithmetic every time a reader toggles reduced motion.
  void setAnimationsEnabled({required bool enabled}) {
    if (enabled) {
      float.repeat();
      hue.repeat();
      // `repeat()`, NOT §13.2's `repeat(reverse: true)`.
      //
      // `reverse: true` is how one usually expresses a there-and-back triangle
      // from a `0→1` controller — and it is right for a control the reader
      // completes. It is wrong here, because `reverse: true` runs *forward for
      // the full 14s and then back for another 14s*, putting the peak at t=14s
      // and completing a wave every 28 seconds.
      //
      // The prototype's keyframes are `0% → 50% → 100%` on a `14s infinite`
      // animation (`index.css:79-81`): the peak is at t=7s and the wave completes
      // in 14. So the triangle is built from the raw 14s clock instead, by
      // `auroraPulse`, and the controller is left running forwards. Same wave,
      // correct period.
      aurora.repeat();
      lumen.ticker.repeat();
    } else {
      float.stop(canceled: false);
      hue.stop(canceled: false);
      aurora.stop(canceled: false);
      lumen.ticker.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    // The subscription first: `dispose()` on a controller clears its listeners,
    // and clearing ours before that keeps `notifyListeners` from firing into a
    // half-disposed notifier.
    _disposed = true;
    _sources.removeListener(_onSourceChanged);
    pointer.dispose();
    // The scene first: it holds a listener on `lumen`, and `lumen.dispose()`
    // clears the clock's listeners — so the scene has to let go before the
    // clock does.
    lumenScene.dispose();
    // Before its ticker, or the clock's own `dispose` would remove a listener
    // from a controller that is already gone.
    lumen.dispose();
    float.dispose();
    hue.dispose();
    aurora.dispose();
    lumen.ticker.dispose();
    super.dispose();
  }
}

/// Hosts the four shared controllers and publishes them to the tree.
///
/// Mounted **above** `MaterialApp.router` (`lib/app/app.dart`), so a screen
/// never creates one and a route push never restarts the ambient animation.
///
/// Deliberately a plain [InheritedWidget] and not an [InheritedNotifier]: the
/// background already rebuilds through a [ListenableBuilder] over
/// [EvaNeuralMotion.repaint], so notifying the whole subtree from here would
/// defeat the repaint confinement the design exists to get.
class NeuralMotionScope extends StatefulWidget {
  /// Publishes one [EvaNeuralMotion] to [child] and its descendants.
  const NeuralMotionScope({
    required this.child,
    this.animationsEnabled,
    super.key,
  });

  /// The subtree that may read the motion bundle.
  final Widget child;

  /// Whether the four clocks run at all.
  ///
  /// `null` — the default — resolves to the **platform's** reduced-motion
  /// preference, read from
  /// `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`.
  /// `true` or `false` overrides it outright.
  ///
  /// ## WHY A PARAMETER RATHER THAN A `MediaQuery` LOOKUP
  ///
  /// Only because this widget sits **above** `MaterialApp`: there is no
  /// `MediaQuery` above the scope, so `MediaQuery.disableAnimationsOf` is not
  /// reachable from here. That is the whole reason, and it used to be stated
  /// wrongly — the doc also claimed the platform's own signal "cannot reach it
  /// either", which is false. `platformDispatcher` is not part of the widget
  /// tree, so it is reachable from anywhere, including above `MaterialApp`. A
  /// comment asserting otherwise is worse than no comment, because it reads as a
  /// settled reason not to fix the clock.
  ///
  /// ## WHAT THE PLATFORM SIGNAL DOES *NOT* REACH
  ///
  /// Nothing, as of this revision: [NeuralMotionScope] registers a
  /// [WidgetsBindingObserver], so a reader toggling the OS setting mid-session is
  /// honoured without a restart, and an explicit `animationsEnabled` still wins
  /// over it. A later phase replaces the default with the persisted
  /// `UserSettings` value, and the observer has to survive that — which is the one
  /// thing to check when that lands, because a persisted default that bypasses
  /// `didChangePlatformBrightness` would be a behaviour change disguised as a
  /// default. Phase 5 closed without touching this: it delivered `core/network`
  /// and the `auth` feature, so there is no `UserSettings` to read yet.
  ///
  /// The *per-widget* reduced-motion checks are a separate mechanism and are not
  /// affected by anything here: [NeuralBackground] and `GoldFlecks` read
  /// `MediaQuery.maybeDisableAnimationsOf`, which a device fills from the same
  /// `accessibilityFeatures` (and a test can fill directly). So a reader who has
  /// asked for reduced motion gets both halves: no tickers, and no painted
  /// motion even if a caller re-enables the clocks.
  ///
  /// Changing it re-evaluates: [didUpdateWidget] and
  /// [didChangeAccessibilityFeatures] both stop or restart the clocks rather
  /// than leaving a running ticker under a stopped background.
  final bool? animationsEnabled;

  /// The motion bundle published to [context]'s descendants.
  ///
  /// Never null, so the `!` below is a programming-error assertion rather than
  /// a runtime path callers must handle: the only way to reach this is inside
  /// this scope, and a `NeuralBackground` above the scope is a wiring bug with a
  /// stack trace attached.
  static EvaNeuralMotion of(BuildContext context) {
    final _NeuralMotionScopeInherited? scope = context
        .dependOnInheritedWidgetOfExactType<_NeuralMotionScopeInherited>();
    assert(
      scope != null,
      'NeuralMotionScope is missing above this widget. It is mounted once, '
      'above MaterialApp — see lib/app/app.dart.',
    );
    return scope!.motion;
  }

  @override
  State<NeuralMotionScope> createState() => _NeuralMotionScopeState();
}

class _NeuralMotionScopeState extends State<NeuralMotionScope>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final EvaNeuralMotion _motion = _buildMotion();

  /// Whether the clocks should be running, resolving the platform's own signal.
  ///
  /// One place, so the constructor path and [didUpdateWidget] cannot disagree
  /// about what "enabled" means — and so an explicit `true` really does override
  /// the platform, which is what the parameter is for.
  bool get _enabled =>
      widget.animationsEnabled ??
      WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations ==
          false;

  EvaNeuralMotion _buildMotion() {
    final AnimationController float = AnimationController(
      vsync: this,
      duration: kFloatPeriod,
      // `preserve` because these repeat forever: `AnimationBehavior.normal`
      // would collapse them to a single frame under reduced motion, which is
      // the "flashing rapidly" case the doc on the enum warns about. Reduced
      // motion is honoured by `setAnimationsEnabled` and by `NeuralTier`, not by
      // letting the behaviour rewrite the duration behind them.
      animationBehavior: AnimationBehavior.preserve,
    );
    final AnimationController hue = AnimationController(
      vsync: this,
      duration: kHuePeriod,
      animationBehavior: AnimationBehavior.preserve,
    );
    final AnimationController aurora = AnimationController(
      vsync: this,
      duration: EvaMotion.aurora,
      animationBehavior: AnimationBehavior.preserve,
    );
    final AnimationController lumenTicker = AnimationController(
      vsync: this,
      duration: kLumenClockPeriod,
      // `preserve` for the same reason as the three above, and it matters more
      // here: `AnimationBehavior.normal` multiplies the *duration* by
      // `disableAnimationsFactor`, and this controller's duration is not read at
      // all — `TickedLumenClock` reads `lastElapsedDuration`, which the ticker
      // owns and no behaviour rewrites. So the flag is not about correctness for
      // the shader clock; it is about the four controllers above the scope not
      // being collapsed to one frame by a fourth addition to the list.
      animationBehavior: AnimationBehavior.preserve,
    );
    final EvaNeuralMotion motion = EvaNeuralMotion(
      float: float,
      hue: hue,
      aurora: aurora,
      pointer: ValueNotifier<Offset>(Offset.zero),
      lumen: TickedLumenClock(ticker: lumenTicker),
    );
    if (_enabled) {
      motion.setAnimationsEnabled(enabled: true);
    }
    return motion;
  }

  @override
  void initState() {
    super.initState();
    // Only when the platform owns the answer. A caller that passed an explicit
    // `animationsEnabled` is not asking the OS anything, and registering would
    // mean an OS toggle could restart clocks the app explicitly holds still.
    if (widget.animationsEnabled == null) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didUpdateWidget(NeuralMotionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationsEnabled != widget.animationsEnabled) {
      _motion.setAnimationsEnabled(enabled: _enabled);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    // A reader who toggles "reduce motion" in the OS mid-session gets the answer
    // here. Without this the signal would be honoured at first mount only, which
    // is half a fix wearing a whole fix's name.
    if (widget.animationsEnabled == null) {
      _motion.setAnimationsEnabled(enabled: _enabled);
    }
  }

  @override
  void dispose() {
    // Symmetrical with `initState`: observing unconditionally would let an OS
    // toggle push into a bundle whose clocks the composition root deliberately
    // holds still.
    if (widget.animationsEnabled == null) {
      WidgetsBinding.instance.removeObserver(this);
    }
    // The four controllers are disposed **here**, by the host that owns the
    // `TickerProvider`. `TickerProviderStateMixin.dispose` throws if any ticker
    // it created is still alive, so this is not merely tidy-up: leaving it out
    // turns every app shutdown into a FlutterError.
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _NeuralMotionScopeInherited(motion: _motion, child: widget.child);
}

class _NeuralMotionScopeInherited extends InheritedWidget {
  const _NeuralMotionScopeInherited({
    required this.motion,
    required super.child,
  });

  final EvaNeuralMotion motion;

  @override
  bool updateShouldNotify(_NeuralMotionScopeInherited oldWidget) =>
      !identical(motion, oldWidget.motion);
}

/// The shared float clock's period. §13.2's reference: 20 seconds.
const Duration kFloatPeriod = Duration(seconds: 20);

/// The shared hue clock's period. §13.2's reference: 12 seconds.
const Duration kHuePeriod = Duration(seconds: 12);

/// The LUMEN shader clock's controller period.
///
/// ## WHY AN HOUR, AND WHY IT IS **NOT** THE PERIOD OF `u_time`
///
/// Because the period is never read. `TickedLumenClock` reads
/// `AnimationController.lastElapsedDuration` — the ticker's elapsed time since
/// `start()` — not `value × duration`, so the cycle this number defines never
/// reaches the shader. It exists only because a controller has to have one, and
/// an hour is long enough that nothing can observe the wrap: the first thing a
/// shorter period would buy is a discontinuity nobody wants and cannot see.
///
/// The prototype's aurora has no period at all for this term (`redesign.html`
/// accumulates `u_time` without bound), so this number is as close to
/// "not a parameter" as a `Duration` can be.
const Duration kLumenClockPeriod = Duration(hours: 1);
