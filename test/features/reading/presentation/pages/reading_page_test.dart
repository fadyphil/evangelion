import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingPage', () {
    testWidgets('pumps as a Scaffold with an app bar titled by its route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ReadingPage()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text(AppRoutes.reading), findsOneWidget);
      expect(find.text('/reading'), findsOneWidget);
    });

    testWidgets('body says it is a placeholder, not the real screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ReadingPage()));

      expect(find.text('Placeholder for /reading'), findsOneWidget);
    });
  });
}
