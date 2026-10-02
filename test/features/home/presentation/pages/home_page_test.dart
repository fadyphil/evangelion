import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomePage', () {
    testWidgets('pumps as a Scaffold with an app bar titled by its route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text(AppRoutes.home), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
    });

    testWidgets('body says it is a placeholder, not the real screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));

      expect(find.text('Placeholder for /'), findsOneWidget);
    });
  });
}
