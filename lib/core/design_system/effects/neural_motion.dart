import 'package:evangelion/core/design_system/effects/ambient_tick_budget.dart';
import 'package:evangelion/core/design_system/effects/lumen_clock.dart';
import 'package:evangelion/core/design_system/effects/lumen_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// The two shared controllers app-wide.
///
/// §13.2, mitigation 2: the prototype declares 3–4 orbs per screen each with
/// independent `floatDur` / `hueDur`, which is eight screens × 4 orbs × 2
/// animations = **64** animations. This collapsed to **four**
/// [AnimationController]s — float, hue, aurora, and the LUMEN shader clock —
/// and the orbs' retirement took it to **two**: the float clock and the shader
/// clock. Both are created once, above `MaterialApp`, published by
/// [NeuralMotionScope] and never recreated per screen.
///
/// ## WHY THE **FLOAT** CLOCK OUTLIVED THE ORBS
///
/// The float clock was the old design's *orb* float, and the orbs are gone —
/// but two things read it, and neither is an orb:
///
/// * `GoldFlecks` — the flecks' own float, and the flecks are on the quiz's
///   correct option today;
/// * the witness sky's star twinkle, whose phase is derived from the float
///   clock the same way the flecks' is (`kFloatPeriod` is still the shared
///   period).
///
/// **So the clock stayed and the orbs went**, and that is the shape of every
/// retirement in this repository: the thing that was *built around* the removed
/// thing can outlive it, and the honest test is "who reads it now", not "what
/// was it for".
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
/// each of the two sources, one [notifyListeners] per change, and
/// `ListenableBuilder(listenable: motion.repaint)` in `lumen_background.dart`
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
/// that is what the orb painter did, and the orbs' retirement took the
/// prescription with it.
///
/// **What survives, and is tested:**
///
/// - the **float clock's** own 20s period, which the flecks and the sky's
///   twinkle both read;
/// - `EvaMotion.orbFloatFor` / `orbHueFor`, which spread §5.3's `14–28s` and
///   `7–14s` ranges — they have **no production caller left**, because the orbs
///   that needed them are gone. They are recorded here so a reader knows they
///   are transcriptions of the prototype's table and not of a live rule.

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
    required this.lumen,
    DateTime Function()? now,
    this.budget = const AmbientTickBudget(
      paintEveryNTick: 1,
      notifyEveryNTick: 1,
    ),
  }) : lumenScene = LumenScene(clock: lumen, now: now, budget: budget) {
    _sources = Listenable.merge(<Listenable>[float, lumen]);
    _sources.addListener(_onSourceChanged);
  }

  late final Listenable _sources;

  /// How often the ambient may **notify** its listeners.
  ///
  /// ## WHAT THE NOTIFICATION COSTS
  ///
  /// The four consumers are the witness sky's **forty-four stars** — each one
  /// a `Positioned` / `Transform.scale` / `Opacity` / `DecoratedBox` /
  /// `SizedBox` chain, so about **265 elements re-instantiated per frame**,
  /// with **forty-four composited `Opacity` layers** and **eighty-eight shadow
  /// blurs** — plus the gold flecks, the CTA's breathing bead and the CTA's
  /// ripple ring.
  ///
  /// **All four are seconds-long ambient loops**, and the sky's twinkle has a
  /// period of seconds, so **twenty notifications a second is well past the
  /// point where the eye can tell it from a smooth one** — and it is a third
  /// of the frames.
  ///
  /// ## AND WHY THE BUDGET IS ON THE **NOTIFICATION** AND NOT THE **CLOCK**
  ///
  /// Because the clock's **ticking** is not the cost — the clock's
  /// **notification** is. The clock still ticks at the display's rate, so
  /// everything that reads a clock's **value** — the sky's twinkle phase, the
  /// flecks' phase — reads the same number it always did. What is rarer is
  /// the **wake-up**, and the wake-up is what rebuilds the stars.
  final AmbientTickBudget budget;

  bool _notifiedThisFrame = false;
  bool _disposed = false;

  /// Coalesces the two sources into **one** notification per frame.
  ///
  /// ## WHY COALESCING IS NOT OPTIONAL HERE
  ///
  /// Two `repeat()`ing controllers each fire their own listener every frame,
  /// so a naive forward fires `notifyListeners` **twice per frame** and the
  /// `ListenableBuilder` in `lumen_background.dart` rebuilds the painter twice
  /// for one visual update. That is the churn §13's collapse to three
  /// controllers was supposed to *remove*, reintroduced one layer up.
  ///
  /// Nothing is lost by dropping the second. Both tickers run in the same
  /// `transientCallbacks` pass, before the build and paint phases, so by the
  /// time the painter reads `floatValue` / `lumen.seconds` every clock has
  /// already advanced. The first notification is therefore a complete one, and
  /// the flag is cleared in a post-frame callback — the end of the same frame,
  /// not the start of the next.
  ///
  /// `addPostFrameCallback` rather than a microtask: the scheduler's frame
  /// callback is synchronous from transient callbacks through paint, so a
  /// microtask would also land "after the frame", but it would land after the
  /// *next* frame's scheduling decisions in a way that is much harder to reason
  /// about. Post-frame is the boundary that means what it says.
  void _onSourceChanged() {
    if (_disposed || _notifiedThisFrame) return;
    _notifiedThisFrame = true;
    // ## THE **NOTIFY BUDGET**
    //
    // The coalescing above is per **frame**; this is per **interval**. Two
    // `repeat()`ing controllers each fire their own listener every frame, and
    // the coalescing turns two notifications into one — but one per frame is
    // still sixty a second, and the forty-four stars are rebuilt on every one
    // of them.
    //
    // **The gate is over a [Stopwatch], and not over
    // `SchedulerBinding.currentFrameTimeStamp`.** The frame timestamp is the
    // obvious choice and it is **wrong**: it asserts that a frame is in
    // progress, and this notification can arrive **outside** one — the clock's
    // `setReducedMotion` is called from `setAnimationsEnabled`, which the
    // composition root calls from a `WidgetsBindingObserver` callback, and
    // that is not a frame. The first version read it, and the suite caught it.
    if (_notifyGate.isDue()) {
      notifyListeners();
    }
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _notifiedThisFrame = false;
    });
  }

  /// The notify budget's gate.
  ///
  /// **Built from [budget], and not from a constant** — a caller that passes
  /// its own budget gets its own gate.
  late final AmbientTickGate _notifyGate = budget.notifyGate;

  /// The orb float clock. §13.2's reference duration: 20s.
  ///
  /// **It outlived the orbs**, and that is worth saying: the clock itself was
  /// the old design's *orb* float, and the orbs are gone, but two things read
  /// it — `GoldFlecks` (the flecks' own float) and the witness sky's star
  /// twinkle — so the clock stays and only the orbs go.
  final AnimationController float;

  /// The LUMEN shader's clock — `u_time`, in unwrapped elapsed seconds.
  ///
  /// A [TickedLumenClock] and not a [LumenClock] because this bundle **runs**
  /// clocks: `setAnimationsEnabled` has to stop and start this one with the
  /// other three, **and hold it at zero** when the reader has asked for
  /// reduced motion, and the only way to do that through an abstraction is to
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

  /// The listenable that fires whenever either clock advances.
  ///
  /// This object. See the class doc for why the reference implementation's
  /// version of this never fired.
  Listenable get repaint => this;

  /// [float]'s position in `0..1`.
  double get floatValue => float.value;

  /// Starts or stops both clocks together.
  ///
  /// ## WHY THIS IS HERE AND NOT ONLY A TIER DECISION
  ///
  /// `LumenTiers.resolve` drops the *painted* layer to nothing when the user
  /// has asked for reduced motion, and that is the requirement. This is the
  /// other half: two controllers left `repeat()`ing under a background that
  /// draws neither of them are two tickers burning frames for a decision that
  /// has already been made. [NeuralMotionScope] exposes it so the composition
  /// root can turn the clock off outright rather than pay for a background it
  /// will not show.
  ///
  /// Stopping rather than setting `value` to zero: a reduced-motion user should
  /// get a still background, not one snapped to the top of its cycle, and
  /// `stop(canceled: false)` leaves each clock wherever it had got to.
  ///
  /// ## THE SHADER CLOCK IS HELD AT **ZERO**, AND THAT IS A DIFFERENT THING
  ///
  /// The float clock stops **wherever it had got to** — a still background, not
  /// a snapped one. The shader clock does not: under reduced motion the
  /// shader's `u_time` reads **0**, so the aurora is a still image of its
  /// initial state rather than of wherever it happened to be. The plan asks for
  /// exactly that — "a shader clock frozen at `t = 0`" (`plan:2392-2394`) — and
  /// it is a *different answer* to the prototype's, which scales `u_time` by
  /// `0.15` and lets it keep advancing (`eva/redesign.html:888`). The
  /// divergence is recorded at `plan:2004-2007` and at `lumen_clock.dart`'s
  /// [TickedLumenClock.setReducedMotion].
  ///
  /// **A freeze at "wherever it had reached" would be a function of how long
  /// the app has been running** and of when the reader toggled the setting,
  /// so the same reader on the same screen would see two different frames.
  /// At zero it is a function of the setting and of nothing else.
  ///
  /// ## THE ORDER OF THE TWO HALVES, AND WHY IT IS NOT COSMETIC
  ///
  /// The clock's notification is what makes the scene repaint, so the
  /// notification has to carry the value the clock will report from then on:
  ///
  /// * **stopping** — the ticker is stopped *first*, so the hold's
  ///   notification arrives with the clock fully at rest and reporting `0`;
  /// * **starting** — the hold is lifted *first*, so the notification arrives
  ///   with the clock reporting the elapsed time it preserved, and the
  ///   restored frame is painted before the ticker starts advancing it.
  ///
  /// The elapsed time is **preserved** across the hold, so turning reduced
  /// motion off hands back the aurora the reader had — the same hue, the same
  /// brightness, the same shader phase — rather than a state the app has never
  /// been in. What the hold costs is stated in the same place:
  /// `lumen_clock.dart`'s [TickedLumenClock.setReducedMotion].
  void setAnimationsEnabled({required bool enabled}) {
    if (enabled) {
      float.repeat();
      // The lift before the restart, for the reason the class doc gives: the
      // notification is the repaint, and the frame it paints is the restored
      // one.
      lumen.setReducedMotion(reducedMotion: false);
      lumen.ticker.repeat();
    } else {
      float.stop(canceled: false);
      // The stop before the hold, for the same reason: the notification
      // arrives with the clock at rest.
      lumen.ticker.stop(canceled: false);
      lumen.setReducedMotion(reducedMotion: true);
    }
  }

  @override
  void dispose() {
    // The subscription first: `dispose()` on a controller clears its listeners,
    // and clearing ours before that keeps `notifyListeners` from firing into a
    // half-disposed notifier.
    _disposed = true;
    _sources.removeListener(_onSourceChanged);
    // The scene first: it holds a listener on `lumen`, and `lumen.dispose()`
    // clears the clock's listeners — so the scene has to let go before the
    // clock does.
    lumenScene.dispose();
    // Before its ticker, or the clock's own `dispose` would remove a listener
    // from a controller that is already gone.
    lumen.dispose();
    float.dispose();
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
    this.now,
    this.budget,
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

  /// The wall clock the **vespers auto-dim** reads.
  ///
  /// `null` — the default — is the real wall clock. **A test injects a fixed
  /// one**, because the ambient's target carries the vespers factor
  /// (`eva/redesign.html:890` — `const vesp=vespersOn&&isNight()?0.78:1;`) and
  /// a golden captured at 09:00 would be a different frame at 22:00. The
  /// background's sixteen goldens are captured through this harness, so the
  /// hour they were captured at is now a **fact about the harness** rather
  /// than a fact about the night the suite ran.
  ///
  /// **The reader's switch is not involved.** `LumenPreferences.vespersAutoDim`
  /// carries it, and the harness's fixed hour is only *which* hour the factor
  /// is computed for.
  final DateTime Function()? now;

  /// How often the ambient may paint and notify.
  ///
  /// **`null` resolves it from the platform's own display**, which is where
  /// the cap belongs: a 120 Hz panel can paint four times as often as a 60 Hz
  /// one, and the budget is what stops the ambient from taking the invitation.
  ///
  /// **And a caller may pass one**, which is how the suite asserts the
  /// budget's own behaviour without a display.
  final AmbientTickBudget? budget;

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
    final AnimationController lumenTicker = AnimationController(
      vsync: this,
      duration: kLumenClockPeriod,
      // `preserve` for the same reason as the three above, and it matters more
      // here: `AnimationBehavior.normal` multiplies the *duration* by
      // `disableAnimationsFactor`, and this controller's duration is not read at
      // all — `TickedLumenClock` reads `lastElapsedDuration`, which the ticker
      // owns and no behaviour rewrites. So the flag is not about correctness for
      // the shader clock; it is about the controllers above the scope not
      // being collapsed to one frame by an addition to the list.
      animationBehavior: AnimationBehavior.preserve,
    );
    final EvaNeuralMotion motion = EvaNeuralMotion(
      float: float,
      lumen: TickedLumenClock(ticker: lumenTicker),
      now: widget.now,
      // **The platform's own display**, resolved once per scope — and the
      // scope is mounted **once**, above `MaterialApp`, so it is resolved
      // once for the life of the process.
      budget: widget.budget ?? AmbientTickBudget.resolveForPlatform(),
    );
    // **Unconditionally, and not only when the clocks are enabled.**
    //
    // The shader clock's *held at zero* state is a state, not an absence: a
    // scope built with motion reduced must hold `u_time` at zero from its
    // first frame, and the way to say that is to state it. Leaving the
    // bundle untouched would make the clock read zero for the wrong reason —
    // "the ticker never started" rather than "the reader asked for reduced
    // motion" — and the difference is invisible in the number and decisive
    // in the next reader's understanding of it.
    motion.setAnimationsEnabled(enabled: _enabled);
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
    // The controllers are disposed **here**, by the host that owns the
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
