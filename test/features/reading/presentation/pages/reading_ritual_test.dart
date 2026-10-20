import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/reading/domain/breath_guide.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/breath_guide_line.dart';
import 'package:evangelion/features/reading/presentation/widgets/verse_line.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/design_system_harness.dart';
import '../../../../support/reading_harness.dart';
import '../../../../support/settings_harness.dart';

/// `/reading`'s ritual — the focus mode's idle dim, and the breath guide.
///
/// `eva/redesign.html:1287-1294` (focus mode), `:173-176` (the breath guide),
/// `:683` and `:685` (the two Workshop switches that drive them).
void main() {
  /// The aurora's scene, captured during a build.
  ///
  /// **A capture and not a lookup in the test body**, because
  /// `NeuralMotionScope.of` is a *dependent* lookup and Flutter refuses one
  /// outside a build.
  LumenScene? scene;

  /// Mounts the page over the reader's own preferences.
  ///
  /// **The settings are seeded into the real store** — `settingsHarness` — so
  /// a row that says "the reader chose a fifteen-second focus delay" is
  /// asserting against a persisted choice.
  ///
  /// **And the page is torn down at the end of every test**, because
  /// `/reading` arms an idle timer on entry and `flutter_test` fails a case
  /// with a pending timer.
  Future<void> pumpSanctuary(
    WidgetTester tester, {
    UserSettings? settings,
    bool disableAnimations = false,
  }) async {
    settingsHarness(initial: settings);
    final ReadingHarness harness = readingHarness();
    await tester.pumpWidget(
      evaPrimitiveHarness(
        theme: EvaThemeDark.theme,
        disableAnimations: disableAnimations,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        child: Builder(
          builder: (BuildContext context) {
            scene = NeuralMotionScope.of(context).lumenScene;
            return settingsScope(tester, ReadingPage(cubit: harness.cubit));
          },
        ),
      ),
    );
    // The passage's own load.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  /// The reader's first verse.
  ///
  /// **By type and not by its text**, because `VerseLine` paints the verse
  /// and the reading suites find it the same way.
  Finder firstVerse() => find.byType(VerseLine).first;

  /// The guide, if it is on the screen.
  Finder guide() => find.byType(BreathGuideLine);

  /// **The line itself**, and not the guide's box.
  ///
  /// The `Transform.scale` is **inside** the guide's padding, so the guide's
  /// own rect is the *untransformed* one and never changes. The painted line —
  /// the `DecoratedBox` — is inside the transform, and its rect is the one that
  /// breathes.
  Finder line() => find.descendant(
    of: find.byType(BreathGuideLine),
    matching: find.byType(DecoratedBox),
  );

  group('the focus mode', () {
    testWidgets('the delay is the reader\'s own choice', (
      WidgetTester tester,
    ) async {
      await pumpSanctuary(
        tester,
        settings: const UserSettings(focusDelaySec: 15),
      );

      // **Four seconds is the default, and this reader asked for fifteen.**
      await tester.pump(const Duration(seconds: 4));
      expect(scene!.focusDimmed, isFalse);

      await tester.pump(const Duration(seconds: 11));
      expect(scene!.focusDimmed, isTrue);
    });

    testWidgets('and the default is four seconds', (WidgetTester tester) async {
      await pumpSanctuary(tester);

      await tester.pump(const Duration(seconds: 3));
      expect(scene!.focusDimmed, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(scene!.focusDimmed, isTrue);
    });

    testWidgets('a press undims it', (WidgetTester tester) async {
      await pumpSanctuary(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(scene!.focusDimmed, isTrue);

      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      expect(scene!.focusDimmed, isFalse);
    });

    testWidgets('leaving the sanctuary gives the dim back', (
      WidgetTester tester,
    ) async {
      await pumpSanctuary(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(scene!.focusDimmed, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(scene!.focusDimmed, isFalse);
    });
  });

  group('the breath guide', () {
    testWidgets('it is not drawn until a verse is chosen', (
      WidgetTester tester,
    ) async {
      await pumpSanctuary(tester);
      expect(guide(), findsNothing);
    });

    testWidgets('choosing a verse draws it', (WidgetTester tester) async {
      await pumpSanctuary(tester);

      await tester.tap(firstVerse());
      await tester.pump();

      expect(guide(), findsOneWidget);
    });

    testWidgets('and the reader\'s own switch decides', (
      WidgetTester tester,
    ) async {
      await pumpSanctuary(
        tester,
        settings: const UserSettings(breathGuide: false),
      );

      await tester.tap(firstVerse());
      await tester.pump();

      expect(guide(), findsNothing);
    });

    testWidgets('it is drawn under the chosen verse', (
      WidgetTester tester,
    ) async {
      await pumpSanctuary(tester);

      await tester.tap(firstVerse());
      await tester.pump();

      // **Under** the verse and not over it — the prototype's `p.after(d)`
      // (`eva/redesign.html:1375`).
      final Rect verse = tester.getRect(firstVerse());
      final Rect painted = tester.getRect(line());
      expect(painted.top, greaterThanOrEqualTo(verse.bottom));
    });

    testWidgets('and it breathes', (WidgetTester tester) async {
      await pumpSanctuary(tester);
      await tester.tap(firstVerse());
      await tester.pump();

      final double first = tester.getRect(line()).width;

      await tester.pump(const Duration(milliseconds: 2000));
      final double second = tester.getRect(line()).width;

      // **The line's width changes** — and the prototype's own keyframes make
      // it widen over the first four seconds and narrow over the second four.
      expect(second, isNot(closeTo(first, 0.5)));
    });

    testWidgets('under reduced motion it is drawn at rest', (
      WidgetTester tester,
    ) async {
      await pumpSanctuary(tester, disableAnimations: true);
      await tester.tap(firstVerse());
      await tester.pump();

      // ## THE **END STATE**, NOT A FROZEN HALF
      //
      // §14 asks a reduced-motion reader for the end state, and the line's end
      // state is the state it is in when the animation is **not** running: CSS's
      // `animation-fill-mode` defaults to `none`, and `eva/redesign.html:173`
      // declares no `transform` and no `opacity` on `.breath` — so the line at
      // rest is `scaleX(1)` at `opacity: 1`.
      //
      // **And the opacity is the whole of the assertion**, because it is the
      // value a reader can see: a frozen half would be the 50% peak at
      // `opacity:.6`, and the end state is fully opaque.
      final Opacity opacity = tester.widget(
        find.descendant(of: guide(), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 1.0);

      // **And the line is at its full width** — `kBreathRest`'s scale of 1.
      final double rest = tester.getRect(line()).width;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getRect(line()).width, closeTo(rest, 0.5));
    });

    test('and the rest state is the prototype\'s own', () {
      expect(kBreathRest.scale, 1.0);
      expect(kBreathRest.opacity, 1.0);
    });
  });
}
