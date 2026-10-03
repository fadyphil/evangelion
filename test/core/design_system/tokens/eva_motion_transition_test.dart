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
Future<Offset> _pumpProbe(
  WidgetTester tester, {
  required double height,
  required double value,
  Widget child = const SizedBox.expand(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(400, height);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
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

  group('the shape auto_route depends on', () {
    test('fadeSlide fits RouteTransitionsBuilder', () {
      // The structural fact `AppRouter.defaultRouteType` relies on: a function
      // of exactly the framework's four-parameter shape, assignable to the
      // typedef. Restated at runtime so a signature change is a failing test
      // rather than only a compile error.
      final RouteTransitionsBuilder builder = EvaMotion.fadeSlide;

      expect(builder, same(EvaMotion.fadeSlide));
    });
  });
}
