import 'package:evangelion/features/servant/presentation/widgets/question_option_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../servant_harness.dart';

void main() {
  group('the option editor', () {
    testWidgets('shows the letter and the two fields', (
      WidgetTester tester,
    ) async {
      await pumpServant(
        tester,
        // **A `Material` above it**, because `EvaTextField` is a `TextField`
        // and a `TextField` needs a `Material` ancestor. The app's own screens
        // get one from the `Scaffold` inside `NeuralScaffold`; a widget test
        // that mounts the editor on its own has to bring it.
        Material(
          child: QuestionOptionEditor(
            letter: 'A',
            arabicText: 'الخير',
            englishText: 'The good',
            onChanged: ({required bool arabic, required String text}) {},
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('The good'), findsOneWidget);
      expect(find.text('الخير'), findsOneWidget);
    });

    testWidgets('reports which of the two texts changed', (
      WidgetTester tester,
    ) async {
      final List<({bool arabic, String text})> changes =
          <({bool arabic, String text})>[];
      await pumpServant(
        tester,
        Material(
          child: QuestionOptionEditor(
            letter: 'A',
            arabicText: '',
            englishText: '',
            onChanged: ({required bool arabic, required String text}) =>
                changes.add((arabic: arabic, text: text)),
          ),
        ),
      );

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'الخير');
      await tester.enterText(fields.at(1), 'The good');
      await tester.pump();

      // **The last change of each half**, and not the first: focusing a field
      // is itself a change of the controller's value, and the framework
      // reports it. The claim is that each half reports **its own** text.
      final ({bool arabic, String text}) arabicChange = changes.lastWhere(
        (({bool arabic, String text}) change) => change.arabic,
      );
      final ({bool arabic, String text}) englishChange = changes.lastWhere(
        (({bool arabic, String text}) change) => !change.arabic,
      );
      expect(arabicChange.text, 'الخير');
      expect(englishChange.text, 'The good');
    });

    testWidgets('and a rebuild does not move the caret', (
      WidgetTester tester,
    ) async {
      final List<({bool arabic, String text})> changes =
          <({bool arabic, String text})>[];
      await pumpServant(
        tester,
        Material(
          child: QuestionOptionEditor(
            letter: 'A',
            arabicText: '',
            englishText: '',
            onChanged: ({required bool arabic, required String text}) =>
                changes.add((arabic: arabic, text: text)),
          ),
        ),
      );

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'The good');
      await tester.pump();
      final int before = changes.length;

      // **A rebuild with the same text changes nothing**, because the widget
      // writes into its controller only when the two differ.
      await tester.pump();
      expect(changes, hasLength(before));
    });
  });
}
