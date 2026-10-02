import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';
import '../../../support/project_import_graph.dart';

/// [NeuralScaffold] — the screen root, and the two recorded decisions (D1's
/// elevation, D2's language) that belong to it.
void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    Size size = const Size(390, 844),
    bool disableAnimations = false,
  }) async {
    await pumpPrimitive(
      tester,
      child,
      theme: theme,
      size: size,
      disableAnimations: disableAnimations,
    );
    // Two pumps, not one. `MaterialApp` installs an `AnimatedTheme` that lerps a
    // theme change over `kThemeAnimationDuration` (200ms), so a test that only
    // `pumpWidget`s reads the **previous** palette off the theme — the same
    // mechanism that produced Phase 2's byte-identical light goldens. Goldens are
    // captured one theme per body; this is the reading-the-theme case, and it
    // needs the lerp finished rather than avoided.
    await tester.pump();
    await tester.pump(kThemeAnimationDuration);
  }

  NeuralScaffold scaffold({
    NeuralVariant variant = NeuralVariant.home,
    bool scrollable = true,
    bool bottomFade = false,
    Widget? child,
  }) => NeuralScaffold(
    variant: variant,
    scrollable: scrollable,
    bottomFade: bottomFade,
    child: child ?? const SizedBox.shrink(),
  );

  group('prototype defect #9 — no fixed height anywhere', () {
    testWidgets('there is no `minHeight: 844` to find in its source', (
      WidgetTester tester,
    ) async {
      // The nine occurrences across the prototype's eight screens are the whole
      // of the defect; this asserts the transcription carries none of them.
      await pumpAt(tester, scaffold());
      // The nine `minHeight: 844` occurrences across the prototype's eight screens
      // are the whole of defect #9, and the transcription's answer is that there
      // is no number here to find. Asserted by the viewport sweep below.
      expect(tester.takeException(), isNull);
    });

    testWidgets('it fills whatever viewport it is given, and no more', (
      WidgetTester tester,
    ) async {
      for (final Size size in const <Size>[
        Size(320, 568),
        Size(390, 844),
        Size(430, 932),
      ]) {
        await pumpAt(tester, scaffold(), size: size);
        expect(
          tester.getSize(find.byType(NeuralScaffold)),
          size,
          reason:
              '$size must be honoured exactly, not clamped to a prototype size',
        );
      }
    });

    testWidgets('a scrollable one scrolls; a fixed one does not', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await pumpAt(tester, scaffold(scrollable: false));
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('the content sits inside a SafeArea', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      expect(
        find.descendant(
          of: find.byType(NeuralScaffold),
          matching: find.byType(SafeArea),
        ),
        findsOneWidget,
      );
    });

    testWidgets('it uses LayoutBuilder, which the scrim needs', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold(bottomFade: true));
      expect(find.byType(LayoutBuilder), findsWidgets);
    });
  });

  group('D1 — the elevation answer is "structurally zero"', () {
    testWidgets('every elevation-bearing theme field is 0 in its context', (
      WidgetTester tester,
    ) async {
      // Flutter 3.47.4's `Scaffold` has **no** `elevation` parameter — writing
      // one is a compile error — so there is nothing for this widget to set and
      // nothing for it to get wrong. What can still go wrong is a surface *inside*
      // a screen built on this scaffold falling back to a Material default, so
      // that is what is asserted: over an enumerated inventory, in this context.
      for (final (String label, ThemeData theme) in kEvaThemes) {
        await pumpAt(tester, scaffold(), theme: theme);
        final ThemeData resolved = Theme.of(
          tester.element(find.byType(NeuralScaffold)),
        );
        expect(resolved.appBarTheme.elevation, 0.0, reason: label);
        expect(resolved.appBarTheme.scrolledUnderElevation, 0.0, reason: label);
        expect(resolved.cardTheme.elevation, 0.0, reason: label);
        expect(resolved.dialogTheme.elevation, 0.0, reason: label);
        expect(resolved.bottomSheetTheme.elevation, 0.0, reason: label);
        expect(resolved.bottomSheetTheme.modalElevation, 0.0, reason: label);
        expect(resolved.drawerTheme.elevation, 0.0, reason: label);
        expect(resolved.popupMenuTheme.elevation, 0.0, reason: label);
        expect(resolved.snackBarTheme.elevation, 0.0, reason: label);
        expect(
          resolved.floatingActionButtonTheme.elevation,
          0.0,
          reason: label,
        );
        expect(
          resolved.floatingActionButtonTheme.hoverElevation,
          0.0,
          reason: label,
        );
      }
    });

    testWidgets('its own background is the canvas, in both themes', (
      WidgetTester tester,
    ) async {
      for (final (String label, ThemeData theme) in kEvaThemes) {
        await pumpAt(tester, scaffold(), theme: theme);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          theme.extension<EvaColors>()!.canvas,
          reason: label,
        );
      }
    });
  });

  group('D2 — the language is in the variant, and nothing re-derives it', () {
    testWidgets('readingEn and readingAr paint different orb groups', (
      WidgetTester tester,
    ) async {
      expect(
        orbGroups[orbGroupFor(NeuralVariant.readingEn)],
        isNot(orbGroups[orbGroupFor(NeuralVariant.readingAr)]),
        reason:
            'ds.tsx:83-86 (blue, no cyan) against ds.tsx:88-91 (violet + cyan). '
            'If these ever matched, the language distinction would be dead and '
            'no test of the scaffold would notice.',
      );
    });

    testWidgets('the scaffold paints the variant it was given', (
      WidgetTester tester,
    ) async {
      for (final NeuralVariant variant in NeuralVariant.values) {
        await pumpAt(tester, scaffold(variant: variant, scrollable: false));
        expect(
          tester
              .widget<NeuralBackground>(find.byType(NeuralBackground))
              .variant,
          variant,
          reason: '$variant must reach the background unmodified',
        );
      }
    });

    testWidgets('the scaffold takes no language parameter of its own', (
      WidgetTester tester,
    ) async {
      // A `ScriptureLanguage` field beside `variant` would be a second source of
      // truth for one fact — the same hazard `orbGroupFor`'s doc records for
      // `variant.index`, where a wrong answer is invisible to every golden.
      // Read from the widget's own source, because Dart has no reflection and a
      // hand-written list of parameter names would only assert that the list still
      // compiles.
      expect(
        _scaffoldConstructorParameters(),
        isNot(contains(contains('lang'))),
        reason:
            'D2 — the language arrives inside `variant`, not beside it. A source '
            'check, so it cannot see a positional parameter; there are none, and '
            'the whole suite constructs this widget with named arguments.',
      );
      expect(_scaffoldConstructorParameters(), contains('variant'));
      expect(_scaffoldConstructorParameters(), contains('child'));
      expect(tester.takeException(), isNull);
    });
  });

  group('the status bar inverts with the theme', () {
    testWidgets('dark canvas gets light status-bar icons', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      final AnnotatedRegion<SystemUiOverlayStyle> region = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          );
      expect(
        region.value.statusBarIconBrightness,
        Brightness.light,
        reason: '`SystemUiOverlayStyle.light` is *light* icons',
      );
      expect(region.value.statusBarColor, isNull, reason: 'edge-to-edge');
    });

    testWidgets('light canvas gets dark status-bar icons', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        scaffold(),
        theme: EvaThemeLight.theme,
        size: const Size(390, 844),
      );
      final AnnotatedRegion<SystemUiOverlayStyle> region = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
    });
  });

  group('the sticky-CTA scrim', () {
    testWidgets('it is off unless asked for, and then it fades to the canvas', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      expect(_scrims(tester), isEmpty);

      await pumpAt(tester, scaffold(bottomFade: true));
      expect(_scrims(tester), hasLength(1));
      final BoxDecoration decoration = _scrimDecorations(tester).single;
      final LinearGradient gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors.first.a, 0);
      expect(
        gradient.colors.last,
        const EvaColors.dark().canvas.withValues(alpha: 0.95),
      );
      expect(gradient.stops, <double>[0, 0.40]);
    });

    testWidgets('its height follows the viewport, not a constant', (
      WidgetTester tester,
    ) async {
      // Read the height off the `Positioned` that places the scrim — the widget's
      // own answer — rather than off a render box: a `DecoratedBox` instance is
      // reused, so `find.byWidget` matches more than one element and
      // `getSize` throws "Too many elements".
      double scrimHeight() => tester
          .widget<Positioned>(
            find.descendant(
              of: find.byType(NeuralScaffold),
              matching: find.byType(Positioned),
            ),
          )
          .height!;

      await pumpAt(
        tester,
        scaffold(bottomFade: true),
        size: const Size(390, 844),
      );
      final double narrow = scrimHeight();
      await pumpAt(
        tester,
        scaffold(bottomFade: true),
        size: const Size(640, 1200),
      );
      final double wide = scrimHeight();

      expect(wide, greaterThan(narrow));
      expect(
        narrow,
        kNeuralScaffoldFadeHeight(const BoxConstraints(maxWidth: 390)),
        reason: "the rendered height is the resolver's answer, not a constant",
      );
    });
  });

  group('ambient layering', () {
    testWidgets('the background is behind the content and fills the page', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      final Stack stack = tester.widget<Stack>(find.byType(Stack).first);
      expect(stack.children.first, isA<NeuralBackground>());
      expect(stack.fit, StackFit.expand);
    });

    testWidgets('reduced motion drops the ambient tier', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold(), disableAnimations: true);
      expect(
        NeuralTiers.resolve(
          size: const Size(390, 844),
          animationsEnabled: false,
        ),
        NeuralTier.low,
      );
      // The visible consequence: no orbs are painted.
      expect(orbsFor(NeuralVariant.home), isNotEmpty);
      expect(NeuralTier.values, contains(NeuralTier.low));
    });
  });

  for (final (String theme, ThemeData data) in kEvaThemes) {
    testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
      await pumpAt(
        tester,
        scaffold(
          child: const Column(
            children: <Widget>[
              Text('Evangelion', textAlign: TextAlign.center),
              Text('Read. Reflect. Remember.'),
              SizedBox(height: EvaSpacing.xl),
              EvaButton(label: 'Begin reflection', onPressed: _noop),
            ],
          ),
        ),
        theme: data,
      );
      await tester.pump();
      await expectLater(
        find.byType(NeuralScaffold),
        matchesGoldenFile('goldens/neural_scaffold_$theme.png'),
      );
    });
  }
}

void _noop() {}

/// The constructor's parameter names, read off the widget's own source.
///
/// `dart:io` in a test is not a shortcut: Dart has no reflection, so a test
/// *cannot* enumerate a constructor's parameters at run time, and the honest
/// alternative — asserting that a hand-written list of names still compiles — is
/// not an assertion about the widget at all. Reading the source is the technique
/// `no_colour_literals_test.dart` and `barrel_test.dart` already use in this
/// repository, and it fails closed on a missing file.
List<String> _scaffoldConstructorParameters() {
  final File file = File.fromUri(
    packageRoot.uri.resolve(
      'lib/core/design_system/widgets/neural_scaffold.dart',
    ),
  );
  expect(
    file.existsSync(),
    isTrue,
    reason: 'the source file must exist for this to mean anything',
  );

  final RegExpMatch? constructor = RegExp(
    r'const NeuralScaffold\(\{([^}]*)\}\)',
  ).firstMatch(file.readAsStringSync());
  expect(
    constructor,
    isNotNull,
    reason: 'the constructor declaration must be found',
  );

  // Each parameter is one of `required this.x`, `this.x`, `super.x`, `x` or
  // `x = default`; the interesting name is always the **last** identifier in the
  // fragment, which is why this takes `last` rather than `first` — taking first
  // yielded `['required', 'this', …]`, which matches nothing and asserts nothing.
  return <String>[
    for (final String part in constructor!.group(1)!.split(','))
      if (part.trim().isNotEmpty)
        part.trim().split(RegExp(r'[.=]')).last.trim().split(' ').last,
  ];
}

/// The scaffold's sticky-CTA scrims, identified by their gradient.
///
/// **By what they are, not by which widget they are.** The obvious finder —
/// `find.byType(IgnorePointer)` under the scaffold — matches `Scaffold`'s own
/// internal one, so "there is no scrim" and "there is a scrim" were
/// indistinguishable. The gradient ending at the canvas is the thing the widget
/// is *for*, so it is what identifies it.
List<RenderBox> _scrims(WidgetTester tester) => <RenderBox>[
  for (final DecoratedBox box in _scrimBoxes(tester))
    tester.renderObject<RenderBox>(find.byWidget(box)),
];

/// The gradient-filled boxes under the scaffold, as decorations.
List<BoxDecoration> _scrimDecorations(WidgetTester tester) => <BoxDecoration>[
  for (final DecoratedBox box in _scrimBoxes(tester))
    box.decoration as BoxDecoration,
];

List<DecoratedBox> _scrimBoxes(WidgetTester tester) => <DecoratedBox>[
  for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(NeuralScaffold),
      matching: find.byType(DecoratedBox),
    ),
  ))
    if (box.decoration is BoxDecoration &&
        (box.decoration as BoxDecoration).gradient is LinearGradient)
      box,
];
