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
      //
      // **The source scan is the assertion**, and it is here rather than in a
      // comment because this test used to *be* the comment: it pumped the widget,
      // asserted `takeException()` was null, and left the promise its name made to
      // a reader. The real coverage was the viewport sweep below, which is a
      // behavioural check and cannot see a `minHeight` written into a padding or a
      // `ConstrainedBox` — defect #9 is about a **number**, and a number is a
      // source fact.
      //
      // The scan strips comments first, which is not optional here:
      // `neural_scaffold.dart`'s own doc quotes `minHeight: 844` three times while
      // explaining that the transcription carries none of them, so a raw substring
      // search over the file would fail on the documentation. That is exactly why
      // the stripper is shared (`project_import_graph.dart`'s `withoutDartComments`)
      // rather than written a third time.
      final String code = withoutDartComments(
        File.fromUri(
          packageRoot.uri.resolve(
            'lib/core/design_system/widgets/neural_scaffold.dart',
          ),
        ).readAsStringSync(),
      );
      expect(code, isNot(contains('minHeight')), reason: 'defect #9, in full');
      expect(code, isNot(contains('844')), reason: 'and its number');

      await pumpAt(tester, scaffold());
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
      //
      // ## THE EXACT SET, NOT A SUBSTRING
      //
      // The first version asserted `isNot(contains(contains('lang')))` — a
      // case-sensitive four-character substring on the parameter *name*. That kills
      // `language` and leaves `scriptureLanguage` (capital L), `Locale? locale`,
      // `readingLanguage`, `script`, `direction` and `textDirection` all green. The
      // requirement is about a **concept**; the check was about a **spelling**, and
      // a spelling is the easiest thing in the world to route around.
      //
      // So the assertion is the **whole set**, lower-cased. Adding any parameter at
      // all now fails, which is the point: `NeuralScaffold` is the screen root, and
      // a new parameter on it is a decision every screen inherits, not a default.
      // The two spelling checks are kept as well, because they are what makes a
      // failure *legible*: "the set grew" says what happened, "this one parameter
      // looks like a language" says why it matters.
      expect(
        _scaffoldConstructorParameters(),
        <String>{
          'variant',
          'child',
          'scrollable',
          'padding',
          'bottomfade',
          'tier',
          'key',
        },
        reason:
            'D2 — the language arrives inside `variant`, not beside it, and every '
            'parameter this widget accepts is listed. A new one is a deliberate '
            'act on the screen root: add it here with the reason it is allowed.',
      );
      expect(
        _scaffoldConstructorParameters(),
        isNot(contains(contains('lang'))),
        reason: 'and no parameter may be named for a language',
      );
      expect(
        _scaffoldConstructorParameters(),
        isNot(contains(contains('locale'))),
        reason: 'nor for a locale',
      );
      // `variant` and `child` are the two the constructor requires, so they are
      // the two whose disappearance would break every call site in the suite
      // loudly. Named explicitly anyway: they are what the D2 argument above is
      // actually about, and a set assertion alone says nothing about which entries
      // are load-bearing.
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

/// The constructor's parameter names, read off the widget's own source, **lower
/// cased**.
///
/// `dart:io` in a test is not a shortcut: Dart has no reflection, so a test
/// *cannot* enumerate a constructor's parameters at run time, and the honest
/// alternative — asserting that a hand-written list of names still compiles — is
/// not an assertion about the widget at all. Reading the source is the technique
/// `no_colour_literals_test.dart` and `barrel_test.dart` already use in this
/// repository, and it fails closed on a missing file.
///
/// Comments are stripped first: a doc comment that *shows* a constructor would
/// otherwise be read as one, and this file's whole subject is a number that only
/// appears in prose.
///
/// ## WHY THE SPLITTER IS A DEPTH COUNTER
///
/// The first version did `constructor.group(1)!.split(',')` and then took the last
/// `Identifier` after splitting each fragment on `[.=]`. That silently produced
/// garbage for every parameter **with a default value**, because a default is where
/// both the `,` and the `.` live:
///
/// ```
/// this.scrollable = false   →  'false'
/// this.padding = const EdgeInsets.symmetric(horizontal: EvaSpacing.lg)  →  'lg)'
/// ```
///
/// Four of this constructor's seven parameters have defaults, so the old reader
/// returned `['variant', 'child', 'false', 'lg)', 'false', 'tier', 'key']`. Nothing
/// noticed, because the only assertions over it were `contains('variant')`,
/// `contains('child')` — the two parameters without defaults — and a `lang`
/// substring that garbage does not contain. A reading that is wrong about four
/// entries out of seven still satisfies every question that was asked of it.
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
  ).firstMatch(withoutDartComments(file.readAsStringSync()));
  expect(
    constructor,
    isNotNull,
    reason: 'the constructor declaration must be found',
  );

  return <String>[
    for (final String fragment in _splitTopLevel(constructor!.group(1)!))
      if (_parameterName(fragment).isNotEmpty) _parameterName(fragment),
  ];
}

/// [body] split on the commas that separate parameters — and only those.
///
/// `(` , `[` and `{` are counted, `)` , `]` and `}` close them, and `<` / `>` are
/// **not**: a generic argument list in a default value (`const <BoxShadow>[…]`)
/// always arrives inside one of the three counted brackets, whereas `>` also appears
/// in an arrow (`=>`) and in a comparison, and counting those would corrupt the
/// split in exactly the cases a parameter default can contain.
List<String> _splitTopLevel(String body) {
  final List<String> parts = <String>[];
  final StringBuffer current = StringBuffer();
  int depth = 0;
  for (int i = 0; i < body.length; i++) {
    final String ch = body[i];
    if (ch == '(' || ch == '[' || ch == '{') depth++;
    if (ch == ')' || ch == ']' || ch == '}') depth--;
    if (ch == ',' && depth == 0) {
      parts.add(current.toString());
      current.clear();
      continue;
    }
    current.write(ch);
  }
  if (current.isNotEmpty) parts.add(current.toString());
  return parts;
}

/// The parameter's own name out of one constructor fragment.
///
/// Each parameter is one of `required this.x`, `this.x`, `super.x`, `x`,
/// `x = default` or `required this.x = default`. The name is the **last**
/// identifier before any default value — taking the first yielded
/// `['required', 'this', …]`, which matches nothing and asserts nothing.
String _parameterName(String fragment) {
  String head = fragment.trim();
  final int equals = head.indexOf('=');
  if (equals >= 0) head = head.substring(0, equals).trim();
  if (head.isEmpty) return '';
  return head.split(RegExp(r'[.\s]')).last.trim().toLowerCase();
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
