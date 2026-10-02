import 'package:evangelion/core/navigation/app_routes.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginPage', () {
    testWidgets('pumps as a Scaffold with an app bar titled by its route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      // The bare route path, not a product title. The stub names the screen it
      // stands in for, so a screenshot of it is self-identifying.
      //
      // The constant, not the literal — `AppRoutes.login` *is* `'/login'`, so
      // asserting both was a byte-for-byte duplicate at runtime. This pins that
      // the title is derived from the route definition;
      // `app_routes_test.dart` is where the literal values are pinned.
      expect(find.text(AppRoutes.login), findsOneWidget);
    });

    testWidgets('body says it is a placeholder, not the real screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.text('Placeholder for /login'), findsOneWidget);
    });
  });
}
