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
    return MaterialApp(
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

      // NO theme. Phase 1 owns the dark glassmorphic design system, and
      // inventing a `ColorScheme` here would freeze an arbitrary palette into
      // the one file every screen and every golden test descends from. Stock
      // Material for now; the replacement is a one-line change here.
      //
      // And no `routerConfig` — see the class doc.
      home: const LoginPage(),
    );
  }
}
