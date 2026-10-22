/// ## WHAT THIS SUITE IS
///
/// Three gates on the dock orb's ripple, and they are three different kinds
/// of claim:
///
/// 1. **A RATE** — the ripple's repaint rate is inside the app's own ambient
///    budget, and the ceiling is **read from** [AmbientTickBudget] rather than
///    written down, so the two cannot drift apart.
/// 2. **A SIGNAL** — the painter is driven by the budget's **gated** notifier
///    and **not** by the raw LUMEN clock. The proof is the *fire schedule*:
///    the painter is asked to repaint on exactly the frames the gated notifier
///    fires, and on fewer frames than the raw clock fires.
/// 3. **A CONTAINMENT** — the ripple carries its own [RepaintBoundary], so its
///    repaint stops there and never re-records the layer that owns the dock's
///    σ22 [BackdropFilter].
///
/// ## WHY THE BUDGET IS **READ** AND NOT **COPIED**
///
/// Because a benchmark prints a number and a number rots. **A budget fails the
/// build, so it cannot rot.** Every ceiling below is computed from
/// [AmbientTickBudget.resolve] — the budget the app itself is paced by — so a
/// change to the budget's divisors moves the ceiling with them instead of
/// leaving a second copy of the old numbers behind.
///
/// ## AND WHY THERE IS A **NEGATIVE CONTROL**
///
/// Because a gate that cannot fail is worse than no gate. The rate row is only
/// meaningful if the instrument can tell a **gated** painter from an **ungated**
/// one, and the only way to show that is to measure one of each with the same
/// instrument in the same file. The control is a painter that rides the **raw**
/// clock — the shape the ripple used to have — and the row that measures it
/// asserts that the instrument reports it as **over budget**. If that row ever
/// goes quiet, the rate row above it is green about nothing.
///
/// ## THE APPEARANCE HALF
///
/// The last group measures the ring's **painted** geometry — its radius, its
/// alpha and its ink — and compares them with the numbers **read out of the
/// prototype's own stylesheet** (`eva/redesign.html:230` and `:234`). It is
/// here because the fix changes the rate at which the ring is redrawn, and a
/// reader is entitled to a measurement rather than a promise that nothing else
/// moved.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/css_reference.dart';
import '../../../support/design_system_harness.dart';
import '../../../support/project_import_graph.dart';

/// The display the budget is resolved for.
///
/// **A fixed rate and not the platform's**, because the budget's divisors are a
/// function of the refresh rate, and a gate whose ceiling depends on the
/// machine it runs on is a gate that passes on one laptop and fails on
/// another. 60 Hz is the rate the repository's own numbers are written at
/// (`ambient_tick_budget.dart:71`).
const double _displayHz = 60;

/// The ambient's budget at [_displayHz].
///
/// **Read from the budget's own resolver** and not written out, so the ceilings
/// below are the ones the app is paced by rather than a second copy of them.
/// At 60 Hz that is `paintEveryNTick: 2` (thirty paints a second) and
/// `notifyEveryNTick: 3` (twenty a second).
final AmbientTickBudget _budget = AmbientTickBudget.resolve(
  displayRefreshRate: _displayHz,
);

/// How many frames the measurement runs for.
///
/// **Thirty frames is half a second at 60 Hz**, which is long enough for the
/// budget's divisors to show their shape — the notify gate fires ten times in
/// thirty frames and the paint gate fifteen — and short enough that a failure
/// reads as a rate rather than as a total.
const int _frames = 30;

/// The most notifications the ambient's **notify** budget allows in [_frames].
///
/// The gate fires on the first frame and then every Nth, so the count over
/// [_frames] frames is `ceil(frames / N)`. It is computed from the budget
/// rather than written down.
int _notifyCeiling() =>
    (_frames + _budget.notifyEveryNTick - 1) ~/ _budget.notifyEveryNTick;

/// The most repaints the ambient's **paint** budget allows in [_frames].
int _paintCeiling() =>
    (_frames + _budget.paintEveryNTick - 1) ~/ _budget.paintEveryNTick;

/// The key of the probe's own [RepaintBoundary].
///
/// **A key rather than a positional finder**, because `MaterialApp`, `Scaffold`
/// and `Stack` all insert `RepaintBoundary`s of their own, and "the first one
/// in the tree" would silently start capturing a different layer the day any of
/// them does.
const Key _probeKey = Key('eva.dock.ripple.probe');

/// The side of the probe's surface, in logical pixels.
///
/// **The orb is 30 and the ring reaches 1.6× of it — 48 — so the probe has to
/// be wider than the ring** or the measurement would read a clipped picture.
const double _probeSide = 120;

/// The phase band the appearance measurement is taken in.
///
/// **Away from both ends of the cycle on purpose.** At phase 0 the ring sits
/// exactly on the orb's own edge (`:234`'s `scale(1)`), where the disc's opaque
/// pixels and the ring's ink are the same pixels; near phase 1 the ring is
/// almost transparent. In between the ring stands clear of the disc, in
/// transparent pixels, and the measurement is of the ring and nothing else.
const double _phaseLow = 0.40;
const double _phaseHigh = 0.55;

/// The orb's ripple [CustomPaint].
///
/// **Reached through the widget rather than through a type name**, because the
/// painter is private to `lumen_dock.dart` on purpose — and because the orb
/// holds **two** `CustomPaint`s: the other one is the four-pointed star, which
/// carries no `repaint` signal at all and would report zero repaints for ever,
/// which is the shape of a green test that proves nothing.
CustomPaint _ripplePaint(WidgetTester tester) {
  final Finder ignore = find.descendant(
    of: find.byType(LumenOrb),
    matching: find.byType(IgnorePointer),
  );
  expect(
    ignore,
    findsOneWidget,
    reason:
        'the orb holds exactly one `IgnorePointer` — the one around the '
        'ripple. Anything else and this finder is pointing at the wrong '
        'painter, and the four-pointed star reports no repaints at all.',
  );
  return tester.widget<CustomPaint>(
    find.descendant(of: ignore, matching: find.byType(CustomPaint)),
  );
}

/// The frame counter every log in one measurement shares.
class _FrameCounter {
  int value = 0;
}

/// Records the frames on which a listenable fires.
///
/// **A painter is a listenable, and that is the whole instrument.**
/// `CustomPainter.addListener` **forwards to the `repaint` listenable** — the
/// SDK's `CustomPainter` holds no listener list of its own
/// (`rendering/custom_paint.dart:163`) — so a listener added to a painter is a
/// listener on the thing that schedules its repaints. The count is therefore
/// the framework's own definition of "this painter was asked to repaint", and
/// it works for a **private** painter reached through its widget, which a
/// `paint`-call counter could not.
class _FireLog {
  _FireLog(this.name, this.signal, this.counter) {
    signal.addListener(listener);
  }

  /// What this log counts, for the failure messages.
  final String name;

  /// The listenable being counted.
  final Listenable signal;

  /// The frame counter the log stamps its fires with.
  final _FrameCounter counter;

  /// The frames on which [signal] fired.
  final List<int> frames = <int>[];

  /// The closure handed to [signal].
  ///
  /// **Held in a field and not torn off at the removal site**, because a
  /// tear-off and a second tear-off of the same method on the same object are
  /// equal in Dart 3 — but only by a rule a reader has to know, and a removal
  /// that silently did nothing would leave a log counting a signal nobody owns.
  late final VoidCallback listener = _onFire;

  void _onFire() => frames.add(counter.value);

  /// Stops counting.
  void dispose() => signal.removeListener(listener);
}

/// What one rate measurement found.
///
/// **The three logs, not three lists**, so a failure message can name the
/// signal it is talking about instead of saying "the list".
typedef _Rate = ({
  _FireLog painter,
  _FireLog gated,
  _FireLog clock,
  int paints,
});

/// Counts the frames on which the painter at [read] fires, the frames on which
/// the ambient's **gated** notifier fires, the frames on which the **raw**
/// LUMEN clock notifies, and the frames on which the painter's
/// [RenderCustomPaint] is actually painted.
///
/// **Three counts and they are not the same count.** A painter riding the
/// gated notifier fires on the gated notifier's frames and on fewer than the
/// clock's; a painter riding the raw clock fires on the clock's frames and on
/// more than the gated notifier's. The two are told apart by the *schedule*,
/// not by a count alone.
///
/// ## AND WHY THE **IDENTITY FILTER** IS A PARAMETER
///
/// [isTarget] answers "was *this* render object painted?", and the only way to
/// answer it is to compare the painted object with the one under test. **That
/// comparison is an identity claim**, and it is handed in by the test that owns
/// the measurement rather than written here: a claim made inside a helper
/// belongs to no named test, and
/// `test/core/common/no_identical_on_converted_types_test.dart` requires every
/// identity site in `test/` to sit inside one and to be listed in its audited
/// table.
///
/// **The count is unchanged by the hand-over** — the filter is the same
/// comparison over the same two objects, applied to the same painted object on
/// the same frame.
Future<_Rate> _measureRate(
  WidgetTester tester, {
  required EvaNeuralMotion motion,
  required CustomPaint Function(WidgetTester tester) read,
  required bool Function(RenderObject painted, RenderObject target) isTarget,
}) async {
  final CustomPaint paint = read(tester);
  final CustomPainter? painter = paint.painter;
  if (painter == null) {
    throw StateError(
      'the CustomPaint carries no painter, so it paints nothing and every '
      'repaint assertion over it would be vacuous',
    );
  }
  final RenderCustomPaint target = tester.renderObject<RenderCustomPaint>(
    find.byWidget(paint),
  );

  final _FrameCounter counter = _FrameCounter();
  final _FireLog painterLog = _FireLog('the painter', painter, counter);
  final _FireLog gatedLog = _FireLog(
    'the gated notifier',
    motion.repaint,
    counter,
  );
  final _FireLog clockLog = _FireLog('the raw clock', motion.lumen, counter);
  addTearDown(painterLog.dispose);
  addTearDown(gatedLog.dispose);
  addTearDown(clockLog.dispose);

  int paints = 0;
  final ProfilePaintCallback? previous = debugOnProfilePaint;
  debugOnProfilePaint = (RenderObject painted) {
    if (isTarget(painted, target)) paints++;
  };
  try {
    for (int frame = 0; frame < _frames; frame++) {
      counter.value = frame;
      await tester.pump(const Duration(milliseconds: 16));
    }
  } finally {
    // **Restored here and not in `addTearDown`.** `flutter_test` verifies its
    // debug invariants at the END of the test body, which is **before** the
    // teardowns run — so a teardown restore trips
    // `debugAssertAllRenderVarsUnset` and fails a test that was measuring
    // something else entirely.
    debugOnProfilePaint = previous;
  }

  return (
    painter: painterLog,
    gated: gatedLog,
    clock: clockLog,
    paints: paints,
  );
}

/// A painter that rides the **raw** clock — the shape the ripple used to have.
///
/// **The negative control, and not a mock.** The rate row is only meaningful
/// if the instrument can tell a gated painter from an ungated one, and the
/// only way to show that is to measure one of each with the same instrument.
class _RawClockPainter extends CustomPainter {
  _RawClockPainter({required this.clock}) : super(repaint: clock);

  /// The raw clock — the one that notifies on every vsync.
  final LumenClock clock;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_RawClockPainter oldDelegate) => false;
}

/// The orb, under a scope that hands out the motion bundle.
///
/// The bundle is captured through a [Builder] rather than read back out of the
/// tree, because `NeuralMotionScope.of` **depends** on an inherited widget and
/// calling that from outside a build is not a thing the framework supports.
Widget _orbWithMotion(void Function(EvaNeuralMotion motion) capture) => Builder(
  builder: (BuildContext context) {
    capture(NeuralMotionScope.of(context));
    return const LumenOrb();
  },
);

void main() {
  group("the dock orb's ripple repaint signal", () {
    testWidgets('is the ambient\'s GATED notifier, and not the raw clock', (
      WidgetTester tester,
    ) async {
      EvaNeuralMotion? captured;
      await tester.pumpWidget(
        evaAmbientHarness(
          budget: _budget,
          child: _orbWithMotion((EvaNeuralMotion motion) {
            captured = motion;
          }),
        ),
      );
      await tester.pump();

      final EvaNeuralMotion motion =
          captured ??
          (throw StateError(
            'the orb was not mounted under a `NeuralMotionScope`, so there is '
            'no ambient signal to measure',
          ));

      // ## THE IDENTITY CLAIM, AND WHY IT IS MADE **HERE**
      //
      // "Only the paints of the render object under test count" is a claim
      // that two references are the *same* object, so it is made in the test
      // that owns the measurement: a claim inside a helper belongs to no named
      // test, and `no_identical_on_converted_types_test.dart` requires every
      // identity site in `test/` to sit inside one and to be listed in its
      // audited table. `RenderObject` declares no `operator ==`, so identity
      // is the only way to say it.
      //
      // **A named local function and not a lambda**, because a lambda here
      // would be `identical` written as a tear-off — and a tear-off of
      // `identical` is not a call, so the gate would not see the claim at all.
      bool isTheTarget(RenderObject painted, RenderObject target) =>
          identical(painted, target);

      final _Rate rate = await _measureRate(
        tester,
        motion: motion,
        read: _ripplePaint,
        isTarget: isTheTarget,
      );

      debugPrint(
        '── the dock orb\'s ripple ──\n'
        '${rate.painter.name} : ${rate.painter.frames.length} requests in '
        '$_frames frames\n'
        '${rate.gated.name} : ${rate.gated.frames.length} notifications in '
        '$_frames frames\n'
        '${rate.clock.name} : ${rate.clock.frames.length} notifications in '
        '$_frames frames\n'
        'paints  : ${rate.paints} in $_frames frames\n'
        'ceiling : ${_notifyCeiling()} notifications, ${_paintCeiling()} paints '
        'per $_frames frames (the ambient budget at ${_displayHz.round()} Hz: '
        'one every ${_budget.notifyEveryNTick} frames, one every '
        '${_budget.paintEveryNTick} frames)',
      );

      expect(
        rate.painter.frames,
        isNotEmpty,
        reason:
            'the ripple was never asked to repaint at all, so the rate below '
            'is measuring nothing. The instrument has to be able to see a '
            'painter that repaints on every frame.',
      );
      expect(
        rate.painter.frames,
        rate.gated.frames,
        reason:
            'the ripple must be driven by the ambient\'s GATED notifier, so it '
            'must be asked to repaint on exactly the frames that notifier '
            'fires — no earlier, no later.\n'
            'MEASURED: the painter fired on ${rate.painter.frames.length} '
            'frames and the gated notifier on ${rate.gated.frames.length}. The '
            'cause of a mismatch is the painter\'s own `repaint` signal: '
            '`motion.repaint` (`neural_motion.dart:232`) is gated at '
            '`neural_motion.dart:165-166` by the 20 Hz `notifyGate`, and the '
            'raw `TickedLumenClock` notifies on every vsync '
            '(`lumen_clock.dart:302-305`). The gold flecks '
            '(`gold_flecks.dart:183`) and the witness sky\'s stars '
            '(`witness_sky.dart:898-917`) ride the gated one.',
      );
      expect(
        rate.painter.frames.length,
        lessThan(rate.clock.frames.length),
        reason:
            'the ripple must NOT be driven by the raw LUMEN clock, which '
            'notifies on every vsync.\n'
            'MEASURED: the painter fired on ${rate.painter.frames.length} '
            'frames and the raw clock on ${rate.clock.frames.length} — a '
            'painter riding the clock fires on every one of them.',
      );
      expect(
        rate.painter.frames.length,
        lessThanOrEqualTo(_notifyCeiling()),
        reason:
            'the ripple asked for a repaint ${rate.painter.frames.length} times '
            'in $_frames frames, and the ambient budget at '
            '${_displayHz.round()} Hz allows one notification every '
            '${_budget.notifyEveryNTick} frames, which is ${_notifyCeiling()} '
            'in $_frames.',
      );
      expect(
        rate.paints,
        lessThanOrEqualTo(_paintCeiling()),
        reason:
            'the ripple was painted ${rate.paints} times in $_frames frames, '
            'and the ambient budget at ${_displayHz.round()} Hz allows one '
            'paint every ${_budget.paintEveryNTick} frames, which is '
            '${_paintCeiling()} in $_frames.',
      );
    });

    testWidgets('and the instrument can SEE a painter that rides the raw clock', (
      WidgetTester tester,
    ) async {
      // ## THE NEGATIVE CONTROL
      //
      // The row above is green because the ripple rides the gated notifier.
      // This row is what makes that statement mean something: the **same
      // instrument**, in the **same file**, is pointed at a painter that rides
      // the **raw** clock — and it must report that painter as over budget.
      //
      // A gate that cannot fail is worse than no gate, and an instrument that
      // reports the same number for everything is exactly that.
      EvaNeuralMotion? captured;
      await tester.pumpWidget(
        evaAmbientHarness(
          budget: _budget,
          child: Builder(
            builder: (BuildContext context) {
              captured = NeuralMotionScope.of(context);
              return SizedBox(
                width: LumenOrb.diameter,
                height: LumenOrb.diameter,
                child: CustomPaint(
                  painter: _RawClockPainter(clock: captured!.lumen),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      final EvaNeuralMotion motion =
          captured ??
          (throw StateError(
            'the control painter was not mounted under a `NeuralMotionScope`',
          ));

      // ## THE IDENTITY CLAIM, AND WHY IT IS MADE **HERE**
      //
      // The control painter is a different render object from the ripple's,
      // and only the paints of the one under test count — so the identity
      // claim is made in the test that owns the measurement.
      bool isTheTarget(RenderObject painted, RenderObject target) =>
          identical(painted, target);

      final _Rate rate = await _measureRate(
        tester,
        motion: motion,
        read: (WidgetTester t) =>
            t.widget<CustomPaint>(find.byType(CustomPaint)),
        isTarget: isTheTarget,
      );

      debugPrint(
        '── the control: a painter on the raw clock ──\n'
        'painter : ${rate.painter.frames.length} requests in $_frames frames\n'
        'clock   : ${rate.clock.frames.length} notifications in $_frames frames\n'
        'ceiling : ${_notifyCeiling()} notifications per $_frames frames',
      );

      expect(
        rate.painter.frames,
        rate.clock.frames,
        reason:
            'a painter riding the raw clock is asked to repaint on every frame '
            'the clock notifies on, and on no other frame.',
      );
      expect(
        rate.painter.frames.length,
        greaterThan(_notifyCeiling()),
        reason:
            'THE CONTROL. The control painter asked for a repaint '
            '${rate.painter.frames.length} times in $_frames frames, and the '
            'budget allows ${_notifyCeiling()}. It is over budget **on '
            'purpose** — it is the raw-clock shape the ripple used to have, '
            'and this row is what proves the instrument can see that shape. If '
            'it ever reads at or under the ceiling, the instrument has stopped '
            'telling a gated painter from an ungated one and the row above it '
            'is green about nothing.',
      );
    });
  });

  group("the dock orb's ripple containment", () {
    testWidgets('is its OWN RepaintBoundary, and the nearest one above it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(evaAmbientHarness(child: const LumenOrb()));
      await tester.pump();

      final Finder orb = find.byType(LumenOrb);
      final Finder boundaries = find.descendant(
        of: orb,
        matching: find.byType(RepaintBoundary),
      );

      // ## WHY THE COUNT IS **EXACTLY ONE**
      //
      // The claim is "the ripple carries a boundary **of its own**", and a
      // count of "at least one" would be satisfied by a boundary that belongs
      // to something else. The orb's other `CustomPaint` is the four-pointed
      // star, and the star carries no boundary — so one is the whole truth.
      expect(
        boundaries,
        findsOneWidget,
        reason:
            'the ripple must carry a `RepaintBoundary` of its own, and the '
            'orb must carry exactly one: the four-pointed star carries none, '
            'so a second one would be a boundary this gate does not know '
            'about. Before the fix the orb carried none, and the ripple\'s '
            'repaint re-recorded the layer that owns the dock\'s σ22 '
            '`BackdropFilter` (`lumen_dock.dart:314`).',
      );

      final CustomPaint ripple = _ripplePaint(tester);
      final Finder inside = find.descendant(
        of: boundaries,
        matching: find.byType(CustomPaint),
      );
      expect(
        inside,
        findsOneWidget,
        reason:
            'the boundary must hold the ripple and nothing else — the star\'s '
            '`CustomPaint` is the orb\'s other one, and it is a sibling of '
            'the boundary, not a child of it.',
      );
      expect(
        find.descendant(of: boundaries, matching: find.byWidget(ripple)),
        findsOneWidget,
        reason:
            'and the one `CustomPaint` inside the boundary must BE the ripple '
            '— the orb\'s other `CustomPaint` is the four-pointed star, and it '
            'is a sibling of the boundary rather than a child of it.',
      );
      expect(
        find.descendant(of: boundaries, matching: find.byType(RepaintBoundary)),
        findsNothing,
        reason:
            'nothing may sit between the ripple and its boundary, or the '
            '**nearest** boundary above the ripple would not be this one — and '
            'the nearest is the one that stops the repaint. Together with the '
            'row above — the orb carries exactly one boundary, and the ripple '
            'is inside it — this says the ripple\'s repaint stops inside the '
            'orb and never reaches the dock\'s layer.',
      );
    });
  });

  group("the dock orb's ripple appearance", () {
    testWidgets('is the prototype\'s radius, alpha and ink', (
      WidgetTester tester,
    ) async {
      // ## THE PROTOTYPE'S OWN NUMBERS, READ AT TEST TIME
      //
      // `eva/redesign.html:230` is `.orbmini::after{…border:1.2px solid '
      // 'rgba(232,176,75,.6);animation:ripple 2.6s var(--e-out) infinite}` and
      // `:234` is `@keyframes ripple{0%{transform:scale(1);opacity:.8}'
      // '100%{transform:scale(1.6);opacity:0}}`. **Read, not copied** — a
      // table of numbers copied out of a stylesheet is a table that rots.
      final File prototype = File.fromUri(
        packageRoot.uri.resolve('eva/redesign.html'),
      );
      final Map<String, String> after = cssRule(prototype, '.orbmini::after');
      final String? border = after['border'];
      expect(
        border,
        isNotNull,
        reason: 'the prototype no longer declares the ring\'s border',
      );
      final RegExpMatch? stroke = RegExp(
        r'^([\d.]+)px solid rgba\((\d+),(\d+),(\d+),([\d.]+)\)$',
      ).firstMatch(border!);
      expect(
        stroke,
        isNotNull,
        reason:
            'the ring\'s border is "$border", which is not a stroke this '
            'harness reads',
      );
      final double strokeWidth = double.parse(stroke!.group(1)!);
      // **The fifth group and not the fourth.** The prototype writes the alpha
      // as `.6` — a leading dot and no leading zero — and a reader that
      // accepted `\.?` before the number would read `6` and then compute an
      // alpha ten times the one the prototype declares.
      final double ringAlpha = double.parse(stroke.group(5)!);

      final String keyframes = _rippleKeyframes(prototype);
      final RegExpMatch? from = RegExp(
        r'0%\{transform:scale\(([\d.]+)\);opacity:([\d.]+)\}',
      ).firstMatch(keyframes);
      final RegExpMatch? to = RegExp(
        r'100%\{transform:scale\(([\d.]+)\);opacity:([\d.]+)\}',
      ).firstMatch(keyframes);
      expect(
        from,
        isNotNull,
        reason:
            'the ripple keyframes no longer open with a scale and an '
            'opacity: "$keyframes"',
      );
      expect(
        to,
        isNotNull,
        reason:
            'the ripple keyframes no longer close with a scale and an '
            'opacity: "$keyframes"',
      );
      final double scaleFrom = double.parse(from!.group(1)!);
      final double opacityFrom = double.parse(from.group(2)!);
      final double scaleTo = double.parse(to!.group(1)!);
      final double opacityTo = double.parse(to.group(2)!);

      // ## THE MEASUREMENT
      //
      // **The surface is the probe's own size**, and not a larger one with
      // the probe inside it: a parent that hands its child a **tight** height
      // keeps it — a `SizedBox(height: 78)` inside a tight 568-tall parent is
      // 568 tall, which is the fact `LumenDock`'s own doc records
      // (`lumen_dock.dart:165-168`) — so a 120-wide probe inside a 200-wide
      // surface is a 200-wide probe, and the ring would be measured against
      // the wrong centre.
      useAmbientSurface(tester, size: const Size(_probeSide, _probeSide));

      EvaNeuralMotion? captured;
      bool notified = false;
      await tester.pumpWidget(
        evaAmbientHarness(
          budget: _budget,
          child: Builder(
            builder: (BuildContext context) {
              captured = NeuralMotionScope.of(context);
              return const RepaintBoundary(
                key: _probeKey,
                child: SizedBox(
                  width: _probeSide,
                  height: _probeSide,
                  child: Center(child: LumenOrb()),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      final EvaNeuralMotion motion =
          captured ??
          (throw StateError(
            'the orb was not mounted under a `NeuralMotionScope`',
          ));
      motion.repaint.addListener(() {
        notified = true;
      });

      // ## THE FRAME
      //
      // The ring is captured on a frame on which the ambient's **gated**
      // notification fired, because that is the frame on which the ring is
      // redrawn — and the clock's reading at the end of that frame is the
      // reading the painter used, because the ticker ticks in the transient
      // phase and the paint happens after it.
      double? phase;
      for (int frame = 0; frame < 400; frame++) {
        notified = false;
        await tester.pump(const Duration(milliseconds: 16));
        if (!notified) continue;
        final double candidate = LumenOrb.ripplePhase(motion.lumen.seconds);
        if (candidate >= _phaseLow && candidate <= _phaseHigh) {
          phase = candidate;
          break;
        }
      }
      expect(
        phase,
        isNotNull,
        reason:
            'the ambient never notified on a frame whose phase fell between '
            '$_phaseLow and $_phaseHigh, so the ring was never captured in a '
            'band where it stands clear of the orb\'s own disc',
      );

      final double eased = EvaMotion.dockRippleCurve.transform(phase!);
      final double scale = scaleFrom + (scaleTo - scaleFrom) * eased;
      final double opacity = opacityFrom + (opacityTo - opacityFrom) * eased;
      const double orbRadius = LumenOrb.diameter / 2;
      final double expectedRadius = orbRadius * scale;
      final double expectedAlphaSum = ringAlpha * opacity * 255 * strokeWidth;

      // ## THE PIXELS
      final Uint8List pixels = await _pixelsOf(tester, find.byKey(_probeKey));

      final int side = _probeSide.toInt();
      final int centre = side ~/ 2;
      double alphaSum = 0;
      double weightedRadius = 0;
      double red = 0;
      double green = 0;
      double blue = 0;
      // **From just outside the orb's own disc** — the disc's pixels are
      // opaque gold and the ring's are transparent gold over nothing, and the
      // two are not the same measurement.
      for (int x = centre + orbRadius.ceil() + 1; x < side; x++) {
        final int offset = (centre * side + x) * 4;
        final int alpha = pixels[offset + 3];
        if (alpha == 0) continue;
        alphaSum += alpha;
        weightedRadius += alpha * (x + 0.5 - centre);
        red += pixels[offset] * 255;
        green += pixels[offset + 1] * 255;
        blue += pixels[offset + 2] * 255;
      }

      debugPrint(
        '── the ring, painted ──\n'
        'phase          : $phase (eased $eased)\n'
        'expected radius: $expectedRadius  (scale $scale)\n'
        'measured radius: ${weightedRadius / alphaSum}\n'
        'expected alpha : $expectedAlphaSum  (sum of the byte alphas)\n'
        'measured alpha : $alphaSum\n'
        'ink            : '
        '(${red / alphaSum}, ${green / alphaSum}, ${blue / alphaSum})',
      );

      expect(
        alphaSum,
        greaterThan(0),
        reason:
            'no pixel outside the orb\'s own disc carries any ink, so the ring '
            'was not painted there at all. `:234` scales it to 1.6× — 24px '
            'from the centre of a 30px orb — and a `RepaintBoundary` that '
            'clipped it would take the ring with it.',
      );
      expect(
        (weightedRadius / alphaSum - expectedRadius).abs(),
        lessThanOrEqualTo(1.0),
        reason:
            'the ring\'s painted radius is ${weightedRadius / alphaSum} and '
            'the prototype\'s own numbers say $expectedRadius — the orb\'s '
            'radius ($orbRadius) scaled by $scale, which is `:234`\'s '
            '`scale($scaleTo)` eased by `--e-out`.',
      );
      expect(
        (alphaSum - expectedAlphaSum).abs(),
        lessThanOrEqualTo(4),
        reason:
            'the ring\'s painted ink sums to $alphaSum and the prototype\'s own '
            'numbers say $expectedAlphaSum — the border\'s alpha ($ringAlpha) '
            'times the keyframe\'s opacity ($opacity) over a stroke '
            '$strokeWidth wide. A ring that were a different alpha, a '
            'different stroke or a different scale would move this number.',
      );

      final Color ink = Color.fromARGB(
        255,
        (red / alphaSum).round(),
        (green / alphaSum).round(),
        (blue / alphaSum).round(),
      );
      final Color gold = const EvaColors.dark().ember;
      expect(
        (ink.r - gold.r).abs(),
        lessThanOrEqualTo(0.08),
        reason: 'the ring\'s ink is $ink and the gold is $gold',
      );
      expect(
        (ink.g - gold.g).abs(),
        lessThanOrEqualTo(0.08),
        reason: 'the ring\'s ink is $ink and the gold is $gold',
      );
      expect(
        (ink.b - gold.b).abs(),
        lessThanOrEqualTo(0.08),
        reason: 'the ring\'s ink is $ink and the gold is $gold',
      );
    });
  });
}

/// The prototype's `@keyframes ripple` block, read out of the stylesheet.
///
/// **The line, not a rule.** `eva/redesign.html` writes the keyframes on one
/// line (`:234`), and the block is nested two deep — which is why a rule
/// reader cannot read it and this one can.
String _rippleKeyframes(File prototype) {
  for (final String line in prototype.readAsLinesSync()) {
    if (line.startsWith('@keyframes ripple{')) return line;
  }
  throw StateError(
    'the prototype no longer declares `@keyframes ripple`, so this harness '
    'cannot read the ring\'s own animation',
  );
}

/// The RGBA bytes of the layer under [finder].
///
/// **The same instrument as `design_system_harness.dart`'s `backgroundPixels`,
/// pointed at a different target.** `toImageSync` and not `toImage`, because
/// `toImage` waits for the next frame and the test body runs inside a
/// fake-async zone where that frame never arrives; and `runAsync` around
/// `toByteData`, because that half crosses into the engine.
Future<Uint8List> _pixelsOf(WidgetTester tester, Finder finder) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(finder);
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = boundary.toImageSync();
    final ByteData? data = await image.toByteData();
    image.dispose();
    if (data == null) {
      throw StateError('the probe\'s layer produced no pixels');
    }
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('runAsync returned no pixels');
  }
  return bytes;
}
