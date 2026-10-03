import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The application's root widget.
///
/// `MaterialApp.router`, over the `AppRouter` resolved from the locator.
///
/// ## WHY THE ROUTER IS RESOLVED HERE AND NOT BUILT HERE
///
/// `06-navigation.md` §8: the router takes the session by constructor, so a
/// second instance built as a field or in `build` would sit alongside the
/// injected one holding a stale answer — two routers, two `navigatorKey`s, and
/// nothing to say which one the user is looking at. So `build` asks the locator.
/// There is no constructor parameter to pass a different one, deliberately: an
/// override is a way for a second router to exist, which is the exact hazard the
/// plan names.
///
/// Resolving inside `build` rather than caching it in a field keeps the lookup
/// lazy, and keeps this a `StatelessWidget`: a field would resolve during
/// construction, which is earlier than anything in the tree exists.
///
/// ## WHERE `reevaluateListenable` ACTUALLY GOES
///
/// Not here: `MaterialApp.router` has no such parameter. It belongs on the
/// `RouterConfig`, which is what `AppRouter.config(reevaluateListenable:)` builds,
/// and `config()` is what gets handed to `MaterialApp.router` below. The plan
/// says "in `MaterialApp.router`"; the listenable reaches the delegate through
/// that config, which is the only route auto_route offers.
///
/// [locale] exists for one reason — the localisation assertions in `app_test`
/// need to pin the app to a specific language, and `MaterialApp.locale` left
/// null resolves from the platform, which is whatever the test host happens to
/// report. A reader-facing language switch is also the reason it will eventually
/// have to be settable from Dart: settings are local-only and include an in-app
/// language switch, so the app's locale cannot stay readable only from the OS.
///
/// Phase 5 did **not** deliver that switch — it delivered `core/network` and the
/// `auth` feature, and the settings repository is a later phase. This comment
/// previously said "Phase 5 also needs it for real", which named the wrong phase
/// and, once Phase 5 closed, would have read as a claim that the switch shipped.
/// It did not.
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
    // `MediaQuery` to read from this far up. So `animationsEnabled` is left at
    // its default, which resolves the **platform's** own
    // `accessibilityFeatures.disableAnimations` through
    // `WidgetsBinding.instance.platformDispatcher` — reachable from anywhere,
    // including above `MaterialApp`, and honoured again if the reader toggles it
    // mid-session (`NeuralMotionScope` registers a `WidgetsBindingObserver`).
    //
    // A later phase replaces that default with the persisted `UserSettings`
    // value, and per-widget reduced motion is honoured where the `MediaQuery`
    // is, inside `NeuralBackground` and `GoldFlecks`. Phase 5 closed without
    // touching it: that phase was `core/network` plus the `auth` feature, so
    // there is no `UserSettings` to read yet and the platform default stands.
    final AppRouter router = getIt<AppRouter>();

    return NeuralMotionScope(
      child: MaterialApp.router(
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

        // Dark on launch, on every host, until a later phase replaces this with the
        // reader's persisted `AppThemeMode`. Not `ThemeMode.system`: this design is
        // dark by identity (§5.1 publishes the dark palette first and the whole
        // prototype is a dark canvas), and shipping "follow the OS" first would
        // mean the app opened light on every light-mode machine for no reason.
        //
        // Set here rather than left null, because `ThemeMode.system` on a
        // light-mode host would open the light theme — visible in the stub pages
        // that exist today and invisible once a settings phase lands, which is
        // the worst time to discover it.
        themeMode: ThemeMode.dark,

        // The one place the router enters the widget tree. See the class doc
        // for why it is resolved from the locator and never constructed here.
        //
        // `router` above is the ONE lookup, and that it is one is the point:
        // `navigation_injection.dart` warns that this registration must stay a
        // `lazySingleton` because a factory would hand back a second router with
        // its own `navigatorKey` and no `Navigator` behind it. Reading the locator
        // twice made the code depend on that lifetime silently; reading it once
        // makes the dependency visible in the shape of the statement instead.
        routerConfig: router.config(reevaluateListenable: router.authChanges),
      ),
    );
  }
}
