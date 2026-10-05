import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The application's root widget.
///
/// `MaterialApp.router`, over the `AppRouter` resolved from the locator.
///
/// ## WHY IT IS A **`StatefulWidget`** NOW, AND WHAT THAT BUYS
///
/// It was a `StatelessWidget` because nothing above `MaterialApp` needed to change.
/// Phase 9 changed that: the palette, the locale and the text scale all come from the
/// reader's stored preferences, and `MaterialApp` is where each of them is installed.
///
/// **It is a `StatefulWidget` for exactly two things and neither is "hold the
/// settings."**
///
/// 1. **A [StreamSubscription].** `SettingsCubit` is the owner; this subscribes to its
///    stream so a change rebuilds the app. The alternative — a `BlocBuilder` around
///    the whole tree — is the same mechanism with an extra widget and no benefit, and
///    it would have put `flutter_bloc` in the composition root's own build for a
///    one-line subscription.
/// 2. **A cached [RouterConfig].** This is the load-bearing half, and it is the
///    finding that shaped the file. See the router paragraph below.
///
/// ## THE **`ROUTERCONFIG` MUST BE A STABLE IDENTITY** OR A THEME FLIP LOSES THE
/// ## NAVIGATION STACK
///
/// Measured against the framework, not reasoned about. `Router.withConfig`'s own body
/// is `Router(routeInformationProvider: config.routeInformationProvider,
/// routeInformationParser: config.routeInformationParser,
/// routerDelegate: config.routerDelegate, …)` — so `routerConfig` is **destructured
/// into fields**, and the widget that compares them on update is
/// `_RouterState.didUpdateWidget`
/// (`packages/flutter/lib/src/widgets/router.dart:732-758`), which does
/// `oldWidget.routerDelegate.removeListener(…)` whenever `widget.routerDelegate`
/// differs.
///
/// `AppRouter.config()` builds a **new** `RouterConfig` — and therefore a **new**
/// `RootStackRouter` — on every call. So `router.config(reevaluateListenable: …)`
/// written inline in `build` meant that any rebuild of `MaterialApp.router` handed
/// `Router` a different delegate, `Router` unsubscribed the live one, and the app
/// **rebuilt the whole navigation stack from the initial route**: a reader who
/// changed their theme on `/reading` was thrown back to `/`.
///
/// The alternative — an `InheritedWidget` above `MaterialApp` plus a `Theme`
/// override in `builder` — was rejected because `themeMode` is a `MaterialApp`
/// property and overriding `Theme` below it leaves `MediaQuery.platformBrightnessOf`
/// disagreeing with `Theme.of(context).brightness`, which is a quieter version of the
/// same bug.
///
/// **So the config is memoised on the router it came from**, and `settings_page_test`
/// asserts the stack survives a palette change in the failing direction. The
/// memoisation is on the *config*, not on the *router*: `AppRouter` is still resolved
/// out of the locator in `build`, which is what the class doc below is about.
///
/// ## WHERE `reevaluateListenable` ACTUALLY GOES
///
/// Not here: `MaterialApp.router` has no such parameter. It belongs on the
/// `RouterConfig`, which is what `AppRouter.config(reevaluateListenable:)` builds,
/// and `config()` is what gets handed to `MaterialApp.router` below. The plan
/// says "in `MaterialApp.router`"; the listenable reaches the delegate through
/// that config, which is the only route auto_route offers.
///
/// ## [locale] EXISTS FOR ONE REASON, AND IT IS NOW **NOT** THE ONLY WAY IN
///
/// It overrides the device locale for a test, and it still wins: `app_test.dart`'s
/// localisation group pins the app to a specific language, and
/// `MaterialApp.locale` left null resolves from the platform, which is whatever the
/// test host happens to report.
///
/// **A reader-facing language switch is now installed**, and the ordering matters
/// because this parameter and the stored preference can both be present. A test's
/// `locale` is a **test harness** speaking; a reader's stored language is the
/// **product**. So [locale] is consulted first and the stored preference second, and
/// `UserSettings.language` is nullable precisely so that a reader who has never
/// chosen keeps following the device — which is what this parameter used to do
/// unconditionally.
///
/// ## §13.2 MITIGATION 2 IS STILL SATISFIED, AND NOW THE SCOPE IS **NESTED** INSIDE
/// ## THE SETTINGS SCOPE RATHER THAN ABOVE IT
///
/// The three shared ambient controllers live in ONE `TickerProviderStateMixin` host
/// above `MaterialApp` — here and, in Phase 4, above `MaterialApp.router`. Two
/// consequences worth stating:
///
///  * the ambient animation survives a route push, because the scope is above the
///    `Navigator` rather than inside a page;
///  * a screen never constructs a controller, so there is nothing for a page to
///    forget to dispose.
///
/// It is above `MaterialApp` deliberately, which also means there is no `MediaQuery`
/// to read from this far up. So `animationsEnabled` is resolved from the **platform's**
/// own `accessibilityFeatures.disableAnimations` through
/// `WidgetsBinding.instance.platformDispatcher` — reachable from anywhere, including
/// above `MaterialApp`, and honoured again if the reader toggles it mid-session
/// (`NeuralMotionScope` registers a `WidgetsBindingObserver`).
///
/// **The persisted preference is combined with it, not substituted for it.** See
/// `UserSettings.reducedMotion`'s doc: this app's control is an *additional* off
/// switch, so a reader who has asked the OS for reduced motion gets it whatever
/// `/settings` says. The two signals are read through one named helper
/// ([_animationsEnabled]) so that the `WidgetsBindingObserver` in the scope and the
/// value passed here cannot be computed differently.
class EvangelionApp extends StatefulWidget {
  /// The application root.
  const EvangelionApp({super.key, this.locale});

  /// Overrides the device locale **and** the stored preference.
  ///
  /// Null means "the stored preference, or the platform if there is none", which is
  /// what a real install wants. See the class doc.
  final Locale? locale;

  @override
  State<EvangelionApp> createState() => _EvangelionAppState();
}

class _EvangelionAppState extends State<EvangelionApp> {
  /// The cubit this app reads its settings from, and the only writer of them.
  ///
  /// Resolved from the locator in `initState` rather than in `build`, for a measured
  /// reason: `configureNavigation()` registers it as a **singleton**, so the lookup
  /// returns the same object every time and there is nothing to gain by repeating it
  /// on every frame. `AppRouter` is still resolved in `build` — see the class doc's
  /// "why the router is resolved here and not built here" paragraph, which is
  /// unchanged and is about there being exactly **one** router.
  ///
  /// **Resolved from the locator rather than from [SettingsScope]**, because the scope
  /// is a *descendant* of this element — see [build] — and `app.dart` needs the value
  /// to build `MaterialApp`, which the scope is below. The identity assertion is
  /// `test/app/app_settings_wiring_test.dart`'s `identical` case.
  late final SettingsCubit _settings = getIt<SettingsCubit>();

  /// The handle the tree reads, and the notifier every descendant rebuilds from.
  ///
  /// ## THE **LOCATOR'S** INSTANCE, AND THE FIRST VERSION GOT THIS WRONG
  ///
  /// It built its own, over the same cubit. Nothing looked wrong — both handles call
  /// through to `SettingsCubit.state`, so every read agreed — and
  /// `app_settings_wiring_test.dart`'s `identical` assertion found it: there were
  /// **two** [SettingsHandle]s over one set of preferences, and the locator's was the
  /// one that would never fire.
  ///
  /// One object, registered once by `configureNavigation()`, is also what makes
  /// [SettingsScope]'s locator fallback equivalent to the scope instead of a second
  /// source of truth — which is the whole of that fallback's contract.
  late final SettingsHandle _handle = getIt<SettingsHandle>();

  /// Keeps [_handle] notifying when the cubit emits.
  StreamSubscription<SettingsState>? _subscription;

  /// The memoised router configuration. See the class doc's `RouterConfig` section
  /// for the measurement that makes this necessary rather than tidy.
  RouterConfig<UrlState>? _routerConfig;

  @override
  void initState() {
    super.initState();
    _subscription = _settings.stream.listen((SettingsState _) {
      if (!mounted) return;
      // **Two notifications and both are needed.** [SettingsScope] is an
      // `InheritedNotifier` over [_handle], so `notifyListeners()` is what rebuilds the
      // **descendants** — `/settings` and `/reading`, which read the setting through
      // the scope. `setState` is what rebuilds **this** element, and this element is
      // *above* the scope, so the inherited notification cannot reach it. `themeMode`,
      // `locale` and the step are all `MaterialApp` properties and nothing below it
      // can change them.
      _handle.announce();
      setState(() {});
    });
    // The one read, fired here rather than in `build`: `SharedPreferences` is async,
    // so the answer cannot be available for the first frame. `SettingsCubit`'s doc
    // says why the defaults are rendered in the meantime instead of a blank app.
    unawaited(_settings.load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _handle.dispose();
    super.dispose();
  }

  /// The router configuration, built once and reused.
  ///
  /// Resolved in `build`, not cached as the router — the lookup stays where the
  /// original design put it, and the memoisation is on the product of it.
  RouterConfig<UrlState> _configFor(AppRouter router) =>
      _routerConfig ??= router.config(reevaluateListenable: router.authChanges);

  /// Whether this app's own animations may run.
  ///
  /// **Two signals, both off-means-off, and no substitution.** The platform's
  /// reduce-motion setting and the reader's in-app preference are independent
  /// reasons to stop, so `true` requires both to agree. `NeuralMotionScope` resolves
  /// the platform half itself when it is given `null`; passing an explicit `false`
  /// here is what suppresses its observer, which is the documented behaviour
  /// (`didChangeAccessibilityFeatures` checks `widget.animationsEnabled == null`).
  static bool _animationsEnabled(bool readerPrefersStill) =>
      !readerPrefersStill &&
      !WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;

  @override
  Widget build(BuildContext context) {
    final AppRouter router = getIt<AppRouter>();
    final UserSettings settings = _handle.settings;

    // `theme:` is what Material renders in LIGHT mode and `darkTheme:` what it renders
    // in DARK; putting the light palette in `theme` and the dark palette in `darkTheme`
    // is the only assignment under which both names mean what they say.
    return NeuralMotionScope(
      animationsEnabled: _animationsEnabled(settings.reducedMotion),
      child: SettingsScope(
        key: const Key('eva-settings-scope'),
        handle: _handle,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Evangelion',

          // RTL-ready, not RTL-later. The reading sanctuary serves Arabic scripture
          // (Smith & Van Dyck) alongside English NKJV, and the Arabic arm has to lay
          // out right-to-left with Arabic date, time and number formats. Without
          // these delegates `MaterialApp` installs no localisations at all, so an
          // `ar` locale renders with English-only Material widgets and nothing
          // throws — the failure mode is a silently half-translated app.
          //
          // `AppLocalizations.localizationsDelegates` is `gen_l10n`'s own generated
          // list: this app's `AppLocalizations.delegate` FIRST, then the
          // `GlobalMaterialLocalizations.delegate` + Cupertino + Widgets trio it used
          // to be. Order matters only in that the app's own strings must resolve; the
          // trio is what supplies Arabic date, time and number formats to Material
          // widgets, so it stays.
          //
          // `supportedLocales` lists only en and ar because those are the only two
          // languages this app ships (AGENT_CONTEXT §1) — adding a third is a product
          // decision, not a plumbing one. It is written out rather than taken from
          // `AppLocalizations.supportedLocales` so the two-locale promise stays a
          // claim in the composition root, where `app_test.dart` can read it.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          // See the class doc: the test's override wins, then the reader's stored
          // choice, then **null** — and null is what follows the platform, which is
          // why `UserSettings.language` is nullable.
          locale:
              widget.locale ??
              (settings.language == null
                  ? null
                  : Locale(settings.language!.code)),

          // The Eva design system (AGENT_CONTEXT §2, decision 6 — a dark
          // glassmorphic system, `docs/plans/03-design-system.md` §5).
          theme: EvaThemeLight.theme,
          darkTheme: EvaThemeDark.theme,

          // ## THE ONE LINE THAT MAKES A PALETTE CHANGE **APP-WIDE**
          //
          // It was a hard-coded `ThemeMode.dark` for eight phases, with a measured
          // reason recorded in place — dark by identity, and "follow the OS" first
          // would open the app light on every light-mode machine for no reason. The
          // default it was protecting is now `UserSettings.themeMode`'s default, which
          // is `AppThemeMode.dark`, so **the behaviour of a fresh install is
          // unchanged** and the sentence is still true; what changed is that the
          // reader can now change it.
          //
          // **An exhaustive `switch` and not a map lookup**, so a fourth
          // `AppThemeMode` is a compile error *here* — at the composition root —
          // rather than a screen that keeps the previous palette. `app_theme_mode.dart`
          // says why the `ThemeMode` mapping is here and not beside the enum.
          themeMode: switch (settings.themeMode) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.system => ThemeMode.system,
          },

          // ## THE TEXT SCALE IS INSTALLED **HERE**, AND IT IS NOW **ONE INPUT**
          //
          // `eva_typography.dart` recorded for eight phases that this scaler was
          // "exported and tested but uninstalled, because its `step` argument belongs
          // to Phase 9's `settings_repository`". This is that line.
          //
          // `builder` is the only site that can install it, because it is the only
          // place **above every route** and **below `Localizations`** — which matters
          // for `Directionality`, since `ReadingPage`'s Arabic band and
          // `ReadingControls`' mirrored back button both read the ambient direction.
          //
          // **There is no composition here and there never will be again.** The
          // recorded dead zone — steps 3, 4 and 5 all rendering at 1.22× once the
          // platform was above 1.109 — was the price of multiplying the reader's step
          // by the platform's scaler and capping the product at §5.2's top row. With a
          // single persisted preference there is one input, one `MediaQuery` and one
          // scale, so the five positions are five distinct sizes on every device and
          // there is no threshold above which the control's top half goes inert.
          //
          // **What the reader's OS font-size setting now does here is nothing**, and
          // that is a deliberate reversal of `eva_typography.dart`'s recorded
          // rejection of "wrapping the platform's scaler in a way that ignores it".
          // Its reason was per-screen — "the one screen where reading is hardest is
          // the one screen that ignores their accessibility setting" — and **that
          /// reason dies when the control is app-wide**, because there is no second
          /// screen to disagree with. What survives is the trade itself: this app has
          /// one font-size control, it is reachable from `/settings` in the reader's
          /// own language, and it is the only one the app offers. §14's requirement
          /// (survive 1.22× without overflow at 320px) is what bounds the table, and
          /// it is satisfied by construction.
          builder: (BuildContext context, Widget? child) {
            final Widget body = child ?? const SizedBox.shrink();
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: evaScalerFor(settings.fontStep)),
              child: body,
            );
          },

          // The one place the router enters the widget tree. See the class doc for
          // why it is resolved from the locator and never constructed here, and for
          // why the configuration it produced is memoised.
          routerConfig: _configFor(router),
        ),
      ),
    );
  }
}
