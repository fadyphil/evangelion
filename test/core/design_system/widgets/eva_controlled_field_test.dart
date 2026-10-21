import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/design_system_harness.dart';

/// **The controlled field's contract, in the order the class doc states it.**
///
/// The widget exists because six defects of one class were found in this
/// repository's servant-portal work and **none of them was found by a gate** —
/// they were found by an agent reading the code. The class is in
/// `eva_controlled_field.dart`'s own doc and in AGENT_CONTEXT's decision 188:
///
/// > **A screen and the state it mirrors can stop agreeing — and the request is
/// > the one that writes.**
///
/// So these tests are the mechanism's half of the answer, and
/// `mirrored_controller_check_test.dart` is the gate's half: the first proves
/// the pattern is right, the second proves nobody hand-rolls it instead.
void main() {
  group('the controlled field reports the reader and only the reader', () {
    testWidgets('the reader\'s typing is reported', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));

      await tester.enterText(find.byType(TextField), 'John 3:1');

      expect(
        reported,
        <String>['John 3:1'],
        reason: 'the reader typed, and the reader\'s text is what the state is told',
      );
    });

    testWidgets('the mount reports nothing, whatever the value is', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(
        _host(
          value: 'a value the state already holds',
          onChanged: reported.add,
        ),
      );

      expect(
        reported,
        isEmpty,
        reason:
            'a controller\'s constructor notifies nobody, so the mount cannot '
            'report. The reader has not typed anything, and the cubit must not '
            'be told that they have — the reader clearing the field is one of '
            'the six defects this widget exists to remove.',
      );
      expect(
        _fieldText(tester),
        'a value the state already holds',
        reason: 'and the field shows the state from the first frame',
      );
    });

    testWidgets('a value that arrives from outside is mirrored, and reports '
        'nothing', (WidgetTester tester) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));

      await tester.pumpWidget(
        _host(value: "the server's draft", onChanged: reported.add),
      );

      expect(
        _fieldText(tester),
        "the server's draft",
        reason: 'the state moved, so the field shows it',
      );
      expect(
        reported,
        isEmpty,
        reason:
            '**THE CRUX.** The widget filled its own controller, and the '
            'controller told its listener — and the listener is the widget\'s '
            'way of reporting a keystroke. A write the widget made on purpose '
            'arriving as the reader\'s edit is defect #1: the cubit\'s edit '
            'writer drops the server\'s refusal with the edit, so a server\'s '
            'answer could vanish in the frame it arrived.',
      );
    });

    testWidgets('a value that arrives from outside replaces what the reader '
        'typed', (WidgetTester tester) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));
      await tester.enterText(find.byType(TextField), 'half written');

      await tester.pumpWidget(
        _host(value: 'the state is the truth', onChanged: reported.add),
      );

      expect(
        _fieldText(tester),
        'the state is the truth',
        reason:
            'the state moved to something the reader never typed, and the state '
            'is what the field shows. The mirror is one direction: the state '
            'into the field, never the field into the state.',
      );
      expect(reported, <String>['half written']);
    });
  });

  group('and the mirror never fights the reader', () {
    testWidgets('a rebuild that does not change the value changes nothing', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));
      await tester.enterText(find.byType(TextField), 'x');

      // The state has not caught up yet — this is the rebuild that arrives
      // before the cubit's own emission has reached the tree.
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));

      expect(
        _fieldText(tester),
        'x',
        reason:
            'the controlled value did not move, so there is nothing to mirror, '
            'and the character the reader has just typed stays on the screen. A '
            'mirror that ran on every rebuild would take it away.',
      );
      expect(reported, <String>['x']);
    });

    testWidgets('the state catching up does not move the caret', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));
      await tester.enterText(find.byType(TextField), 'abc');

      // The cubit took the edit, and the tree is rebuilt with what it now
      // holds. That is the controlled value catching up with the reader — and
      // the field already holds it, so writing it back would move the caret
      // for nothing.
      await tester.pumpWidget(_host(value: 'abc', onChanged: reported.add));

      expect(
        _fieldText(tester),
        'abc',
        reason: 'the reader\'s own text is still the text',
      );
      expect(
        reported,
        <String>['abc'],
        reason:
            'and the state catching up is not a second edit — the reader typed '
            'once, and the state was told once.',
      );
    });

    testWidgets('a keystroke after the state caught up is still reported', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      await tester.pumpWidget(_host(value: '', onChanged: reported.add));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpWidget(_host(value: 'a', onChanged: reported.add));

      await tester.enterText(find.byType(TextField), 'ab');

      expect(
        reported,
        <String>['a', 'ab'],
        reason:
            'the second keystroke is the reader\'s, and it is reported whole — '
            'the comparison that suppresses the widget\'s own write must not '
            'swallow a reader\'s.',
      );
      expect(_fieldText(tester), 'ab');
    });
  });

  group('§14 — the field is a field', () {
    testWidgets('it survives 320px at 1.22× without overflowing', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        Material(
          type: MaterialType.transparency,
          child: EvaControlledField(
            value: 'a long value that has to fit',
            onChanged: (String _) {},
            label: 'Passage',
          ),
        ),
        textScale: kEvaRequiredTextScale,
      );

      expectNoOverflow(
        tester,
        somethingRendered: () => find.byType(TextField).evaluate().isNotEmpty,
        surface: '${kNarrowSurface.width}px at ${kEvaRequiredTextScale}x',
      );
    });

    testWidgets('and it carries the focus ring its delegate draws', (
      WidgetTester tester,
    ) async {
      await pumpPrimitive(
        tester,
        Material(
          type: MaterialType.transparency,
          child: EvaControlledField(
            value: '',
            onChanged: (String _) {},
            label: 'Email',
          ),
        ),
      );

      final Finder field = find.byType(TextField);
      expect(field, findsOneWidget);

      await tester.tap(field);
      await tester.pump();

      expect(
        // The **whole** `EvaTextField`, not the `TextField` inside it: the rim
        // is drawn by a `DecoratedBox` that is the field's *ancestor*, and
        // `renderedBorders` looks at descendants of what it is given.
        renderedBorders(tester, find.byType(EvaTextField)),
        contains(evaFocusRingBorder(const EvaColors.dark())),
        reason:
            'the controlled field delegates to EvaTextField, and the field\'s '
            'own rim is §14\'s ring — the controlled field adds no surface of '
            'its own and no focus node.',
      );
    });
  });
}

/// The field under test, in the composition a design-system primitive is pumped
/// inside.
///
/// **`Material` is a `TextField` requirement, not decoration** — its
/// `InputDecorator` asserts on one, and a real screen gets it from `Scaffold`.
class _Host extends StatelessWidget {
  const _Host({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: EvaControlledField(
      value: value,
      onChanged: onChanged,
      label: 'Field',
    ),
  );
}

Widget _host({
  required String value,
  required ValueChanged<String> onChanged,
}) => evaPrimitiveHarness(
  child: _Host(value: value, onChanged: onChanged),
);

/// The text the field is showing, read off the field's own controller.
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;
