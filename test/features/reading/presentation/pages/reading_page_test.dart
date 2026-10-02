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
      // CAVEAT, AND IT IS THE WHOLE POINT OF BEING HERE IN THE TEST: this
      // AppBar is scaffolding, not the design. AGENT_CONTEXT §2 describes the
      // reading screen as "zero chrome", and the real `ReadingPage` has **no**
      // AppBar — the sanctuary is built to hide it. It is here because six
      // stubs sharing one shape give Phase 4's router and every widget test a
      // single form to recognise.
      //
      // When Phase 6 builds the sanctuary, **delete this assertion — do not
      // satisfy it.** The cheap way back to green is to put the AppBar back and
      // ship chrome the design explicitly rejects, and nothing in this project
      // would object. That is why the caveat lives in the test rather than in
      // `reading_page.dart`, where it would be read once and forgotten: this is
      // the only file a future author opens before touching the assertion.
      expect(find.byType(AppBar), findsOneWidget);
      // The constant, not the literal — `AppRoutes.reading` *is*
      // `/reading`, so asserting both was a byte-for-byte duplicate at
      // runtime. `app_routes_test.dart` is where the literal values are
      // pinned.
      expect(find.text(AppRoutes.reading), findsOneWidget);
    });

    testWidgets('body says it is a placeholder, not the real screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ReadingPage()));

      expect(find.text('Placeholder for /reading'), findsOneWidget);
    });
  });
}
