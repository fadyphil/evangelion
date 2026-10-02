import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsPage', () {
    testWidgets('pumps as a Scaffold with an app bar titled by its route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      // The constant, not the literal — `AppRoutes.settings` *is*
      // `/settings`, so asserting both was a byte-for-byte duplicate at
      // runtime. `app_routes_test.dart` is where the literal values are
      // pinned.
      expect(find.text(AppRoutes.settings), findsOneWidget);
    });

    testWidgets('body says it is a placeholder, not the real screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

      expect(find.text('Placeholder for /settings'), findsOneWidget);
    });
  });
}
