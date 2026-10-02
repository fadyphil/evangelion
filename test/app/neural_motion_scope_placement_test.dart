import 'package:evangelion/app/app.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// §13.2's placement requirement, asserted at the composition root.
///
/// The three shared controllers must be hosted **above** `MaterialApp` — and, in
/// Phase 4, above `MaterialApp.router`. If the scope were inside a page, a route
/// push would tear the `TickerProviderStateMixin` down and restart the ambient
/// animation from zero, and every screen would have to remember to host its own.
///
/// A test in the effects directory cannot see that decision, which is why this
/// file exists and lives under `test/app/`.
void main() {
  testWidgets('EvangelionApp hosts the motion scope above MaterialApp', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EvangelionApp());
    await tester.pump();

    expect(find.byType(NeuralMotionScope), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('the scope is an ancestor of the MaterialApp, not a descendant', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EvangelionApp());
    await tester.pump();

    // `find.ancestor` is the whole assertion: a scope nested inside the app would
    // be a descendant and this finds nothing.
    expect(
      find.ancestor(
        of: find.byType(MaterialApp),
        matching: find.byType(NeuralMotionScope),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(MaterialApp),
        matching: find.byType(NeuralMotionScope),
      ),
      findsNothing,
    );
  });

  testWidgets('a descendant can actually read the bundle', (
    WidgetTester tester,
  ) async {
    // The inverse check: `of()` asserts rather than returning null, so "the scope
    // is above" and "the scope is reachable" are different claims.
    late EvaNeuralMotion seen;
    await tester.pumpWidget(
      NeuralMotionScope(
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              seen = NeuralMotionScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(seen, isA<EvaNeuralMotion>());
  });

  testWidgets('unmounting the app disposes the bundle', (
    WidgetTester tester,
  ) async {
    // The flip side of hosting it at the root: tearing the app down tears the
    // controllers down, and `TickerProviderStateMixin` throws if they were not.
    await tester.pumpWidget(const EvangelionApp());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
