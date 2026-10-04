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
    'EvaButton — primary': () => const EvaButton(
      labelFamily: EvaTypography.uiFamily,
      label: 'Begin reflection',
      onPressed: _noopVoid,
    ),
    'EvaButton — secondary, expanded': () => const EvaButton(
      labelFamily: EvaTypography.uiFamily,

      label: 'Back to library',
      variant: EvaButtonVariant.secondary,
      onPressed: _noopVoid,
    ),
    'EvaButton — ghost + chevron': () => const EvaButton(
      labelFamily: EvaTypography.uiFamily,

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
      action: EvaButton(
        labelFamily: EvaTypography.uiFamily,
        label: 'Start',
        onPressed: _noopVoid,
      ),
    ),
    'ErrorView': () => const ErrorView(
      message: 'Could not reach the server.',
      onRetry: _noopVoid,
      retryLabel: 'Retry',
      retryFamily: EvaTypography.uiFamily,
    ),
    'IconActionButton': () => const IconActionButton(
      tooltipFamily: EvaTypography.uiFamily,

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
            EvaButton(
              labelFamily: EvaTypography.uiFamily,
              label: 'Sign in',
              onPressed: _noopVoid,
            ),
            SizedBox(height: EvaSpacing.md),
            EvaButton(
              labelFamily: EvaTypography.uiFamily,

              label: 'Back to library',
              variant: EvaButtonVariant.secondary,
              onPressed: _noopVoid,
            ),
            HairlineDivider(label: 'or'),
            EvaButton(
              labelFamily: EvaTypography.uiFamily,
              label: 'Continue with Google',
              onPressed: _noopVoid,
            ),
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
    // The sweep above cannot fail for a widget that is allowed to grow. The **four**
    // controls below are the ones the design gives a **fixed** height or a floor:
    // `EvaButton` 52 (`ds.tsx:240`), `EvaTextField`'s shell 52 (`ds.tsx:306`), the
    // settings row's 56 floor (`ds.tsx:488`), and `IconActionButton`'s 44
    // (`SettingsScreen.tsx:39`). Those are the places where Phase-1 decision 5's
    // 57sp `displayLarge` would actually break the layout, so they are the places
    // a text-size regression has to be caught.
    //
    // ## AND HOW EACH ONE IS MEASURED — WHICH TOOK GETTING RIGHT
    //
    // The first version wrapped each control in `SizedBox(height: <the constant>)`
    // and then asked whether it overflowed. **That box did nothing at all.**
    // `MaterialApp.home` hands the route `BoxConstraints(w: 320, h: 568)` — tight —
    // and `BoxConstraints.enforce` clamps *this* min/max into the incoming range,
    // so `clampDouble(56, 568, 568) == 568`. The control rendered 568 tall inside
    // a "56px" box, the failure message described a failure the box could not
    // produce, and every assertion in the group passed for a reason that had
    // nothing to do with the control. Reproduced with no project code at all:
    // `MaterialApp.home` gives `Size(320, 568)`; a bare `Directionality` gives
    // `Size(44, 56)`.
    //
    // So there is no box. Each entry names **the box that carries the height** —
    // the widget itself, or for `EvaTextField` the decorated shell, because that
    // widget's *own* height is label + gap + 52 and the 52 is what the design
    // fixes — and the constant is compared against `tester.getSize` of it. Two
    // consequences, both of them the point:
    //
    // - a height mutation is now caught: `EvaTextField`'s shell 52 → 72 and
    //   `IconActionButton` 44 → 72 were the two §14-shaped losses that **nothing
    //   in the suite caught**, and both are the first assertion below;
    // - the text is found **by its data**, not positionally. `find.byType(Text)
    //   .first` was unsound for two of the four: `EvaTextField` renders exactly
    //   one `Text` — the floating label, `"PASSWORD"` at 12sp — so the measurement
    //   never touched the entered value, and `IconActionButton` has no `Text` at
    //   all, so the `isNotEmpty` guard skipped the measurement entirely and
    //   `size 44 → 72` sailed through.

    for (final _FixedHeight entry in _fixed) {
      testWidgets('${entry.label} holds its height at 1.22×', (
        WidgetTester tester,
      ) async {
        await pumpPrimitive(
          tester,
          Align(alignment: Alignment.topCenter, child: entry.build()),
          size: kNarrowSurface,
          textScale: kEvaRequiredTextScale,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final Finder box = entry.box();
        expect(box, findsOneWidget, reason: entry.finderReason);

        final Size size = tester.getSize(box);
        expect(
          size.height,
          lessThanOrEqualTo(entry.height),
          reason:
              '§14 — ${entry.label} rendered ${size.height}px tall where the '
              'design fixes ${entry.height}px. ${entry.heightReason}',
        );

        // The second, and independent, claim. `takeException()` is **not** enough
        // here, and measuring how it is not enough produced this: a
        // `RenderParagraph` in a constrained box clips or ellipsises rather than
        // reporting an overflow, so a label moved from 16sp to 45sp stayed green
        // through every exception-based assertion in this file. The question §14
        // actually asks is whether the *text* fits the control it is in, and that
        // is a measurement.
        if (entry.text case final String data) {
          final Finder label = find.text(data);
          expect(label, findsOneWidget, reason: entry.textReason!(data));
          // Measured **intrinsically**, which is the whole point and took two
          // attempts. `tester.getSize(find.text(data))` inside the real tree
          // returns the size the *parent* already handed the paragraph — and the
          // parent is the fixed-height box, so the reading is clamped to 52 and
          // can never exceed it. That assertion could not fail for `EvaButton`
          // even at `displayMedium`, where one line of the label is ~63px.
          // (An `OverflowBox` was tried for the unconstrained layout and handed
          // the child the viewport's tight height anyway, 568 — which is the same
          // class of bug as the `SizedBox` this group used to start with.)
          //
          // So the label is laid out by a [TextPainter] with the SDK's own
          // paragraph engine, the style the widget actually resolved, and the
          // same scaler §14 names. One line is the conservative reading: if one
          // line does not fit, a wrapped second line cannot.
          // The `Text`'s own `maxLines` is copied when there is one. For
          // `EvaTextField`'s value there is not — `EditableText` renders through a
          // `RichText` — and the default (as many lines as it takes) is the
          // conservative reading here anyway.
          final Finder asText = find.byWidgetPredicate(
            (Widget w) => w is Text && w.data == data,
          );
          final int? maxLines = asText.evaluate().isEmpty
              ? null
              : tester.widget<Text>(asText).maxLines;
          final TextStyle style = entry.styleOf!(tester);
          expect(style, isNotNull, reason: 'the style the text renders with');
          final TextPainter painter = TextPainter(
            text: TextSpan(text: data, style: style),
            // LTR, because that is the direction the widget was pumped in and
            // the one the prototype lays out in. `Directionality.of` would need
            // an element, and re-deriving the direction from the tree to measure
            // the tree is one step more than the measurement needs.
            textDirection: TextDirection.ltr,
            textScaler: const TextScaler.linear(kEvaRequiredTextScale),
            maxLines: maxLines,
            textAlign: TextAlign.start,
          )..layout();
          final double intrinsic = painter.height;
          painter.dispose();
          expect(
            intrinsic,
            lessThanOrEqualTo(entry.height),
            reason:
                '§14 — one line of the text in ${entry.label} is ${intrinsic}px '
                'tall at $kEvaRequiredTextScale×, inside a control the design '
                'fixes at ${entry.height}px. It is not overflowing *visibly* '
                'because RenderParagraph clips or ellipsises, which is worse.',
          );
        } else {
          expect(
            entry.noText,
            isNotEmpty,
            reason: 'entry without text must say why',
          );
        }
      });
    }
  });

  group('what this sweep does and does not catch', () {
    // The comment above used to claim `EvaButton`'s `titleMedium` →
    // `headlineMedium` turns the group red, "and the sweep above stays green". It
    // does not: measured, all 46 cases stay green. `headlineMedium` is 28sp, so at
    // 1.22× its line box is ~42px and it still fits the 52px pill. **Detection of
    // a slot mutation begins at `displayMedium` (45sp → 64px measured), which is
    // over — and it is over because this group measures the label's intrinsic
    // height, not its clamped height inside the pill.**
    //
    // Stated rather than quietly re-worded, because the eleven mutations below do
    // survive the sweep and a reader deciding whether §14 is covered needs to know
    // which half of it is load-bearing:
    //
    // | mutation | survives the sweep | caught by |
    // | --- | --- | --- |
    // | `StatTile` value `headlineSmall` → `displayLarge` | yes | `surfaces_test.dart`'s slot assertion, the goldens |
    // | `StatTile` padding 14/10 → 40/24 | yes | the goldens |
    // | `EmptyState` `headlineMedium` → `displayLarge` | yes | `surfaces_test.dart`, the goldens |
    // | `EvaSectionHeader` `titleMedium` → `displayMedium` | yes | the goldens |
    // | `EvaTextField` `bodyLarge` → `headlineMedium` | yes | the goldens |
    // | `SettingsTile` padding `sm` → `lg` | yes | the goldens |
    // | `SettingsTile` title `bodyLarge` → `headlineMedium` | yes | `surfaces_test.dart`, the goldens |
    // | `EvaButton` `titleMedium` → `headlineMedium` | yes | **nothing** — 42px still fits 52, see above |
    // | `EvaTextField` shell height 52 → 72 | **no** | **nothing**, before this change |
    // | `IconActionButton` size 44 → 72 | **no** | **nothing**, before this change |
    //
    // So the sweep is *redundant* over most of that list rather than unguarded —
    // a slot assertion in `surfaces_test.dart` or a golden already turns red — and
    // the two genuine §14-shaped losses were the two height constants, which the
    // fixed-height group now measures directly. The one row with nothing behind it
    // is `EvaButton`'s label slot between `titleMedium` and `displayMedium`, and
    // the honest reading is that a reader who picked a 28–44sp label would not see
    // it clipped: the pill is 52 and `RenderParagraph` ellipsises. That is a
    // legibility question rather than a layout failure, and it is named rather
    // than asserted away.
    test('the constants this group checks are the design\'s own', () {
      expect(kEvaButtonHeight, 52.0, reason: 'ds.tsx:240 — `height: 52`');
      expect(kEvaTextFieldHeight, 52.0, reason: 'ds.tsx:306 — `height: 52`');
      expect(SettingsTile.minHeight, 56.0, reason: 'ds.tsx:488 — `height: 56`');
      expect(_fixed, hasLength(4), reason: 'four controls, not five');
    });
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

    // ## THE TEST THAT WAS HERE, AND WHY IT WAS WORTHLESS
    //
    // It read:
    //
    // ```dart
    // test('and the one placeholder constant is not a substitute for a widget', () {
    //   expect(_box, isA<Widget>());
    //   expect(_toggleBox, isA<Widget>());
    // });
    // ```
    //
    // Both constants are declared `const Widget`, so the **static type** guarantees
    // `isA<Widget>()` and no program text can make it fail. It described a
    // comparison the test never made. Kept as a real check instead: the thing
    // worth knowing about `_box` / `_toggleBox` is what they *lack*, which is
    // text — they exist to be a `SettingsTile`'s `trailing` slot, and a slot with
    // no text would make the row's sweep pass vacuously.
    testWidgets('and the placeholder slots carry no text of their own', (
      WidgetTester tester,
    ) async {
      for (final (String label, Widget slot) in <(String, Widget)>[
        ('_box', _box),
        ('_toggleBox', _toggleBox),
      ]) {
        await pumpPrimitive(tester, slot, size: kNarrowSurface);
        await tester.pump();
        expect(
          find.byType(Text),
          findsNothing,
          reason:
              '$label is a bare box, which is the point of it: it stands in for a '
              'row\'s trailing control and contributes no text. If it ever grew '
              'one, this would stop being true.',
        );
      }
    });

    testWidgets('so the rows that use them are measured on their own text', (
      WidgetTester tester,
    ) async {
      for (final (String row, String text) in const <(String, String)>[
        ('SettingsTile', 'Notifications'),
        ('SettingsGroup', 'Theme'),
      ]) {
        await pumpPrimitive(
          tester,
          Align(alignment: Alignment.topCenter, child: cases[row]!()),
          size: kNarrowSurface,
          textScale: kEvaRequiredTextScale,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.text(text),
          findsOneWidget,
          reason:
              'the $row sweep row must be measuring the row\'s own text, not a '
              'placeholder',
        );
      }
    });
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

/// One control with a height the design fixes, the box that carries it, and the
/// text that has to fit inside it.
typedef _FixedHeight = ({
  String label,
  Widget Function() build,
  Finder Function() box,
  String finderReason,
  double height,
  String heightReason,
  String? text,
  String Function(String)? textReason,

  /// How to obtain the [TextStyle] the text renders with.
  ///
  /// Not always `tester.widget<Text>(find.text(text)).style`: `EvaTextField`
  /// renders its **value** through `EditableText`'s `RichText`, which carries no
  /// readable `TextStyle` — so the style comes off the `TextField` instead. That
  /// indirection is the price of naming the text by its data rather than by its
  /// position, and it is the reason `find.byType(Text).first` was unsound.
  TextStyle Function(WidgetTester tester)? styleOf,
  String? noText,
});

/// The four fixed-height controls.
///
/// A record rather than a `Map<String, (Widget, double)>` because each entry now
/// carries five more facts, and a positional tuple of seven elements is not
/// readable at the call site — which is how the finder for the wrong box got
/// written in the first place.
final List<_FixedHeight> _fixed = <_FixedHeight>[
  (
    label: 'EvaButton at 52',
    build: () => const EvaButton(
      labelFamily: EvaTypography.uiFamily,
      label: 'Begin reflection',
      onPressed: _noopVoid,
    ),
    box: () => find.byType(EvaButton),
    finderReason: 'the button is its own box — it sets `height:` on its shell',
    height: kEvaButtonHeight,
    heightReason:
        'The pill is fixed at 52 (`ds.tsx:240`), and a control that cannot grow '
        'absorbs a type-scale change by clipping its own label.',
    text: 'Begin reflection',
    textReason: (String data) => 'the button label is the text under test',
    styleOf: (WidgetTester tester) =>
        tester.widget<Text>(find.text('Begin reflection')).style!,
    noText: null,
  ),
  (
    label: 'EvaTextField at 52',
    build: () => Material(
      type: MaterialType.transparency,
      child: EvaTextField(
        label: 'Password',
        controller: TextEditingController(text: 'hunter2'),
      ),
    ),
    // NOT `find.byType(EvaTextField)`. That widget is a `Column` of a mono-caps
    // label, a 6px gap and the 52px shell, so it measures ~77 — the 52 the design
    // fixes belongs to the shell, which is the one `DecoratedBox` in the
    // subtree. `find.byType(Text).first` was the same mistake in a different
    // place: it found the floating label, `"PASSWORD"` at 12sp, and never the
    // entered value at 16sp — the one §14 is actually about.
    box: () => find.ancestor(
      of: find.byType(TextField),
      matching: find.byType(DecoratedBox),
    ),
    finderReason:
        'the field shell is the only `DecoratedBox` above the `TextField`, and it '
        'is the box SizedBox(height: kEvaTextFieldHeight) draws',
    height: kEvaTextFieldHeight,
    heightReason:
        'The shell is fixed at 52 (`ds.tsx:306`). The widget as a whole is taller '
        'by design — label plus gap — so this is the shell\'s height and not the '
        'column\'s.',
    // The **entered value**, named by its data. `EditableText` renders it through
    // a `RichText`, not a `Text`, which is why `find.byType(Text)` never saw it.
    text: 'hunter2',
    textReason: (String data) =>
        'the entered value is the text a reader is looking at; the floating '
        'label above it is 12sp and would pass at any size',
    styleOf: (WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).style!,
    noText: null,
  ),
  (
    label: 'IconActionButton at 44',
    build: () => const IconActionButton(
      tooltipFamily: EvaTypography.uiFamily,

      icon: Icons.arrow_back,
      tooltip: 'Back',
      onPressed: _noopVoid,
    ),
    box: () => find.byType(IconActionButton),
    finderReason:
        'the button is its own box — it sets `size:` on its `SizedBox`',
    height: 44,
    heightReason:
        "44 is ds.tsx's literal (`SettingsScreen.tsx:39`) and also "
        "`iOSTapTargetGuideline`'s minimum, so one number satisfies both.",
    // **No text, and the reason matters.** There is no `Text` in this widget at
    // all: the content is an `Icon`, and `Icon` does not scale with `TextScaler`,
    // so there is no text for 1.22× to overflow. The previous version wrote
    // `if (find.byType(Text).evaluate().isNotEmpty)` and therefore **skipped** its
    // own second assertion here — which is how `size 44 → 72` survived a group
    // whose whole purpose is fixed heights. The height check above is the whole
    // check for this control, and it is the one that used to be a no-op.
    noText:
        'an `IconActionButton` renders no `Text` — its content is an `Icon`, '
        'which does not scale with `TextScaler`, so there is nothing for the text '
        'measurement to measure and the height assertion carries this entry alone',
    text: null,
    textReason: null,
    styleOf: null,
  ),
  (
    label: 'SettingsTile at its 56 floor',
    build: () =>
        const SettingsTile(title: 'Notifications', trailing: _toggleBox),
    box: () => find.byType(SettingsTile),
    finderReason: 'the row is its own box — it sets the `minHeight` constraint',
    height: SettingsTile.minHeight,
    heightReason:
        "The constraint is a **floor**, not a fixed height (`settings_tile.dart`'s "
        'doc says so at length), and the row is allowed to exceed it when its '
        'content needs the room. What §14 asks is that 1.22× does not *force* it '
        'past its floor — so the bound is `<=` and the row passing at exactly 56 is '
        'the passing case, not a tautology.',
    text: 'Notifications',
    textReason: (String data) => 'the row title is the text under test',
    styleOf: (WidgetTester tester) =>
        tester.widget<Text>(find.text('Notifications')).style!,
    noText: null,
  ),
];

const Widget _box = SizedBox(width: 60, height: 24);
const Widget _toggleBox = SizedBox(width: 44, height: 24);

void _noopVoid() {}

void _noopBool(bool value) {}

void _noopInt(int value) {}

void _noopString(String value) {}
