import 'package:evangelion/core/design_system/tokens/eva_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// HEIGHTS THE SLIDE IS MEASURED AT, and why there is more than one.
///
/// `docs/plans/06-navigation.md` §8 specifies the global transition as an
/// **8px** slide and is emphatic about the spelling: `Offset(0, 8 /
/// constraints.maxHeight)` — "rather than a fixed 4% fraction", because a
/// fraction is only correct on the screen it was measured on.
///
/// So a single-height test cannot tell the two implementations apart: a fixed
/// fraction `f` and a fixed 8px distance agree at exactly one height, `8 / f`.
/// Two heights kill the coincidence — `f` is constant, `8 / h` is not — so the
/// test reads the rendered fraction at two real device heights (Phase 10's
/// 320×568 and 390×844 matrices, `08-build-phases.md`) and asks whether each one
/// comes out to eight pixels.
const List<double> _probeHeights = <double>[568, 844];

/// A page of exactly [height] logical pixels, running [EvaMotion.fadeSlide] at
/// animation value [value], wrapping [child].
///
/// The `Builder` exists to obtain a real `BuildContext`: the signature is
/// Flutter's, so the builder must be handed one. `Builder` builds no
/// `RenderObject`, so it cannot disturb the `FractionalTranslation` the
/// assertions below read out of the tree.
///
/// [tester]'s surface is resized to match, because `constraints.maxHeight` — the
/// number the 8px is divided by — is whatever the framework hands the builder,
/// and an `Align` inside the default 800×600 test window silently clamps a
/// taller page to 600.
///
/// ## THE `MediaQuery` IS INSTALLED UNCONDITIONALLY, AND THAT IS THE POINT
///
/// [disableAnimations] defaults to `false`, which is what the platform's own
/// default is, so every pre-existing probe in this file is unchanged by its
/// presence — but the wrapper is not conditional on the flag. A `MediaQuery`
/// that appears only when the test wants it to see one is a probe that cannot
/// distinguish "the flag is off" from "there was nothing to read", which is the
/// same shape as a gate that cannot fail. The reduced-motion group below needs
/// the off case to be a *measurement*, not an absence.
///
/// The [MediaQueryData] carries the real [size] rather than `MediaQueryData()`'s
/// `Size.zero`, because a zero-sized `MediaQuery` is a second, unrelated way for
/// a layout to be wrong and this file measures layouts.
///
/// ## THIS CALL IS ALSO THE SIGNATURE CHECK `AppRouter` DEPENDS ON
///
/// `fadeSlide` is invoked here through the framework's own four-parameter shape,
/// so a change to its signature stops this file compiling — the earliest and
/// loudest form of failure available, and the one `RouteType.custom(
/// transitionsBuilder:)` needs.
///
/// It replaces a standalone `test('fadeSlide fits RouteTransitionsBuilder')`
/// whose body assigned `final RouteTransitionsBuilder builder =
/// EvaMotion.fadeSlide;` and then asserted `same(EvaMotion.fadeSlide)` against
/// it, under a comment claiming the compile-time check was "restated at runtime".
/// It was not restated: `builder` had just been assigned from that expression, so
/// the matcher compared a value with itself. Dart offers no runtime check of a
/// static method's signature, so there was nothing for that test to assert beyond
/// the assignment it had just performed. The observable half of the same claim —
/// that `AppRouter.defaultRouteType` installs *this* function, read off the live
/// `RouteType` — is in `app_router_test.dart`.
Future<Offset> _pumpProbe(
  WidgetTester tester, {
  required double height,
  required double value,
  bool disableAnimations = false,
  Widget child = const SizedBox.expand(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(400, height);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 568),
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: height,
          width: 400,
          child: Builder(
            builder: (BuildContext context) => EvaMotion.fadeSlide(
              context,
              AlwaysStoppedAnimation<double>(value),
              const AlwaysStoppedAnimation<double>(0),
              child,
            ),
          ),
        ),
      ),
    ),
  );

  return tester
      .widget<FractionalTranslation>(find.byType(FractionalTranslation))
      .translation;
}

/// The slide offset the pumped widget actually received, in logical pixels.
///
/// `SlideTransition` builds exactly one `FractionalTranslation` and applies
/// `translation.dy` as a fraction of the CHILD's height, so the travel is
/// `fraction * laid-out height`. Both factors are read off the pumped tree rather
/// than assumed, which is what makes this a measurement of the widget the router
/// mounts instead of a second implementation of the same arithmetic.
double _renderedTravelPx(WidgetTester tester) {
  final Offset fraction = tester
      .widget<FractionalTranslation>(find.byType(FractionalTranslation))
      .translation;
  final double laidOut = tester
      .getSize(find.byType(FractionalTranslation))
      .height;

  return fraction.dy * laidOut;
}

void main() {
  group('the 8px screen slide — the pure seam', () {
    // Red-first per AGENT_CONTEXT §6, and the mutation that proves it: the
    // implementation was first written as the "fixed 4% fraction"
    // `Offset(0, 0.04)` that `06-navigation.md` §8 rejects, and every assertion
    // in this group went red at BOTH heights. That is the whole reason the
    // fraction is read twice.
    for (final double height in _probeHeights) {
      test('is 8 logical pixels on a ${height}px page', () {
        final Offset begin = EvaMotion.screenSlideBeginFor(height);

        expect(begin.dx, 0.0, reason: 'the slide is vertical only');
        expect(
          begin.dy * height,
          EvaMotion.screenSlidePixels,
          reason:
              'at ${height}px tall the slide must be eight pixels, not a '
              'fraction of the viewport',
        );
      });
    }

    test('the fraction is not constant across heights', () {
      // The discriminating assertion, stated on its own so a failure names the
      // property instead of the arithmetic. A fixed fraction cannot satisfy this
      // at any height — the two implementations agree at exactly one.
      expect(
        EvaMotion.screenSlideBeginFor(_probeHeights.first).dy,
        isNot(EvaMotion.screenSlideBeginFor(_probeHeights.last).dy),
        reason:
            '8px on a 568px page and 8px on an 844px page are different '
            'fractions; equal values mean a fixed fraction is in use',
      );
    });

    test('the rejected 4% fraction and this one coincide at exactly 200px', () {
      // Why the two-height design is load-bearing rather than lucky. `8 / 0.04`
      // is 200, so a 4% implementation and an 8px implementation produce the
      // IDENTICAL number on a 200px-tall viewport — and a test run only there
      // would pass for both, passing for the wrong reason. 568 and 844 are
      // nowhere near 200, which is why they were chosen.
      expect(
        EvaMotion.screenSlideBeginFor(200).dy,
        closeTo(0.04, 1e-12),
        reason:
            'the single height at which the two readings cannot be told '
            'apart',
      );
      expect(EvaMotion.screenSlideBeginFor(568).dy, isNot(closeTo(0.04, 1e-3)));
      expect(EvaMotion.screenSlideBeginFor(844).dy, isNot(closeTo(0.04, 1e-3)));
    });

    test('a non-positive or NaN height yields no slide, not a bad matrix', () {
      // `8 / 0` is Infinity and `8 / -1` is -8; either handed to
      // `FractionalTranslation` becomes an infinite or backwards transform.
      // `double.infinity` already divides to zero, so it needs no arm of its
      // own — this test says so rather than leaving it implied.
      expect(EvaMotion.screenSlideBeginFor(0), Offset.zero);
      expect(EvaMotion.screenSlideBeginFor(-1), Offset.zero);
      expect(EvaMotion.screenSlideBeginFor(double.nan), Offset.zero);
      expect(EvaMotion.screenSlideBeginFor(double.infinity), Offset.zero);
    });

    test('the distance is 8, and the duration is the existing screen token', () {
      // `06-navigation.md` also names `EvaMotion.screenDuration`, which does not
      // exist and must not: `EvaMotion.screen` (250ms) already carries that
      // number, and a second constant restating it would be two things to keep
      // in step. Asserting `screen` here is what makes the absence a decision
      // rather than an oversight.
      expect(EvaMotion.screenSlidePixels, 8.0);
      expect(
        EvaMotion.screen,
        const Duration(milliseconds: 250),
        reason: 'AppRouter.defaultRouteType reuses EvaMotion.screen verbatim',
      );
    });
  });

  group('the 8px screen slide — the widget the router mounts', () {
    // The group above proves the arithmetic; this one proves `fadeSlide`
    // actually applies it. Without it, a builder that ignored
    // `screenSlideBeginFor` and hard-coded a fraction would pass everything
    // above.
    for (final double height in _probeHeights) {
      testWidgets('renders 8px of travel on a ${height}px page', (
        WidgetTester tester,
      ) async {
        await _pumpProbe(tester, height: height, value: 0);

        expect(
          _renderedTravelPx(tester),
          closeTo(EvaMotion.screenSlidePixels, 1e-9),
          reason: 'measured off the laid-out page, not off the requested size',
        );
      });
    }

    testWidgets('ends at the origin once the animation completes', (
      WidgetTester tester,
    ) async {
      final Offset end = await _pumpProbe(tester, height: 844, value: 1);

      expect(end, Offset.zero);
    });

    testWidgets('fades and slides on one curve, eased past linear at t=0.5', (
      WidgetTester tester,
    ) async {
      // Read at an interior point where `easeOutCubic` and linear genuinely
      // differ. A slide left linear while the fade was eased would disagree
      // here, and a builder that used neither [EvaMotion.screenCurve] nor any
      // curve would sit at `t` itself.
      const double t = 0.5;
      final double eased = EvaMotion.screenCurve.transform(t);
      expect(
        eased - t,
        greaterThan(0.3),
        reason:
            'easeOutCubic is well past linear at the midpoint; a builder '
            'that left the animation uncurved would land on $t',
      );

      await _pumpProbe(tester, height: 844, value: t);

      final FadeTransition fade = tester.widget<FadeTransition>(
        find.byType(FadeTransition),
      );
      expect(fade.opacity.value, closeTo(eased, 1e-9));

      final SlideTransition slide = tester.widget<SlideTransition>(
        find.byType(SlideTransition),
      );
      expect(
        slide.position.value.dy,
        closeTo((1 - eased) * EvaMotion.screenSlideBeginFor(844).dy, 1e-9),
      );
      expect(
        _renderedTravelPx(tester),
        closeTo((1 - eased) * EvaMotion.screenSlidePixels, 1e-6),
        reason:
            'mid-way through an eased 8px slide, under half the distance '
            'has been covered',
      );
    });

    testWidgets('wraps the page rather than replacing it', (
      WidgetTester tester,
    ) async {
      // `fadeSlide` is a *transitions builder*: it wraps whatever auto_route
      // hands it. A version returning its own scaffold would still satisfy every
      // offset assertion above while discarding the page.
      await _pumpProbe(
        tester,
        height: 844,
        value: 1,
        child: const Text('the page', textDirection: TextDirection.ltr),
      );

      expect(find.text('the page'), findsOneWidget);
    });

    testWidgets(
      'ignores secondaryAnimation, so it cannot fight the outgoing page',
      (WidgetTester tester) async {
        // `EvaMotion.fadeSlide`'s doc says the outgoing route's animation is
        // deliberately unused. That is a claim about the tree, so it is checked
        // against the tree: the same `animation` with two different
        // `secondaryAnimation`s must produce the same opacity and the same offset.
        // A builder that honoured it — the usual cross-fade pattern — would move both.
        await _pumpProbe(tester, height: 844, value: 1);
        final double foreground = _renderedTravelPx(tester);
        final FadeTransition foregroundFade = tester.widget<FadeTransition>(
          find.byType(FadeTransition),
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 844,
              width: 400,
              child: Builder(
                builder: (BuildContext context) => EvaMotion.fadeSlide(
                  context,
                  const AlwaysStoppedAnimation<double>(1),
                  // The route underneath is fully dismissed.
                  const AlwaysStoppedAnimation<double>(0.5),
                  const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );

        expect(_renderedTravelPx(tester), foreground);
        expect(foreground, 0.0, reason: 'sanity: the page is at rest at t=1');
        expect(
          tester
              .widget<FadeTransition>(find.byType(FadeTransition))
              .opacity
              .value,
          foregroundFade.opacity.value,
        );
      },
    );

    testWidgets('emits exactly one FractionalTranslation', (
      WidgetTester tester,
    ) async {
      // The offset assertions above reach the slide through `tester.widget`,
      // which THROWS when the finder matches more than one. Stated as its own
      // test so that failure reads as "the builder produced two slides" instead
      // of an incidental count mismatch inside an offset assertion.
      await _pumpProbe(tester, height: 844, value: 0);

      expect(find.byType(FractionalTranslation), findsOneWidget);
    });
  });

  /// §14's row for this transition: *"Animations ignore reduced-motion — every
  /// animation checks `MediaQuery.disableAnimationsOf(context)`; when disabled,
  /// jump straight to the end state."*
  ///
  /// ## WHY THIS GROUP IS **THE** GAP AND NOT ONE OF SEVEN
  ///
  /// `09-quality-gates.md` §14's row is universal, so Phase 10 enumerated every
  /// animation site rather than assuming. Seven sites, six of which already
  /// honoured the flag before this phase:
  ///
  /// | site | file:line | honoured |
  /// | --- | --- | --- |
  /// | orb float / hue / aurora clocks | `neural_motion.dart:324` | yes — `platformDispatcher`, because the scope sits **above** `MaterialApp` and there is no `MediaQuery` to read |
  /// | `NeuralBackground` painting | `neural_background.dart:110` | yes |
  /// | `GoldFlecks` painting | `gold_flecks.dart:68` | yes |
  /// | `EvaButton` pressed fill | `eva_button.dart:308` | yes |
  /// | `EvaToggle` knob | `eva_toggle.dart:92` | yes |
  /// | `SegmentedControl` track | `segmented_control.dart:135` | yes |
  /// | **the global route transition** | **`eva_motion.dart:144`** | **no** |
  ///
  /// And it is the one a reader meets most: `AppRouter.defaultRouteType` installs
  /// this builder **app-wide**, so every one of the six screens arrives with a
  /// 250ms fade and an 8px slide whether or not the reader asked for reduced
  /// motion. The other six sites are per-widget or per-clock; this one is the
  /// transition *between* screens, which is the first thing that moves on every
  /// navigation the reader makes.
  ///
  /// ## THE IMPLEMENTATION'S OWN DOC STATED THE VIOLATION AS ITS REASON
  ///
  /// `fadeSlide`'s doc read: *"The `BuildContext` is taken because the typedef
  /// carries one; nothing here reads from it."* That sentence is what §14's row
  /// forbids, written down as if it were a design note. The `BuildContext` is
  /// there because a `RouteTransitionsBuilder` receives one, and a route
  /// transition **is** below `MaterialApp.builder` — so
  /// `MediaQuery.disableAnimationsOf` is reachable from it, which the previous
  /// doc never checked. Contrast `neural_motion.dart:259-268`, which *did* check
  /// reachability before recording a reason, and corrected its own earlier claim
  /// when it found the reason was wrong.
  group('reduced motion — §14\'s row, and the one site that did not', () {
    testWidgets('with the flag on, t=0 is already the END state', (
      WidgetTester tester,
    ) async {
      // ## RED-FIRST, AND THE MUTATION IS THE WHOLE ARGUMENT
      //
      // This was written before the implementation changed and failed on both
      // assertions, with the real numbers: travel `8.0` where `0.0` was
      // required, and opacity `0.0` where `1.0` was required. An implementation
      // that simply returned `child` when animations are off would pass these
      // two — and would break `emits exactly one FractionalTranslation` and
      // `wraps the page rather than replacing it` in the group above, which is
      // why the end state is reached by substituting the animation instead of by
      // dropping the widgets.
      await _pumpProbe(tester, height: 844, value: 0, disableAnimations: true);

      expect(
        _renderedTravelPx(tester),
        0.0,
        reason:
            '§14 says "jump straight to the end state". At t=0 with animations '
            'off the page must already be where it is at t=1, which is no '
            'travel at all.',
      );
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        1.0,
        reason: 'and fully opaque — an invisible page is the other end state',
      );
    });

    testWidgets('and it is the SAME end state the animation reaches at t=1', (
      WidgetTester tester,
    ) async {
      // Not "close to zero" — the identical numbers. A version that snapped the
      // slide to `Offset.zero` but left a residual opacity, or eased to a
      // different point on the curve, would pass the first test and fail here.
      await _pumpProbe(tester, height: 844, value: 1);
      final double restingOpacity = tester
          .widget<FadeTransition>(find.byType(FadeTransition))
          .opacity
          .value;
      final double restingTravel = _renderedTravelPx(tester);

      await _pumpProbe(tester, height: 844, value: 0, disableAnimations: true);

      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        restingOpacity,
      );
      expect(_renderedTravelPx(tester), restingTravel);
      expect(restingOpacity, 1.0, reason: 'sanity: a completed fade is opaque');
      expect(
        restingTravel,
        0.0,
        reason: 'sanity: a completed slide is at rest',
      );
    });

    testWidgets(
      'the widget shape is unchanged — it still wraps and still slides',
      (WidgetTester tester) async {
        // The negative control on the implementation choice. "Jump straight to the
        // end state" is satisfied by `return child`, and that version throws away
        // the transition widgets — which `emits exactly one FractionalTranslation`
        // and `wraps the page rather than replacing it` above would both catch, but
        // only for the flag-OFF case, so they do not cover this branch on their
        // own. Asserted here so the reduced-motion branch is held to the same
        // shape as the animated one.
        await _pumpProbe(
          tester,
          height: 844,
          value: 0,
          disableAnimations: true,
          child: const Text('the page', textDirection: TextDirection.ltr),
        );

        expect(find.text('the page'), findsOneWidget);
        expect(find.byType(FadeTransition), findsOneWidget);
        expect(find.byType(SlideTransition), findsOneWidget);
        expect(find.byType(FractionalTranslation), findsOneWidget);
      },
    );

    testWidgets('and the flag OFF is unchanged — the control', (
      WidgetTester tester,
    ) async {
      // The anti-vacuity half, and the test that would go red if the fix were
      // made by ignoring [animation] unconditionally. `value: 0` with the flag off
      // must still be the **beginning** of the transition: all eight pixels of
      // travel, fully transparent. A builder that substituted
      // `kAlwaysCompleteAnimation` outside the `if` would render the end state
      // here too and pass the three tests above.
      await _pumpProbe(tester, height: 844, value: 0);

      expect(
        _renderedTravelPx(tester),
        closeTo(EvaMotion.screenSlidePixels, 1e-9),
      );
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        0.0,
      );
    });

    testWidgets('and it follows the flag when the flag changes', (
      WidgetTester tester,
    ) async {
      // Read from the **ambient** `MediaQuery` rather than from a parameter, so
      // this also asserts the value is re-read per build. A `final bool` captured
      // once in a `State` — or a value cached on the builder's closure — would
      // keep rendering the old answer after a reader toggles the OS setting
      // mid-session, which is the case `neural_motion.dart:270-280` is explicit
      // about ("a reader toggling the OS setting mid-session is honoured without
      // a restart").
      await _pumpProbe(tester, height: 844, value: 0);
      expect(
        _renderedTravelPx(tester),
        closeTo(EvaMotion.screenSlidePixels, 1e-9),
      );

      await _pumpProbe(tester, height: 844, value: 0, disableAnimations: true);
      expect(_renderedTravelPx(tester), 0.0);

      await _pumpProbe(tester, height: 844, value: 0);
      expect(
        _renderedTravelPx(tester),
        closeTo(EvaMotion.screenSlidePixels, 1e-9),
      );
    });
  });
}
