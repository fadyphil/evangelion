import 'dart:ui' as ui;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The viewport every ambient golden and pixel test is captured at.
///
/// Fixed, because a golden is only reproducible if the surface is. The default
/// test surface is 800x600 logical at devicePixelRatio 3, which is neither a
/// phone nor anything the orb offsets were authored for; 390x844 is the window
/// `ORB_CONFIGS` positions its orbs for (`x: -160, y: 640`, `ds.tsx:77-80`), so
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
///
/// [animationsEnabled] is passed through **explicitly**, so the scope never
/// falls back to its default. The default now reads the platform's
/// `disableAnimations`, which would make every ambient test in the suite
/// depend on the host's accessibility setting — a test that passes on one
/// machine and paints nothing on another, which reads exactly like a broken
/// golden. `neural_motion_test.dart` drives the default directly.
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

/// The viewport §14's text-scaling requirement is stated at: 320px wide.
///
/// `09-quality-gates.md` §14 — "text scales to 1.22× without overflow at 320px
/// width". Both numbers come from there and neither is negotiated.
const Size kNarrowSurface = Size(320, 568);

/// The text scale §14 names, as a plain double for readability at call sites.
const double kEvaRequiredTextScale = 1.22;

/// Wraps [child] in the composition a Phase-3 primitive is pumped inside.
///
/// Narrower than [kAmbientSurface] and deliberately so: the ambient goldens want
/// a phone at 390 so the orb offsets land where the prototype put them, while
/// §14's overflow requirement is at **320**. Using the ambient surface for a
/// primitive golden would test the wrong width and every overflow test would be
/// passing for the wrong reason.
///
/// [textScale] is injected through [MediaQuery.textScalerOf], which is where a
/// device puts it — not through `MaterialApp.builder`, which is where Phase 5
/// will install `evaScalerFor`. That distinction matters: a test that installed
/// the reader's *preference* here would be testing the wrong scaler, and the
/// §14 requirement is about the platform's accessibility scaling.
Widget evaPrimitiveHarness({
  required Widget child,
  ThemeData? theme,
  double textScale = 1.0,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  TextDirection textDirection = TextDirection.ltr,
  // Retained so a caller can pass it, but the surface is fixed by
  // [pumpPrimitive] instead — see that function for why a `SizedBox` in here
  // does not work.
  Size? size,
  bool ambientAnimations = false,
}) => NeuralMotionScope(
  // OFF by default, and that is not a shortcut. A primitive test never paints a
  // [NeuralBackground], so the three shared clocks tick forever over nothing —
  // and a forever-ticking ticker makes `pumpAndSettle` time out, which silently
  // costs every test that wanted to settle a press animation. This is a
  // *different* switch from [disableAnimations]: that one is §14's reduced-motion
  // requirement and is passed through untouched.
  animationsEnabled: ambientAnimations,
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
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(textDirection: textDirection, child: child),
      ),
    ),
  ),
);

/// Pumps [child] on a **320×568** surface at [textScale], and settles nothing.
///
/// ## WHY THE VIEW IS SIZED HERE AND NOT BY A `SizedBox`
///
/// The obvious arrangement — a `SizedBox(width: 320, …)` inside
/// `MaterialApp.home` — does not work, and it fails *quietly*: the widget under
/// test reports the full 800×600 test surface and every width assertion against
/// it is measuring the wrong number. A `SizedBox` is a `RenderConstrainedBox`,
/// and its size is its **child's** size, so a child that lays out against the
/// incoming constraints rather than its own intrinsic size simply fills the
/// screen. [useAmbientSurface] sets `tester.view.physicalSize`, which is the
/// mechanism Phase 2's goldens already use and which does pin the viewport.
///
/// [size] and [textScale] are both parameters because §14 names both numbers and
/// a caller should have to choose them, not inherit them by accident.
Future<void> pumpPrimitive(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Size size = kNarrowSurface,
  double textScale = 1.0,
  bool disableAnimations = false,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: theme,
      textScale: textScale,
      disableAnimations: disableAnimations,
      textDirection: textDirection,
      child: child,
    ),
  );
}

/// The theme under test, one per entry so no test body ever loops over themes.
///
/// The loop-out rule is not a style preference. `MaterialApp` installs an
/// `AnimatedTheme` that lerps a theme change over `kThemeAnimationDuration`,
/// and the single zero-duration `pump()` after `pumpWidget` does not advance it
/// — so two captures in one body wrote the first palette into the second file.
/// Phase 2 shipped two byte-identical "light" goldens that way. A list of themes
/// iterated by `testWidgets` gives one body per theme for free.
final List<(String, ThemeData)> kEvaThemes = <(String, ThemeData)>[
  ('dark', EvaThemeDark.theme),
  ('light', EvaThemeLight.theme),
];

/// Tabs until [finder] — or something inside it — holds primary focus.
///
/// The mechanical way to answer "can a keyboard reach this?" without adding a
/// test-only focus API to a production widget. Bounded rather than unbounded so a
/// control that is *never* reachable fails in a fixed number of steps instead of
/// hanging until the ten-minute timeout, which is what the first attempt at
/// this helper did.
Future<void> tabUntilFocused(
  WidgetTester tester,
  Finder finder, {
  int maxTabs = 12,
}) async {
  for (int i = 0; i < maxTabs; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (find
        .descendant(of: finder, matching: find.byType(Focus))
        .evaluate()
        .isNotEmpty) {
      final FocusNode? node = tester
          .widgetList<Focus>(
            find.descendant(of: finder, matching: find.byType(Focus)),
          )
          .map((Focus focus) => focus.focusNode)
          .where((FocusNode? node) => node != null)
          .firstOrNull;
      if (node != null && node.hasFocus) return;
    }
    if (_primaryFocusIsInside(tester, finder)) return;
  }
  throw StateError(
    'tabUntilFocused: nothing under $finder took focus after $maxTabs tabs',
  );
}

bool _primaryFocusIsInside(WidgetTester tester, Finder finder) {
  final FocusNode? node = FocusManager.instance.primaryFocus;
  if (node == null) return false;
  // `find.byWidget` needs a Widget; a `FocusNode` is not one, and a node has no
  // `Focus` widget that can be found by value because several may share it. So
  // the check is the node's own flag plus containment of the finder.
  return node.hasFocus &&
      find
          .descendant(of: finder, matching: find.byType(Focus))
          .evaluate()
          .isNotEmpty;
}

/// The `Border`s currently painted anywhere under [finder].
///
/// The focus-ring gate compares these against [evaFocusRingBorder], so it reads
/// what is **rendered** rather than re-deriving the number under test. A gate that
/// re-derives the value it is checking agrees with a wrong widget whenever both
/// are wrong the same way.
List<Border> renderedBorders(WidgetTester tester, Finder finder) {
  final List<Border> borders = <Border>[];
  for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
    find.descendant(of: finder, matching: find.byType(DecoratedBox)),
  )) {
    final Decoration decoration = box.decoration;
    if (decoration is! BoxDecoration) continue;
    // `BoxDecoration.border` is a `BoxBorder`, because a decoration may also be
    // rounded on some sides only. §14's ring is a uniform `Border.all`, so a
    // partial border is simply not a ring and is skipped — which is why the gate
    // also asserts the count, not just the presence of a match.
    final BoxBorder? border = decoration.border;
    if (border is Border) borders.add(border);
  }
  return borders;
}

/// The [SemanticsNode] at [finder].
///
/// A helper rather than `tester.getSemantics(finder)` spelled out at every call
/// site for one reason: `SemanticsNode` lives in `package:flutter/semantics.dart`,
/// which `material.dart` does **not** re-export, so every file that asserts on a
/// node has to add an import that is otherwise unused. Here it is used once.
///
/// `finder` must resolve to exactly one node. [SemanticsNode] is not `Object`-safe
/// across subtree rebuilds, so it is read eagerly and not held.
SemanticsNode semanticsOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder);
