import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The viewport every ambient golden and pixel test is captured at.
///
/// Fixed, because a golden is only reproducible if the surface is. The default
/// test surface is 800x600 logical at devicePixelRatio 3, which is neither a
/// phone nor anything the orb offsets were authored for; 390x844 is the window
/// `ORB_CONFIGS` positions its orbs for (`x: -160, y: 640`, `ds.tsx:73-77`), so
/// the goldens show what the prototype showed.
const Size kAmbientSurface = Size(390, 844);

/// Pins the test surface and restores the framework's defaults afterwards.
///
/// `addTearDown` rather than a `setUp`: a test that overrides the view and does
/// not restore it makes every *later* test in the file non-deterministic, which
/// looks exactly like a flaky golden and gets "fixed" by re-recording.
void useAmbientSurface(WidgetTester tester, {Size size = kAmbientSurface}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Wraps [child] in the composition the app root builds.
///
/// `NeuralMotionScope` above `MaterialApp` is the arrangement §13.2 mandates and
/// `lib/app/app.dart` now installs. It is reproduced here rather than reached
/// for through `EvangelionApp` so a test can pass a tier and a theme without the
/// app's own opinions getting in the way.
Widget evaAmbientHarness({
  required Widget child,
  ThemeData? theme,
  bool animationsEnabled = true,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
}) => NeuralMotionScope(
  animationsEnabled: animationsEnabled,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? EvaThemeDark.theme,
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        // Injected rather than toggled through
        // `platformDispatcher.accessibilityFeaturesTestValue`, so the reduced-
        // motion path is exercised through the same `MediaQuery` a device sets
        // and not through a test-only channel into the framework.
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child,
      ),
    ),
  ),
);

/// A `NeuralBackground` filling its parent, the way `NeuralScaffold` will.
///
/// The widget itself is a bare `CustomPaint` and sizes itself to nothing, which
/// is correct — a background must not decide the page's layout — so every test
/// has to give it a box. Doing that here means the fourteen goldens are all
/// captured through one arrangement instead of fourteen ad-hoc `Stack`s.
Widget ambientBackground({required NeuralVariant variant, NeuralTier? tier}) =>
    Stack(
      children: <Widget>[
        Positioned.fill(
          child: NeuralBackground(variant: variant, tier: tier),
        ),
      ],
    );

/// Advances the three shared clocks to a known phase and settles.
///
/// Golden determinism depends on this: `AnimationController.value` is a pure
/// function of elapsed time, so pumping a fixed duration puts every clock at an
/// exact value. Without it a golden captures whatever fraction of a frame the
/// test happened to stop on.
Future<void> pumpAmbientPhase(WidgetTester tester, Duration elapsed) async {
  await tester.pump();
  await tester.pump(elapsed);
}

/// The raw RGBA bytes of the `NeuralBackground`'s own layer.
///
/// ## WHY `toImageSync` AND NOT `toImage`
///
/// `RenderRepaintBoundary.toImage` returns a `Future` that resolves after the
/// *next* frame — it schedules one and waits for it. `flutter_test` runs the test
/// body inside a fake async zone where that frame never arrives, so the await
/// does not fail: it hangs, and the test dies at the ten-minute timeout with
/// nothing in the output to explain why. That is exactly what happened here on
/// the first attempt, across 19 tests at a cost of three hours of wall clock.
///
/// `toImageSync` asks for the pixels already sitting in the layer and hands back
/// an `ui.Image` directly, so no frame is needed. `toByteData` still crosses into
/// the engine, so that half stays inside `runAsync`, which steps out of the fake
/// zone for the duration.
///
/// The render object is fetched *before* `runAsync` on purpose: reading the
/// element tree inside it is fine, but it must not be the thing being measured.
Future<Uint8List> backgroundPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(_backgroundBoundary(tester));
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = boundary.toImageSync(pixelRatio: 1.0);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (data == null) {
      throw StateError('the background layer produced no pixels');
    }
    return data.buffer.asUint8List();
  });
  if (bytes == null) {
    throw StateError('runAsync returned no pixels');
  }
  return bytes;
}

/// The `RepaintBoundary` §13.1 puts around the background.
///
/// Anchored as a descendant of `NeuralBackground` rather than as "the first
/// `RepaintBoundary` in the tree": `MaterialApp`, `Scaffold` and `Stack` all
/// insert their own, and "first" would silently start capturing the wrong layer
/// the day any of them does.
Finder _backgroundBoundary(WidgetTester tester) => find.descendant(
  of: find.byType(NeuralBackground),
  matching: find.byType(RepaintBoundary),
);

/// The `RepaintBoundary` widget instance `NeuralBackground.build` created.
///
/// **This is the rebuild counter.** `NeuralBackground` is a
/// `StatelessWidget`, so its `build` re-running is the only way anything inside
/// it can be rebuilt by Flutter; the `RepaintBoundary` it returns is a fresh
/// object each time it runs, so `identical` across two samples means "did not
/// rebuild". Counting instances would need a counter in production code;
/// identity needs none.
Widget backgroundBoundaryInstance(WidgetTester tester) =>
    tester.widget(_backgroundBoundary(tester));

/// The `CustomPaint` the `ListenableBuilder`'s closure produced.
///
/// The counterpart to [backgroundBoundaryInstance]: §13.1's `ListenableBuilder`
/// *should* rebuild per frame, and this is how that is observed — a new painter
/// each time the closure runs.
CustomPaint backgroundPaintInstance(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint));
