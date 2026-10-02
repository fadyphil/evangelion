import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// The Phase 3 keyboard gate: `SegmentedControl` **selects via keyboard**, not
/// just via taps. `08-build-phases.md` §Phase 3 names it as the phase's verify
/// line and the prototype cannot pass it — `SettingsScreen.tsx:6,52-61` is three
/// `<button>`s over a `useState`, so a keyboard reaches them one at a time and
/// arrow keys do nothing at all.
///
/// The model itself ([nextSelection], [selectionStepFor]) is pinned in
/// `selection_model_test.dart`; this file is the widget wiring it to keys.
void main() {
  final Finder controlFinder = find.byType(SegmentedControl<String>);

  Future<void> pump(
    WidgetTester tester, {
    String selected = 'Dark',
    ValueChanged<String>? onPicked,
    ThemeData? theme,
    bool disableAnimations = false,
    TextDirection direction = TextDirection.ltr,
  }) => pumpPrimitive(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: _Live(initial: selected, onPicked: onPicked),
    ),
    theme: theme,
    disableAnimations: disableAnimations,
    textDirection: direction,
  );

  AnimatedContainer segmentAt(WidgetTester tester, int index) =>
      tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: controlFinder,
              matching: find.byType(AnimatedContainer),
            )
            .at(index),
      );

  group('Phase 3 gate — selects via keyboard', () {
    testWidgets('Tab reaches the control, and it is one stop', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      await tabUntilFocused(tester, controlFinder);
      expect(
        segmentAt(tester, 1).duration,
        EvaMotion.base,
        reason: 'the middle segment is the selected one',
      );
    });

    testWidgets('one Tab leaves the control, so it is not three stops', (
      WidgetTester tester,
    ) async {
      // A sibling control **after** the segmented control. Without a second
      // focusable in the tree, Tab has nowhere to go and stays put, which would
      // make "Tab left" untestable rather than false.
      await pumpPrimitive(
        tester,
        const Column(
          children: <Widget>[
            _Live(initial: 'Dark', onPicked: null),
            EvaButton(label: 'After', onPressed: _noop),
          ],
        ),
      );
      await tabUntilFocused(tester, controlFinder);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Three separately focusable segments would need three more presses before
      // focus reached the button; one means the control is a single stop.
      expect(semanticsOf(tester, find.text('After')).label, 'After');
      expect(
        tester
            .widget<Focus>(
              find
                  .descendant(
                    of: find.byType(EvaButton),
                    matching: find.byType(Focus),
                  )
                  .first,
            )
            .focusNode
            ?.hasFocus,
        isTrue,
        reason: 'focus arrived at the next control in one press',
      );
    });

    testWidgets('ArrowRight steps forward and wraps', (
      WidgetTester tester,
    ) async {
      final List<String> seen = <String>[];
      await pump(tester, selected: 'Dark', onPicked: seen.add);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <String>['System']);
      expect(find.text('LIGHT'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <String>['System', 'Light']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen.last, 'Dark', reason: 'three options, three steps, wrapped');
    });

    testWidgets('ArrowLeft steps back and wraps', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      await pump(tester, selected: 'Dark', onPicked: seen.add);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seen, <String>['Light']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seen.last, 'System');
    });

    testWidgets('the fill follows the selection, not just the callback', (
      WidgetTester tester,
    ) async {
      // The load-bearing half of "selects via keyboard": a control that reports a
      // new value but does not *move its selection* has not selected anything.
      await pump(tester, selected: 'Dark');
      await tabUntilFocused(tester, controlFinder);

      final Color darkFill =
          (segmentAt(tester, 1).decoration as BoxDecoration).color!;
      final Color lightFill =
          (segmentAt(tester, 0).decoration as BoxDecoration).color!;
      expect(darkFill, isNot(lightFill));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(
        (segmentAt(tester, 0).decoration as BoxDecoration).color,
        darkFill,
        reason: 'Light now carries the selected fill Dark had',
      );
      expect(
        (segmentAt(tester, 1).decoration as BoxDecoration).color,
        lightFill,
      );
    });

    testWidgets('focus does not leave the control while arrowing', (
      WidgetTester tester,
    ) async {
      // The reason [EvaFocusRing] forwards key events instead of letting the
      // default `HorizontalTraversalIntent` run: if focus moved, a reader arrowing
      // through a setting would land in the next control instead of the next value.
      await pump(tester);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        tester
            .widget<Focus>(
              find
                  .descendant(of: controlFinder, matching: find.byType(Focus))
                  .first,
            )
            .focusNode
            ?.hasFocus,
        isTrue,
      );
    });

    testWidgets('ArrowRight walks backwards in an RTL screen', (
      WidgetTester tester,
    ) async {
      // §14 and prototype defect #2 in the same place: a control whose "forward"
      // ignores `Directionality` is the same bug as Arabic laid out LTR.
      final List<String> seen = <String>[];
      await pump(
        tester,
        selected: 'Dark',
        onPicked: seen.add,
        direction: TextDirection.rtl,
      );
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen, <String>['Light'], reason: 'RTL flips what "forward" means');
    });

    testWidgets('Home and End jump to the ends', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      await pump(tester, selected: 'Dark', onPicked: seen.add);
      await tabUntilFocused(tester, controlFinder);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(seen.last, 'System');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(seen.last, 'Light');
    });

    testWidgets('a tap still works — the keyboard is additive', (
      WidgetTester tester,
    ) async {
      final List<String> seen = <String>[];
      await pump(tester, selected: 'Dark', onPicked: seen.add);
      await tester.tap(find.text('LIGHT'));
      await tester.pump();
      expect(seen, <String>['Light']);
    });

    testWidgets('with animations off the selection fill lands at once', (
      WidgetTester tester,
    ) async {
      await pump(tester, disableAnimations: true);
      expect(segmentAt(tester, 0).duration, Duration.zero);
    });
  });

  group('Semantics', () {
    testWidgets('each segment is a button that reports itself selected', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, selected: 'Dark');
      handle.dispose();

      final chosen = semanticsOf(tester, find.text('DARK'));
      expect(chosen.flagsCollection.isButton, isTrue);
      expect(chosen.flagsCollection.isSelected.toBoolOrNull(), isTrue);

      final idle = semanticsOf(tester, find.text('LIGHT'));
      expect(idle.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    });
  });

  group('shape', () {
    testWidgets('an empty value list renders no text and does not throw', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        SegmentedControl<String>(
          values: const <String>[],
          selected: '',
          labelOf: (String value) => value,
          onChanged: (String _) {},
        ),
      );
      expect(controlFinder, findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the track is the prototype\'s one filled container', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      // `SettingsScreen.tsx:51` — one `background: rgba(…, 0.06)` wrapper with
      // `overflow: hidden`, not three separate pills.
      final Container track = tester.widget<Container>(
        find
            .descendant(of: controlFinder, matching: find.byType(Container))
            .first,
      );
      expect(
        (track.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(SegmentedControl.trackRadius),
      );
      expect(SegmentedControl.trackRadius, 8.0);
    });

    testWidgets('the labels are the prototype\'s mono caps', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final Text label = tester.widget<Text>(find.text('DARK'));
      expect(
        label.data,
        'DARK',
        reason: 'uppercased — Flutter has no CSS-style',
      );
      expect(label.style!.fontFamily, EvaTypography.monoFamily);
    });
  });

  for (final (String theme, ThemeData data) in kEvaThemes) {
    testWidgets('a golden per theme — $theme', (WidgetTester tester) async {
      await pump(tester, theme: data);
      await tester.pump();
      await expectLater(
        controlFinder,
        matchesGoldenFile('goldens/segmented_control_$theme.png'),
      );
    });
  }

  testWidgets('state golden — focused', (WidgetTester tester) async {
    await pump(tester);
    await tabUntilFocused(tester, controlFinder);
    await tester.pump();
    await expectLater(
      controlFinder,
      matchesGoldenFile('goldens/segmented_control_state_focused.png'),
    );
  });
}

/// A control whose `selected` **follows** `onChanged`.
///
/// [SegmentedControl] is a controlled component: `onChanged` reports and the
/// caller feeds the value back. A test that pumps a fixed `selected` and then
/// presses an arrow key twice is testing a control that never moves — and the
/// assertion it fails is about the test, not the widget. This is the smallest
/// honest stand-in for the Settings cubit that Phase 9 will supply.
void _noop() {}

class _Live extends StatefulWidget {
  const _Live({required this.initial, this.onPicked});

  final String initial;
  final ValueChanged<String>? onPicked;

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  late String _selected = widget.initial;

  @override
  Widget build(BuildContext context) => SegmentedControl<String>(
    values: const <String>['Light', 'Dark', 'System'],
    selected: _selected,
    labelOf: (String value) => value,
    onChanged: (String value) {
      setState(() => _selected = value);
      widget.onPicked?.call(value);
    },
  );
}
