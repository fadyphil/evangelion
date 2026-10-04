import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// RED-FIRST — AGENT_CONTEXT §6: "if a widget needs a conditional or
/// calculation, extract it to a cubit or a pure function and TDD that".
///
/// The prototype's three button components are three CSS blocks asking the same
/// three questions (fill, ink, rim) three different ways, and the collapsed
/// widget has to answer all three from one table. That table is this function.
///
/// Source: `eva/src/components/ds.tsx` — `ButtonPrimary` (:222-250),
/// `ButtonSecondary` (:253-268), `ButtonText` (:271-286).
void main() {
  group('resolveButtonStyle — primary', () {
    test('fills with ember and inks with onEmber', () {
      const EvaColors colors = EvaColors.dark();
      final EvaButtonStyle style = resolveButtonStyle(
        variant: EvaButtonVariant.primary,
        colors: colors,
      );
      expect(style.background, colors.ember);
      expect(style.foreground, colors.onEmber);
      expect(style.border, isNull, reason: 'ds.tsx:240 — `border: none`');
    });

    test('presses to emberDeep', () {
      // `ds.tsx:239` — `background: pressed ? hex.emberDeep : hex.ember`.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        expect(
          resolveButtonStyle(
            variant: EvaButtonVariant.primary,
            colors: colors,
          ).pressedBackground,
          colors.emberDeep,
        );
      }
    });

    test('carries the two-part ember glow', () {
      // `ds.tsx:244` — `0 0 28px rgba(ember,.35), 0 4px 14px rgba(ember,.25)`.
      const EvaColors colors = EvaColors.dark();
      final EvaButtonStyle style = resolveButtonStyle(
        variant: EvaButtonVariant.primary,
        colors: colors,
      );
      expect(style.glow, hasLength(2));
      expect(style.glow[0].color, colors.ember.withValues(alpha: 0.35));
      expect(style.glow[0].offset, Offset.zero);
      expect(style.glow[0].blurRadius, 28);
      expect(style.glow[1].color, colors.ember.withValues(alpha: 0.25));
      expect(style.glow[1].offset, const Offset(0, 4));
      expect(style.glow[1].blurRadius, 14);
    });

    test('the pressed glow is empty — ds.tsx:244 says `pressed ? none`', () {
      expect(
        resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: const EvaColors.dark(),
        ).pressedGlow,
        isEmpty,
      );
    });
  });

  group('resolveButtonStyle — secondary', () {
    test('is transparent with an ink-at-20% 1.5px rim', () {
      // `ds.tsx:260-261`.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaButtonStyle style = resolveButtonStyle(
          variant: EvaButtonVariant.secondary,
          colors: colors,
        );
        expect(style.background, Colors.transparent);
        expect(style.border, isNotNull);
        expect(style.border!.top.width, 1.5);
        expect(style.border!.top.color, colors.ink.withValues(alpha: 0.20));
        expect(style.glow, isEmpty, reason: 'ds.tsx — no box-shadow');
      }
    });

    test('inks with `ink`, not with a computed on-fill colour', () {
      // `ds.tsx:260` — `color: T.ink` over a transparent fill.
      expect(
        resolveButtonStyle(
          variant: EvaButtonVariant.secondary,
          colors: const EvaColors.dark(),
        ).foreground,
        const EvaColors.dark().ink,
      );
    });

    test('has no pressed fill, because the prototype has none', () {
      // `ButtonSecondary` transitions `border-color` and nothing else
      // (`ds.tsx:264`), so inventing a pressed fill would be inventing a state.
      // The press feedback that *does* exist is `InkWell`'s own splash.
      final EvaButtonStyle style = resolveButtonStyle(
        variant: EvaButtonVariant.secondary,
        colors: const EvaColors.dark(),
      );
      expect(style.pressedBackground, style.background);
      expect(style.pressedGlow, isEmpty);
    });
  });

  group('resolveButtonStyle — ghost', () {
    test('is bare ink with no rim and no glow', () {
      // `ds.tsx:277-279` — `background: none`, `border: none`, `color: T.ink`.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaButtonStyle style = resolveButtonStyle(
          variant: EvaButtonVariant.ghost,
          colors: colors,
        );
        expect(style.background, Colors.transparent);
        expect(style.border, isNull);
        expect(style.glow, isEmpty);
        expect(style.foreground, colors.ink);
        expect(style.pressedBackground, style.background);
      }
    });
  });

  group('the enum and the defaults', () {
    test('has exactly the three prototype components', () {
      expect(EvaButtonVariant.values, <EvaButtonVariant>[
        EvaButtonVariant.primary,
        EvaButtonVariant.secondary,
        EvaButtonVariant.ghost,
      ]);
    });

    test('the inventory defaults are primary, 52 high, expanded', () {
      const EvaButton button = EvaButton(
        labelFamily: EvaTypography.uiFamily,
        label: 'Sign in',
      );
      expect(button.variant, EvaButtonVariant.primary);
      expect(button.height, 52.0);
      expect(button.expanded, isTrue);
      expect(button.trailingChevron, isFalse);
      expect(button.icon, isNull);
      expect(button.onPressed, isNull);
    });

    test('style is a value, so the two palettes cannot drift', () {
      expect(
        resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: const EvaColors.dark(),
        ),
        resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: const EvaColors.dark(),
        ),
      );
      expect(
        resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: const EvaColors.dark(),
        ),
        isNot(
          resolveButtonStyle(
            variant: EvaButtonVariant.primary,
            colors: const EvaColors.light(),
          ),
        ),
      );
    });
  });

  _widgetTests();
}

// ── widget behaviour, semantics and goldens ────────────────────────────────

/// One theme per test body, always.
///
/// `MaterialApp` installs an `AnimatedTheme` that lerps a theme change over
/// `kThemeAnimationDuration`, and the single zero-duration `pump()` after
/// `pumpWidget` does not advance it — so two captures in one body wrote the
/// first palette into the second file, which is how Phase 2 shipped two
/// byte-identical "light" goldens. `kEvaThemes` is iterated to *create* tests,
/// never to loop inside one.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  bool disableAnimations = false,
  double textScale = 1.0,
}) => pumpPrimitive(
  tester,
  Align(alignment: Alignment.topCenter, child: child),
  theme: theme,
  disableAnimations: disableAnimations,
  textScale: textScale,
);

AnimatedContainer _bodyOf(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(EvaButton),
        matching: find.byType(AnimatedContainer),
      ),
    );

void _widgetTests() {
  group('EvaButton', () {
    testWidgets('renders its label once, as the accessible name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      handle.dispose();

      expect(find.text('Sign in'), findsOneWidget);
      final node = semanticsOf(tester, find.byType(EvaButton));
      expect(node.label, 'Sign in');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
    });

    testWidgets('a disabled button is not a button to a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const EvaButton(labelFamily: EvaTypography.uiFamily, label: 'Sign in'),
      );
      handle.dispose();

      final node = semanticsOf(tester, find.byType(EvaButton));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
    });

    testWidgets('activating it calls onPressed exactly once', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pump(
        tester,
        EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(EvaButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a disabled button cannot be tapped', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(labelFamily: EvaTypography.uiFamily, label: 'Sign in'),
      );
      await tester.tap(find.byType(EvaButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('it is 52 tall and as wide as it is told to be', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      expect(tester.getSize(find.byType(EvaButton)).height, 52.0);
      expect(tester.getSize(find.byType(EvaButton)).width, 320.0);
    });

    testWidgets('expanded: false sizes to its content', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          expanded: false,
          onPressed: _noop,
        ),
      );
      expect(tester.getSize(find.byType(EvaButton)).width, lessThan(320.0));
    });

    testWidgets('the trailing chevron appears only when asked for', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,

          label: 'Sign in',
          trailingChevron: true,
          onPressed: _noop,
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('pressing fills with emberDeep and drops the glow', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );

      final BoxDecoration idle = _bodyOf(tester).decoration as BoxDecoration;
      expect(idle.boxShadow, hasLength(2));

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(EvaButton)),
      );
      await tester.pump();
      final BoxDecoration pressed = _bodyOf(tester).decoration as BoxDecoration;
      expect(pressed.color, const EvaColors.dark().emberDeep);
      expect(pressed.boxShadow, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_bodyOf(tester).decoration as BoxDecoration, idle);
    });

    testWidgets('with animations off the press lands in one frame', (
      WidgetTester tester,
    ) async {
      // §14 — "when disabled, jump straight to the end state". The end state is
      // the pressed fill, so one `pump()` must already show it.
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
        disableAnimations: true,
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(EvaButton)),
      );
      await tester.pump();

      final AnimatedContainer body = _bodyOf(tester);
      expect(body.duration, Duration.zero);
      expect(
        (body.decoration as BoxDecoration).color,
        const EvaColors.dark().emberDeep,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the disabled state is the prototype\'s 45%', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(labelFamily: EvaTypography.uiFamily, label: 'Sign in'),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(EvaButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.45);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — primary $theme', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          const EvaButton(
            labelFamily: EvaTypography.uiFamily,
            label: 'Sign in',
            onPressed: _noop,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          find.byType(EvaButton),
          matchesGoldenFile('goldens/eva_button_primary_$theme.png'),
        );
      });

      testWidgets('a golden per theme — secondary $theme', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          const EvaButton(
            labelFamily: EvaTypography.uiFamily,

            label: 'Back to library',
            variant: EvaButtonVariant.secondary,
            onPressed: _noop,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          find.byType(EvaButton),
          matchesGoldenFile('goldens/eva_button_secondary_$theme.png'),
        );
      });

      testWidgets('a golden per theme — ghost $theme', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          const EvaButton(
            labelFamily: EvaTypography.uiFamily,

            label: 'Forgot password?',
            variant: EvaButtonVariant.ghost,
            trailingChevron: true,
            expanded: false,
            onPressed: _noop,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          find.byType(EvaButton),
          matchesGoldenFile('goldens/eva_button_ghost_$theme.png'),
        );
      });
    }

    testWidgets('state golden — pressed', (WidgetTester tester) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(EvaButton)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(EvaButton),
        matchesGoldenFile('goldens/eva_button_state_pressed.png'),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('state golden — disabled', (WidgetTester tester) async {
      await _pump(
        tester,
        const EvaButton(labelFamily: EvaTypography.uiFamily, label: 'Sign in'),
      );
      await tester.pump();
      await expectLater(
        find.byType(EvaButton),
        matchesGoldenFile('goldens/eva_button_state_disabled.png'),
      );
    });

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      await tabUntilFocused(tester, find.byType(EvaButton));
      await tester.pump();
      await expectLater(
        find.byType(EvaButton),
        matchesGoldenFile('goldens/eva_button_state_focused.png'),
      );
    });
  });
}

void _noop() {}
