import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The five Tier-1 controls that share one shape: a labelled, tappable thing
/// with a §14 focus ring, a `Semantics(button: true)`, and no prototype component
/// of their own beyond a CSS block.
///
/// ## AND THE §14 ROW THAT SAID "ACTIVATABLE" AND MEANT "NAMED"
///
/// The last group in this file is the gate for §14's second row, and it exists
/// because six of the eleven interactive widgets failed it. `Semantics(…,
/// excludeSemantics: true)` is the right way to stop a screen reader saying
/// "Sign in, Sign in" — and it also drops the `InkWell`'s tap **action**, because
/// the `InkWell` is a descendant of the node doing the excluding. The outer node
/// kept `isButton` and the label and offered the reader nothing to do with them.
///
/// Every committed test passed, because every one of them used `tester.tap()`,
/// which goes through the pointer path, and the keyboard path works through
/// `ActivateIntent`. `grep -rn 'SemanticsAction|hasAction|performAction' test/`
/// returned **zero** hits: no test in the suite had ever read a semantics
/// *action*, and §14's row was only ever checked against flags and labels.
///
/// So the gate reads `SemanticsData.hasAction` — against the data, never against
/// the presence of a `Semantics` widget — over the shared
/// [kInteractiveWidgets] inventory, which `focus_ring_gate_test.dart` also uses.
/// One inventory, two §14 rows.
void main() {
  const FontSizeStepperLabels stepperLabels = FontSizeStepperLabels(
    decrease: 'Decrease font size',
    increase: 'Increase font size',
    track: 'Font size',
  );

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
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 3, onChanged: (int _) {}),
      );
      handle.dispose();

      expect(find.bySemanticsLabel('Decrease font size'), findsOneWidget);
      expect(find.bySemanticsLabel('Increase font size'), findsOneWidget);
      expect(findIconButton(), findsNWidgets(2));
    });

    testWidgets('the track is announced as a slider with its step', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 4, onChanged: (int _) {}),
      );
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
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 1, onChanged: seen.add),
      );
      await tester.tap(find.bySemanticsLabel('Decrease font size'));
      await tester.pump();
      expect(seen, isEmpty, reason: 'step 1 is already the floor');

      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 5, onChanged: seen.add),
      );
      await tester.tap(find.bySemanticsLabel('Increase font size'));
      await tester.pump();
      expect(seen, isEmpty, reason: 'step 5 is already the ceiling');
    });

    testWidgets('a corrupt stored step renders as the nearest real one', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 99, onChanged: (int _) {}),
      );
      expect(
        semanticsOf(tester, find.bySemanticsLabel('Font size')).value,
        '5',
        reason: 'clamped for display, not for storage',
      );
    });

    testWidgets('the track is 80 wide, the prototype\'s own value', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        FontSizeStepper(labels: stepperLabels, step: 3, onChanged: (int _) {}),
      );
      expect(FontSizeStepper.trackWidth, 80);
    });

    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          FontSizeStepper(
            labels: stepperLabels,
            step: 3,
            onChanged: (int _) {},
          ),
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
          tooltipFamily: EvaTypography.uiFamily,

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
          tooltipFamily: EvaTypography.uiFamily,

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
        const IconActionButton(
          tooltipFamily: EvaTypography.uiFamily,
          icon: Icons.close,
          tooltip: 'Close',
        ),
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
            tooltipFamily: EvaTypography.uiFamily,

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
          tooltipFamily: EvaTypography.uiFamily,

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

    testWidgets(
      'the chevron is ember, like the prototype\'s and like EvaButton\'s',
      (WidgetTester tester) async {
        // M9. One prototype glyph had two colours in one phase: `ds.tsx:283` writes
        // `color: hex.ember` on the `›`, `EvaButton` transcribes it as
        // `colors.ember`, and `TextLink` was reading `ink` — the link's own colour.
        // It was not among the eight declared divergences, so it was a transcription
        // error rather than a decision, and nothing asserted it: the chevron tests
        // checked `findsOneWidget` / `findsNothing` and never its paint.
        //
        // Both palettes, because a colour that is only right in one is a half-fix.
        for (final (String theme, ThemeData data) in kEvaThemes) {
          await pumpAt(
            tester,
            const TextLink(
              label: 'Forgot password?',
              chevron: true,
              onPressed: _noop,
            ),
            theme: data,
          );
          final ThemeData resolved = Theme.of(tester.element(findLink()));
          expect(
            tester.widget<Icon>(find.byIcon(Icons.chevron_right)).color,
            resolved.extension<EvaColors>()!.ember,
            reason:
                '$theme — `ds.tsx:283` writes `hex.ember` on the `›`, and the size '
                'is already 16 to match. The link\'s *label* is a separate '
                'question, answered by the `color` parameter.',
          );
        }
      },
    );

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

    // ## WHY THIS GOLDEN PINS NO COLOUR
    //
    // It used to pass `color: Color(0xFFE8A33D)` — a literal, and `#E8A33D` is the
    // **dark** palette's `ember`. So the light capture was a byte-identical copy of
    // the dark one, and the file's name — "a golden per theme" — claimed a
    // theming check the pair could not possibly make. `Color(0xFFE8A33D)` is not
    // `EvaColors.dark().ember` anyway; it is a colour that bypassed the token
    // table to *imitate* one.
    //
    // With `color` dropped the widget resolves its own default, `ds.tsx:278`'s
    // `color: color ?? T.ink`, which is `EvaColors.ink` — `#EAE8F5` in dark and
    // `#120E28` in light. Now the pair differs, and the golden can fail for a
    // theming regression, which is the only thing it was ever able to check.
    //
    // What is *not* lost: the `color` parameter is still pinned, by the test above
    // ("without `color` it inks `ink`, and `ember` on request"), which is a better
    // place for it than a picture — it asserts the resolution rather than the
    // pixel. And `TextLink` ignoring `color` entirely still turns this pair red,
    // because the resolved default would no longer be what the images show.
    for (final (String theme, ThemeData data) in kEvaThemes) {
      testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
        await pumpAt(
          tester,
          const TextLink(label: 'Create account', onPressed: _noop),
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

  group('§14 — every interactive widget is ACTIVATABLE, not only named', () {
    // ## WHY THIS GROUP IS A SEPARATE GATE
    //
    // `Semantics(…, excludeSemantics: true)` drops the subtree's semantics —
    // including the `InkWell`'s tap action, because the `InkWell` is a descendant
    // of the node doing the excluding. Six widgets wrapped that way: `EvaButton`,
    // `TextLink`, `EvaChip`, `EvaToggle`, `IconActionButton`, and therefore
    // `ErrorView`'s retry. Each shipped `isButton == true` and a label, and
    // `hasAction(SemanticsAction.tap) == false`: a screen reader could read the
    // control and could not press it. A TalkBack double-tap is `ACTION_CLICK`,
    // which is `SemanticsAction.tap`.
    //
    // Every committed test was green because every one of them called
    // `tester.tap()` — the pointer path, which does not consult the semantics tree
    // — and the keyboard path, which works through `ActivateIntent`. Before this
    // group, `grep -rn 'SemanticsAction|hasAction|performAction' test/` returned
    // nothing at all: no test in the suite had ever read a semantics *action*.

    for (final InteractiveWidget entry in kInteractiveWidgets) {
      testWidgets('${entry.widget} offers ${entry.activation.name}', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, entry.build());
        final List<SemanticsData> actionable = nodesOffering(
          tester,
          entry.activation,
        );

        // Matched per **line**, not as a whole string. `SettingsTile` is the one
        // widget here that deliberately keeps its subtree in the tree
        // (`excludeSemantics: false`, so the trailing control survives), which
        // means its own title `Text` merges into the node's label and the label
        // arrives as "Edit profile\nEdit profile". That duplication is a real
        // §14 first-row wrinkle and it is **not** fixed here: it is outside this
        // task's findings, and changing a shipped widget's semantics to satisfy a
        // new gate is the wrong order of operations. It is recorded rather than
        // worked around silently — and a split is enough either way, because what
        // this gate is about is whether the *action* is there.
        expect(
          actionable.any(
            (SemanticsData d) =>
                d.label.split('\n').contains(entry.tappableLabel),
          ),
          isTrue,
          reason:
              '§14 — ${entry.widget} put no ${entry.activation.name} action on a '
              'node naming "${entry.tappableLabel}". ${entry.name}. A control a '
              "reader can name but not activate is this row's whole defect. "
              'Actionable labels were: '
              '${actionable.map((SemanticsData d) => '"${d.label}"').toList()}',
        );
      });

      testWidgets('${entry.widget} names every node it can activate', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, entry.build());
        final List<SemanticsData> actionable = nodesOffering(
          tester,
          entry.activation,
        );
        expect(actionable, isNotEmpty);
        for (final SemanticsData data in actionable) {
          expect(
            data.label.trim(),
            isNotEmpty,
            reason:
                '§14 — ${entry.widget} contributed a node a reader can activate '
                'and nothing can name. ${entry.name}',
          );
        }
      });
    }

    for (final InteractiveWidget entry in kDisabledWidgets) {
      testWidgets('${entry.widget} disabled offers no action at all', (
        WidgetTester tester,
      ) async {
        // The other half, and it cannot be folded into the loop above: a control
        // announced as disabled and then *responding* is worse than one that never
        // responded, because the reader has been told a lie about the state of the
        // page. `enabled: false` is not enough — the action has to be **absent**,
        // which is why these assert `hasAction` is false rather than checking the
        // flag.
        await pumpAt(tester, entry.build());
        expect(
          nodesOffering(tester, entry.activation),
          isEmpty,
          reason:
              '§14 — ${entry.widget} is inert but still publishes a '
              '${entry.activation.name} action. ${entry.name}',
        );
      });
    }

    group('and the negative control, so this gate is known to bite', () {
      testWidgets('a node with a flag and a label but no action fails it', (
        WidgetTester tester,
      ) async {
        // The exact shape of the six defects, built by hand so the gate is seen
        // failing rather than merely believed to.
        await pumpAt(tester, const _NamelesslyActable());

        expect(
          tester
              .getSemantics(find.byType(_NamelesslyActable))
              .flagsCollection
              .isButton,
          isTrue,
          reason: 'the control does look like a button…',
        );
        expect(
          nodesOffering(tester, SemanticsAction.tap),
          isEmpty,
          reason: '…and offers nothing to press, which is what §14 forbids',
        );
      });

      testWidgets('and a labelled action passes', (WidgetTester tester) async {
        // The control, so "the assertion above failed" is not the same as
        // "the walk found nothing at all".
        await pumpAt(tester, const _ActuallyActable());
        expect(
          nodesOffering(
            tester,
            SemanticsAction.tap,
          ).map((SemanticsData d) => d.label),
          contains('Push me'),
        );
      });
    });
  });
}

/// A control that is a button, is named, and cannot be pressed.
///
/// The negative control for §14's activatable row, built to the shape of the six
/// defects it replaced: `Semantics(button: true, label: …, excludeSemantics: true)`
/// over an `InkWell`, which is exactly what drops the tap action.
class _NamelesslyActable extends StatelessWidget {
  const _NamelesslyActable();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: true,
    label: 'Push me',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: () {},
      child: const SizedBox(width: 80, height: 44),
    ),
  );
}

/// The same control with the action restored.
class _ActuallyActable extends StatelessWidget {
  const _ActuallyActable();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: true,
    label: 'Push me',
    excludeSemantics: true,
    onTap: () {},
    child: GestureDetector(
      onTap: () {},
      child: const SizedBox(width: 80, height: 44),
    ),
  );
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
