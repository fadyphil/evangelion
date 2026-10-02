import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The application's root widget.
///
/// A plain `MaterialApp`, not `MaterialApp.router`: Phase 4 owns the router, and
/// wiring a `routerConfig` to a stub would make this file look more finished
/// than it is.
///
/// [locale] exists for one reason — the localisation assertions in `app_test`
/// need to pin the app to a specific language, and `MaterialApp.locale` left
/// null resolves from the platform, which is whatever the test host happens to
/// report. Phase 5 also needs it for real: settings are local-only and include
/// an in-app language switch, so the app's locale has to be settable from Dart
/// rather than only from the OS.
class EvangelionApp extends StatelessWidget {
  const EvangelionApp({super.key, this.locale});

  /// Overrides the device locale. Null means "follow the platform", which is
  /// what a real install wants.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    // §13.2, mitigation 2: the three shared ambient controllers live in ONE
    // `TickerProviderStateMixin` host mounted above `MaterialApp` — here and, in
    // Phase 4, above `MaterialApp.router`. Two consequences worth stating:
    //
    //  * the ambient animation survives a route push, because the scope is above
    //    the `Navigator` rather than inside a page;
    //  * a screen never constructs a controller, so there is nothing for a page
    //    to forget to dispose.
    //
    // It is above `MaterialApp` deliberately, which also means there is no
    // `MediaQuery` to read from this far up — `animationsEnabled` is a parameter
    // rather than a lookup. Phase 5 wires it to the persisted `UserSettings`;
    // per-widget reduced-motion is honoured where the `MediaQuery` is, inside
    // `NeuralBackground` and `GoldFlecks`.
    return NeuralMotionScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Evangelion',

        // RTL-ready, not RTL-later. The reading sanctuary serves Arabic scripture
        // (Smith & Van Dyck) alongside English NKJV, and the Arabic arm has to lay
        // out right-to-left with Arabic date, time and number formats. Without
        // these delegates `MaterialApp` installs no localisations at all, so an
        // `ar` locale renders with English-only Material widgets and nothing
        // throws — the failure mode is a silently half-translated app. Phase 1
        // adds the bilingual string table on top of this; the plumbing is here so
        // it has something to plug into.
        //
        // `GlobalMaterialLocalizations.delegates` is the Cupertino + Material +
        // Widgets trio. `supportedLocales` lists only en and ar because those are
        // the only two languages this app ships (AGENT_CONTEXT §1) — adding a
        // third is a product decision, not a plumbing one.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        locale: locale,

        // The Eva design system (AGENT_CONTEXT §2, decision 6 — a dark
        // glassmorphic system, `docs/plans/03-design-system.md` §5).
        //
        // WHICH THEME GOES IN WHICH SLOT. `theme:` is what Material renders in
        // LIGHT mode and `darkTheme:` is what it renders in DARK mode; putting the
        // light palette in `theme` and the dark palette in `darkTheme` is the only
        // assignment under which both names mean what they say. The reversed
        // assignment would be defensible as "the Eva dark system is the default
        // appearance", but it would leave `darkTheme` holding a light theme, which
        // is a lie every future reader would have to re-derive.
        //
        // The dark-first *product* decision therefore lives in [themeMode] below,
        // where it belongs and where it is one line.
        theme: EvaThemeLight.theme,
        darkTheme: EvaThemeDark.theme,

        // Dark on launch, on every host, until Phase 5 replaces this with the
        // reader's persisted `AppThemeMode`. Not `ThemeMode.system`: this design is
        // dark by identity (§5.1 publishes the dark palette first and the whole
        // prototype is a dark canvas), and shipping "follow the OS" first would
        // mean the app opened light on every light-mode machine for no reason.
        //
        // Set here rather than left null, because `ThemeMode.system` on a
        // light-mode host would open the light theme — visible in the stub pages
        // that exist today and invisible once Phase 5 lands, which is the worst
        // time to discover it.
        themeMode: ThemeMode.dark,

        // NO `routerConfig` — see the class doc.
        home: const LoginPage(),
      ),
    );
  }
}
