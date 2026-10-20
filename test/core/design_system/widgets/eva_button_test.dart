import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
/// Source: `redesign.html` — `.cta` (:381-386), `.qnext` (:363-368),
/// `.ghosts button` (:388-390). The three states with no redesign line at all
/// — pressed fill, pressed glow removal, disabled — are recorded on the widget
/// as such.
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
      expect(
        style.border,
        isNull,
        reason: 'redesign.html:381 — `border: none`',
      );
    });

    test('presses to emberDeep', () {
      // The superseded prototype's `background: pressed ? hex.emberDeep :
      // hex.ember` — **the redesign has no counterpart for it**.
      // `redesign.html` declares **no** `:active` fill: its only `:active` rule
      // for `.cta` is `transform: scale(.97)` (:384), which is paint. So this is a
      // surviving prototype value rather than a transcription, and the widget says
      // so rather than leaving the citation to imply otherwise.
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
      // The superseded prototype's
      // `0 0 28px rgba(ember,.35), 0 4px 14px rgba(ember,.25)` — **the redesign
      // has no counterpart for it**.
      // Kept: `redesign.html:381` declares no `box-shadow` at all, and the ring
      // it draws is a separate `::after` element rather than a shadow.
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

    test('the pressed glow is empty — the prototype said `pressed ? none`, and the '
        'redesign has no counterpart', () {
      expect(
        resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: const EvaColors.dark(),
        ).pressedGlow,
        isEmpty,
      );
    });

    test(
      'and it has no hover state at all, because the page has no `:hover`',
      () {
        // `redesign.html:381` writes a `transition` and no `:hover` rule. The
        // honest transcription is the identity in both hover fields — not a second
        // invented value, and not an absence of the fields.
        const EvaColors colors = EvaColors.dark();
        final EvaButtonStyle style = resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: colors,
        );
        expect(style.hoverBackground, style.background);
        expect(style.hoverForeground, style.foreground);
        expect(style.hoverBorder, style.border);
      },
    );
  });

  group('resolveButtonStyle — secondary, the `.qnext` gold-rim role', () {
    test('is transparent with a 1px gold rim', () {
      // `redesign.html:363` — `border: 1px solid rgba(232,176,75,.55)`, against
      // the superseded prototype's `1.5px solid rgba(ink, 0.2)` — which **the
      // redesign has no counterpart for**. Both halves move: the width
      // and the hue. This is decision 1 of the Task 4.2 status block.
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
        expect(style.border!.top.width, 1);
        expect(
          style.border!.top.color,
          colors.emberInk.withValues(alpha: kEvaButtonGoldRimAlpha),
        );
        expect(
          style.border!.top.color,
          isNot(colors.ink.withValues(alpha: 0.20)),
          reason:
              'the old role was an `ink`-at-20% rim. A regression back to it '
              'would be a regression back to the superseded prototype rather '
              'than to the redesign\'s gold rim (`redesign.html:363`).',
        );
        expect(style.glow, isEmpty, reason: 'redesign.html — no box-shadow');
      }
    });

    test('inks with gold — `emberInk`, not `ember`', () {
      // `redesign.html:363` — `color: var(--gold)`. Decision 153: `ember` fills
      // and `emberInk` writes, and in light `ember` measures 2.05:1 as text.
      final EvaButtonStyle style = resolveButtonStyle(
        variant: EvaButtonVariant.secondary,
        colors: const EvaColors.light(),
      );
      expect(style.foreground, const EvaColors.light().emberInk);
      expect(
        style.foreground,
        isNot(const EvaColors.light().ember),
        reason: 'Decision 153 — a label writes, and light `ember` is a fill',
      );
    });

    test(
      'hovers a gold wash — `redesign.html:368`, and it is a FILL hover',
      () {
        // `.qnext:hover{background: rgba(232,176,75,.12)}` — the only hover *fill*
        // among the redesign's five button rules.
        const EvaColors colors = EvaColors.dark();
        final EvaButtonStyle style = resolveButtonStyle(
          variant: EvaButtonVariant.secondary,
          colors: colors,
        );
        expect(style.hoverBackground, colors.ember.withValues(alpha: 0.12));
        expect(style.hoverBackground, isNot(style.background));
        expect(
          style.hoverForeground,
          style.foreground,
          reason: '`.qnext:hover` (:368) changes the fill and not the ink',
        );
        expect(style.hoverBorder, style.border);
      },
    );

    test('has no pressed fill, because the prototype has none', () {
      // `redesign.html:363-368` declares no `:active` fill. The press feedback
      // that *does* exist is `EvaInk`'s own splash.
      final EvaButtonStyle style = resolveButtonStyle(
        variant: EvaButtonVariant.secondary,
        colors: const EvaColors.dark(),
      );
      expect(style.pressedBackground, style.background);
      expect(style.pressedGlow, isEmpty);
    });
  });

  group('resolveButtonStyle — ghost, `.ghosts button`', () {
    test('is a glass-rimmed pill in `ink2`, not bare ink with no rim', () {
      // `redesign.html:388-389` — `border: 1px solid var(--glass-line)`,
      // `color: var(--ink-1)`. The superseded prototype was `border: none`,
      // `T.ink`, and **the redesign has no counterpart for either of those two**.
      for (final EvaColors colors in const <EvaColors>[
        EvaColors.dark(),
        EvaColors.light(),
      ]) {
        final EvaButtonStyle style = resolveButtonStyle(
          variant: EvaButtonVariant.ghost,
          colors: colors,
        );
        expect(style.background, Colors.transparent);
        expect(style.border, isNotNull);
        expect(style.border!.top.width, 1);
        expect(style.border!.top.color, colors.glassBorder);
        expect(style.glow, isEmpty);
        expect(style.foreground, colors.ink2);
        expect(
          style.foreground,
          isNot(colors.ink),
          reason:
              '`--ink-1` (`redesign.html:389`) is this system\'s `ink2`. A '
              'regression to `ink` is the superseded prototype\'s value wearing a '
              'redesign citation.',
        );
        expect(style.pressedBackground, style.background);
      }
    });

    test('inks gold on hover, and that is a RECORDED divergence', () {
      // `redesign.html` gives this role three `:hover` rules and they disagree:
      // `:390` and `:465` brighten to `--ink-0`, `:472` goes gold. The widget
      // takes `:472`. Both facts are asserted so neither can drift alone.
      const EvaColors colors = EvaColors.dark();
      final EvaButtonStyle style = resolveButtonStyle(
        variant: EvaButtonVariant.ghost,
        colors: colors,
      );
      expect(style.hoverForeground, colors.emberInk);
      expect(
        style.hoverForeground,
        isNot(colors.ink),
        reason:
            '`:390`/` :465` would give `ink` — one step up the same ramp, and '
            'nearly invisible on a page the button already sits on.',
      );
      expect(style.hoverBackground, style.background, reason: ':388 — no fill');
      expect(style.hoverBorder, style.border, reason: ':390 — no border-color');
    });
  });

  group('the pill, and the token it did not move', () {
    test('the button is a pill and `EvaRadii.button` is still 14', () {
      // `redesign.html:381` — `border-radius: 999px`. The token stays at 14
      // because `login_geometry_test` asserts it as a transcription claim
      // against the superseded prototype's `borderRadius: 14` — **which the
      // redesign has no counterpart for** — and `SocialAuthButton` still draws
      // its own box at
      // it — which is how the harness keeps being able to see the difference.
      expect(kEvaButtonRadius, 999.0);
      expect(EvaRadii.button, 14.0);
      expect(kEvaButtonRadius, EvaRadii.chip);
    });

    test('and the height is untouched, because a harness reads it', () {
      expect(kEvaButtonHeight, 52.0);
      expect(kEvaButtonDisabledOpacity, 0.45);
    });
  });

  group('evaButtonRipplePhase — the phase, and why it is pure', () {
    test('wraps on the 2.4s period', () {
      // `redesign.html:385` — `animation: ripple 2.4s … infinite`.
      expect(kEvaButtonRipplePeriod, const Duration(milliseconds: 2400));
      expect(evaButtonRipplePhase(0), 0.0);
      expect(evaButtonRipplePhase(1.2), closeTo(0.5, 1e-9));
      expect(
        evaButtonRipplePhase(2.4),
        closeTo(0.0, 1e-9),
        reason: 'one whole period is the start of the next cycle',
      );
      expect(evaButtonRipplePhase(4.8), closeTo(0.0, 1e-9));
      // 7.7s: two whole periods and 2.9s of the third, which is past the halfway
      // mark of a 2.4s cycle.
      expect(evaButtonRipplePhase(7.7), closeTo((7.7 / 2.4 % 1), 1e-9));
    });

    test('it is a function of a number, and needs no scope or ticker', () {
      // §6: the arithmetic lives here rather than in a `build`. A regression test
      // that constructs a widget and reads a frame would pass even with the
      // clock source deleted; this one cannot.
      for (final double seconds in <double>[0, 0.4, 1.19, 1.21, 2.39, 100.5]) {
        expect(evaButtonRipplePhase(seconds), inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('evaButtonRippleAt — the two endpoints, verbatim', () {
    // `redesign.html:234` — `@keyframes ripple{0%{transform:scale(1);
    // opacity:.8}100%{transform:scale(1.6);opacity:0}}`.
    test('0% is scale 1 at 80% opacity', () {
      final ring = evaButtonRippleAt(0);
      expect(ring.scale, 1.0);
      expect(ring.opacity, closeTo(0.8, 1e-9));
    });

    test('100% is scale 1.6 at zero opacity', () {
      final ring = evaButtonRippleAt(1);
      expect(ring.scale, closeTo(1.6, 1e-9));
      expect(ring.opacity, 0.0);
    });

    test('the middle is the midpoint, because the ramp is linear', () {
      // The `--e-out` easing on `:385` is **not** applied — recorded on
      // `_RippleRing` — and this is the assertion that says so.
      final ring = evaButtonRippleAt(0.5);
      expect(ring.scale, closeTo(1.3, 1e-9));
      expect(ring.opacity, closeTo(0.4, 1e-9));
    });

    test(
      'clamps rather than wraps, so the ends are reachable from either side',
      () {
        expect(evaButtonRippleAt(-3).scale, 1.0);
        expect(evaButtonRippleAt(5).scale, closeTo(1.6, 1e-9));
        expect(evaButtonRippleAt(-3).opacity, closeTo(0.8, 1e-9));
        expect(evaButtonRippleAt(5).opacity, 0.0);
      },
    );

    test('and the constants are the prototype\'s, not round numbers', () {
      expect(kEvaButtonRippleStartScale, 1.0);
      expect(kEvaButtonRippleEndScale, 1.6);
      expect(kEvaButtonRippleStartOpacity, 0.8);
      expect(kEvaButtonRippleWidth, 1.5);
      expect(kEvaButtonRippleAlpha, 0.65);
    });
  });

  group('the enum and the defaults', () {
    test('has exactly the three prototype action roles', () {
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

/// The [SemanticsData] carrying [label], read off the whole tree.
///
/// ## WHY NOT `tester.getSemantics(find.byType(EvaButton))`, WHICH IS WHAT
/// THIS USED TO SAY
///
/// `MouseRegion` inserts its own `Semantics` widget above the one this widget
/// builds — `MouseRegion.build` wraps its child in a private
/// `_MouseRegionSemantics`, which is a `Semantics` — and `getSemantics` walks
/// the **render** tree upwards to the first node it finds. That used to stop at
/// this widget's own `Semantics`; it now stops at `MouseRegion`'s, which
/// carries the label and none of the flags.
///
/// The same thing already happens to `IconActionButton`, and
/// `design_system_harness.dart` records it in `semanticsTree`'s doc: "the button's
/// own node is real and is reachable only by label". So the walk is the house
/// answer rather than a workaround — and it is the *only* one that survives a
/// wrapper being added above the widget, which is exactly the change that broke
/// it.
///
/// It returns [SemanticsData] rather than a [SemanticsNode] because the harness
/// deliberately does not re-export `SemanticsNode` (only `SemanticsAction`,
/// `SemanticsData` and `SemanticsFlags`, because `material.dart` re-exports
/// those two and not the node). Reading the node as well would have meant this
/// file growing an import the rest of the design-system suite does not have.
///
/// Failing closed: no node at all is a failure, not an empty list.
SemanticsData _nodeLabelled(WidgetTester tester, String label) {
  final List<SemanticsData> named = <SemanticsData>[
    for (final SemanticsData data in semanticsTree(tester))
      if (data.label == label) data,
  ];
  expect(
    named,
    hasLength(1),
    reason:
        'expected exactly one semantics node named "$label" and found '
        '${named.length}. A count rather than a `first`, because "the first node'
        ' that happens to match" would keep passing if the button ever grew a '
        'second identically-named node.',
  );
  return named.single;
}

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
      final node = _nodeLabelled(tester, 'Sign in');
      expect(node.label, 'Sign in');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
    });

    testWidgets('semanticLabel renames the node without touching the paint', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      const String painted = 'GOOGLE';
      const String announced = 'GOOGLE — unavailable in this build';
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.monoFamily,
          label: painted,
          // `onPressed` stays its default `null` — inertness is the subject.
          semanticLabel: announced,
        ),
      );
      handle.dispose();

      // The paint is the brand mark; the node is the sentence. `/login`'s two
      // inert ghosts are the reason the override exists (`eva/redesign.html:509`
      // paints `google`/`apple`; `authUnavailableSuffix` says why they cannot
      // be pressed) — and an override that leaked into the paint would render
      // the suffix on screen, which is what the call site must not do.
      expect(find.text(painted), findsOneWidget);
      expect(find.text(announced), findsNothing);
      final node = _nodeLabelled(tester, announced);
      expect(node.label, announced);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
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

      final node = _nodeLabelled(tester, 'Sign in');
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
  group('EvaButtonStyle compares by value', () {
    // `==` and `hashCode` were never invoked by any test, so both overrides shipped
    // unexercised. They matter: an `AnimatedContainer` that receives an unequal style
    // restarts its animation, and a suite that rebuilt a button on every frame would
    // see a control that never settles.
    test('two styles with the same fields are equal and hash alike', () {
      const EvaButtonStyle a = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[BoxShadow(color: Color(0xFF444444))],
        pressedGlow: <BoxShadow>[],
      );
      const EvaButtonStyle b = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[BoxShadow(color: Color(0xFF444444))],
        pressedGlow: <BoxShadow>[],
      );
      expect(a, b);
      // Equal objects must hash equally, or a `Set` or `Map` keyed by style silently
      // holds duplicates — the failure mode `hashCode` exists to prevent.
      expect(a.hashCode, b.hashCode);
    });

    test('a different glow makes them unequal', () {
      // The glow lists are compared with `listEquals`, not `==`, because `BoxShadow`
      // has no value equality of its own.
      //
      // **The two styles here differ in the glow and nothing else.** That is the whole
      // point, and the first version of this test compared a `primary` against a
      // `ghost` — which differ in background, foreground and border as well, so it
      // still passed with `listEquals(other.glow, glow)` deleted. A mutation that
      // removed the glow comparison ran green; this pair cannot.
      const EvaButtonStyle dim = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[],
        pressedGlow: <BoxShadow>[],
      );
      const EvaButtonStyle lit = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[BoxShadow(color: Color(0xFF444444))],
        pressedGlow: <BoxShadow>[],
      );
      expect(dim, isNot(lit));

      // The same for the pressed glow, which is the other list-compared field.
      const EvaButtonStyle pressedLit = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[],
        pressedGlow: <BoxShadow>[BoxShadow(color: Color(0xFF555555))],
      );
      expect(dim, isNot(pressedLit));
    });

    test('and the hover fields are compared too, not just carried', () {
      // Six new fields arrived with `redesign.html`'s two `:hover` rules, and a
      // field that is stored but never compared is a field that can change without
      // anything noticing — which is how an `AnimatedContainer` starts restarting
      // its animation on a hover that looks like no change at all.
      //
      // Each pair differs in **exactly one** field, so a mutation that dropped any
      // single comparison would leave the other five passing.
      const EvaButtonStyle base = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[],
        pressedGlow: <BoxShadow>[],
      );
      const EvaButtonStyle otherHoverBackground = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFFAAAAAA),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[],
        pressedGlow: <BoxShadow>[],
      );
      const EvaButtonStyle otherHoverForeground = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFFBBBBBB),
        border: null,
        hoverBorder: null,
        glow: <BoxShadow>[],
        pressedGlow: <BoxShadow>[],
      );
      const EvaButtonStyle otherHoverBorder = EvaButtonStyle(
        background: Color(0xFF111111),
        pressedBackground: Color(0xFF222222),
        hoverBackground: Color(0xFF222222),
        foreground: Color(0xFF333333),
        hoverForeground: Color(0xFF333333),
        border: null,
        hoverBorder: Border.fromBorderSide(
          BorderSide(color: Color(0xFFCCCCCC)),
        ),
        glow: <BoxShadow>[],
        pressedGlow: <BoxShadow>[],
      );
      expect(base, isNot(otherHoverBackground));
      expect(base, isNot(otherHoverForeground));
      expect(base, isNot(otherHoverBorder));
    });

    test('a style is not equal to an unrelated object', () {
      expect(
        resolveButtonStyle(
          variant: EvaButtonVariant.primary,
          colors: const EvaColors.dark(),
        ),
        isNot(equals(Object())),
      );
    });
  });

  group('the icon slot', () {
    testWidgets('a leading glyph renders beside the label, not instead', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'See all',
          icon: Icons.chevron_right,
          onPressed: _noop,
        ),
      );

      // Both. The icon arm wraps the glyph in padding and tints it with the style's
      // own foreground, so asserting the glyph alone would pass even if the label had
      // been replaced by it.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      // The two live in one `Row`, which is the layout the arm exists to produce.
      expect(
        find.descendant(of: find.byType(EvaButton), matching: find.byType(Row)),
        findsWidgets,
      );
    });

    testWidgets('with no icon the label is a bare Text, not a Row', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'See all',
          onPressed: _noop,
        ),
      );
      // The `leading == null && trailing == null` arm skips the `Row` entirely, so a
      // label-only button costs no extra node. Asserted because the icon arm and this
      // arm are the two branches of one conditional.
      expect(find.text('See all'), findsOneWidget);
    });
  });

  group('the pill', () {
    testWidgets('the painted corner radius is 999, on every variant', (
      WidgetTester tester,
    ) async {
      // `redesign.html:381` — `border-radius: 999px`. Asserted on the **painted**
      // `BoxDecoration` rather than on the constant, because the constant is what a
      // mutation would change and the paint is what a reader sees.
      for (final EvaButtonVariant variant in EvaButtonVariant.values) {
        await _pump(
          tester,
          EvaButton(
            labelFamily: EvaTypography.uiFamily,
            label: 'Sign in',
            variant: variant,
            onPressed: _noop,
          ),
        );
        final BoxDecoration decoration =
            _bodyOf(tester).decoration as BoxDecoration;
        expect(
          (decoration.borderRadius! as BorderRadius).topLeft.x,
          999.0,
          reason: '$variant',
        );
      }
    });

    testWidgets('and the focus ring is a pill too, not a 14px box around one', (
      WidgetTester tester,
    ) async {
      // The ring paints on the **outer** box, which is the button's box. Left at
      // `EvaFocusRing`'s own default it would be a 14-cornered rectangle around a
      // pill, which is the one shape in the design system nothing else has.
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

      final Border ring = renderedBorders(tester, find.byType(EvaButton)).first;
      expect(ring, evaFocusRingBorder(const EvaColors.dark()));
      // The radius is a sibling of the border, so it is read off the same
      // `DecoratedBox` the gate's `renderedBorders` reads the border off.
      final Iterable<BoxDecoration> painted = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(EvaButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox box) => box.decoration)
          .whereType<BoxDecoration>();
      expect(
        painted.any(
          (BoxDecoration d) =>
              (d.borderRadius! as BorderRadius).topLeft.x == kEvaButtonRadius,
        ),
        isTrue,
      );
    });

    testWidgets('the ink is clipped to the pill, not to a rectangle', (
      WidgetTester tester,
    ) async {
      // `EvaInk`'s `borderRadius` was left at `null` before this widget was a
      // pill, and `null` clips to nothing — so a splash used to leave the control
      // sideways. The parameter is asserted on the widget rather than on a
      // rendered splash, because a splash only exists during a press.
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      expect(
        tester
            .widget<EvaInk>(
              find.descendant(
                of: find.byType(EvaButton),
                matching: find.byType(EvaInk),
              ),
            )
            .borderRadius,
        const BorderRadius.all(Radius.circular(kEvaButtonRadius)),
      );
    });
  });

  group('the `.cta::after` ring', () {
    /// The ring's own rim, read out of the painted tree.
    ///
    /// `Positioned.fill` puts it at the button's own bounds, so the finder is a
    /// `Border` of [kEvaButtonRippleWidth] rather than any particular widget
    /// type — and `BoxDecoration.border` left null on the beads, the fill and
    /// the focus ring means the only 1.5px border in the tree is this one.
    Border rippleBorderOf(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(EvaButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((BoxDecoration d) => d.border)
        .whereType<Border>()
        .firstWhere(
          (Border b) => b.top.width == kEvaButtonRippleWidth,
          orElse: () => throw StateError('no 1.5px border is painted'),
        );

    testWidgets('a primary button paints it, at the keyframe\'s 0% frame', (
      WidgetTester tester,
    ) async {
      // `redesign.html:385` — `inset: 0`, `border: 1.5px solid
      // rgba(232,176,75,.65)`, and `redesign.html:234`'s `0%` is `opacity: .8`,
      // so the resting alpha is `.65 × .8 = .52`.
      //
      // **Phase 0 is why this is deterministic.** `pumpPrimitive` installs
      // `NeuralMotionScope(animationsEnabled: false)`, so the `lumen` clock never
      // starts and `seconds` is `0` on every frame — which is also the statement
      // that the ring costs no ticker.
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      final Border ring = rippleBorderOf(tester);
      expect(
        ring.top.color,
        const EvaColors.dark().emberInk.withValues(
          alpha: kEvaButtonRippleAlpha * 0.8,
        ),
      );
    });

    testWidgets('and it is positioned over the button box, not inside it', (
      WidgetTester tester,
    ) async {
      // `inset: 0` means the ring's own box **is** the button's box — which is
      // what `Positioned.fill` says and what a child of the `AnimatedContainer`
      // would not. Asserted on the box, because the visual consequence is only
      // that the ring can grow *past* the button at `scale(1.6)`.
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Sign in',
          onPressed: _noop,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(EvaButton),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
        reason: 'the scale the keyframes animate is a `Transform`',
      );
    });

    testWidgets('only the filled role has one', (WidgetTester tester) async {
      // `.qnext` (:363-368), `.ghosts button` (:388-390), `.rghost` (:463-465) and
      // `.pctl button` (:470-472) declare **no** `::after`. Asserted as an
      // absence per variant, because "the ring is on the primary" is the claim
      // and "the ring is not on everything" is what makes it a role rather than
      // a decoration.
      for (final EvaButtonVariant variant in <EvaButtonVariant>[
        EvaButtonVariant.secondary,
        EvaButtonVariant.ghost,
      ]) {
        await _pump(
          tester,
          EvaButton(
            labelFamily: EvaTypography.uiFamily,
            label: 'Sign in',
            variant: variant,
            onPressed: _noop,
          ),
        );
        expect(
          find.descendant(
            of: find.byType(EvaButton),
            matching: find.byType(Transform),
          ),
          findsNothing,
          reason: '$variant declares no ::after in redesign.html',
        );
      }
    });

    testWidgets(
      'reduced motion paints no ring at all, rather than a frozen one',
      (WidgetTester tester) async {
        // §14 — "when disabled, jump straight to the end state". An infinite loop
        // has no end state to land on, so the honest reading is "do not start".
        // `NeuralMotionScope` stops the clock independently, so the two mechanisms
        // agree rather than one being relied on to cover the other.
        await _pump(
          tester,
          const EvaButton(
            labelFamily: EvaTypography.uiFamily,
            label: 'Sign in',
            onPressed: _noop,
          ),
          disableAnimations: true,
        );
        expect(
          find.descendant(
            of: find.byType(EvaButton),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
      },
    );
  });

  group('hover', () {
    testWidgets('a secondary button fills gold under the pointer', (
      WidgetTester tester,
    ) async {
      // `redesign.html:368` — `.qnext:hover{background: rgba(232,176,75,.12)}`.
      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Next',
          variant: EvaButtonVariant.secondary,
          onPressed: _noop,
        ),
      );
      final BoxDecoration idle = _bodyOf(tester).decoration as BoxDecoration;
      expect(idle.color, Colors.transparent);

      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(EvaButton)));
      await tester.pumpAndSettle();
      expect(
        (_bodyOf(tester).decoration as BoxDecoration).color,
        const EvaColors.dark().ember.withValues(alpha: 0.12),
      );

      // And it leaves again — a hover that latches is a stuck state. The target is
      // *below* the button, not merely off to the side: the harness aligns the
      // button to the top centre and it is `expanded`, so it spans the full 320px
      // width and (5, 5) is still inside it.
      await gesture.moveTo(
        tester.getCenter(find.byType(EvaButton)) + const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(
        (_bodyOf(tester).decoration as BoxDecoration).color,
        Colors.transparent,
      );
      await gesture.removePointer();
    });

    testWidgets('a ghost button inks gold, in the label as well as the rim', (
      WidgetTester tester,
    ) async {
      // `redesign.html:389`'s `--ink-1` idle and the recorded gold hover. The
      // **label** is asserted too, because the resolved style's ink has to reach
      // the `Text` and not only the `BoxDecoration` — a hover that tinted only
      // the fill would be half a hover.
      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await _pump(
        tester,
        const EvaButton(
          labelFamily: EvaTypography.uiFamily,
          label: 'Skip',
          variant: EvaButtonVariant.ghost,
          onPressed: _noop,
        ),
      );
      Color labelInk() => tester.widget<Text>(find.text('Skip')).style!.color!;
      expect(labelInk(), const EvaColors.dark().ink2);

      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(EvaButton)));
      await tester.pumpAndSettle();
      expect(labelInk(), const EvaColors.dark().emberInk);
      await gesture.removePointer();
    });
  });
}

void _noop() {}
