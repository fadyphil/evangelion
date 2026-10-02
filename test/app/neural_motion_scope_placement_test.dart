import 'package:evangelion/app/app.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
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
    //
    // Through `EvangelionApp`, not through a hand-built `NeuralMotionScope` +
    // `MaterialApp`. The previous version built its own pair, which is a
    // duplicate of `neural_motion_test.dart`'s `pumpScope` and **cannot fail on
    // an app regression**: if `lib/app/app.dart` stopped hosting the scope, or
    // hosted it somewhere the pages could not reach, this test still passed
    // because it never used the app.
    //
    // What it does now: pump the real app, then read the bundle from a real
    // descendant of the real scope — the page `MaterialApp` actually puts on
    // screen. If the composition root regressed, there is no bundle here to read
    // and `NeuralMotionScope.of` asserts.
    await tester.pumpWidget(const EvangelionApp());
    await tester.pump();

    final Finder loginPage = find.byType(LoginPage);
    expect(loginPage, findsOneWidget, reason: 'the app root builds LoginPage');
    expect(
      find.ancestor(of: loginPage, matching: find.byType(NeuralMotionScope)),
      findsOneWidget,
      reason:
          'the page is inside the scope, which is the reachability this claims',
    );
    expect(
      NeuralMotionScope.of(tester.element(loginPage)),
      isA<EvaNeuralMotion>(),
    );
  });

  testWidgets('and it is the one bundle, shared by every descendant', (
    WidgetTester tester,
  ) async {
    // `§13.2 mitigation 2` is "one set of three controllers, app-wide". Read from
    // two *different* elements in the tree and compare identity — a page that
    // constructed its own would produce a second bundle, and `identical` across
    // two independent reads is the only thing that can tell them apart.
    //
    // Comparing one read against itself would be vacuous, which is the mistake
    // this file made before: it rebuilt its own scope instead of reading the
    // app's, so it could not fail on an app regression at all.
    await tester.pumpWidget(const EvangelionApp());
    await tester.pump();

    final EvaNeuralMotion fromApp = NeuralMotionScope.of(
      tester.element(find.byType(MaterialApp)),
    );
    final EvaNeuralMotion fromPage = NeuralMotionScope.of(
      tester.element(find.byType(LoginPage)),
    );
    expect(identical(fromApp, fromPage), isTrue);
    expect(
      fromApp.float.duration,
      kFloatPeriod,
      reason: 'and it is the ambient float clock, not something else',
    );
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
