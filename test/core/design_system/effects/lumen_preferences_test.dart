import 'package:evangelion/core/design_system/effects/lumen_preferences.dart';
import 'package:evangelion/core/domain/entities/curtain_shape.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The aurora's inputs — the ten light-workshop choices, and the scope that
/// publishes them.
void main() {
  group('the projection from `UserSettings`', () {
    test('every field is read, and none is invented', () {
      const UserSettings settings = UserSettings(
        shaderEnabled: false,
        curtainShape: CurtainShape.shafts,
        reach: 77,
        glow: 111,
        touchGlow: 22,
        hue: 199,
        multichromeMelt: true,
        rayCombing: false,
        whiteCores: false,
        dotVeil: true,
      );
      final LumenPreferences preferences = LumenPreferences.fromSettings(
        settings,
      );
      expect(preferences.enabled, isFalse);
      expect(preferences.shape, CurtainShape.shafts);
      expect(preferences.reach, 77);
      expect(preferences.glow, 111);
      expect(preferences.touchGlow, 22);
      expect(preferences.hue, 199);
      expect(preferences.melt, isTrue);
      expect(preferences.rayCombing, isFalse);
      expect(preferences.whiteCores, isFalse);
      expect(preferences.dotVeil, isTrue);
    });

    test('the defaults agree with `UserSettings`\'s, field by field', () {
      // The reader's stored preferences and the aurora's own defaults are two
      // statements about the same thing, and a drift between them would show
      // the aurora a colour the reader never chose. The defaults are the
      // prototype's control defaults (`eva/redesign.html:658-665`).
      const UserSettings settings = UserSettings();
      const LumenPreferences preferences = LumenPreferences();
      expect(preferences, LumenPreferences.fromSettings(settings));
    });

    test('and the defaults are the prototype\'s own', () {
      // `:658` reach 42, `:659` glow 100, `:660` touch 55, `:661` hue 312,
      // `:662` the melt off, `:663` the rays on, `:664` the white core on,
      // `:665` the dot veil off, and the shape is `top` (`:654-655`).
      const LumenPreferences preferences = LumenPreferences();
      expect(preferences.enabled, isTrue);
      expect(preferences.shape, CurtainShape.top);
      expect(preferences.reach, 42);
      expect(preferences.glow, 100);
      expect(preferences.touchGlow, 55);
      expect(preferences.hue, 312);
      expect(preferences.melt, isFalse);
      expect(preferences.rayCombing, isTrue);
      expect(preferences.whiteCores, isTrue);
      expect(preferences.dotVeil, isFalse);
    });
  });

  group('equality', () {
    test('all ten fields decide it', () {
      expect(const LumenPreferences(), const LumenPreferences());
      expect(const LumenPreferences(), isNot(const LumenPreferences(hue: 313)));
      expect(
        const LumenPreferences(),
        isNot(const LumenPreferences(enabled: false)),
      );
    });

    test('and it names every field', () {
      // Failure output: ten fields printed as `Instance of` would make a
      // failed `expect` useless.
      expect(
        const LumenPreferences().toString(),
        'LumenPreferences(enabled: true, shape: top, reach: 42, glow: 100, '
        'touchGlow: 55, hue: 312, melt: false, rayCombing: true, '
        'whiteCores: true, dotVeil: false)',
      );
    });

    test('the hash agrees with it', () {
      expect(
        const LumenPreferences().hashCode,
        const LumenPreferences().hashCode,
      );
    });
  });

  group('the scope', () {
    Widget harness(LumenPreferences preferences, Widget child) =>
        LumenPreferencesScope(preferences: preferences, child: child);

    testWidgets('it publishes the preferences', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const LumenPreferences(hue: 42),
          Builder(
            builder: (BuildContext context) {
              expect(LumenPreferencesScope.maybeOf(context)?.hue, 42);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('there is none above the scope', (WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            expect(LumenPreferencesScope.maybeOf(context), isNull);
            return const SizedBox.shrink();
          },
        ),
      );
    });

    testWidgets('a reader that changes a choice is told', (
      WidgetTester tester,
    ) async {
      int seen = 0;
      Widget child() => Builder(
        builder: (BuildContext context) {
          seen = LumenPreferencesScope.maybeOf(context)?.hue ?? -1;
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(harness(const LumenPreferences(), child()));
      expect(seen, 312);
      await tester.pumpWidget(
        harness(const LumenPreferences(hue: 42), child()),
      );
      expect(seen, 42);
    });

    test('and it is told ONLY when one of the ten changed', () {
      // The contract the framework calls, asserted directly — because
      // `pumpWidget` rebuilds the whole tree and so cannot distinguish "the
      // scope notified" from "everything was rebuilt anyway".
      //
      // This is the property that matters: the scope sits above every
      // screen, so a notification rebuilds all of them, and the reader
      // changing their **font size** must not.
      const LumenPreferences base = LumenPreferences();
      const LumenPreferencesScope scope = LumenPreferencesScope(
        preferences: base,
        child: SizedBox.shrink(),
      );

      LumenPreferencesScope scopeWith(LumenPreferences preferences) =>
          LumenPreferencesScope(
            preferences: preferences,
            child: const SizedBox.shrink(),
          );

      expect(
        scope.updateShouldNotify(scopeWith(base)),
        isFalse,
        reason: 'the same ten values are not a change',
      );
      expect(
        scope.updateShouldNotify(scopeWith(const LumenPreferences(hue: 42))),
        isTrue,
      );
      expect(
        scope.updateShouldNotify(
          scopeWith(const LumenPreferences(enabled: false)),
        ),
        isTrue,
      );
    });
  });
}
