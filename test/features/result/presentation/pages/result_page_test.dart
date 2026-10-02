import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultPage', () {
    testWidgets('pumps as a Scaffold with an app bar titled by its route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ResultPage()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      // The constant, not the literal — `AppRoutes.result` *is*
      // `/result`, so asserting both was a byte-for-byte duplicate at
      // runtime. `app_routes_test.dart` is where the literal values are
      // pinned.
      expect(find.text(AppRoutes.result), findsOneWidget);
    });

    testWidgets('body says it is a placeholder, not the real screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ResultPage()));

      expect(find.text('Placeholder for /result'), findsOneWidget);
    });
  });
}
