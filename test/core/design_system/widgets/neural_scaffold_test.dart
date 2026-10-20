import 'dart:io';

import 'package:evangelion/core/design_system/barrel.dart';
// The curtain's shape moved to `core/domain/entities/curtain_shape.dart` in Task
// 5.7 — see that file's doc for why the prototype's ONE `data-shape` attribute
// (`:1463`) is one type rather than two. It is imported **by path**, the way
// every shared-kernel entity is: the barrel re-exports nothing from a domain.
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
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
    bool scrollable = true,
    bool bottomFade = false,
    CurtainShape curtain = CurtainShape.bottom,
    LumenShaderTier? tier,
    Widget? child,
  }) => NeuralScaffold(
    scrollable: scrollable,
    bottomFade: bottomFade,
    curtain: curtain,
    tier: tier,
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

  group('D2 — the background does not vary by screen', () {
    testWidgets('the ambient carries no screen, so it cannot vary by one', (
      WidgetTester tester,
    ) async {
      // ## THE SURVIVING CLAIM, AND IT IS THE STRONGER ONE
      //
      // The claim this group used to make was that the two reading arms paint
      // different orb groups — a claim about a **per-screen selection**. The
      // redesign replaced that selection with **one canvas for every screen**
      // (`eva/redesign.html:46`), and the orbs that carried it are retired, so
      // the selection is gone.
      //
      // What is left is stronger than "the two arms match": there is no input
      // left that could make the ambient vary. `LumenBackground`'s only
      // optional parameter is the tier, so a screen cannot name itself to the
      // ambient even if it wanted to — and a future one that adds a screen
      // parameter has to come here and say why.
      expect(
        _constructorParametersOf(
          path: 'lib/core/design_system/effects/lumen_background.dart',
          className: 'LumenBackground',
        ),
        <String>{'tier', 'key'},
        reason:
            'the ambient\'s whole parameter set. A screen-identifying '
            'parameter here would put a second background in the design, and '
            'the redesign gives every screen one canvas (`eva/redesign.html:46`)',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the scaffold passes its tier to the ambient unmodified', (
      WidgetTester tester,
    ) async {
      // The one knob the ambient does have, and the scaffold is its carrier.
      // It is asserted **through the tree** rather than against the scaffold's
      // own field, because a tier the scaffold holds and never forwards is a
      // parameter that does nothing.
      await pumpAt(
        tester,
        scaffold(tier: LumenShaderTier.noShafts, scrollable: false),
      );
      expect(
        tester.widget<LumenBackground>(find.byType(LumenBackground)).tier,
        LumenShaderTier.noShafts,
        reason: 'the tier must reach the ambient unmodified',
      );

      // And `null` — the default — means "resolve one", not "off".
      await pumpAt(tester, scaffold(scrollable: false));
      expect(
        tester.widget<LumenBackground>(find.byType(LumenBackground)).tier,
        isNull,
      );
    });

    testWidgets('the scaffold takes no language parameter of its own', (
      WidgetTester tester,
    ) async {
      // A `ScriptureLanguage` field would be a second source of truth for one
      // fact. Read from the widget's own source, because Dart has no reflection
      // and a hand-written list of parameter names would only assert that the
      // list still compiles.
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
          'child',
          'scrollable',
          'padding',
          'bottomfade',
          'curtain',
          'tier',
          'overlay',
          'key',
        },
        reason:
            'D2 — the background does not vary by screen, and every parameter '
            'this widget accepts is listed. A new one is a deliberate '
            'act on the screen root: add it here with the reason it is allowed.\n\n'
            '**`variant` is GONE, and its absence is the point.** It used to be '
            'the per-screen orb-group selector, and the orbs it selected are '
            'retired, so a parameter whose reason had died is a parameter that '
            'can only confuse the next reader. `eva/redesign.html:46` gives every '
            'screen one canvas.\n\n'
            '**`overlay` is the sixth, added for the `SealFab`.** It is a viewport-fixed '
            'widget placed above the content and below `bottomFade`\'s scrim, and the '
            'gate that caught it is the reason it is worth stating: the content is '
            'inside a `SingleChildScrollView` on four of the seven screens, so a caller '
            'placing a floating control in its own column produces one that scrolls '
            'away — which is not a floating control. The `Stack` this widget already '
            'owns is the prototype\'s `position: absolute; inset: 0` container '
            '(`ds.tsx:162`), so an overlay is the shape the prototype had rather than a '
            'second mechanism invented for Flutter. `null` on the four screens that '
            'have none, and `bottomFade` still paints over it so a scrolling screen\'s '
            'CTA gradient covers a bottom-right overlay instead of the other way round.\n\n'
            '**`curtain` is the seventh, added with `:112-115`.** '
            '`eva/redesign.html` '
            'declares `.scrim` once and overrides its whole `background` per '
            '`data-shape`, so a shape here is not a direction on one ramp — it picks '
            'between two different ones, and `:115`\'s `.88`-at-both-edges / '
            'nothing-in-the-middle is neither. A single `LinearGradient` hard-wired '
            'to the CTA\'s would have been a ramp the prototype does not have.',
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
      // `child` is the one the constructor requires, so it is the one whose
      // disappearance would break every call site in the suite loudly. Named
      // explicitly anyway: a set assertion alone says nothing about which
      // entries are load-bearing.
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
      await pumpAt(tester, scaffold(), theme: EvaThemeLight.theme);
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
      // `eva/redesign.html:113` — `rgba(6,7,12,.30) 22%`, `.80 46%`, `.92 100%`.
      // The last stop was `.95` (`ReadingEnScreen.tsx:83`) and the whole ramp was
      // two stops; `:113` is four, and its peak is *lighter*, which is the point
      // — a two-stop ramp that ends in a step paints a plate over the last verses.
      expect(gradient.stops, <double>[0, 0.22, 0.46, 1]);
      expect(gradient.colors, <Color>[
        const EvaColors.dark().canvas.withValues(alpha: 0),
        const EvaColors.dark().canvas.withValues(alpha: 0.30),
        const EvaColors.dark().canvas.withValues(alpha: 0.80),
        const EvaColors.dark().canvas.withValues(alpha: 0.92),
      ]);
      expect(gradient.colors.last.a, isNot(closeTo(0.95, 1e-9)));
    });

    testWidgets('the light ramp is `:61`\'s, and it is not the dark one', (
      WidgetTester tester,
    ) async {
      // `eva/redesign.html:61` re-states `.scrim` under
      // `.screen[data-mode=light]` with its own four alphas — `.35 / .82 / .94`
      // against the dark ramp's `.30 / .80 / .92`. A per-brightness ramp is the
      // prototype's own shape, so this is a transcription rather than an
      // invention, and those three numbers are what distinguish it.
      await pumpAt(
        tester,
        scaffold(bottomFade: true),
        theme: EvaThemeLight.theme,
      );
      final LinearGradient gradient =
          _scrimDecorations(tester).single.gradient! as LinearGradient;
      expect(gradient.stops, <double>[0, 0.22, 0.46, 1]);
      expect(
        gradient.colors.map((Color color) => color.a).toList(),
        orderedEquals(<Object>[
          0.0,
          closeTo(0.35, 1e-9),
          closeTo(0.82, 1e-9),
          closeTo(0.94, 1e-9),
        ]),
        reason: ':61 carries an alpha no other table has',
      );
    });

    testWidgets('the substituted colour is `canvas`, and it says so', (
      WidgetTester tester,
    ) async {
      // `:113` shades with `rgba(6,7,12,…)` and `:61` with
      // `rgba(245,242,234,…)` — the prototype's own floor colours, beside a
      // `#05081A` canvas and a `#F0EEFF` one, and **neither is a token**. They are
      // substituted by `canvas` (`skyStarFill`'s precedent): the ramp's *shape* is
      // the prototype's and the *pigment* is this design system's. The alphas
      // above are the prototype's verbatim, which is why they are asserted.
      for (final (String label, ThemeData theme) in kEvaThemes) {
        await pumpAt(tester, scaffold(bottomFade: true), theme: theme);
        final LinearGradient gradient =
            _scrimDecorations(tester).single.gradient! as LinearGradient;
        for (final Color color in gradient.colors) {
          expect(
            color.toARGB32() & 0x00FFFFFF,
            theme.extension<EvaColors>()!.canvas.toARGB32() & 0x00FFFFFF,
            reason: label,
          );
        }
      }
    });

    testWidgets('the three shapes are three DIFFERENT ramps', (
      WidgetTester tester,
    ) async {
      // `:113`/`:114` share a table and differ only in direction; `:115` has its
      // own alphas (`.88`, not `.92`) and a flat transparent centre. Reading the
      // enum as "a direction on one ramp" is the reading that gets `sides` wrong.
      await pumpAt(tester, scaffold(bottomFade: true));
      final LinearGradient bottom =
          _scrimDecorations(tester).single.gradient! as LinearGradient;
      expect(bottom.begin, Alignment.bottomCenter);
      expect(bottom.end, Alignment.topCenter);

      await pumpAt(
        tester,
        scaffold(bottomFade: true, curtain: CurtainShape.top),
      );
      final LinearGradient top =
          _scrimDecorations(tester).single.gradient! as LinearGradient;
      expect(top.begin, Alignment.topCenter);
      expect(top.end, Alignment.bottomCenter);
      expect(
        top.stops,
        bottom.stops,
        reason: '`:113` and `:114` share a table',
      );
      expect(
        top.colors.map((Color c) => c.a).toList(),
        bottom.colors.map((Color c) => c.a).toList(),
      );

      await pumpAt(
        tester,
        scaffold(bottomFade: true, curtain: CurtainShape.sides),
      );
      final LinearGradient sides =
          _scrimDecorations(tester).single.gradient! as LinearGradient;
      expect(sides.stops, <double>[0, 0.2, 0.8, 1]);
      expect(
        sides.colors.map((Color c) => c.a).toList(),
        <double>[0.88, 0, 0, 0.88],
        reason:
            '`:115` — `.88` at both edges and `transparent 20% 80%` between, '
            'which Flutter spells as two stops of nothing',
      );
    });

    testWidgets('the shape does NOT change the scrim\'s extent', (
      WidgetTester tester,
    ) async {
      // `:112`'s `.scrim` is `position:absolute; inset:0` — the **full-screen**
      // curtain, a different layer from the reader CTA's
      // (`ReadingEnScreen.tsx:80-86`), and this widget paints the latter. So the
      // shape picks the ramp and [kNeuralScaffoldFadeHeight] still picks the
      // height; a `sides` curtain that suddenly went full-bleed would be the other
      // scrim arriving through this parameter.
      double scrimHeight() => tester
          .widget<Positioned>(
            find.descendant(
              of: find.byType(NeuralScaffold),
              matching: find.byType(Positioned),
            ),
          )
          .height!;

      await pumpAt(tester, scaffold(bottomFade: true));
      final double bottomHeight = scrimHeight();
      await pumpAt(
        tester,
        scaffold(bottomFade: true, curtain: CurtainShape.sides),
      );
      expect(
        scrimHeight(),
        bottomHeight,
        reason: 'the extent is the CTA block for every shape',
      );
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

      await pumpAt(tester, scaffold(bottomFade: true));
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

    testWidgets('the OPAQUE part stays inside the content reserve', (
      WidgetTester tester,
    ) async {
      // THE TEST THAT WAS MISSING, and the reason the shade covered the verses.
      //
      // `stops: [0, 0.40]` means the gradient reaches full opacity 60% of its OWN
      // height above the bottom edge — so the height of the scrim and the height
      // at which it becomes opaque are two different numbers, and only the second
      // one decides whether a reader can read the last line of the passage.
      //
      // The test directly above cannot see any of this. It asserts `wide > narrow`
      // and that the rendered height equals `kNeuralScaffoldFadeHeight(...)` — and
      // both hold for the *wrong* formula too, because a function asked to confirm
      // its own output is always self-consistent. That formula added the content's
      // 130px reserve into the scrim's extent, giving 234px at 390 wide, so the
      // opaque region began 140.4px above the bottom while the content stopped at
      // 130: the final ~10px of scripture sat under solid `canvas`. VERIFIED —
      // restoring the old sum makes this test red at all three widths below.
      //
      // The assertion is the RELATIONSHIP, not a number, so it holds at any width
      // and cannot be satisfied by re-deriving the same mistake.
      const double contentReserve = 130; // ReadingEnScreen.tsx:26
      // `eva/redesign.html:113`'s last rung is at 46%, so the shoulder begins
      // `1 - 0.46 = 54%` of the scrim's height above the bottom edge. The old
      // `stops: [0, 0.40]` made it `60%` — so `:113` moved the shoulder 6.2px
      // earlier at 390 wide (56.2 rather than 62.4) AND lowered its peak from .95
      // to .92. The relationship, not the number, is what is asserted here.
      const double opaqueFraction = 1 - 0.46; // stops: [0, .22, .46, 1]

      for (final double width in <double>[320, 390, 430]) {
        await pumpAt(
          tester,
          scaffold(bottomFade: true),
          size: Size(width, width == 320 ? 568 : (width == 390 ? 844 : 932)),
        );
        final double height = kNeuralScaffoldFadeHeight(
          BoxConstraints(maxWidth: width),
        );
        final double opaqueStart = height * opaqueFraction;

        expect(
          opaqueStart,
          lessThanOrEqualTo(contentReserve),
          reason:
              'at ${width.toInt()}px wide the scrim is ${height.toStringAsFixed(1)}px '
              'tall and is fully opaque from ${opaqueStart.toStringAsFixed(1)}px '
              'above the bottom, but the content only reserves '
              '${contentReserve.toInt()}px — the last verses would be painted over',
        );
      }
    });
  });

  group('ambient layering', () {
    testWidgets('the background is behind the content and fills the page', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      final Stack stack = tester.widget<Stack>(find.byType(Stack).first);
      // **The redesign's ambient**: the aurora is mounted in the screen root
      // (`eva/redesign.html:46`, `.screen canvas`), and `LumenBackground` is
      // what decides between it and the fallback.
      expect(stack.children.first, isA<LumenBackground>());
      expect(stack.fit, StackFit.expand);

      // And the **fallback** is what this harness paints, because it
      // publishes no `LumenPreferencesScope` — an ambient with no choices
      // published has no choices to paint with. The ambient is still first in
      // the tree, and still behind the content.
      expect(find.byType(LumenBackground), findsOneWidget);
    });

    testWidgets('the fallback fills the page, and it is the first thing', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold());
      // The background's own box is the page's box. The ambient sizes itself
      // to nothing in the fallback case, so the *scaffold's* stack is what
      // gives it a box — and the assertion is on the painted result, not on a
      // widget's declared size.
      final Size painted = tester.getSize(find.byType(LumenBackground));
      expect(painted, const Size(390, 844));
    });

    testWidgets('reduced motion drops the ambient tier', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, scaffold(), disableAnimations: true);
      expect(
        LumenTiers.resolve(
          size: const Size(390, 844),
          animationsEnabled: false,
        ),
        LumenShaderTier.off,
        reason:
            'reduced motion is the last word: `off` whatever the size says and '
            'whatever the override says',
      );
      // The visible consequence: the flat canvas paints and the aurora does
      // not. The `LumenBackground` is still mounted — the fallback is a
      // `ColoredBox` inside it, not a different widget.
      expect(
        find.descendant(
          of: find.byType(LumenBackground),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
        reason: 'no aurora means no `CustomPaint` at all',
      );
    });
  });

  // The golden that actually sees the scrim. The two above pump `scaffold()`
  // **without** `bottomFade`, so `:112-115`'s four-stop ramp is not in either of
  // them — a restyle of the scrim is invisible in every other golden in this
  // file, which is the kind of coverage that reads as coverage until the one
  // change it cannot see is made. This one has the verses a shade would be
  // painting over, so the ramp's shoulder is measured rather than asserted.
  for (final (String theme, ThemeData data) in kEvaThemes) {
    testWidgets('a golden of the scrim per theme — $theme', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        scaffold(
          scrollable: false,
          bottomFade: true,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text('The Word was in the beginning.'),
              Text('And the Word was with God.'),
              SizedBox(height: 40),
            ],
          ),
        ),
        theme: data,
      );
      await tester.pump();
      await expectLater(
        find.byType(NeuralScaffold),
        matchesGoldenFile('goldens/neural_scaffold_scrim_$theme.png'),
      );
    });
  }

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
              EvaButton(
                labelFamily: EvaTypography.uiFamily,
                label: 'Begin reflection',
                onPressed: _noop,
              ),
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
List<String> _scaffoldConstructorParameters() => _constructorParametersOf(
  path: 'lib/core/design_system/widgets/neural_scaffold.dart',
  className: 'NeuralScaffold',
);

/// A named constructor's parameter names, read off its own source, **lower
/// cased**.
///
/// [path] is package-relative and [className] is the class whose `const`
/// constructor is read. The two are parameters rather than two copies of the
/// reader because the reader is the fragile half and there are now **two**
/// subjects for it: this widget's own constructor and the ambient's — and the
/// ambient's parameter set is what proves that the background cannot vary by
/// screen.
List<String> _constructorParametersOf({
  required String path,
  required String className,
}) {
  final File file = File.fromUri(packageRoot.uri.resolve(path));
  expect(
    file.existsSync(),
    isTrue,
    reason: 'the source file must exist for this to mean anything',
  );

  final RegExpMatch? constructor = RegExp(
    'const ${RegExp.escape(className)}\\(\\{([^}]*)\\}\\)',
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
