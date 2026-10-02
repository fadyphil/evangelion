import 'package:evangelion/core/design_system/theme/eva_theme.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_dark.dart';
import 'package:evangelion/core/design_system/theme/eva_theme_light.dart';
import 'package:evangelion/core/design_system/tokens/eva_colors.dart';
import 'package:evangelion/core/design_system/tokens/eva_radii.dart';
import 'package:evangelion/core/design_system/tokens/eva_typography.dart';
import 'package:evangelion/core/design_system/tokens/sticker_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Both themes, paired with the palette each was built from.
///
/// Reading the palette back off the theme under test rather than off a literal is
/// deliberate: it is what makes "this theme really was built from these tokens"
/// an assertion about the wiring, instead of a second transcription of the token
/// tables that could drift from the first.
final List<({String name, ThemeData theme, EvaColors colors})> themes =
    <({String name, ThemeData theme, EvaColors colors})>[
      (name: 'dark', theme: EvaThemeDark.theme, colors: const EvaColors.dark()),
      (
        name: 'light',
        theme: EvaThemeLight.theme,
        colors: const EvaColors.light(),
      ),
    ];

void main() {
  group('each theme carries the palette it was built from', () {
    for (final ({String name, ThemeData theme, EvaColors colors}) t in themes) {
      test('${t.name}: the EvaColors extension round-trips', () {
        final EvaColors? resolved = t.theme.extension<EvaColors>();
        expect(resolved, isNotNull, reason: 'extensions list is empty');
        expect(
          resolved!.canvas,
          t.colors.canvas,
          reason: 'a different extension instance is installed',
        );
        expect(resolved.surface, t.colors.surface);
        expect(resolved.ember, t.colors.ember);
        expect(resolved.sticker.keys.length, t.colors.sticker.length);
      });

      test('${t.name}: brightness matches the palette it was built from', () {
        expect(
          t.theme.brightness,
          t.theme.colorScheme.brightness,
          reason: 'ThemeData.brightness and colorScheme.brightness disagree',
        );
        expect(
          t.theme.brightness,
          t.name == 'dark' ? Brightness.dark : Brightness.light,
        );
      });

      test('${t.name}: surfaces come from the palette', () {
        expect(t.theme.scaffoldBackgroundColor, t.colors.canvas);
        expect(t.theme.canvasColor, t.colors.canvas);
        expect(t.theme.cardColor, t.colors.surface);
        expect(
          t.theme.dividerColor,
          t.colors.line,
          reason: 'the divider IS the line token',
        );
        expect(t.theme.disabledColor, t.colors.ink3);
      });

      test('${t.name}: the colour scheme is derived, not invented', () {
        // Each field below is asserted against a named Eva token. §5.1 defines
        // fourteen tokens and `ColorScheme` has ~40 fields; the ones not listed
        // here are deliberately left unset so Material falls back to its own
        // defaults, which is the only way to avoid freezing an arbitrary colour.
        final ColorScheme scheme = t.theme.colorScheme;
        expect(scheme.primary, t.colors.ember, reason: 'primary ← ember');
        expect(scheme.onPrimary, t.colors.onEmber);
        expect(scheme.primaryContainer, t.colors.emberDeep);
        expect(scheme.onPrimaryContainer, t.colors.onEmber);
        expect(scheme.secondary, t.colors.emberDeep);
        expect(scheme.onSecondary, t.colors.onEmber);
        expect(scheme.tertiary, t.colors.ink2);
        expect(scheme.onTertiary, t.colors.surface);
        expect(scheme.error, t.colors.err, reason: 'error ← err');
        expect(scheme.onError, t.colors.onEmber);
        expect(scheme.surface, t.colors.surface);
        expect(scheme.onSurface, t.colors.ink);
        expect(scheme.onSurfaceVariant, t.colors.ink2);
        expect(scheme.outline, t.colors.ink3);
        expect(
          scheme.outlineVariant,
          t.colors.line,
          reason: 'outlineVariant is the hairline',
        );
        expect(scheme.surfaceDim, t.colors.canvas);
        expect(scheme.surfaceContainerLowest, t.colors.canvas);
        expect(scheme.shadow, t.colors.glassShadow);
      });

      test(
        '${t.name}: no surface tint, so nothing is tinted behind a layer',
        () {
          // Material 3 tints elevated surfaces with `primary`. On a flat,
          // hairline-separated system that reads as a stain, so the tint colour is
          // the surface colour — the tint is present and invisible rather than
          // absent-and-defaulted.
          expect(t.theme.colorScheme.surfaceTint, t.theme.colorScheme.surface);
          expect(t.theme.cardTheme.surfaceTintColor, isNull);
          expect(t.theme.bottomSheetTheme.surfaceTintColor, isNull);
        },
      );

      test('${t.name}: the focus ring is ember at 40% alpha', () {
        // `09-quality-gates.md` §14: "Focus + a 2px ember ring at 40% alpha on
        // every interactive widget." 40% is the only alpha the spec gives
        // anywhere in the design system, and it is used here.
        final Color focus = t.theme.focusColor;
        expect(focus.r, closeTo(t.colors.ember.r, 1e-6));
        expect(focus.g, closeTo(t.colors.ember.g, 1e-6));
        expect(focus.b, closeTo(t.colors.ember.b, 1e-6));
        expect(focus.a, closeTo(0.40, 1e-6), reason: 'the spec says 40%');
      });

      test('${t.name}: typography is the Eva mapping in the Eva ink', () {
        final TextTheme theme = t.theme.textTheme;
        expect(theme.displayLarge!.fontFamily, EvaTypography.displayFamily);
        expect(theme.headlineMedium!.fontFamily, EvaTypography.displayFamily);
        expect(theme.titleLarge!.fontFamily, EvaTypography.uiFamily);
        expect(theme.bodyMedium!.fontFamily, EvaTypography.uiFamily);
        expect(theme.labelSmall!.fontFamily, EvaTypography.uiFamily);
        expect(theme.bodyMedium!.color, t.colors.ink);
        expect(theme.titleMedium!.color, t.colors.ink);
      });

      test('${t.name}: every elevation-bearing field resolves to the flat token', () {
        // WHAT THIS ASSERTS, PRECISELY — because the class doc and an earlier
        // version of this comment both claimed more.
        //
        // It asserts that each field below reads `0`. It does NOT assert that the
        // theme read `EvaElevations` to get there, because it cannot: every token
        // is `0`, so `elevation: EvaElevations.card` and `elevation: 0` are the
        // same expression to the compiler and the same value at run time. A test
        // claiming otherwise would be asserting that two identical programs differ.
        //
        // The teeth it does have are real, and they are the ones that matter:
        //
        // - DELETE the line from `eva_theme.dart` and the field becomes `null`,
        //   because `ThemeData` leaves component-theme fields unset rather than
        //   filling in a default. `null` is not `0`, so this fires.
        // - PIN Material's own default (a card at 1, a drawer at 16) and this
        //   fires, which is the failure `eva_elevations.dart` exists to prevent.
        // - ADD a themed surface to `eva_theme.dart` and forget this class, and it
        //   fires — because the inventory below is written out field by field, so
        //   an unlisted field is a gap a reader can see. (It cannot *detect* one
        //   automatically; Dart has no reflection over `ThemeData`. That limit is
        //   stated here rather than implied away.)
        //
        // The inventory is deliberately broader than the six named tokens:
        // `EvaElevations.none` covers the surfaces §5 gives no role for, and those
        // are the ones Material leaves at the largest shadows.
        final List<({String field, double? value})> elevations =
            <({String field, double? value})>[
              (
                field: 'cardTheme.elevation',
                value: t.theme.cardTheme.elevation,
              ),
              (
                field: 'dialogTheme.elevation',
                value: t.theme.dialogTheme.elevation,
              ),
              (
                field: 'appBarTheme.elevation',
                value: t.theme.appBarTheme.elevation,
              ),
              (
                field: 'appBarTheme.scrolledUnderElevation',
                value: t.theme.appBarTheme.scrolledUnderElevation,
              ),
              (
                field: 'bottomSheetTheme.elevation',
                value: t.theme.bottomSheetTheme.elevation,
              ),
              (
                field: 'bottomSheetTheme.modalElevation',
                value: t.theme.bottomSheetTheme.modalElevation,
              ),
              (
                field: 'floatingActionButtonTheme.elevation',
                value: t.theme.floatingActionButtonTheme.elevation,
              ),
              (
                field: 'floatingActionButtonTheme.focusElevation',
                value: t.theme.floatingActionButtonTheme.focusElevation,
              ),
              (
                field: 'floatingActionButtonTheme.hoverElevation',
                value: t.theme.floatingActionButtonTheme.hoverElevation,
              ),
              (
                field: 'floatingActionButtonTheme.highlightElevation',
                value: t.theme.floatingActionButtonTheme.highlightElevation,
              ),
              (
                field: 'snackBarTheme.elevation',
                value: t.theme.snackBarTheme.elevation,
              ),
              (
                field: 'drawerTheme.elevation',
                value: t.theme.drawerTheme.elevation,
              ),
              (
                field: 'bottomNavigationBarTheme.elevation',
                value: t.theme.bottomNavigationBarTheme.elevation,
              ),
              (
                field: 'bottomAppBarTheme.elevation',
                value: t.theme.bottomAppBarTheme.elevation,
              ),
              (
                field: 'navigationDrawerTheme.elevation',
                value: t.theme.navigationDrawerTheme.elevation,
              ),
              (
                field: 'navigationBarTheme.elevation',
                value: t.theme.navigationBarTheme.elevation,
              ),
              (
                field: 'popupMenuTheme.elevation',
                value: t.theme.popupMenuTheme.elevation,
              ),
            ];

        expect(elevations, isNotEmpty);
        for (final ({String field, double? value}) e in elevations) {
          expect(
            e.value,
            0.0,
            reason:
                '${t.name} ${e.field} resolves to '
                '${e.value ?? 'null (unset — Material\'s own default would apply)'}'
                ', not the flat token',
          );
        }
        expect(elevations.length, 17, reason: 'the inventory is exhaustive');
      });

      test('${t.name}: container shapes use the radius tokens', () {
        // Compared as RADIUS VALUES, not as shapes. `RoundedRectangleBorder` does
        // not override `==`, so `expect(light.cardTheme.shape,
        // dark.cardTheme.shape)` is an identity comparison that passes only
        // because both are `const` and therefore canonicalised — the same trap as
        // comparing const `Color` objects, which is why the colour assertions in
        // this suite go through `toARGB32()`. Reading `topLeft.x` off the
        // `BorderRadius` compares doubles, which is a real comparison.
        expect(
          _radiusOf(t.theme.cardTheme.shape),
          EvaRadii.card,
          reason: 'a Card must not keep Material\'s 12dp default',
        );
        expect(
          _radiusOf(t.theme.dialogTheme.shape),
          EvaRadii.glassForm,
          reason: 'the dialog is the outermost container on a screen',
        );
        expect(
          _radiusOf(t.theme.bottomSheetTheme.shape),
          EvaRadii.heroPanel,
          reason: 'a bottom sheet shows only its top corners',
        );
        expect(
          _radiusOf(t.theme.snackBarTheme.shape),
          EvaRadii.card,
          reason: 'a snack bar is a card-like glass panel',
        );
      });

      test('${t.name}: the bottom sheet rounds its top corners and only those', () {
        // `_radiusOf` reads `topLeft.x`, so `BorderRadius.vertical(top: r)` and
        // `BorderRadius.all(r)` are indistinguishable through it — and they are
        // not the same shape. `eva_theme.dart` says why: "Only the top corners
        // are on screen; a bottom sheet that rounds all four reads as a floating
        // card." Without this, the comment is a claim and rounding all four
        // corners ships.
        final ShapeBorder? shape = t.theme.bottomSheetTheme.shape;
        expect(shape, isA<RoundedRectangleBorder>());
        final BorderRadiusGeometry geometry =
            (shape! as RoundedRectangleBorder).borderRadius;
        expect(geometry, isA<BorderRadius>());

        final BorderRadius radius = geometry as BorderRadius;
        expect(radius.topLeft.x, EvaRadii.heroPanel);
        expect(radius.topRight.x, EvaRadii.heroPanel, reason: 'symmetric');
        expect(
          radius.bottomLeft.x,
          0.0,
          reason: 'the bottom edge is flush with the screen',
        );
        expect(radius.bottomRight.x, 0.0);
      });

      test('${t.name}: a radius literal inlined over the token is not a bug', () {
        // NOTED, NOT ASSERTED, AND DELIBERATELY SO. The Phase 1 review recorded
        // that `Radius.circular(EvaRadii.card)` → `Radius.circular(18)` survives
        // 3/3 mutations and asked for it to be caught. It is caught here only as
        // a comment, because the mutation is *provably behaviour-preserving*:
        //
        //     Radius.circular(EvaRadii.card)  ==  Radius.circular(18)
        //
        // by the definition of `EvaRadii.card`. The two expressions compute the
        // same `Radius` from the same double, so no run-time observation can tell
        // them apart — the same structural limit as the zero-elevation case in
        // `eva_elevations.dart`, and for the same reason: inlining a const is the
        // classic constant-propagation mutation, which changes the program's text
        // and not its behaviour.
        //
        // A test that caught it would therefore be asserting textual fidelity —
        // reading the source and regexing for the identifier — which is precisely
        // what the Phase 1 review deleted from `eva_typography_test.dart` for
        // false-failing two legitimate edits and being blind to the mutation that
        // mattered. The honest guarantee is the one above: each container holds
        // the radius its token names, and it keeps holding it when the token moves,
        // which is what "the token table is the single source of truth" actually
        // has to mean.
        expect(_radiusOf(t.theme.cardTheme.shape), EvaRadii.card);
        expect(
          EvaRadii.card,
          18.0,
          reason:
              '§5.3 — and the assertion above tracks '
              'it, so a token change moves the shape with it',
        );
      });

      test('${t.name}: every field this theme sets is pinned to its token', () {
        // THE COMPLEMENT OF THE ELEVATION INVENTORY. These seven-plus fields were
        // set in `eva_theme.dart` and asserted nowhere, so each survived a
        // visibly-wrong mutation: a divider that was not the hairline, an app bar
        // whose foreground did not match the theme ink, a FAB that painted ink on
        // the accent. "Set" is not the same as "chosen", and the difference is
        // invisible until a golden is re-captured to match the mistake.
        //
        // Deliberately value assertions rather than `identical` comparisons:
        // `Color ==` compares by value, which is what is wanted here — the claim
        // is "this field holds this token's colour", not "this field holds the
        // canonicalised object".
        expect(
          t.theme.dividerTheme.color,
          t.colors.line,
          reason: 'dividerTheme.color is the hairline',
        );
        expect(t.theme.dividerTheme.thickness, 1.0, reason: '§5 line is 1px');
        expect(t.theme.dividerTheme.space, 1.0);
        expect(
          t.theme.appBarTheme.foregroundColor,
          t.colors.ink,
          reason: 'the bar\'s title and actions take the primary ink',
        );
        expect(t.theme.appBarTheme.backgroundColor, t.colors.surface);
        expect(
          t.theme.appBarTheme.surfaceTintColor,
          t.colors.surface,
          reason: 'tint == surface, so the tint is present and invisible',
        );
        expect(
          t.theme.dialogTheme.backgroundColor,
          t.colors.surface,
          reason: 'a dialog is a glass surface, not a raised one',
        );
        expect(
          t.theme.snackBarTheme.contentTextStyle,
          t.theme.textTheme.bodyMedium,
          reason:
              'the snack bar reads in the same body style as everything else',
        );
        expect(
          t.theme.snackBarTheme.actionTextColor,
          t.colors.ember,
          // NOTE: this pairing is 2.30:1 on `raised` in the light palette, which
          // is below even AA-large. It is recorded, floored and flagged in
          // `eva_colors_test.dart`; the pin here is that the theme really does
          // wire the accent, not an endorsement of the result. Phase 3 owns the
          // snack bar.
          reason: 'the action is the accent — see the sub-AA inventory',
        );
        expect(
          t.theme.snackBarTheme.backgroundColor,
          t.colors.raised,
          reason: 'a snack bar is the most-forwarded glass surface',
        );
        expect(
          t.theme.floatingActionButtonTheme.backgroundColor,
          t.colors.surface,
        );
        expect(
          t.theme.floatingActionButtonTheme.foregroundColor,
          t.colors.ink,
          reason: 'the FAB is tinted glass, so its icon takes the ink',
        );
        expect(
          t.theme.primaryTextTheme,
          t.theme.textTheme,
          reason:
              'set at eva_theme.dart and asserted nowhere before; a primary bar '
              'must not render in a different ink from the rest of the app',
        );
      });
    }
  });

  group('the two themes are genuinely different themes', () {
    test('they are distinct ThemeData instances', () {
      expect(identical(EvaThemeDark.theme, EvaThemeLight.theme), isFalse);
    });

    test('every Eva colour the theme exposes differs between them', () {
      // Walked as (name, dark value, light value) pairs rather than by comparing
      // two `ThemeData`s with `==` — `ThemeData` has no value equality, so that
      // comparison would be identity and would pass for any two instances at all.
      final List<({String name, Color? dark, Color? light})> pairs =
          <({String name, Color? dark, Color? light})>[
            (
              name: 'scaffoldBackgroundColor',
              dark: EvaThemeDark.theme.scaffoldBackgroundColor,
              light: EvaThemeLight.theme.scaffoldBackgroundColor,
            ),
            (
              name: 'dividerColor',
              dark: EvaThemeDark.theme.dividerColor,
              light: EvaThemeLight.theme.dividerColor,
            ),
            (
              name: 'colorScheme.primary',
              dark: EvaThemeDark.theme.colorScheme.primary,
              light: EvaThemeLight.theme.colorScheme.primary,
            ),
            (
              name: 'colorScheme.error',
              dark: EvaThemeDark.theme.colorScheme.error,
              light: EvaThemeLight.theme.colorScheme.error,
            ),
            (
              name: 'colorScheme.surface',
              dark: EvaThemeDark.theme.colorScheme.surface,
              light: EvaThemeLight.theme.colorScheme.surface,
            ),
            (
              name: 'colorScheme.onSurface',
              dark: EvaThemeDark.theme.colorScheme.onSurface,
              light: EvaThemeLight.theme.colorScheme.onSurface,
            ),
            (
              name: 'colorScheme.shadow',
              dark: EvaThemeDark.theme.colorScheme.shadow,
              light: EvaThemeLight.theme.colorScheme.shadow,
            ),
            (
              name: 'cardTheme.color',
              dark: EvaThemeDark.theme.cardTheme.color,
              light: EvaThemeLight.theme.cardTheme.color,
            ),
            (
              name: 'textTheme.bodyMedium.color',
              dark: EvaThemeDark.theme.textTheme.bodyMedium!.color,
              light: EvaThemeLight.theme.textTheme.bodyMedium!.color,
            ),
          ];

      for (final ({String name, Color? dark, Color? light}) pair in pairs) {
        expect(pair.dark, isNot(pair.light), reason: pair.name);
      }
      expect(pairs.length, 9);
    });

    test('and share their geometry, which is not per-brightness', () {
      // Spacing, radii and motion have one value each in the spec. If the two
      // themes disagreed on a radius, one of them would be wrong and the token
      // table would no longer be the single source of truth.
      expect(
        _radiusOf(EvaThemeDark.theme.cardTheme.shape),
        _radiusOf(EvaThemeLight.theme.cardTheme.shape),
      );
      expect(
        EvaThemeDark.theme.dialogTheme.elevation,
        EvaThemeLight.theme.dialogTheme.elevation,
      );
    });
  });

  group('the theme participates in ThemeData interpolation', () {
    test('a half-way blend carries a half-way EvaColors', () {
      // `ThemeData.lerp` walks the extension list and calls each extension's
      // `lerp`. Without that the light/dark switch would pop rather than
      // cross-fade, and the sticker palette in particular would be unobservable
      // in a transition.
      final ThemeData blended = ThemeData.lerp(
        EvaThemeDark.theme,
        EvaThemeLight.theme,
        0.5,
      );
      final EvaColors mid = blended.extension<EvaColors>()!;

      expect(
        mid.canvas.r,
        closeTo(
          (const EvaColors.dark().canvas.r + const EvaColors.light().canvas.r) /
              2,
          0.01,
        ),
      );
      expect(
        mid.orbOpacity,
        closeTo(
          (const EvaColors.dark().orbOpacity +
                  const EvaColors.light().orbOpacity) /
              2,
          1e-9,
        ),
      );
    });

    test('a full blend lands exactly on the destination theme', () {
      final ThemeData landed = ThemeData.lerp(
        EvaThemeDark.theme,
        EvaThemeLight.theme,
        1,
      );
      expect(landed.colorScheme.surface, const EvaColors.light().surface);
      expect(landed.scaffoldBackgroundColor, const EvaColors.light().canvas);
    });
  });

  group('EvaColorsX reads the palette off a live tree', () {
    // Two tests, not one that pumps twice. `MaterialApp` wraps its theme in an
    // `AnimatedTheme`, so a second `pumpWidget` with a different `theme:` leaves
    // the OLD theme in place until the transition runs — the first draft of this
    // group read the dark canvas out of a light tree and read it as a token bug.
    // One tree per brightness makes the claim unambiguous.
    testWidgets('reads the dark palette through Theme.of', (
      WidgetTester tester,
    ) async {
      late BuildContext seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaThemeDark.theme,
          home: Builder(
            builder: (BuildContext context) {
              seen = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.colors.canvas, const EvaColors.dark().canvas);
      expect(seen.colors.ink, const EvaColors.dark().ink);
      expect(seen.colors.ember, const EvaColors.dark().ember);
      expect(seen.colors.sticker.keys.length, StickerSlot.values.length);
    });

    testWidgets('reads the light palette through Theme.of', (
      WidgetTester tester,
    ) async {
      late BuildContext seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaThemeLight.theme,
          home: Builder(
            builder: (BuildContext context) {
              seen = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.colors.canvas, const EvaColors.light().canvas);
      expect(seen.colors.ink, const EvaColors.light().ink);
    });

    testWidgets('and the switch between them cross-fades the palette', (
      WidgetTester tester,
    ) async {
      // The `AnimatedTheme` above is only a nicety if the extension takes part in
      // it. Half-way through the 200ms transition the palette must be a genuine
      // midpoint of the two — this is the user-visible payoff of `EvaColors.lerp`
      // existing at all, and it is invisible to every other assertion in the
      // suite.
      late BuildContext seen;
      Widget tree(ThemeData theme) => MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext context) {
            seen = context;
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(tree(EvaThemeDark.theme));
      expect(seen.colors.canvas, const EvaColors.dark().canvas);

      await tester.pumpWidget(tree(EvaThemeLight.theme));
      await tester.pump(const Duration(milliseconds: 100));

      final EvaColors mid = seen.colors;
      expect(
        mid.canvas.r,
        closeTo(
          (const EvaColors.dark().canvas.r + const EvaColors.light().canvas.r) /
              2,
          0.02,
        ),
        reason: 'half-way through the transition',
      );
      expect(mid.canvas, isNot(const EvaColors.dark().canvas));
      expect(mid.canvas, isNot(const EvaColors.light().canvas));

      await tester.pumpAndSettle();
      expect(seen.colors.canvas, const EvaColors.light().canvas);
    });

    testWidgets('and asserts loudly when the extension is missing', (
      WidgetTester tester,
    ) async {
      // The `!` inside `EvaColorsX.colors` is a programming-error assertion, and
      // this proves it fires as one. Without it, a screen that forgets to
      // install the extension would fail with a bare null-check error far from the
      // cause.
      late BuildContext seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (BuildContext context) {
              seen = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(() => seen.colors, throwsA(isA<AssertionError>()));
    });
  });

  group('EvaTheme.build is the single assembly point', () {
    test('is what both instance files call', () {
      // If either instance file hand-rolled a ThemeData, one of them would
      // drift and every assertion above would pass for only half the system.
      // Identity is the only honest check available: ThemeData has no value
      // equality, so a structural comparison would be comparing widgets.
      expect(
        identical(EvaThemeDark.theme, EvaTheme.build(const EvaColors.dark())),
        isFalse,
        reason:
            'build() returns a fresh ThemeData; the instances are stable '
            'singletons, so identity must NOT hold — see the next test for why '
            'that is a property worth asserting',
      );
    });

    test('produces equal themes for equal palettes', () {
      final ThemeData a = EvaTheme.build(const EvaColors.dark());
      final ThemeData b = EvaTheme.build(const EvaColors.dark());
      expect(a.colorScheme.primary, b.colorScheme.primary);
      expect(a.scaffoldBackgroundColor, b.scaffoldBackgroundColor);
      expect(
        a.textTheme.displayLarge!.fontFamily,
        b.textTheme.displayLarge!.fontFamily,
      );
      // As a RADIUS, not as a shape. `RoundedRectangleBorder` does not override
      // `==`, so comparing two of them is an identity comparison — and it passes
      // here only because both are `const` and therefore canonicalised into one
      // object. Compare the geometry and the claim is real.
      expect(_radiusOf(a.cardTheme.shape), _radiusOf(b.cardTheme.shape));
      expect(_radiusOf(a.cardTheme.shape), EvaRadii.card);
    });

    test('and different themes for different palettes', () {
      final ThemeData dark = EvaTheme.build(const EvaColors.dark());
      final ThemeData light = EvaTheme.build(const EvaColors.light());
      expect(
        dark.scaffoldBackgroundColor,
        isNot(light.scaffoldBackgroundColor),
      );
      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);
    });

    test('derives brightness from the palette rather than being told', () {
      // There is no `build(colors, brightness)` parameter: the two palettes are
      // the only two themes there are, and a brightness flag that could disagree
      // with the palette would be a way to build an incoherent theme.
      expect(
        EvaTheme.build(const EvaColors.dark()).colorScheme.brightness,
        Brightness.dark,
      );
      expect(
        EvaTheme.build(const EvaColors.light()).colorScheme.brightness,
        Brightness.light,
      );
    });

    test('accepts a palette obtained without a const invocation', () {
      // THE REGRESSION THIS FILE EXISTS TO PREVENT. `EvaColors.dark()` written
      // without `const` in a non-const context does NOT return the canonical
      // instance — the const constructor runs as ordinary code and allocates. A
      // brightness check written as `identical(colors, EvaColors.dark())`
      // therefore rejects a perfectly valid palette, and it rejected the first
      // draft of `EvaTheme.build` itself, at static-initialisation time, from
      // inside `eva_theme_dark.dart`. Asserted against a `copyWith` too, since
      // that is the other way a caller ends up holding a non-canonical palette.
      final EvaColors darkCopy = const EvaColors.dark();
      expect(
        EvaTheme.build(darkCopy).colorScheme.brightness,
        Brightness.dark,
        reason: 'a non-const invocation of a const constructor is a new object',
      );
      expect(
        EvaTheme.build(darkCopy.copyWith()).colorScheme.brightness,
        Brightness.dark,
        reason: 'and so is every copyWith result',
      );
      expect(
        EvaTheme.build(
          const EvaColors.light().copyWith(ink: const Color(0xFF010203)),
        ).colorScheme.brightness,
        Brightness.light,
      );
    });

    test('rejects a palette whose canvas belongs to neither theme', () {
      // The design has exactly two themes. A third canvas is not a third theme;
      // it is a bug, and the loud failure is at the composition root rather than
      // as a light theme rendering a dark canvas.
      expect(
        () => EvaTheme.build(
          const EvaColors.dark().copyWith(canvas: const Color(0xFF123456)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('the themes leave a stable instance identity', () {
    test('reading EvaThemeDark.theme twice returns the same object', () {
      // `MaterialApp` compares `theme`/`darkTheme` by identity when deciding
      // whether to re-localise, so a factory method would rebuild the whole tree
      // on every rebuild of the app widget.
      expect(identical(EvaThemeDark.theme, EvaThemeDark.theme), isTrue);
      expect(identical(EvaThemeLight.theme, EvaThemeLight.theme), isTrue);
    });
  });

  group('the reading sanctuary really is zero-chrome', () {
    test('the app bar is flat and hairline-separated', () {
      // AGENT_CONTEXT §2 describes `/reading` as "Reading sanctuary, EN and AR,
      // zero chrome". The theme is where that is enforced: a raised app bar on
      // that screen would be a regression with nothing to catch it.
      expect(EvaThemeDark.theme.appBarTheme.elevation, 0.0);
      expect(EvaThemeDark.theme.appBarTheme.scrolledUnderElevation, 0.0);
      expect(EvaThemeDark.theme.appBarTheme.shadowColor, isNull);
    });

    // DELETED: "the screen gutter token is reachable from the theme file", which
    // asserted `EvaSpacing.screenHorizontal == 20.0` and claimed it was "present
    // so a widget never reaches into EvaSpacing for the gutter by accident". The
    // claim was false and the assertion was a copy: `EvaSpacing` has no reader in
    // `lib/` and `eva_theme.dart` does not import it, so the theme file could not
    // have been made to disagree with the gutter, and the "reach into EvaSpacing"
    // it warned against is the only correct thing for a page to do. It duplicated
    // `eva_spacing_test.dart`, which already pins the same value against the same
    // token. The Phase 1 review deleted it.
  });
}

/// The corner radius of a themed container's shape, or `null` for a shape that
/// is not a rounded rectangle.
double? _radiusOf(ShapeBorder? shape) {
  if (shape is! RoundedRectangleBorder) return null;
  final BorderRadiusGeometry radius = shape.borderRadius;
  if (radius is! BorderRadius) return null;
  return radius.topLeft.x;
}
