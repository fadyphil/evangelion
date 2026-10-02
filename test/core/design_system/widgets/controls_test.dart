import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The five Tier-1 controls that share one shape: a labelled, tappable thing
/// with a §14 focus ring, a `Semantics(button: true)`, and no prototype component
/// of their own beyond a CSS block.
void main() {
  Finder findToggle() => find.byType(EvaToggle);
  Finder findStepper() => find.byType(FontSizeStepper);
  Finder findIconButton() => find.byType(IconActionButton);
  Finder findLink() => find.byType(TextLink);
  Finder findDivider() => find.byType(HairlineDivider);

  AnimatedContainer toggleBodyOf(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(EvaToggle),
          matching: find.byType(AnimatedContainer),
        ),
      );

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    double textScale = 1.0,
    Alignment alignment = Alignment.topCenter,
  }) => pumpPrimitive(
    tester,
    Align(alignment: alignment, child: child),
    theme: theme,
    textScale: textScale,
  );

  group('EvaToggle', () {
    testWidgets('is 44×24 with an 18px knob, per SettingsScreen.tsx:16,24', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, EvaToggle(value: true, onChanged: (bool _) {}));
      expect(EvaToggle.trackSize, const Size(44, 24));
      expect(EvaToggle.knobSize, 18);
      expect(EvaToggle.knobInset, 3);
    });

    testWidgets('is a switch in the semantics tree, not a button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, EvaToggle(value: true, onChanged: (bool _) {}));
      handle.dispose();

      final node = semanticsOf(tester, findToggle());
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isTrue);
      expect(node.label, 'On');
    });

    testWidgets('says Off when off — the state is not colour-only', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, EvaToggle(value: false, onChanged: (bool _) {}));
      handle.dispose();

      final node = semanticsOf(tester, findToggle());
      expect(node.flagsCollection.isToggled.toBoolOrNull(), isFalse);
      expect(node.label, 'Off');
    });

    testWidgets('tapping reports the opposite value', (
      WidgetTester tester,
    ) async {
      final List<bool> seen = <bool>[];
      await pumpAt(tester, EvaToggle(value: true, onChanged: seen.add));
      await tester.tap(findToggle());
      await tester.pump();
      expect(seen, <bool>[false]);
    });

    testWidgets('the knob moves, so the state survives greyscale', (
      WidgetTester tester,
    ) async {
      Future<Alignment> knobAt({required bool on}) async {
        await pumpAt(tester, EvaToggle(value: on, onChanged: (bool _) {}));
        await tester.pump();
        return tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: findToggle(),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .alignment
            as Alignment;
      }

      expect(await knobAt(on: false), Alignment.centerLeft);
      expect(await knobAt(on: true), Alignment.centerRight);
    });

    testWidgets('the knob slides over EvaMotion.base by default', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, EvaToggle(value: false, onChanged: (bool _) {}));
      expect(toggleBodyOf(tester).duration, EvaMotion.base);
    });

    testWidgets('§14 — with animations off the knob lands in one frame', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: _LiveToggle(initial: false),
        ),
        disableAnimations: true,
      );
      // The end state is the knob on the right, so a single `pump()` after the
      // tap must already show it — not after `base`.
      expect(toggleBodyOf(tester).duration, Duration.zero);
      await tester.tap(findToggle());
      await tester.pump();
      expect(toggleBodyOf(tester).alignment, Alignment.centerRight);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          EvaToggle(value: true, onChanged: (bool _) {}),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findToggle(),
          matchesGoldenFile('goldens/eva_toggle_$theme.png'),
        );
      });
    }

    testWidgets('state golden — off', (WidgetTester tester) async {
      await pumpAt(tester, EvaToggle(value: false, onChanged: (bool _) {}));
      await tester.pump();
      await expectLater(
        findToggle(),
        matchesGoldenFile('goldens/eva_toggle_state_off.png'),
      );
    });

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await pumpAt(tester, EvaToggle(value: true, onChanged: (bool _) {}));
      await tabUntilFocused(tester, findToggle());
      await tester.pump();
      await expectLater(
        findToggle(),
        matchesGoldenFile('goldens/eva_toggle_state_focused.png'),
      );
    });
  });

  group('FontSizeStepper', () {
    testWidgets('the two buttons carry their own accessible names', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, FontSizeStepper(step: 3, onChanged: (int _) {}));
      handle.dispose();

      expect(find.bySemanticsLabel('Decrease font size'), findsOneWidget);
      expect(find.bySemanticsLabel('Increase font size'), findsOneWidget);
      expect(findIconButton(), findsNWidgets(2));
    });

    testWidgets('the track is announced as a slider with its step', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(tester, FontSizeStepper(step: 4, onChanged: (int _) {}));
      handle.dispose();

      final node = semanticsOf(tester, find.bySemanticsLabel('Font size'));
      expect(node.label, 'Font size');
      expect(node.value, '4');
      expect(node.increasedValue, '5');
      expect(node.decreasedValue, '3');
    });

    testWidgets('the buttons clamp rather than run off the end', (
      WidgetTester tester,
    ) async {
      final List<int> seen = <int>[];
      await pumpAt(tester, FontSizeStepper(step: 1, onChanged: seen.add));
      await tester.tap(find.bySemanticsLabel('Decrease font size'));
      await tester.pump();
      expect(seen, isEmpty, reason: 'step 1 is already the floor');

      await pumpAt(tester, FontSizeStepper(step: 5, onChanged: seen.add));
      await tester.tap(find.bySemanticsLabel('Increase font size'));
      await tester.pump();
      expect(seen, isEmpty, reason: 'step 5 is already the ceiling');
    });

    testWidgets('a corrupt stored step renders as the nearest real one', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, FontSizeStepper(step: 99, onChanged: (int _) {}));
      expect(
        semanticsOf(tester, find.bySemanticsLabel('Font size')).value,
        '5',
        reason: 'clamped for display, not for storage',
      );
    });

    testWidgets('the track is 80 wide, the prototype\'s own value', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, FontSizeStepper(step: 3, onChanged: (int _) {}));
      expect(FontSizeStepper.trackWidth, 80);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          FontSizeStepper(step: 3, onChanged: (int _) {}),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findStepper(),
          matchesGoldenFile('goldens/font_size_stepper_$theme.png'),
        );
      });
    }
  });

  group('IconActionButton', () {
    testWidgets('§14 — the tooltip is the accessible name, not a second one', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const IconActionButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _noop,
        ),
      );
      handle.dispose();

      // Found **by label**, not by type: `IconActionButton` nests its own
      // `Semantics` inside a `Tooltip`, which contributes a node of its own, and
      // resolving the type would read whichever of the two happens to be nearest
      // the element rather than the one the widget annotates.
      final node = semanticsOf(tester, find.bySemanticsLabel('Back'));
      expect(node.label, 'Back');
      expect(find.byTooltip('Back'), findsOneWidget);
      // One string, one source: the doc's reason for a required `tooltip` rather
      // than `tooltip` + `semanticLabel`.
      expect(node.label, tester.widget<Tooltip>(find.byType(Tooltip)).message);
    });

    testWidgets('is a square 44, which is also the iOS tap-target minimum', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const IconActionButton(
          icon: Icons.close,
          tooltip: 'Close',
          onPressed: _noop,
        ),
      );
      final Size size = tester.getSize(findIconButton());
      expect(size, const Size.square(44));
    });

    testWidgets('a disabled one is not enabled and takes no tap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        const IconActionButton(icon: Icons.close, tooltip: 'Close'),
      );
      handle.dispose();

      expect(
        semanticsOf(
          tester,
          find.bySemanticsLabel('Close'),
        ).flagsCollection.isEnabled.toBoolOrNull(),
        isFalse,
      );
      await tester.tap(findIconButton());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const IconActionButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: _noop,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findIconButton(),
          matchesGoldenFile('goldens/icon_action_button_$theme.png'),
        );
      });
    }

    testWidgets('state golden — focused', (WidgetTester tester) async {
      await pumpAt(
        tester,
        const IconActionButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _noop,
        ),
      );
      await tabUntilFocused(tester, findIconButton());
      await tester.pump();
      await expectLater(
        findIconButton(),
        matchesGoldenFile('goldens/icon_action_button_state_focused.png'),
      );
    });
  });

  group('TextLink', () {
    testWidgets('is a named button, and tapping it reports', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        TextLink(label: 'Create account', onPressed: () => taps++),
      );
      handle.dispose();

      final node = semanticsOf(tester, findLink());
      expect(node.label, 'Create account');
      expect(node.flagsCollection.isButton, isTrue);

      await tester.tap(findLink());
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the chevron is opt-in, as on Login\'s Create account', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const TextLink(label: 'Create account', onPressed: _noop),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await pumpAt(
        tester,
        const TextLink(
          label: 'Forgot password?',
          chevron: true,
          onPressed: _noop,
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('without `color` it inks `ink`, and `ember` on request', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        const TextLink(label: 'Forgot password?', onPressed: _noop),
      );
      expect(
        tester.widget<Text>(find.text('Forgot password?')).style!.color,
        const EvaColors.dark().ink,
      );

      await pumpAt(
        tester,
        TextLink(
          label: 'Create account',
          color: const EvaColors.dark().ember,
          onPressed: _noop,
        ),
      );
      expect(
        tester.widget<Text>(find.text('Create account')).style!.color,
        const EvaColors.dark().ember,
      );
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const TextLink(
            label: 'Create account',
            color: Color(0xFFE8A33D),
            onPressed: _noop,
          ),
          theme: data,
        );
        await tester.pump();
        await expectLater(
          findLink(),
          matchesGoldenFile('goldens/text_link_$theme.png'),
        );
      });
    }
  });

  group('HairlineDivider', () {
    testWidgets('a bare rule is 1px tall', (WidgetTester tester) async {
      await pumpAt(tester, const HairlineDivider());
      expect(tester.getSize(findDivider()).height, HairlineDivider.thickness);
      expect(HairlineDivider.thickness, 1.0);
    });

    testWidgets('a labelled one is a label between two rules', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const HairlineDivider(label: 'or'));
      expect(find.text('OR'), findsOneWidget);
      expect(
        find.descendant(of: findDivider(), matching: find.byType(Container)),
        findsNWidgets(2),
      );
    });

    testWidgets('the rule is the prototype\'s 8% ink, not the `line` token', (
      WidgetTester tester,
    ) async {
      // Recorded in the widget's doc: `line` is `#1C2238` on a `#05081A` canvas,
      // which is far fainter than the prototype's 8% white.
      await pumpAt(tester, const HairlineDivider());
      final Container rule = tester.widget<Container>(
        find
            .descendant(of: findDivider(), matching: find.byType(Container))
            .first,
      );
      expect(rule.color, const EvaColors.dark().ink.withValues(alpha: 0.08));
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(tester, const HairlineDivider(label: 'or'), theme: data);
        await tester.pump();
        await expectLater(
          findDivider(),
          matchesGoldenFile('goldens/hairline_divider_$theme.png'),
        );
      });
    }
  });
}

void _noop() {}

/// An [EvaToggle] whose `value` follows its own `onChanged`.
///
/// `EvaToggle` is a controlled component, so a test that taps it and then asserts
/// the knob moved is asserting that the widget writes to its own input — which it
/// deliberately does not. Phase 9's `SettingsCubit` is the real stand-in.
class _LiveToggle extends StatefulWidget {
  const _LiveToggle({required this.initial});

  final bool initial;

  @override
  State<_LiveToggle> createState() => _LiveToggleState();
}

class _LiveToggleState extends State<_LiveToggle> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) => EvaToggle(
    value: _value,
    onChanged: (bool next) => setState(() => _value = next),
  );
}
