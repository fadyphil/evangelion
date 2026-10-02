import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// The three shared controllers app-wide, plus the pointer offset.
///
/// §13.2, mitigation 2: the prototype declares 3–4 orbs per screen each with
/// independent `floatDur` / `hueDur`, which is eight screens × 4 orbs × 2
/// animations = **64** animations. This collapses to **three** [AnimationController]s
/// — float, hue, aurora — created once, above `MaterialApp`, published by
/// [NeuralMotionScope] and never recreated per screen.
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
/// each of the four sources, one [notifyListeners] per change, and
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
/// periods**, and a period is a property of a controller. With three controllers
/// there is no way to honour twenty-two of them, and no amount of cleverness
/// changes that: one clock has one rate. §13.2 anticipates exactly this and
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
  }) {
    _sources = Listenable.merge(<Listenable>[float, hue, aurora, pointer]);
    _sources.addListener(_onSourceChanged);
  }

  late final Listenable _sources;

  bool _notifiedThisFrame = false;
  bool _disposed = false;

  /// Coalesces the four sources into **one** notification per frame.
  ///
  /// ## WHY COALESCING IS NOT OPTIONAL HERE
  ///
  /// Three `repeat()`ing controllers each fire their own listener every frame,
  /// so a naive forward fires `notifyListeners` **three times per frame** and the
  /// `ListenableBuilder` in `neural_background.dart` rebuilds the painter three
  /// times for one visual update. That is the churn §13's collapse to three
  /// controllers was supposed to *remove*, reintroduced one layer up.
  ///
  /// Nothing is lost by dropping the second and third. All three tickers run in
  /// the same `transientCallbacks` pass, before the build and paint phases, so by
  /// the time the painter reads `floatValue` / `hueValue` / `auroraValue` every
  /// clock has already advanced. The first notification is therefore a complete
  /// one, and the flag is cleared in a post-frame callback — the end of the same
  /// frame, not the start of the next.
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
  /// A [ValueNotifier] rather than a fourth controller: it is not a clock, it is
  /// a position, and it settles. The prototype lerps it towards the target at
  /// 0.05 per frame (`ds.tsx:143-144`); Flutter's [Listener] reports a pointer
  /// position directly, so the smoothing would be the *only* thing missing and
  /// it is deliberately not added — see the D3 note in this class's doc for the
  /// same reason the durations are not honoured.
  final ValueNotifier<Offset> pointer;

  /// The listenable that fires whenever any of the three clocks advances or the
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

  /// Starts or stops all three clocks together.
  ///
  /// ## WHY THIS IS HERE AND NOT ONLY A TIER DECISION
  ///
  /// [NeuralTiers.resolve] drops the *painted* layers to nothing when the user
  /// has asked for reduced motion, and that is the requirement. This is the
  /// other half: three controllers left `repeat()`ing under a background that
  /// draws none of them are three tickers burning frames for a decision that has
  /// already been made. [NeuralMotionScope] exposes it so the composition root
  /// can turn the clock off outright rather than pay for a background it will
  /// not show.
  ///
  /// Stopping rather than setting `value` to zero: a reduced-motion user should
  /// get a still background, not one snapped to the top of its cycle, and
  /// `stop(canceled: false)` leaves each clock wherever it had got to.
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
    } else {
      float.stop(canceled: false);
      hue.stop(canceled: false);
      aurora.stop(canceled: false);
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
    float.dispose();
    hue.dispose();
    aurora.dispose();
    super.dispose();
  }
}

/// Hosts the three shared controllers and publishes them to the tree.
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

  /// Whether the three clocks run at all.
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
  /// over it. Phase 5 replaces the default with the persisted `UserSettings`
  /// value, and the observer has to survive that.
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
    final EvaNeuralMotion motion = EvaNeuralMotion(
      float: float,
      hue: hue,
      aurora: aurora,
      pointer: ValueNotifier<Offset>(Offset.zero),
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
    // The three controllers are disposed **here**, by the host that owns the
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
