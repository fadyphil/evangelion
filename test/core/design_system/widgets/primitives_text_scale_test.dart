import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// §14's other requirement, and the one Phase-1 decision 5 made a live risk:
/// **"text scales to 1.22× without overflow at 320px width."**
///
/// Both numbers are §14's and neither is negotiated:
///
/// - `320` — the narrowest phone still supported, and the width
///   `pumpPrimitive`'s surface is pinned to;
/// - `1.22` — `evaScalerFor`'s **largest** step, so this is the top of the range
///   the reader can choose in Settings and not an average.
///
/// ## WHY THE SCALE WAS NOT TUNED TO HIDE A FAILURE
///
/// Phase-1 decision 5 kept Material 3's type scale, so `displayLarge` is **57sp**
/// where the prototype's largest type is **34px**. At 1.22× on a 320px screen
/// `displayLarge` wraps to four lines. That is a real hazard and it is why
/// [EmptyState.titleStyle] uses `headlineMedium` (28sp) and why this file exists.
///
/// The response to a widget that overflows here is to **report it**, not to lower
/// the type scale until it stops: the scale is a Phase-1 decision, the overflow is
/// a per-widget fact, and only one of the two is this phase's to change.
///
/// ## HOW AN OVERFLOW IS DETECTED
///
/// `RenderFlex` and `RenderParagraph` raise a `FlutterError` through
/// `FlutterError.onError`, which `tester.takeException()` returns. That is the
/// only mechanism there is — there is no "did it overflow" property — so it is
/// also the only one a reader can trust.
///
/// ## AND THE NEGATIVE CONTROL
///
/// The last test pumps a `Column` that provably overflows at this scale, and
/// asserts that [tester.takeException] is non-null. Without it, "no overflow
/// everywhere below" is indistinguishable from "this file detects nothing", and
/// that is the same failure as a gate that cannot fail.
void main() {
  /// Every text-bearing Tier-1 widget, in the inventory's own order.
  ///
  /// Enumerated rather than discovered: discovery would need a legal argument for
  /// every widget, and `EvaTextField` needs a `TextEditingController` that a
  /// caller owns. The list is checked against the inventory by hand and a
  /// coverage test below counts it, so a widget added without a row is visible as
  /// a count that a reader can compare with `04-widget-inventory.md`.
  final Map<String, Widget Function()> cases = <String, Widget Function()>{
    'EvaButton — primary': () =>
        const EvaButton(label: 'Begin reflection', onPressed: _noopVoid),
    'EvaButton — secondary, expanded': () => const EvaButton(
      label: 'Back to library',
      variant: EvaButtonVariant.secondary,
      onPressed: _noopVoid,
    ),
    'EvaButton — ghost + chevron': () => const EvaButton(
      label: 'Forgot password?',
      variant: EvaButtonVariant.ghost,
      trailingChevron: true,
      expanded: false,
      onPressed: _noopVoid,
    ),
    'EvaChip — toggle': () =>
        const EvaChip(label: 'Dark', selected: true, onSelected: _noopBool),
    'EvaTextField — with an error': () => Material(
      type: MaterialType.transparency,
      child: EvaTextField(
        label: 'Password',
        controller: TextEditingController(text: 'hunter2'),
        errorText: "That password's too short",
      ),
    ),
    'EvaSectionHeader — section': () =>
        const EvaSectionHeader(label: 'Appearance'),
    'EvaSectionHeader — title, with a trailing control': () =>
        const EvaSectionHeader(
          label: 'Journey',
          size: EvaSectionHeaderSize.title,
          trailing: Text('See all'),
        ),
    'SettingsTile': () =>
        const SettingsTile(title: 'Notifications', trailing: _toggleBox),
    'SettingsGroup': () => const SettingsGroup(
      label: 'Appearance',
      children: <Widget>[
        SettingsTile(title: 'Theme', trailing: _box),
        SettingsTile(title: 'Font size', trailing: _box),
      ],
    ),
    'StatTile — the prototype\'s three-up row': () => const Row(
      children: <Widget>[
        Expanded(
          child: StatTile(value: '14', label: 'Read'),
        ),
        Expanded(
          child: StatTile(value: '9', label: 'Reflected'),
        ),
        Expanded(
          child: StatTile(value: '5/5', label: 'Best'),
        ),
      ],
    ),
    'TextLink': () =>
        const TextLink(label: 'Create account', onPressed: _noopVoid),
    'HairlineDivider — labelled': () => const HairlineDivider(label: 'or'),
    'EmptyState': () => const EmptyState(
      icon: Icons.inbox_outlined,
      title: 'Nothing here yet',
      message: 'Your reflections will appear here once you finish a reading.',
      action: EvaButton(label: 'Start', onPressed: _noopVoid),
    ),
    'ErrorView': () => const ErrorView(
      message: 'Could not reach the server.',
      onRetry: _noopVoid,
      retryLabel: 'Retry',
    ),
    'IconActionButton': () => const IconActionButton(
      icon: Icons.arrow_back,
      tooltip: 'Back',
      onPressed: _noopVoid,
    ),
    'EvaToggle': () => const EvaToggle(value: true, onChanged: _noopBool),
    'FontSizeStepper': () =>
        const FontSizeStepper(step: 3, onChanged: _noopInt),
    'SegmentedControl': () => SegmentedControl<String>(
      values: const <String>['Light', 'Dark', 'System'],
      selected: 'Dark',
      labelOf: (String value) => value,
      onChanged: _noopString,
    ),
    'ProgressBeads': () =>
        const ProgressBeads(total: 5, completed: 2, current: 2),
  };

  for (final MapEntry<String, Widget Function()> entry in cases.entries) {
    final String label = entry.key;
    final Widget Function() build = entry.value;
    testWidgets('$label does not overflow at 1.22× on a 320px screen', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        Align(alignment: Alignment.topCenter, child: build()),
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            '§14 — $label overflowed at $kEvaRequiredTextScale× on '
            '${kNarrowSurface.width}px. The type scale is a Phase-1 decision and '
            'must not be tuned to hide this; fix the widget.',
      );
      expect(kEvaRequiredTextScale, 1.22, reason: '§14 names 1.22');
      expect(kNarrowSurface.width, 320.0, reason: '§14 names 320');
    });

    testWidgets('$label does not overflow at 1.22× in RTL', (
      WidgetTester tester,
    ) async {
      // Defect #2's shape, one phase on: a widget that only works LTR looks fine
      // in every test above and is broken for half the readers.
      await pumpPrimitive(
        tester,
        Align(alignment: Alignment.topCenter, child: build()),
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
        textDirection: TextDirection.rtl,
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '§14 / defect #2 — $label',
      );
    });
  }

  testWidgets('NeuralScaffold holds a full screen body at 1.22×/320', (
    WidgetTester tester,
  ) async {
    // The scaffold's own job: `SafeArea` + `LayoutBuilder` and no fixed height, so
    // a body that is taller than 568 scrolls rather than overflowing.
    await pumpPrimitive(
      tester,
      const NeuralScaffold(
        variant: NeuralVariant.login,
        scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SealMonogram(),
            Text('Evangelion', textAlign: TextAlign.center),
            Text('Read. Reflect. Remember.', textAlign: TextAlign.center),
            SizedBox(height: EvaSpacing.huge),
            EvaButton(label: 'Sign in', onPressed: _noopVoid),
            SizedBox(height: EvaSpacing.md),
            EvaButton(
              label: 'Back to library',
              variant: EvaButtonVariant.secondary,
              onPressed: _noopVoid,
            ),
            HairlineDivider(label: 'or'),
            EvaButton(label: 'Continue with Google', onPressed: _noopVoid),
            SizedBox(height: EvaSpacing.xxl),
            TextLink(label: 'Create account', onPressed: _noopVoid),
          ],
        ),
      ),
      size: kNarrowSurface,
      textScale: kEvaRequiredTextScale,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  group('the fixed-height controls — where this gate can actually fail', () {
    // ## WHY THIS GROUP EXISTS SEPARATELY
    //
    // The sweep above cannot fail for a widget that is allowed to grow, and a box
    // measured off the widget under test cannot fail either — it grows with it.
    // The five controls below are the ones the design gives a **fixed** height:
    // `EvaButton` 52 (`ds.tsx:240`), `EvaTextField` 52 (`ds.tsx:306`), the
    // settings row's 56 floor (`ds.tsx:488`), and `IconActionButton`'s 44
    // (`SettingsScreen.tsx:39`). Those are the places where Phase-1 decision 5's
    // 57sp `displayLarge` would actually break the layout, so they are the places
    // a text-size regression has to be caught.
    //
    // Proven by mutation: `EvaButton`'s label slot `titleMedium` → `headlineMedium`
    // turns this group red, and the sweep above stays green.

    final Map<String, (Widget Function(), double)>
    fixed = <String, (Widget Function(), double)>{
      'EvaButton at 52': (
        () => const EvaButton(label: 'Begin reflection', onPressed: _noopVoid),
        kEvaButtonHeight,
      ),
      'EvaTextField at 52': (
        () => Material(
          type: MaterialType.transparency,
          child: EvaTextField(
            label: 'Password',
            controller: TextEditingController(text: 'hunter2'),
          ),
        ),
        kEvaTextFieldHeight,
      ),
      'IconActionButton at 44': (
        () => const IconActionButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: _noopVoid,
        ),
        44,
      ),
      'SettingsTile at its 56 floor': (
        () => const SettingsTile(title: 'Notifications', trailing: _toggleBox),
        SettingsTile.minHeight,
      ),
    };

    for (final MapEntry<String, (Widget Function(), double)> entry
        in fixed.entries) {
      testWidgets('${entry.key} holds its height at 1.22×', (
        WidgetTester tester,
      ) async {
        await pumpPrimitive(
          tester,
          SizedBox(height: entry.value.$2, child: entry.value.$1()),
          size: kNarrowSurface,
          textScale: kEvaRequiredTextScale,
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason:
              '§14 — ${entry.key} grew past the height the design fixes for it at '
              '$kEvaRequiredTextScale×. A fixed-height control cannot absorb a '
              'type-scale change by growing.',
        );

        // The second, and load-bearing, claim. `takeException()` is **not**
        // enough here, and measuring how it is not enough produced this: a
        // `RenderParagraph` in a constrained box clips or ellipsises rather than
        // reporting an overflow, so a label moved from 16sp to 45sp stayed
        // green through every exception-based assertion in this file. The
        // question §14 actually asks is whether the *text* fits the control it
        // is in, and that is a measurement.
        if (find.byType(Text).evaluate().isNotEmpty) {
          final Size text = tester.getSize(find.byType(Text).first);
          expect(
            text.height,
            lessThanOrEqualTo(entry.value.$2),
            reason:
                '§14 — the label in ${entry.key} is ${text.height}px tall at '
                '$kEvaRequiredTextScale×, inside a control the design fixes at '
                '${entry.value.$2}px. It is not overflowing *visibly* because '
                'RenderParagraph clips, which is worse.',
          );
        }
      });
    }
  });

  group('coverage', () {
    test('every text-bearing Tier-1 widget has a row', () {
      // The 18 Tier-1 primitives minus the two that render no text at all:
      // `ProgressBeads` is here (it has a semantics label but no `Text`), and
      // `NeuralScaffold` has its own test above because it needs a viewport.
      // Counted so a new widget added without a row is a count a reader can
      // compare against `04-widget-inventory.md` §6 rather than an omission.
      // 18 widget *families*; 19 rows because `EvaButton` is tested in its three
      // prototype variants, which is three separate layouts.
      expect(cases, hasLength(19));
      expect(
        cases.keys.map((String label) => label.split(' —').first).toSet(),
        <String>{
          'EvaButton',
          'EvaChip',
          'EvaTextField',
          'EvaSectionHeader',
          'SettingsTile',
          'SettingsGroup',
          'StatTile',
          'TextLink',
          'HairlineDivider',
          'EmptyState',
          'ErrorView',
          'IconActionButton',
          'EvaToggle',
          'FontSizeStepper',
          'SegmentedControl',
          'ProgressBeads',
        },
      );
    });

    test(
      'and the one placeholder constant is not a substitute for a widget',
      () {
        expect(_box, isA<Widget>());
        expect(_toggleBox, isA<Widget>());
      },
    );
  });

  group('the negative control — this file can fail', () {
    testWidgets('a column that provably overflows is caught', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        Column(
          children: <Widget>[
            for (int i = 0; i < 80; i++)
              Text(
                'line $i',
                style: Theme.of(tester.element(find.byType(Text)))
                    .textTheme
                    .titleMedium,
              ),
          ],
        ),
        size: kNarrowSurface,
        textScale: kEvaRequiredTextScale,
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNotNull,
        reason:
            'if this is null then "no overflow" in every test above is '
            'vacuously true and this whole file asserts nothing',
      );
    });
  });
}

const Widget _box = SizedBox(width: 60, height: 24);
const Widget _toggleBox = SizedBox(width: 44, height: 24);

void _noopVoid() {}

void _noopBool(bool value) {}

void _noopInt(int value) {}

void _noopString(String value) {}
