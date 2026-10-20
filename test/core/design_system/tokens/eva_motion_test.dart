import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/css_reference.dart';

/// Every curve in the table must be pinned at both ends, or an animation driven
/// by it settles short of — or before — its target.
void expectProperEndpoints(Curve curve, String name) {
  expect(curve.transform(0.0), 0.0, reason: '$name.transform(0)');
  expect(curve.transform(1.0), 1.0, reason: '$name.transform(1)');
}

// ---------------------------------------------------------------------------
// The redesign's route transition.
//
// Two halves, deliberately apart:
//
// * **the prototype half** reads `eva/redesign.html` and checks the *tokens*
//   against the CSS that states them, so a change in the prototype makes the
//   suite red;
// * **the widget half** drives the builder and measures what it *renders*, so
//   a token that is right and a builder that ignores it are two different
//   defects and only the second half can tell them apart.
//
// The prototype is read at **test time** rather than transcribed into a table,
// because a transcribed table is a second copy of the prototype and the copy
// is what goes stale. The path is overridable so the negative control can
// point the suite at a *scratch copy* outside the repository — see
// [kPrototypePath].
// ---------------------------------------------------------------------------

/// The prototype this suite reads.
///
/// **The seam the negative control uses.** The default is the repository's own
/// `eva/redesign.html`, which is read-only reference material; a violation is
/// planted in a scratch copy *outside* the repository and the suite is pointed
/// at it with
///
/// ```bash
/// flutter test test/core/design_system/tokens/eva_motion_test.dart \
///   --dart-define=EVA_PROTOTYPE=/tmp/opencode/redesign-mutated.html
/// ```
///
/// so the red is demonstrated without the prototype in the repository ever
/// being modified. A suite that can only be made red by editing the file it
/// guards is a suite that will not be made red by anyone.
const String kPrototypePath = String.fromEnvironment(
  'EVA_PROTOTYPE',
  defaultValue: 'eva/redesign.html',
);

/// The route the probes are pumped at.
///
/// **400 logical pixels wide, deliberately.** The redesign's route poses are
/// **percentages of the route's width** and its tab poses are **absolute
/// pixels**, so a width is needed at which the two units are distinguishable:
/// 38% of 400 is 152 and 38 pixels is 38, and a builder that confused a
/// fraction with a pixel count would be wrong by 4×.
const double kRouteWidth = 400;

/// The route's height.
///
/// Part of the expected geometry and not decoration: the poses scale about the
/// route's **centre**, so the height decides where the top of the scaled page
/// lands.
const double kRouteHeight = 600;

/// The key on the page the probes measure.
const Key kPageKey = ValueKey<String>('eva-motion-probe-page');

/// The `translateX(N%)` a CSS `transform` states, as a signed percentage.
///
/// Throws, for the same reason `css_reference.dart`'s readers throw: a
/// pattern that stops matching must be a **failure** and never a pass over
/// nothing.
double _translateXPercent(String transform) {
  final RegExpMatch? match = RegExp(r'translateX\((-?[\d.]+)%\)')
      .firstMatch(transform);
  if (match == null) {
    throw StateError('"$transform" states no translateX(…%)');
  }
  return double.parse(_group(match, 1));
}

/// The `translateY(Npx)` a CSS `transform` states, in logical pixels.
double _translateYPixels(String transform) {
  final RegExpMatch? match = RegExp(r'translateY\((-?[\d.]+)px\)')
      .firstMatch(transform);
  if (match == null) {
    throw StateError('"$transform" states no translateY(…px)');
  }
  return double.parse(_group(match, 1));
}

/// The `scale(N)` a CSS `transform` states.
double _scaleOf(String transform) {
  final RegExpMatch? match = RegExp(r'scale\(([\d.]+)\)').firstMatch(transform);
  if (match == null) {
    throw StateError('"$transform" states no scale(…)');
  }
  return double.parse(_group(match, 1));
}

/// The [index]-th capture group of [match].
///
/// The patterns in this file capture inside groups that cannot be empty, so
/// a null here would mean the pattern and this reader had come apart — which
/// is a **failure**, and reported as one rather than papered over with a `!`.
String _group(RegExpMatch match, int index) {
  final String? group = match.group(index);
  if (group == null) {
    throw StateError('the pattern matched but captured nothing at $index');
  }
  return group;
}

/// The value [property] declares in [rule].
///
/// Throws rather than returning null: a rule that stopped declaring the
/// property is a prototype that moved, and the row citing it is asserting
/// air.
String _property(Map<String, String> rule, String property) {
  final String? value = rule[property];
  if (value == null) {
    throw StateError('the rule states no `$property`');
  }
  return value;
}

/// Every timing a CSS `transition` list states, in milliseconds.
List<double> _transitionMilliseconds(String transition) {
  final List<double> timings = <double>[
    for (final RegExpMatch match in RegExp(r'([\d.]+)s').allMatches(transition))
      double.parse(_group(match, 1)) * 1000,
  ];
  if (timings.isEmpty) {
    throw StateError('"$transition" states no timing in seconds');
  }
  return timings;
}

/// The prototype's `--e-light` bezier, as a curve.
///
/// The value is read out of the stylesheet and **transcribed into a `Cubic`**,
/// so the comparison is against the prototype's own curve and not against a
/// copy of it. `:18` declares `--e-light:cubic-bezier(.16,1,.3,1)`.
Curve _lightCurve(CssDeclaration declaration) {
  final RegExpMatch? match = RegExp(
    r'cubic-bezier\(([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)\)',
  ).firstMatch(declaration.value);
  if (match == null) {
    throw StateError(
      '--e-light is "${declaration.value}", which is not a cubic-bezier this '
      'suite can read. If the prototype changed the curve\'s spelling, the '
      'comparison against it has to be re-derived rather than guessed.',
    );
  }
  return Cubic(
    double.parse(_group(match, 1)),
    double.parse(_group(match, 2)),
    double.parse(_group(match, 3)),
    double.parse(_group(match, 4)),
  );
}

/// `Curves.easeOutExpo`'s own four control points.
///
/// `Curves.easeOutExpo` is `Cubic(0.19, 1.0, 0.22, 1.0)`
/// (`animation/curves.dart:1706`), and a `Cubic`'s four numbers **are** a css
/// `cubic-bezier()`'s four control points — which is what makes the css
/// evaluator below applicable to it.
const ({double x1, double y1, double x2, double y2}) _easeOutExpoControlPoints =
    (x1: 0.19, y1: 1.0, x2: 0.22, y2: 1.0);

/// The four control-point numbers a CSS `cubic-bezier()` declares.
({double x1, double y1, double x2, double y2}) _bezierControlPoints(
  CssDeclaration declaration,
) {
  final RegExpMatch? match = RegExp(
    r'cubic-bezier\(([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)\)',
  ).firstMatch(declaration.value);
  if (match == null) {
    throw StateError('--e-light is "${declaration.value}", not a bezier');
  }
  return (
    x1: double.parse(_group(match, 1)),
    y1: double.parse(_group(match, 2)),
    x2: double.parse(_group(match, 3)),
    y2: double.parse(_group(match, 4)),
  );
}

/// A CSS `cubic-bezier()` evaluated **the way a browser evaluates it**.
///
/// ## WHY THIS EVALUATOR AND NOT `Cubic.transform`
///
/// CSS Timing Functions Level 1 defines the timing function as a cubic bezier
/// and evaluates it with a **polynomial approximation**: the parametric `t` is
/// found from the x-curve and the y-curve is read at that `t`, with the
/// coefficients assembled as
///
/// ```text
/// cx = 3·x1   bx = 3·(x2 - x1) - cx   ax = 1 - cx - bx
/// cy = 3·y1   by = 3·(y2 - y1) - cy   ay = 1 - cy - by
/// sampleX(t) = ((ax·t + bx)·t + cx)·t
/// sampleY(t) = ((ay·t + by)·t + cy)·t
/// ```
///
/// Flutter's `Cubic.transform` does the same thing **by bisection to a
/// tolerance**, so its samples are *quantised* — visibly so: the same input
/// can return the same output twice and the next input can return a different
/// one.
///
/// **The difference matters because the two curves are being compared, and the
/// quantisation is largest exactly where the curve is steepest — which is
/// where the two curves differ most.** Measured with Flutter's evaluator the
/// same pair of curves is **3.08%** apart; measured with CSS's own evaluator,
/// which is what a browser draws, it is **2.53%** apart. The recorded figure
/// in `eva_motion.dart` is the second one, and the first attempt at this test
/// used the first evaluator and read a number that looked like a
/// contradiction.
///
/// So this function exists to make the recorded number **reproducible**, and
/// the test below uses it for exactly that.
double _cssBezier(
  ({double x1, double y1, double x2, double y2}) control,
  double x,
) {
  final double cx = 3 * control.x1;
  final double bx = 3 * (control.x2 - control.x1) - cx;
  final double ax = 1 - cx - bx;
  final double cy = 3 * control.y1;
  final double by = 3 * (control.y2 - control.y1) - cy;
  final double ay = 1 - cy - by;

  // `sampleX` is monotone on [0, 1], so a bisection finds the parametric `t`
  // for this `x`.
  double lo = 0;
  double hi = 1;
  for (int i = 0; i < 64; i++) {
    final double mid = (lo + hi) / 2;
    final double sampleX = ((ax * mid + bx) * mid + cx) * mid;
    if (sampleX < x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final double t = (lo + hi) / 2;
  return ((ay * t + by) * t + cy) * t;
}

/// The widest gap between two curves, and where it is.
///
/// Sampled on a fine grid, because the quantity is a maximum over a
/// continuum and a coarse grid is a different measurement.
({double gap, double at}) _widestGap(
  double Function(double x) a,
  double Function(double x) b,
) {
  double worst = 0;
  double at = 0;
  for (double x = 0; x <= 1.0000001; x += 0.0001) {
    final double sample = x > 1 ? 1.0 : x;
    final double gap = (a(sample) - b(sample)).abs();
    if (gap > worst) {
      worst = gap;
      at = sample;
    }
  }
  return (gap: worst, at: at);
}

/// The prototype's stylesheet, parsed.
///
/// Throws rather than returning null, so a missing or unreadable prototype is
/// a **failure** and never a pass over an empty table.
CssReference _reference() {
  final CssReference? reference = CssReference.fromFile(File(kPrototypePath));
  if (reference == null) {
    throw StateError(
      '$kPrototypePath could not be read, so this suite cannot check the '
      'numbers it was written for. A missing reference is reported, never '
      'assumed unchanged.',
    );
  }
  return reference;
}

/// The prototype's declaration of [token], resolved.
CssDeclaration _declaration(String token) {
  final CssDeclaration? declaration = _reference().declaration(token);
  if (declaration == null) {
    throw StateError(
      'the prototype no longer declares --$token, so the rows that cite it are '
      'asserting air.',
    );
  }
  return declaration;
}

/// Invokes [builder] through **Flutter's own** `RouteTransitionsBuilder`
/// shape.
///
/// **The call is the check.** `RouteTransitionsBuilder` is the framework's
/// typedef for the shape `PageRoute` and auto_route's
/// `RouteType.custom(transitionsBuilder:)` expect, so handing
/// [EvaMotion.goneSlide] to a parameter of that type proves the signature
/// matches at **compile** time — the earliest and loudest form of failure
/// available, and the one `AppRouter.defaultRouteType` relies on.
///
/// It is deliberately **not** a runtime assertion on top of the assignment: a
/// matcher comparing a value with itself proves nothing, which is why
/// `eva_motion_transition_test.dart` records the same decision for
/// `fadeSlide`.
Widget _invokeRouteBuilder(
  RouteTransitionsBuilder builder,
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => builder(context, animation, secondaryAnimation, child);

/// Invokes [builder] through **auto_route's own**
/// `AnimatedIndexedStackTransitionBuilder` shape.
///
/// The same argument as [_invokeRouteBuilder], for the other hook:
/// `AutoTabsRouter.transitionBuilder` wants
/// `Widget Function(BuildContext, Widget, Animation<double>)`
/// (`auto_tabs_router.dart:18`), which is a **different** shape from
/// `RouteTransitionsBuilder`'s — different order, different arity — and a
/// builder written for one cannot be handed to the other.
Widget _invokeTabBuilder(
  AnimatedIndexedStackTransitionBuilder builder,
  BuildContext context,
  Widget child,
  Animation<double> animation,
) => builder(context, child, animation);

/// Pumps [EvaMotion.goneSlide] over a page, with the two animations at
/// [enter] and [covered].
///
/// The two animations are **real `AnimationController`s**, not
/// `AlwaysStoppedAnimation`s, so the builder is driven the way a route drives
/// it — a controller that ticks — rather than being handed a constant. Their
/// values are set directly so the geometry being asserted is the geometry at
/// an **exact** instant, and not "somewhere during the transition".
///
/// The two controllers are **returned** so a test can wind them the way the
/// framework winds them — a pop runs the route's `animation` from 1 to 0 and
/// the route below's `secondaryAnimation` from 1 to 0 — and read the geometry
/// at each end of that movement.
///
/// [loose] gives the builder **loose** constraints instead of the tight ones a
/// real route hands its page. That is the seam that makes "a fraction of the
/// route's width" and "a fraction of the child's own size" two different
/// implementations: with loose constraints the page can be narrower than the
/// route, and the two readings then disagree.
Future<({AnimationController enter, AnimationController covered})> _pumpRoute(
  WidgetTester tester, {
  required double enter,
  required double covered,
  bool disableAnimations = false,
  Widget page = const SizedBox.expand(key: kPageKey),
  bool loose = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(kRouteWidth, kRouteHeight);
  addTearDown(tester.view.reset);

  final AnimationController enterController = AnimationController(
    vsync: const TestVSync(),
    duration: EvaMotion.routeTransition,
  );
  final AnimationController coveredController = AnimationController(
    vsync: const TestVSync(),
    duration: EvaMotion.routeTransition,
  );
  addTearDown(enterController.dispose);
  addTearDown(coveredController.dispose);
  enterController.value = enter;
  coveredController.value = covered;

  Widget route = Builder(
    builder: (BuildContext context) => _invokeRouteBuilder(
      EvaMotion.goneSlide,
      context,
      enterController,
      coveredController,
      page,
    ),
  );
  if (loose) {
    route = Align(alignment: Alignment.topLeft, child: route);
  }

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(kRouteWidth, kRouteHeight),
        disableAnimations: disableAnimations,
      ),
      child: Directionality(textDirection: TextDirection.ltr, child: route),
    ),
  );

  return (enter: enterController, covered: coveredController);
}

/// Pumps [EvaMotion.tabSwap] over a page, with the animation at [value].
Future<void> _pumpTab(
  WidgetTester tester, {
  required double value,
  bool disableAnimations = false,
  Widget page = const SizedBox.expand(key: kPageKey),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(kRouteWidth, kRouteHeight);
  addTearDown(tester.view.reset);

  final AnimationController controller = AnimationController(
    vsync: const TestVSync(),
    duration: EvaMotion.tabTransition,
  );
  addTearDown(controller.dispose);
  controller.value = value;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(kRouteWidth, kRouteHeight),
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (BuildContext context) =>
              _invokeTabBuilder(EvaMotion.tabSwap, context, page, controller),
        ),
      ),
    ),
  );
}

/// The horizontal translation the builder's **outer** `Transform` applies, in
/// logical pixels.
///
/// The outer transform is the translation and the inner one is the scale —
/// that is the order CSS composes `transform:translateX(…) scale(…)` in, and
/// reading them in the wrong order would swap the two numbers this suite is
/// about.
double _appliedTranslationX(WidgetTester tester) => tester
    .widget<Transform>(find.byType(Transform).first)
    .transform
    .storage[12];

/// The uniform scale the builder's **inner** `Transform` applies.
double _appliedScale(WidgetTester tester) =>
    tester.widget<Transform>(find.byType(Transform).last).transform.storage[0];

/// The vertical translation the builder's outer `Transform` applies, in
/// logical pixels.
double _appliedTranslationY(WidgetTester tester) => tester
    .widget<Transform>(find.byType(Transform).first)
    .transform
    .storage[13];

/// The opacity the builder applies.
double _appliedOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;

/// The **painted** rect of the page, in global coordinates.
///
/// `getRect` resolves through the render object's transform, so this is where
/// the page is *drawn* — the composed translation and the composed scale —
/// and not where it was laid out.
Rect _pageRect(WidgetTester tester) => tester.getRect(find.byKey(kPageKey));

void main() {
  group('durations', () {
    test('are the four fixed values from the spec table', () {
      // §5.3: fast 150ms · base 200ms · screen 250ms · fleck 2000ms · aurora 14s.
      //
      // **The aurora's 14s is gone** — it was the OLD design's aurora *band*,
      // and the band died with the orbs. The shader's clock is not a token at
      // all: it is `LumenClock`'s, and it is measured in elapsed seconds.
      expect(EvaMotion.fast, const Duration(milliseconds: 150));
      expect(EvaMotion.base, const Duration(milliseconds: 200));
      expect(EvaMotion.screen, const Duration(milliseconds: 250));
      expect(EvaMotion.fleck, const Duration(seconds: 2));
    });

    test('are ordered fast < base < screen', () {
      // A "fast" that outlasts a "screen" transition means the two roles have
      // been crossed somewhere, and nothing else in the system would say so.
      expect(EvaMotion.fast, lessThan(EvaMotion.base));
      expect(EvaMotion.base, lessThan(EvaMotion.screen));
    });

    test('the interaction durations stay under a quarter second', () {
      // Not a spec value — a budget this phase commits to so the numbers cannot
      // drift upward one at a time. A tap feedback longer than 250ms reads as
      // lag, and `09-quality-gates.md` §13 counts each blurred surface as a
      // saveLayer, so a slow animation here is also a battery cost.
      expect(
        EvaMotion.screen,
        lessThanOrEqualTo(const Duration(milliseconds: 250)),
      );
    });

    test('the ambient durations are seconds, not milliseconds', () {
      // The two categories must not be confused. A fleck that lasts 2000ms is
      // visible motion; the spec's 2000ms is deliberate. Asserting the unit is
      // what catches a `seconds` token written as `milliseconds`.
      //
      // **The orb/aurora entries are gone** — the orbs and the old aurora band
      // are retired, and the shader's clock is elapsed seconds by construction
      // rather than by a token.
      expect(EvaMotion.fleck.inMilliseconds, 2000);
    });
  });

  group('the per-orb duration ranges', () {});

  group('curves', () {
    test('fast and base are ease-out — fast off the mark, slow to settle', () {
      // Asserted SHAPE, not identity. `expect(EvaMotion.fastCurve,
      // Curves.easeOut)` would compare the canonicalised `Curves.easeOut` against
      // itself whenever the token is written as that same constant, so it would
      // hold for any implementation that returned *a* curve. The shape is what
      // actually distinguishes ease-out: most of the distance is covered early.
      for (final MapEntry<String, Curve> entry in <String, Curve>{
        'fast': EvaMotion.fastCurve,
        'base': EvaMotion.baseCurve,
      }.entries) {
        expect(
          entry.value.transform(0.25),
          greaterThan(0.25),
          reason: entry.key,
        );
        expect(entry.value.transform(0.5), greaterThan(0.5), reason: entry.key);
        expect(
          entry.value.transform(0.5),
          closeTo(Curves.easeOut.transform(0.5), 1e-12),
          reason: '${entry.key} must be easeOut exactly, not merely ease-ish',
        );
      }
    });

    test('every curve is pinned at 0 and 1', () {
      // **The orbs' two curves are gone** — `orbFloatCurve` and `orbHueCurve`
      // died with the orbs, and the old aurora band's `auroraCurve` with the
      // band. What is left is the set of curves the app still draws with, and
      // the rule is unchanged: a `Curve` maps [0,1] onto [0,1], and a curve
      // that did not would put the widget's own geometry outside its range.
      expectProperEndpoints(EvaMotion.fastCurve, 'fastCurve');
      expectProperEndpoints(EvaMotion.baseCurve, 'baseCurve');
      expectProperEndpoints(EvaMotion.screenCurve, 'screenCurve');
      expectProperEndpoints(EvaMotion.fleckCurve, 'fleckCurve');
    });

    test('the fleck curve is ease-out, and its DIRECTION is the triangle\'s', () {
      // "fleck | 2000ms | alternate". `alternate` is a DIRECTION, not a shape —
      // in Flutter it is `AnimationController.repeat(reverse: true)`, and there
      // is no `Curves.alternate`. So the curve is the ease-out shape the brief's
      // "all curves are ease-out" rule requires.
      //
      // **AND THE DIRECTION IS NOT A TOKEN.** There was one — `fleckAlternates`
      // — and it said "Phase 2 reads this to choose `repeat(reverse: true)` over
      // `repeat()`", and **Phase 2 came and went without reading it**. The
      // flecks' there-and-back is built by `goldFleckTriangle` instead, from
      // the float clock's sawtooth, so the direction is the widget's arithmetic
      // and not a token. The token is deleted; `gold_flecks_test.dart` pins the
      // triangle.
      //
      // `Curves.easeOut` at t = 0.5 — the value that separates it from
      // easeOutCubic's 0.599 and from linear's 0.5.
      expect(EvaMotion.fleckCurve.transform(0.5), closeTo(0.68359375, 1e-12));
      expect(
        EvaMotion.fleckCurve.transform(0.5),
        isNot(closeTo(EvaMotion.screenCurve.transform(0.5), 1e-6)),
        reason: 'the fleck must not inherit the screen transition\u2019s curve',
      );
    });

    test('no curve is a spring or a bounce', () {
      // Two claims, and Phase 0 changed one of them.
      //
      // STILL TRUE: every entry in this map is a `Curve`, and a `Curve` maps
      // [0,1] onto [0,1] — it cannot overshoot by construction. An overshooting
      // curve puts y outside the range, so this test pins that none of them does.
      //
      // NO LONGER THE WHOLE RULE: "No bounce, no spring — matching the brief's
      // motion rule" was the design brief's wording and it is now partly
      // superseded. `EvaMotion.achievementSpring` IS a spring, deliberately, for
      // achievement moments. It is **not in this map and must never be added to
      // it**, because it is a `SpringDescription` rather than a `Curve` and its
      // whole point is that it leaves [0,1]. Its overshoot is asserted on its own
      // terms in the `achievement spring` group below.
      //
      // **The orbs' three curves are gone**, so the map is what the app still
      // draws with.
      for (final MapEntry<String, Curve> entry in <String, Curve>{
        'fast': EvaMotion.fastCurve,
        'base': EvaMotion.baseCurve,
        'screen': EvaMotion.screenCurve,
        'fleck': EvaMotion.fleckCurve,
        // The Phase 0 routine curve. It belongs in this family and is asserted
        // here precisely because it must stay **monotone** — see the next test.
        'interactive': EvaMotion.interactiveCurve,
      }.entries) {
        double previous = 0.0;
        for (double t = 0.0; t <= 1.0; t += 0.05) {
          final double y = entry.value.transform(t);
          expect(y, inInclusiveRange(0.0, 1.0), reason: '${entry.key} at t=$t');
          expect(
            y,
            greaterThanOrEqualTo(previous),
            reason: '${entry.key} at t=$t',
          );
          previous = y;
        }
      }
    });

    test('screen is easeOutCubic, which is steeper than easeOut', () {
      // The two numbers are `Curves.easeOutCubic` (cubic-bezier(.33, 1, .68, 1))
      // at t = 0.25 and t = 0.75, and `Curves.easeOut` at the same t. They are
      // 0.599 and 0.976 against 0.378 — far enough apart that swapping
      // `screenCurve` for `fastCurve`, or for `easeIn`, cannot pass, and pinned
      // tightly enough (1e-12) that no other shipped curve lands on them.
      expect(
        EvaMotion.screenCurve.transform(0.25),
        closeTo(0.5991595584154129, 1e-12),
      );
      expect(
        EvaMotion.screenCurve.transform(0.75),
        closeTo(0.9760727959871291, 1e-12),
      );
      expect(
        EvaMotion.screenCurve.transform(0.25),
        greaterThan(EvaMotion.fastCurve.transform(0.25)),
        reason: 'easeOutCubic must outrun easeOut early on',
      );
    });
  });

  group('the achievement spring', () {
    // ## WHY THESE ARE MEASURED RATHER THAN READ OFF THE TOKENS
    //
    // `SpringDescription.withDurationAndBounce` derives stiffness as
    // `4π²/duration²` from a **nominal** duration that is not the settle time.
    // The token file's first draft called its 420ms input `achievementSettleHint`
    // and claimed it was "roughly how long the spring takes to look finished";
    // driven and measured, that was false by nearly 2× (~796ms). So the
    // relationships below are properties of the spring, they live here rather than
    // in `eva_motion.dart`, and they are measured by driving a real
    // `SpringSimulation` — not asserted against the token that produced them.
    //
    // A test that read `expect(EvaMotion.achievementDuration, someDuration)` would
    // be the reading-scrim mistake again: a wrong number asked to confirm itself.

    /// Drives the token's spring from 0 to 1 and reports what it actually did.
    ({double peak, double settledAt}) drive() {
      final SpringSimulation sim = SpringSimulation(
        EvaMotion.achievementSpring,
        0,
        1,
        0,
      );
      double peak = 0.0;
      double settledAt = 0.0;
      // 4ms steps: `isDone` is tolerance-based, so the resolution here decides the
      // measured numbers below. Coarser sampling flattens the differences the table
      // in `eva_motion.dart` records.
      for (double t = 0.0; t <= 2.0; t += 0.004) {
        final double x = sim.x(t);
        if (x > peak) peak = x;
        if (sim.isDone(t)) {
          settledAt = t;
          break;
        }
      }
      return (peak: peak, settledAt: settledAt);
    }

    test('overshoots, which is the only reason it is not a curve', () {
      expect(EvaMotion.achievementOvershoots, isTrue);
      expect(EvaMotion.achievementDampingRatio, closeTo(0.62, 0.005));

      final double peak = drive().peak;
      // ~8.3% measured. The point of the assertion is the *sign* — a peak below 1.0
      // would mean this is a curve wearing a spring's name — plus a ceiling, so a
      // future `bounce` bump cannot quietly turn a pop into a trampoline.
      expect(peak, greaterThan(1.0), reason: 'must actually pass its target');
      expect(peak, lessThan(1.15), reason: 'must stay restrained');
    });

    test('settles inside the budget a complex transition is allowed', () {
      final double settledAt = drive().settledAt * 1000;
      // 140ms nominal measures ~350ms. The rule a complex transition answers to is
      // "≤400ms", so this is the assertion that the *nominal* token was chosen
      // correctly — and it is why the token is 140 and not the 420 it started as.
      expect(
        settledAt,
        lessThan(400),
        reason: 'a 420ms nominal settles at ~796ms and blows the budget',
      );
      expect(
        settledAt,
        greaterThan(200),
        reason: 'a spring that snaps reads as a step',
      );
    });

    test('the exit is faster than the entrance it follows', () {
      // Asserted against the spring's **measured** settle rather than against
      // `achievementDuration`, because comparing two nominals would prove nothing:
      // 220ms < 140ms is false, while 220ms < ~350ms is true, and only the second is
      // the claim being made. ~63% of the entrance.
      final double settledAt = drive().settledAt * 1000;
      expect(EvaMotion.achievementExit.inMilliseconds, lessThan(settledAt));
      expect(
        EvaMotion.achievementExit.inMilliseconds / settledAt,
        inInclusiveRange(0.55, 0.75),
      );
    });

    test('the nominal is NOT the settle time, so the two names differ', () {
      // A regression guard on the rename. If someone folds `achievementDuration`
      // back into a name claiming to be the settle time, this fails — because the
      // two genuinely are different numbers, by ~2×.
      expect(
        EvaMotion.achievementDuration.inMilliseconds,
        lessThan(drive().settledAt * 1000),
      );
    });
  });

  group('the achievement curve', () {
    // ## WHY THE CURVE AND THE SPRING BOTH EXIST
    //
    // `flutter_animate`'s `EffectEntry.buildAnimation` wraps its controller in
    // `Interval(begin / controller.duration, end / controller.duration)`. A spring's
    // value exceeds 1.0 by design, and feeding that into the interval trips
    // `ParametricCurve`'s `t >= 0.0 && t <= 1.0` assertion inside `Curves.transform`.
    // So a `SpringSimulation` cannot go through `Animate` at all — not "loses its
    // overshoot", **throws**. `achievementCurve` is what an `Animate`-driven effect
    // uses instead.
    //
    // That leaves two mechanisms that could drift apart on feel, so the pairing is
    // asserted rather than hoped for.

    /// Peak value [curve] reaches above its target, as a fraction.
    double overshootOf(Curve curve) {
      double peak = 0.0;
      for (double t = 0.0; t <= 1.0; t += 0.001) {
        final double y = curve.transform(t);
        if (y > peak) peak = y;
      }
      return peak - 1.0;
    }

    test(
      'ends at exactly 1.0, which is what makes it safe through Animate',
      () {
        expect(EvaMotion.achievementCurve.transform(1.0), 1.0);
        expectProperEndpoints(EvaMotion.achievementCurve, 'achievementCurve');
      },
    );

    test('overshoots, unlike the routine curve', () {
      expect(
        overshootOf(EvaMotion.achievementCurve),
        greaterThan(0.0),
        reason: 'the whole reason it is not interactiveCurve',
      );
      // ~8.7% measured. The ceiling is the point: `Curves.elasticOut` measures 27.5%
      // and reads as a glitch on a flame meant to look like it caught.
      expect(overshootOf(EvaMotion.achievementCurve), lessThan(0.15));
    });

    test('the curve and the spring overshoot by the same amount', () {
      // ~8.7% curve vs ~8.3% spring. They are different mechanisms; if they ever
      // stopped *feeling* the same, the flame would pop differently from everything
      // else celebrating the same event.
      expect(
        (overshootOf(EvaMotion.achievementCurve) - 0.083).abs(),
        lessThan(0.015),
      );
    });

    test('the routine curve is monotone, so the two families stay distinct', () {
      // `closeTo`, not `0.0`: `easeOutExpo` lands at 1.0 minus ~1.2e-10, which is
      // float noise in a bezier evaluation, not an undershoot. Asserting exact
      // equality would be asserting the arithmetic of a polynomial.
      expect(overshootOf(EvaMotion.interactiveCurve), closeTo(0.0, 1e-6));
      // Deliberately **no** `isNot(same(...))` between the two curves. It would only
      // prove they are not the same object, which the overshoot assertions already
      // prove the stronger way: a token aliased to another would pass `same()` and
      // fail there. It would also have to be registered in
      // `no_identical_on_converted_types_test.dart`'s audit table, which is a
      // permanent cost for no extra coverage.
    });
  });

  group('the redesign\'s route transition — the prototype\'s own numbers', () {
    // ## WHY THE PROTOTYPE IS READ AT TEST TIME
    //
    // A table of transcribed numbers is a **second copy** of the prototype,
    // and the copy is what goes stale. So the numbers below are read out of
    // `eva/redesign.html` at the moment the test runs, and the *tokens* are
    // asserted against what the file says. A change in the prototype makes
    // this group red, which is the whole point of reading it rather than
    // transcribing it.
    //
    // `css_reference.dart`'s `cssRule` resolves a selector to its
    // declarations and **throws** when the selector is gone, so a renamed or
    // deleted rule is a failure and never a pass over nothing.

    test('the route poses are the prototype\'s own percentages and scales', () {
      final Map<String, String> goneLeft = cssRule(
        File(kPrototypePath),
        '.route.gone-left',
      );
      final Map<String, String> goneRight = cssRule(
        File(kPrototypePath),
        '.route.gone-right',
      );

      // `:129` — `.route.gone-left{transform:translateX(-28%) scale(.96);…}`
      expect(
        _translateXPercent(_property(goneLeft, 'transform')),
        -28,
        reason: '`:129` states `translateX(-28%)`',
      );
      expect(_scaleOf(_property(goneLeft, 'transform')), 0.96);
      expect(EvaMotion.goneLeftFraction, -0.28);
      expect(EvaMotion.goneLeftScale, 0.96);

      // `:130` — `.route.gone-right{transform:translateX(38%) scale(.98);…}`
      expect(
        _translateXPercent(_property(goneRight, 'transform')),
        38,
        reason: '`:130` states `translateX(38%)`',
      );
      expect(_scaleOf(_property(goneRight, 'transform')), 0.98);
      expect(EvaMotion.goneRightFraction, 0.38);
      expect(EvaMotion.goneRightScale, 0.98);
    });

    test('the tab poses are the prototype\'s own pixels and scales', () {
      final Map<String, String> tabPre = cssRule(
        File(kPrototypePath),
        '.route.tab-pre',
      );
      final Map<String, String> tabOut = cssRule(
        File(kPrototypePath),
        '.route.tab-out',
      );

      // `:132` — `.route.tab-pre{opacity:0;transform:translateY(10px) scale(.985)}`
      expect(
        _translateYPixels(_property(tabPre, 'transform')),
        10,
        reason: '`:132` states `translateY(10px)` — PIXELS, not a percentage',
      );
      expect(_scaleOf(_property(tabPre, 'transform')), 0.985);
      expect(EvaMotion.tabPreOffset, 10);
      expect(EvaMotion.tabPreScale, 0.985);

      // `:133` — `.route.tab-out{opacity:0;transform:translateY(-6px) scale(.99);…}`
      expect(
        _translateYPixels(_property(tabOut, 'transform')),
        -6,
        reason: '`:133` states `translateY(-6px)`',
      );
      expect(_scaleOf(_property(tabOut, 'transform')), 0.99);
      expect(EvaMotion.tabOutOffset, 6);
      expect(EvaMotion.tabOutScale, 0.99);
    });

    test('the transition is 400ms on --e-light, and both tokens say 400ms', () {
      final Map<String, String> route = cssRule(File(kPrototypePath), '.route');
      final String transition = _property(route, 'transition');

      // `:128` — `transition:transform .4s var(--e-light),opacity .4s var(--e-light)`
      expect(_transitionMilliseconds(transition), <double>[
        400,
        400,
      ], reason: '`:128` states the timing once per animated property');
      expect(
        transition,
        contains('var(--e-light)'),
        reason: 'the curve is `--e-light` and not a literal',
      );
      expect(EvaMotion.routeTransition, const Duration(milliseconds: 400));
      expect(
        EvaMotion.tabTransition,
        EvaMotion.routeTransition,
        reason:
            'the tab poses ride the SAME `.route` transition (`:128`); the '
            '260ms at `:1266` is the outgoing tab\'s cleanup timer, not the '
            'visible motion',
      );
    });

    test('--e-light is still the prototype\'s own bezier, on line 18', () {
      final CssDeclaration declaration = _declaration('e-light');
      expect(declaration.value, 'cubic-bezier(.16,1,.3,1)');
      expect(
        declaration.line,
        18,
        reason: '`:18` is where `:root` declares it',
      );
    });

    test('the token the builder uses is within 2.53% of that bezier', () {
      final CssDeclaration declaration = _declaration('e-light');
      final Curve exactCurve = _lightCurve(declaration);
      final ({double x1, double y1, double x2, double y2}) exact =
          _bezierControlPoints(declaration);

      // The builder uses [EvaMotion.interactiveCurve], which is the
      // repository's stand-in for `--e-light` — and `eva_motion.dart`'s own
      // doc says it is an **approximation**, not the same curve, and records
      // the measured distance. Asserted SHAPE rather than identity, for the
      // reason the group above does: `expect(a, b)` on two curves that are the
      // same object would hold for any implementation that returned *a* curve.
      expect(
        EvaMotion.interactiveCurve.transform(0.5),
        closeTo(Curves.easeOutExpo.transform(0.5), 1e-12),
        reason: 'the token IS `Curves.easeOutExpo`',
      );

      // **The recorded 2.53%, re-derived the way CSS evaluates a
      // `cubic-bezier()`** — which is the method the recorded figure was taken
      // with, and the method a browser draws with. See [_cssBezier] for why
      // the evaluator is not `Cubic.transform`.
      final ({double gap, double at}) css = _widestGap(
        (double x) => _cssBezier(exact, x),
        (double x) => _cssBezier(_easeOutExpoControlPoints, x),
      );
      expect(
        css.gap * 100,
        closeTo(2.53, 0.01),
        reason:
            'the recorded figure is "at most 2.53% of the progress", measured '
            'the way CSS evaluates a bezier',
      );
      expect(
        css.at,
        closeTo(0.054, 0.002),
        reason: 'the recorded worst case is "at x ≈ 0.054"',
      );
      expect(
        _cssBezier(exact, css.at) -
            _cssBezier(_easeOutExpoControlPoints, css.at),
        greaterThan(0.0),
        reason: 'the prototype\'s curve is AHEAD of the approximation there',
      );

      // And the same pair measured with **Flutter's** evaluator, which is what
      // this client actually renders: 3.08%, because `Cubic.transformInternal`
      // bisects to a tolerance and its samples are quantised.
      final ({double gap, double at}) flutter = _widestGap(
        exactCurve.transform,
        EvaMotion.interactiveCurve.transform,
      );
      expect(
        flutter.gap,
        lessThanOrEqualTo(0.031),
        reason:
            'Flutter\'s evaluation of the same pair measures 3.08% — the '
            'quantised bisection widens the gap where the curve is steepest',
      );
      expect(
        flutter.gap,
        greaterThan(0.02),
        reason:
            'and they are NOT the same curve — the two are within 2.53% of '
            'each other, which is why the approximation is recorded rather '
            'than hidden. A gap of zero would mean this doc\'s claim of an '
            'approximation had become false.',
      );
    });
  });

  group('the redesign\'s route transition — the widget the router mounts', () {
    // ## THE NUMBERS BELOW ARE LITERALS, NOT THE TOKENS
    //
    // The group above already checks the tokens against the CSS. This group
    // checks the **rendered** geometry against literals transcribed from that
    // CSS, so a builder that ignored its own tokens would be caught here: the
    // chain is CSS → token → pixels, and each link is checked against the one
    // before it rather than against itself.
    //
    // The route is **400px** wide, so 38% of it is 152px and 38px is 38px —
    // the two units the prototype uses are 4× apart at this width, which is
    // what makes "a fraction of the width" and "a pixel count" two different
    // implementations and not one.

    testWidgets('push: the incoming route starts at the +38% pose', (
      WidgetTester tester,
    ) async {
      await _pumpRoute(tester, enter: 0, covered: 0);

      expect(
        _appliedTranslationX(tester),
        closeTo(152, 1e-9),
        reason: '38% of a 400px route — `eva/redesign.html:130`',
      );
      expect(
        _appliedScale(tester),
        closeTo(0.98, 1e-9),
        reason: '`:130` states `scale(.98)`',
      );
      expect(_appliedOpacity(tester), 0.0, reason: '`:130` states `opacity:0`');

      // The **painted** rect: the page is scaled about the route's centre and
      // then translated, which is what CSS's `translateX(38%) scale(.98)` does
      // with its default `transform-origin: 50% 50%`.
      final Rect rect = _pageRect(tester);
      expect(
        rect.left,
        closeTo(156, 1e-9),
        reason: '4px of centring + 152px of travel',
      );
      expect(rect.top, closeTo(6, 1e-9));
      expect(rect.width, closeTo(392, 1e-9));
      expect(rect.height, closeTo(588, 1e-9));
    });

    testWidgets('and the route below moves to the -28% pose as it is covered', (
      WidgetTester tester,
    ) async {
      // `:1256` — `push` adds `gone-left` to the route being covered.
      await _pumpRoute(tester, enter: 1, covered: 1);

      expect(
        _appliedTranslationX(tester),
        closeTo(-112, 1e-9),
        reason: '28% of a 400px route — `eva/redesign.html:129`',
      );
      expect(_appliedScale(tester), closeTo(0.96, 1e-9));
      expect(_appliedOpacity(tester), 0.0);

      final Rect rect = _pageRect(tester);
      expect(
        rect.left,
        closeTo(-104, 1e-9),
        reason: '8px of centring - 112px of travel',
      );
      expect(rect.top, closeTo(12, 1e-9));
      expect(rect.width, closeTo(384, 1e-9));
      expect(rect.height, closeTo(576, 1e-9));
    });

    testWidgets('at rest the route is exactly where the layout put it', (
      WidgetTester tester,
    ) async {
      await _pumpRoute(tester, enter: 1, covered: 0);

      expect(_appliedTranslationX(tester), 0.0);
      expect(_appliedScale(tester), closeTo(1.0, 1e-12));
      expect(_appliedOpacity(tester), 1.0);
      expect(
        _pageRect(tester),
        const Rect.fromLTWH(0, 0, 400, 600),
        reason: 'a route at rest is not moved, scaled or faded at all',
      );
    });

    testWidgets('pop: the same builder plays the push backwards', (
      WidgetTester tester,
    ) async {
      // The state a **push** leaves: the route below is covered, sitting in
      // the `gone-left` pose (`:1256`).
      final ({AnimationController enter, AnimationController covered}) pair =
          await _pumpRoute(tester, enter: 1, covered: 1);
      expect(_appliedTranslationX(tester), closeTo(-112, 1e-9));

      // The **pop** winds both back: the route below's `secondaryAnimation`
      // runs 1 → 0, which is `:1262` removing `gone-left`, and the popped
      // route's own `animation` runs 1 → 0, which is `:1261` giving it
      // `gone-right`.
      pair.covered.value = 0;
      await tester.pump();
      expect(
        _appliedTranslationX(tester),
        0.0,
        reason: 'the route below is released and returns to rest',
      );
      expect(_appliedScale(tester), closeTo(1.0, 1e-12));
      expect(_appliedOpacity(tester), 1.0);

      pair.enter.value = 0;
      await tester.pump();
      expect(
        _appliedTranslationX(tester),
        closeTo(152, 1e-9),
        reason: 'the popped route leaves to the right — `:1261`',
      );
      expect(_appliedScale(tester), closeTo(0.98, 1e-9));
      expect(_appliedOpacity(tester), 0.0);
    });

    testWidgets('the fraction is of the ROUTE\'s width, not of the page\'s', (
      WidgetTester tester,
    ) async {
      // A 100px page inside a 400px route. 38% of the route is 152px of
      // travel; 38% of the page would be 38px. The two are 4× apart, so this
      // distinguishes them — and the prototype's own unit is the route's
      // (`translateX(38%)` on an element that fills the viewport).
      await _pumpRoute(
        tester,
        enter: 0,
        covered: 0,
        loose: true,
        page: const SizedBox(width: 100, height: 100, key: kPageKey),
      );

      expect(
        _appliedTranslationX(tester),
        closeTo(152, 1e-9),
        reason: '38% of the 400px ROUTE, not 38% of the 100px page',
      );
      // And the scale is about the **page's** own centre, because the scale
      // is the page's: 98 wide, 1px to either side of it.
      final Rect rect = _pageRect(tester);
      expect(rect.width, closeTo(98, 1e-9));
      expect(
        rect.left,
        closeTo(153, 1e-9),
        reason: '1px of centring + 152px of travel',
      );
    });

    testWidgets('the builder wraps the page rather than replacing it', (
      WidgetTester tester,
    ) async {
      await _pumpRoute(
        tester,
        enter: 0,
        covered: 0,
        page: const Text(
          'the page',
          key: kPageKey,
          textDirection: TextDirection.ltr,
        ),
      );

      expect(find.text('the page'), findsOneWidget);
    });
  });

  group('the redesign\'s tab swap', () {
    testWidgets('the incoming tab starts 10px low and scaled to 0.985', (
      WidgetTester tester,
    ) async {
      // `:132` — `.route.tab-pre{opacity:0;transform:translateY(10px) scale(.985)}`
      await _pumpTab(tester, value: 0);

      expect(
        _appliedTranslationY(tester),
        closeTo(10, 1e-9),
        reason: '`:132` states `translateY(10px)` — PIXELS',
      );
      expect(_appliedScale(tester), closeTo(0.985, 1e-9));
      expect(_appliedOpacity(tester), 0.0);

      final Rect rect = _pageRect(tester);
      expect(
        rect.top,
        closeTo(14.5, 1e-9),
        reason: '4.5px of centring + 10px of travel',
      );
      expect(rect.width, closeTo(394, 1e-9));
    });

    testWidgets('and it settles at rest', (WidgetTester tester) async {
      await _pumpTab(tester, value: 1);

      expect(_appliedTranslationY(tester), 0.0);
      expect(_appliedScale(tester), closeTo(1.0, 1e-12));
      expect(_appliedOpacity(tester), 1.0);
      expect(_pageRect(tester), const Rect.fromLTWH(0, 0, 400, 600));
    });

    testWidgets('the outgoing tab\'s pose is NEVER applied', (
      WidgetTester tester,
    ) async {
      // The prototype's outgoing tab rises **6px** (`:133`) while the incoming
      // one rises **10px** (`:132`), and auto_route's `IndexedStack` paints
      // only the active tab while the `transitionBuilder` hook wraps the whole
      // stack — so the outgoing pose is not observable, and the shipped
      // builder must therefore never produce it. Its vertical offset is never
      // negative.
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        await _pumpTab(tester, value: t);
        expect(
          _appliedTranslationY(tester),
          greaterThanOrEqualTo(0.0),
          reason: 'at t=$t the offset must not be the prototype\'s -6px rise',
        );
      }
    });
  });

  group('reduced motion — §14\'s row, on the redesign\'s two builders', () {
    testWidgets('the route sits at rest with the flag on', (
      WidgetTester tester,
    ) async {
      await _pumpRoute(tester, enter: 0, covered: 1, disableAnimations: true);

      expect(_appliedTranslationX(tester), 0.0);
      expect(_appliedScale(tester), closeTo(1.0, 1e-12));
      expect(_appliedOpacity(tester), 1.0);
      expect(
        _pageRect(tester),
        const Rect.fromLTWH(0, 0, 400, 600),
        reason: '§14: "jump straight to the end state"',
      );
    });

    testWidgets('and the flag OFF is unchanged — the control', (
      WidgetTester tester,
    ) async {
      // The anti-vacuity half: a builder that substituted
      // `kAlwaysCompleteAnimation` unconditionally would render the end state
      // here too and pass the test above.
      await _pumpRoute(tester, enter: 0, covered: 0);

      expect(_appliedTranslationX(tester), closeTo(152, 1e-9));
      expect(_appliedOpacity(tester), 0.0);
    });

    testWidgets('the tab sits at rest with the flag on', (
      WidgetTester tester,
    ) async {
      await _pumpTab(tester, value: 0, disableAnimations: true);

      expect(_appliedTranslationY(tester), 0.0);
      expect(_appliedScale(tester), closeTo(1.0, 1e-12));
      expect(_appliedOpacity(tester), 1.0);
    });
  });
}
