import 'package:evangelion/app/app.dart';
import 'package:evangelion/core/design_system/barrel.dart';
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
/// ANCHORED ON THE `Navigator`, AND THAT IS LOAD-BEARING. It was anchored on
/// `LoginPage` until this revision, which made six localisation assertions
/// depend on `home:` staying `LoginPage`. Phase 4 replaces `home:` with the
/// router — the whole point of that phase — and the failure would not have been
/// `Expected: rtl / Actual: ltr`. It would have been
///
/// ```
/// Bad state: No element
///   #0 Iterable.single (dart:core/iterable.dart:694:25)
/// ```
///
/// from `tester.element`, i.e. six reports that read as localisation bugs and
/// are really about the router. The `Navigator` is the right anchor because it
/// exists for every page: `WidgetsApp` builds exactly one, it sits below the
/// `Localizations` it wraps, and it does not change when `home:` does.
///
/// `tester.element` on the `Navigator`, not on `MaterialApp` itself: an
/// `Element`'s context resolves ancestors, so asking the `MaterialApp` element
/// for `Localizations.of` would look *above* the app and find the test's own
/// (absent) localisations — which would pass for the wrong reason if the
/// delegates were missing.
///
/// `.first` rather than a single-element `element`, so that a future app which
/// nests navigators degrades to "somewhere below the localisations" instead of
/// throwing before the assertion runs. Every assertion below is about
/// localisations, not about how many navigators the app has.
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
    tester.element(find.byType(Navigator).first);

void main() {
  group('EvangelionApp builds', () {
    testWidgets('pumps the app and lands on the login stub', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
      // `home:` is asserted here, and ONLY here. This is the entry-point
      // contract: `/login` is the pre-auth entry point until Phase 5 gives login
      // a real session to route away from. It is deliberately not asserted by
      // the localisation tests below — anchoring those on `LoginPage` is what
      // made six of them fail in the *finder* the moment Phase 4 swaps `home:`
      // for the router. Asserted off the widget rather than the rendered tree so
      // a `LoginPage` rendered by some other route cannot satisfy it.
      expect(_materialAppIn(tester).home, isA<LoginPage>());
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
    // THE POINT OF THIS GROUP. Without `localizationsDelegates`, an `ar` locale
    // renders with English-only widgets — date and time pickers, tooltips, the
    // semantics of every `Semantics` label Material supplies. Nothing crashes in
    // a way anyone would notice; the app just quietly speaks the wrong language.
    //
    // What the framework does NOT do is save you. `MaterialApp._localizationsDelegates`
    // (material/app.dart:935) appends `DefaultMaterialLocalizations.delegate` and
    // `DefaultCupertinoLocalizations.delegate` *unconditionally*, and
    // `WidgetsApp` appends `DefaultWidgetsLocalizations.delegate`, whose
    // `isSupported` is `=> true` (widgets/localizations.dart:253). So a
    // `Localizations.of<WidgetsLocalizations>` under `ar` is non-null whether or
    // not the app wires the Widgets delegate. Assertions that read like "the
    // Arabic Widgets localisations are installed" and are answered by
    // `DefaultWidgetsLocalizations` are worse than no assertion, because they
    // are believed. Everything in this group is therefore either a declaration
    // check or a behavioural one, and each carries the negative control that
    // shows it can fail.
    testWidgets('declares all three Global localisations delegates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      // THE STRUCTURAL CLAIM, and for Widgets it is the *only* one that works.
      // Dropping `GlobalWidgetsLocalizations.delegate` from `app.dart` fails
      // this test and the RTL one, and nothing else in the file — there is no
      // non-null `WidgetsLocalizations` assertion here to fail, which is exactly
      // why this test has to carry the claim.
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
      // WHY `ar` AND NOT `en` IS THE WHOLE POINT OF THIS TEST. Under `en` the
      // assertion is unfalsifiable: `DefaultMaterialLocalizations.delegate` is
      // appended by `MaterialApp` regardless of what the app declares, and
      // `DefaultMaterialLocalizationsDelegate.isSupported` is
      // `locale.languageCode == 'en'` (material_localizations.dart:726). So
      // `MaterialLocalizations` is non-null under `en` with
      // `localizationsDelegates: const []`, and an "English resolves" test here
      // would pass while proving nothing. Under `ar` the same default delegate
      // declines the locale, the lookup goes null, and this test fails. Verified
      // by deleting `localizationsDelegates` from `app.dart`: four tests in this
      // group go red — this one, the declaration test above, and the two below.
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

    testWidgets('lays Arabic out right-to-left', (WidgetTester tester) async {
      // The behavioural payoff, and the reason for the delegate wiring above.
      //
      // THIS IS THE ONLY *BEHAVIOURAL* PROOF THAT THE WIDGETS DELEGATE IS WIRED.
      // The declaration test above proves it structurally — it reads the list the
      // app hands `MaterialApp` — and this one proves a working
      // `WidgetsLocalizations` actually came out of it. Both go red when
      // `GlobalWidgetsLocalizations.delegate` is dropped; neither survives on the
      // framework's unconditional `DefaultWidgetsLocalizations` fallback, because
      // that delegate's `isSupported` is `=> true`.
      //
      // `textDirection` is a member of `WidgetsLocalizations`, and
      // `DefaultWidgetsLocalizations.textDirection` is `ltr`, so the direction
      // can only come from `GlobalWidgetsLocalizations`. There was a second
      // test here — "resolves Widgets localisations under ar" — asserting
      // `Localizations.of<WidgetsLocalizations>` was non-null. It survived
      // `GlobalWidgetsLocalizations.delegate` being deleted entirely: the lookup
      // was answered by the fallback, so it read non-null while the app rendered
      // *English* Widgets localisations. Verified — dropping the Widgets delegate
      // fails exactly two tests in this file, that declaration test and this one,
      // and the deleted test was not among them.
      await tester.pumpWidget(const EvangelionApp(locale: Locale('ar')));

      expect(Directionality.of(_contextBelowApp(tester)), TextDirection.rtl);
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

  group('the theme is installed, and it is the Eva one', () {
    // THE TRIPWIRE, INVERTED. Until Phase 1 this group asserted `theme` and
    // `darkTheme` were both null — deliberately, so that no agent could satisfy
    // "wire up a theme" by quietly inventing a palette in `app.dart` before the
    // token tables existed. Phase 1 has landed, so the claim is now the opposite
    // one, and it is a STRICTER claim than the old one: not "some theme is
    // present" but "the theme is `EvaThemeLight.theme`, carrying an `EvaColors`
    // extension built from the documented palette".
    //
    // The negative controls are named in each test below, because a test that
    // cannot fail is worse than no test.

    testWidgets('hands MaterialApp a theme and a darkTheme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      expect(
        _materialAppIn(tester).theme,
        isNotNull,
        reason: 'the design system is installed; there is no stock Material',
      );
      expect(
        _materialAppIn(tester).darkTheme,
        isNotNull,
        reason: 'the light theme is not the whole system',
      );
    });

    testWidgets('they are the two Eva instance themes, by identity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());

      // `theme:` carries the light palette and `darkTheme:` the dark one, so
      // that neither slot name is a lie. `MaterialApp` compares both by identity,
      // so identity is also the only check that distinguishes "the real theme"
      // from "a theme that happens to look similar".
      expect(_materialAppIn(tester).theme, same(EvaThemeLight.theme));
      expect(_materialAppIn(tester).darkTheme, same(EvaThemeDark.theme));
    });

    testWidgets('the app opens dark regardless of the host platform', (
      WidgetTester tester,
    ) async {
      // Not `ThemeMode.system`. This design is dark by identity, and Phase 5
      // replaces this with the reader's persisted setting — so the assertion is
      // on the current decision, and it is the one a stub page renders against
      // today.
      await tester.pumpWidget(const EvangelionApp());

      expect(_materialAppIn(tester).themeMode, ThemeMode.dark);
    });

    testWidgets('the theme carries the EvaColors extension, dark and light', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());
      final MaterialApp app = _materialAppIn(tester);

      // Read off the `MaterialApp`'s own fields rather than off a pumped tree:
      // the point is that the *widget the app constructs* carries the extension,
      // and the next two tests prove it reaches a live `BuildContext`.
      expect(
        app.theme!.extension<EvaColors>()!.canvas,
        const EvaColors.light().canvas,
      );
      expect(
        app.darkTheme!.extension<EvaColors>()!.canvas,
        const EvaColors.dark().canvas,
      );
    });

    testWidgets(
      'the theme is built from Eva tokens, not from Material defaults',
      (WidgetTester tester) async {
        await tester.pumpWidget(const EvangelionApp());
        final ThemeData theme = _materialAppIn(tester).darkTheme!;
        final EvaColors colors = const EvaColors.dark();

        // Spot-checks across four different token families, because a theme can be
        // "partly" Eva — the failure mode where the accent was wired but the
        // surfaces were left stock is exactly what a single assertion misses.
        expect(theme.scaffoldBackgroundColor, colors.canvas, reason: 'canvas');
        expect(theme.colorScheme.primary, colors.ember, reason: 'ember');
        expect(theme.colorScheme.error, colors.err, reason: 'err');
        expect(theme.dividerColor, colors.line, reason: 'line');
        expect(
          theme.textTheme.displayLarge!.fontFamily,
          EvaTypography.displayFamily,
          reason: 'the display serif',
        );
        expect(
          theme.cardTheme.elevation,
          0.0,
          reason: 'a flat, hairline-separated system',
        );
      },
    );

    testWidgets('a page rendered by the app reads the Eva palette', (
      WidgetTester tester,
    ) async {
      // The end-to-end proof: the extension is not merely present on the
      // `ThemeData`, it is reachable through `Theme.of` from a widget that the
      // app itself mounted. Anchored on the `Navigator` for the same reason
      // `_contextBelowApp` is — see its doc comment.
      await tester.pumpWidget(const EvangelionApp());

      final EvaColors seen = _contextBelowApp(tester).colors;
      expect(seen.canvas, const EvaColors.dark().canvas);
      expect(seen.ink, const EvaColors.dark().ink);
      expect(seen.ember, const EvaColors.dark().ember);
      expect(seen.sticker.keys.toSet(), StickerSlot.values.toSet());
    });

    testWidgets('darkTheme is a genuinely different theme, not the same twice', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EvangelionApp());
      final MaterialApp app = _materialAppIn(tester);
      final ThemeData light = app.theme!;
      final ThemeData dark = app.darkTheme!;

      expect(identical(light, dark), isFalse, reason: 'same object twice');
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      // `ThemeData` has no value equality, so "different" has to be argued field
      // by field. Four of them, spanning a surface, an accent, a semantic and a
      // piece of geometry-adjacent ink.
      expect(
        light.scaffoldBackgroundColor,
        isNot(dark.scaffoldBackgroundColor),
      );
      expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
      expect(light.colorScheme.error, isNot(dark.colorScheme.error));
      expect(light.dividerColor, isNot(dark.dividerColor));
      expect(
        light.textTheme.bodyMedium!.color,
        isNot(dark.textTheme.bodyMedium!.color),
      );

      // …while the geometry, which the spec defines once, must be shared. A
      // difference here would mean one of the two is wrong.
      //
      // Compared as a RADIUS VALUE. `RoundedRectangleBorder` does not override
      // `==`, so `expect(light.cardTheme.shape, dark.cardTheme.shape)` is an
      // identity comparison that passes only because both shapes are `const` and
      // therefore canonicalised — the same const-canonicalisation trap the colour
      // assertions above avoid by going through values.
      expect(
        _topLeftRadiusOf(light.cardTheme.shape),
        _topLeftRadiusOf(dark.cardTheme.shape),
      );
      expect(_topLeftRadiusOf(light.cardTheme.shape), EvaRadii.card);
      expect(light.dialogTheme.elevation, dark.dialogTheme.elevation);
    });

    testWidgets('the localisation suite is unaffected by the theme', (
      WidgetTester tester,
    ) async {
      // The theme is new on this widget, and `MaterialApp` localises its
      // `TextTheme` through the same delegates the tests above exercise. A theme
      // with hard-coded English strings — or one whose `Localizations` scope
      // ends up below `MaterialApp` — would show up as an RTL regression rather
      // than as a theme bug, so the two are asserted together deliberately.
      await tester.pumpWidget(const EvangelionApp(locale: Locale('ar')));

      expect(Directionality.of(_contextBelowApp(tester)), TextDirection.rtl);
      expect(
        _contextBelowApp(tester).colors.canvas,
        const EvaColors.dark().canvas,
        reason: 'the theme does not disturb the direction or the palette',
      );
    });
  });
}

/// The corner radius of a themed container's shape, or `null` for a shape that
/// is not a rounded rectangle.
///
/// Reads `topLeft.x` rather than comparing `ShapeBorder`s: `RoundedRectangleBorder`
/// does not override `==`, so `expect(a.shape, b.shape)` is an identity check
/// that two `const` shapes pass on canonicalisation alone.
double? _topLeftRadiusOf(ShapeBorder? shape) {
  if (shape is! RoundedRectangleBorder) return null;
  final BorderRadiusGeometry radius = shape.borderRadius;
  if (radius is! BorderRadius) return null;
  return radius.topLeft.x;
}
