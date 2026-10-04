/// `AppTopBar`'s avatar, in **both** of the states it has.
///
/// ## WHY A WIDGET UNIT TEST AND NOT MORE OF `home_page_test.dart`
///
/// `/` passes `onAvatarTap: null` and so can only ever render the **disabled**
/// avatar — decision 32 records that as visible product debt, with the fix being
/// "one argument at one call site". Which means every widget assertion on `/`
/// covers the inert branch and **none** covers the live one: `HomePage`'s coverage
/// of `app_top_bar.dart` stops at 81%, and the 9 uncovered lines are exactly the
/// `Semantics` + `EvaFocusRing` + `EvaInk` subtree the enabled avatar builds.
///
/// The next screen that passes a callback inherits that subtree untested, and
/// "it renders" is not the claim that matters about it — the claims are that it
/// **is tappable**, that it is **announced as a button**, and that it carries a
/// **focus ring**. All three are asserted here.
///
/// The disabled branch is asserted here too, in the failing direction, so this file
/// and not only `/`'s tree is the place that says what an inert avatar does.
library;

import 'dart:ui' show Tristate;

import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/home/presentation/widgets/app_top_bar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';

/// The reason suffix, and therefore the whole of the disabled avatar's name.
const String unavailable = 'profile is not available in this build';

/// The wordmark this file's fixture passes.
///
/// ## WHY IT IS NOT `'Evangelion'`, WHICH IS THE ENTIRE POINT OF THIS FILE
///
/// The fixture used to pass the prototype's own literal. The widget renders
/// `Text(wordmark)`, so a hard-coded `Text('Evangelion')` inside `AppTopBar` and
/// the honest `Text(wordmark)` were **the same rendered tree** — and the fixture
/// agreed with the hard-coding, so replacing the parameter's use with a literal
/// passed every test in this file and every test in the four `/` suites.
///
/// A sentinel the product cannot want is the only value that discriminates. It is
/// deliberately **not** a plausible product name, so nobody "tidies" it into
/// `Evangelion` later and silently re-opens the hole; and the assertion below is in
/// the failing direction, because a widget that rendered *both* would also satisfy
/// a `find.text('Evangelion')`.
const String wordmarkSentinel = 'ZZZ-SENTINEL';

/// A bar with [onAvatarTap] wired, or not.
Widget bar({required VoidCallback? onAvatarTap}) => AppTopBar(
  wordmark: wordmarkSentinel,
  streakDays: 4,
  streakSemanticLabel: '4 day streak',
  streakFailureMessage: null,
  onRetryStreak: () {},
  initials: 'DM',
  avatarSemanticLabel: 'David Mina',
  avatarUnavailableReason: unavailable,
  onAvatarTap: onAvatarTap,
);

void main() {
  group('the ENABLED avatar', () {
    testWidgets('a tap runs the callback exactly once', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpPrimitive(tester, bar(onAvatarTap: () => taps++));

      await tester.tap(find.byType(EvaInk));
      await tester.pump();

      expect(
        taps,
        1,
        reason:
            'a disabled-looking avatar that fires twice is worse than one '
            'that does not fire: the reader cannot tell which press registered',
      );
    });

    testWidgets('is announced as a button, by its name alone', (
      WidgetTester tester,
    ) async {
      // `Semantics` uses `excludeSemantics: true`, so the badge's own `Text('DM')`
      // is dropped and the label below is the *only* name. Without the assertion
      // the suite would pass if the name were `'DM'` — which is a monogram, not a
      // description.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrimitive(tester, bar(onAvatarTap: () {}));

      final List<SemanticsData> buttons = nodesOffering(
        tester,
        SemanticsAction.tap,
      ).where((SemanticsData d) => d.label == 'David Mina').toList();

      expect(buttons, hasLength(1));
      expect(buttons.single.label, isNot(contains(unavailable)));
      expect(find.byType(EvaFocusRing), findsOneWidget);
      handle.dispose();
    });

    testWidgets('and its focus ring is circular, at the badge radius', (
      WidgetTester tester,
    ) async {
      // `EvaFocusRing`'s default radius is a button's 14, which on a 32px badge
      // draws a squircle inside a circle. Asserting the *value* here is the claim;
      // reading `AppTopBar.avatarDiameter / 2` in the assertion would be the
      // tautology, so the number is written out.
      await pumpPrimitive(tester, bar(onAvatarTap: () {}));

      final EvaFocusRing ring = tester.widget<EvaFocusRing>(
        find.byType(EvaFocusRing),
      );

      expect(ring.radius, 16);
      expect(ring.radius, AppTopBar.avatarDiameter / 2);
      expect(ring.enabled, isTrue);
    });
  });

  group('the DISABLED avatar', () {
    testWidgets('offers no tap action at all', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrimitive(tester, bar(onAvatarTap: null));

      final Iterable<SemanticsData> avatar = nodesOffering(
        tester,
        SemanticsAction.tap,
      ).where((SemanticsData d) => d.label.contains('David Mina'));

      expect(
        avatar,
        isEmpty,
        reason:
            'an inert control must not be announced as pressable, or a '
            'screen-reader user is told about a press that does nothing',
      );
      expect(find.byType(EvaFocusRing), findsNothing);
      handle.dispose();
    });

    testWidgets('and its name says why, rather than only that it is inert', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPrimitive(tester, bar(onAvatarTap: null));

      final SemanticsData avatar = semanticsTree(tester)
          .firstWhere((SemanticsData d) => d.label.contains('David Mina'));

      expect(avatar.label, 'David Mina — $unavailable');
      // `SemanticsFlag` is deprecated in 3.47; `flagsCollection` is the
      // replacement and is tristate — `Tristate.isFalse`, not `false`, because a
      // node that never declared the flag is not the same claim as one that
      // declared it absent.
      expect(avatar.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('and the badge is dimmed, because inert is visible', (
      WidgetTester tester,
    ) async {
      // The prototype's avatar is full-strength. Dimming it is a **change**, and
      // `LoginPage`'s disabled social button is the precedent; without an assertion
      // it would be a silent one.
      await pumpPrimitive(tester, bar(onAvatarTap: null));

      final Iterable<Opacity> dimmed = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((Opacity o) => o.opacity < 1);

      expect(dimmed, hasLength(1));
      expect(dimmed.single.opacity, lessThan(1));
      expect(
        dimmed.single.opacity,
        0.45,
        reason:
            'a named constant would be nicer, but the value is what the '
            'prototype\'s disabled social button uses and a reader can check it '
            'in one place — the widget — instead of two',
      );
    });
  });

  group('the bar itself', () {
    testWidgets('renders the wordmark it was GIVEN, not one of its own', (
      WidgetTester tester,
    ) async {
      // The gate defect #11 did not have, and the only one it needed.
      //
      // `wordmark` is `required`, which guarantees the parameter **exists** at the
      // call site and guarantees nothing about whether `build` **reads** it — and
      // `AppTopBar` could render `Text('Evangelion')` while ignoring the argument
      // entirely, with all 1520 tests green. Requiredness is a compile-time
      // property; this is a render-time one, and only a render-time assertion can
      // see it.
      //
      // Asserting the *absence* of the prototype's literal is the second half and it
      // is what makes the first half discriminating: a widget that drew the
      // prototype's wordmark **and** the passed one satisfies `findsOneWidget` on
      // the sentinel alone.
      await pumpPrimitive(tester, bar(onAvatarTap: () {}));

      expect(find.text(wordmarkSentinel), findsOneWidget);
      expect(find.text('Evangelion'), findsNothing);
    });

    testWidgets('draws the streak it is given, and no other number', (
      WidgetTester tester,
    ) async {
      // The prototype hard-codes `12`; the whole point of the parameter is that the
      // number comes from `StreakSummary.currentStreak`. Asserting `'4'` and *not*
      // `'12'` in one expectation, because either alone is satisfied by a widget
      // that draws both.
      await pumpPrimitive(tester, bar(onAvatarTap: () {}));

      expect(find.text('4'), findsOneWidget);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('takes every value as a required parameter', (
      WidgetTester tester,
    ) async {
      // Not a compile-time assertion — it is one at the call site above. This is
      // the runtime half: a bar built with no streak at all must render, because
      // `streakDays` is nullable and `null` means "still loading", not "zero".
      await pumpPrimitive(
        tester,
        AppTopBar(
          wordmark: wordmarkSentinel,
          streakDays: null,
          streakSemanticLabel: 'Streak',
          streakFailureMessage: null,
          onRetryStreak: () {},
          initials: '',
          avatarSemanticLabel: 'Reader',
          avatarUnavailableReason: unavailable,
          onAvatarTap: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}
