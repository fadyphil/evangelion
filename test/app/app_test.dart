import 'package:evangelion/app/app.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The [MaterialApp] this test is inspecting, read off the pumped tree.
///
/// Read through the tree rather than off the `EvangelionApp` instance so these
/// assertions describe what the framework actually received, after any
/// defaulting `MaterialApp` applied.
MaterialApp _materialAppIn(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

/// A [BuildContext] strictly *below* the `MaterialApp`'s localisations.
///
/// `tester.element` on the home widget, not on `MaterialApp` itself: an
/// `Element`'s context resolves ancestors, so asking the `MaterialApp` element
/// for `Localizations.of` would look *above* the app and find the test's own
/// (absent) localisations — which would pass for the wrong reason if the
/// delegates were missing.
///
/// The lookup type is the abstract `MaterialLocalizations`, not
/// `GlobalMaterialLocalizations`. `Localizations` indexes its cache by the
/// delegate's `T`, and `GlobalMaterialLocalizations.delegate` is declared as a
/// `LocalizationsDelegate<MaterialLocalizations>` — the `Global…` name is the
/// concrete implementation, not the key. Asking for it returns null with the
/// delegates correctly wired, which is the worst possible failure for this kind
/// of assertion: it looks like missing localisations and sends you hunting for
/// a bug that is not there.
BuildContext _contextBelowApp(WidgetTester tester) =>
    tester.element(find.byType(LoginPage));

void main() {
  group('EvangelionApp builds', () {
    testWidgets('pumps the app and lands on the login stub', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      expect(find.byType(MaterialApp), findsOneWidget);
      // `/login` is the pre-auth entry point, so it is `home:` until Phase 5
      // gives login a real session to route away from.
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('is titled Evangelion and hides the debug banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      final MaterialApp app = _materialAppIn(tester);
      expect(app.title, 'Evangelion');
      expect(
        app.debugShowCheckedModeBanner,
        isFalse,
        reason: 'the red DEBUG ribbon has no place in a shipped app',
      );
    });

    testWidgets('runs without exceptions', (WidgetTester tester) async {
      await tester.pumpWidget(const EvangelionApp());

      expect(tester.takeException(), isNull);
    });
  });

  group('localisations are wired, for both languages', () {
    // THE POINT OF THIS GROUP. Without `localizationsDelegates`, `MaterialApp`
    // installs no localisations at all, and an `ar` locale then renders with
    // English-only widgets — date and time pickers, tooltips, the semantics of
    // every `Semantics` label Material supplies. Nothing crashes; the app just
    // quietly speaks the wrong language. It also fails *silently at build time*:
    // `Locale('ar')` is a perfectly valid argument to an app with no delegates,
    // so the missing wiring is invisible until someone reads Arabic on screen.
    testWidgets('declares all three Global localisations delegates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      expect(
        _materialAppIn(tester).localizationsDelegates,
        containsAll(<LocalizationsDelegate<Object?>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ]),
        reason:
            'GlobalMaterialLocalizations.delegates bundles all three; '
            'declaring only one leaves the others resolving to English',
      );
    });

    testWidgets('supports en and ar', (WidgetTester tester) async {
      await tester.pumpWidget(const EvangelionApp());

      expect(
        _materialAppIn(tester).supportedLocales,
        containsAll(const <Locale>[Locale('en'), Locale('ar')]),
      );
    });

    testWidgets('resolves Material localisations under ar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp(locale: Locale('ar')));

      expect(
        Localizations.of<MaterialLocalizations>(
          _contextBelowApp(tester),
          MaterialLocalizations,
        ),
        isNotNull,
        reason: 'ar must reach a real Arabic Material localisation',
      );
    });

    testWidgets('resolves Material localisations under en', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp(locale: Locale('en')));

      expect(
        Localizations.of<MaterialLocalizations>(
          _contextBelowApp(tester),
          MaterialLocalizations,
        ),
        isNotNull,
      );
    });

    testWidgets('resolves Widgets localisations under ar, not just Material', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp(locale: Locale('ar')));

      expect(
        Localizations.of<WidgetsLocalizations>(
          _contextBelowApp(tester),
          WidgetsLocalizations,
        ),
        isNotNull,
      );
    });

    testWidgets('lays Arabic out right-to-left', (WidgetTester tester) async {
      // The behavioural payoff, and the reason for the delegate wiring above.
      // `GlobalWidgetsLocalizations` is what carries `textDirection`, so this
      // assertion fails if the delegates are removed even though nothing throws.
      await tester.pumpWidget(const EvangelionApp(locale: Locale('ar')));

      expect(Directionality.of(_contextBelowApp(tester)), TextDirection.rtl);
    });

    testWidgets('leaves English left-to-right', (WidgetTester tester) async {
      await tester.pumpWidget(const EvangelionApp(locale: Locale('en')));

      expect(Directionality.of(_contextBelowApp(tester)), TextDirection.ltr);
    });

    testWidgets('the Material strings themselves are Arabic, not English', (
      WidgetTester tester,
    ) async {
      // Not a tautology with the RTL assertion above. `textDirection == rtl` only
      // proves *something* was right about direction; this proves the Material
      // delegate that supplies every built-in tooltip, button label and semantic
      // string was found and asked for Arabic. A delegate list carrying the
      // Widgets entry but not the Material one passes RTL and fails here — which
      // is precisely the half-wired state this file exists to catch.
      //
      // Asserted as "differs from English" rather than as a literal Arabic
      // string: pinning `intl`'s exact Arabic wording would make this test
      // hostage to a translation change in a transitive dependency.
      await tester.pumpWidget(const EvangelionApp(locale: Locale('ar')));
      final MaterialLocalizations arabic =
          Localizations.of<MaterialLocalizations>(
            _contextBelowApp(tester),
            MaterialLocalizations,
          )!;

      await tester.pumpWidget(const EvangelionApp(locale: Locale('en')));
      final MaterialLocalizations english =
          Localizations.of<MaterialLocalizations>(
            _contextBelowApp(tester),
            MaterialLocalizations,
          )!;

      expect(arabic.backButtonTooltip, isNotEmpty);
      expect(arabic.backButtonTooltip, isNot(english.backButtonTooltip));
      expect(arabic.openAppDrawerTooltip, isNot(english.openAppDrawerTooltip));
    });
  });

  group('the theme belongs to Phase 1, not to this phase', () {
    testWidgets('supplies neither a light nor a dark theme', (
      WidgetTester tester,
    ) async {
      // The project's actual property: `EvangelionApp` hands MaterialApp no
      // theme at all, so the framework default applies and Phase 1 has a clean
      // single place to install the real dark glassmorphic system.
      //
      // Deliberately NOT asserted: any specific colour, and `useMaterial3`.
      // Pinning a colour here would freeze whatever accidental default this
      // happened to produce and make Phase 1's real theme look like a
      // regression; asserting `useMaterial3` would be testing the Flutter SDK,
      // which is not this suite's subject. A golden test belongs in Phase 1,
      // with the theme it is meant to protect.
      await tester.pumpWidget(const EvangelionApp());

      expect(
        _materialAppIn(tester).theme,
        isNull,
        reason: 'Phase 1 owns the theme; do not invent one here',
      );
      expect(
        _materialAppIn(tester).darkTheme,
        isNull,
        reason: 'the dark system is the same Phase 1 deliverable',
      );
    });
  });
}
