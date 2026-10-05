import 'dart:async';

import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/settings_repository.dart';
import 'package:evangelion/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:evangelion/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_state.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'design_system_harness.dart' show evaPrimitiveHarness, kAmbientSurface;

/// The shared fixture for every `/settings` and settings-affected widget test.
///
/// ## IT IS BUILT OVER A **REAL** `shared_preferences`, AND THAT IS THE POINT
///
/// `SharedPreferences.setMockInitialValues` installs an
/// `InMemorySharedPreferencesStore` behind the platform interface, so `getInstance()`
/// is a real read and `setString` is a real write — the round trip goes through the
/// package's own key prefixing (`flutter.eva.font_step`), its own cache and its own
/// `completer` memoisation.
///
/// The alternative — a hand-written `SettingsRepository` that returns whatever it was
/// handed — is what `settings_repository_test.dart`'s mutation replaces, and the whole
/// point of the plan's round-trip requirement is defeated by it: a double that returns
/// what it was given passes a round trip whether or not anything was persisted. The
/// store is real here so that "the value came back from a fresh `read()`" is a claim
/// about `shared_preferences`.
///
/// ## WHY IT IS BUILT **IN THE TEST BODY**
///
/// `login_harness.dart` records the measurement and `reading_harness.dart` repeats
/// it: a bloc built in `setUp` runs its events outside the fake-async zone
/// `tester.pump()` drains, so `find.text(…)` returns zero widgets. Every suite here
/// therefore calls [settingsHarness] inside the test body, with the teardown
/// registered by that function.
final class SettingsHarness {
  /// Builds the fixture over an **empty** store seeded with [initial].
  const SettingsHarness({
    required this.cubit,
    required this.handle,
    required this.store,
    required this.repository,
  });

  /// The app-wide settings cubit. Close it with `addTearDown`.
  final SettingsCubit cubit;

  /// What a widget reads and writes.
  final SettingsHandle handle;

  /// The store, for a test that wants to read the raw keys.
  final SettingsLocalDataSource store;

  /// The port the cubit goes through, for a test that wants to fail a write.
  final SettingsRepositoryImpl repository;

  /// The settings the cubit is holding right now.
  UserSettings get settings => cubit.state.settings;
}

/// Builds a [SettingsHarness] over a fresh, empty `shared_preferences`.
///
/// [initial] is what the **store** starts holding, so a test that wants "the reader
/// chose `light`" seeds it here rather than driving the cubit — which is the
/// difference between "the store holds it" and "the cubit holds it", and only the
/// first survives a restart.
///
/// `addTearDown`s the cubit, the locator entries, and a reset of the mock values, so
/// one test's store cannot be the next test's.
SettingsHarness settingsHarness({
  UserSettings? initial,
  bool loadImmediately = true,
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (initial != null) ...<String, Object>{
      kThemeModeKey: initial.themeMode.storedValue,
      kFontStepKey: initial.fontStep,
      kReducedMotionKey: initial.reducedMotion,
      if (initial.language != null) kLanguageKey: initial.language!.code,
    },
  });

  // A fresh data source per harness. `setMockInitialValues` nullifies the package's
  // singleton completer, but **this** object memoises its own reference to the store,
  // so a second harness in the same test binary would otherwise keep reading the
  // first one's values — and a round-trip test would pass against a store it had
  // already written. `SettingsLocalDataSource.resetForTest` exists for exactly that.
  final SettingsLocalDataSource store = SettingsLocalDataSource();
  final SettingsRepositoryImpl repository = SettingsRepositoryImpl(store);
  final SettingsCubit cubit = SettingsCubit(
    getSettings: GetSettings(repository),
    updateSettings: UpdateSettings(repository),
  );
  final SettingsHandle handle = SettingsHandle(
    read: () => cubit.state.settings,
    write: cubit.apply,
  );

  // ## THE SUBSCRIPTION BELOW IS **NOT** TEST PLUMBING — IT IS `app.dart`'s LINE
  //
  // `EvangelionApp` subscribes to the cubit and calls `SettingsHandle.announce()` on
  // every emission, which is what makes `SettingsScope` (an `InheritedNotifier`) rebuild
  // and the app-wide `EvaTypeScale` re-install at the new step. A harness that registered
  // the scope and stopped there reproduced every other part of the composition and not
  // this one, so `/reading`'s stepper wrote a setting that nothing re-read: the knob
  // moved, the rendered size did not, and `reading_text_scale_test.dart` failed with
  // `Expected: <23.18> Actual: <19.0>` — a test reporting a missing rebuild, correctly.
  //
  // So the fixture installs the same subscription production installs. Anything else
  // here would be a second, quieter composition.
  final StreamSubscription<SettingsState> subscription = cubit.stream.listen(
    (SettingsState _) => handle.announce(),
  );
  addTearDown(subscription.cancel);

  addTearDown(cubit.close);
  addTearDown(handle.dispose);
  // **Both** registrations, and the cubit is the one that was missing.
  //
  // `settings_harness.dart` registered only the handle, so every screen that resolves a
  // `SettingsCubit` from the locator — `SettingsPage.build`, and `EvangelionApp.initState`
  // — threw `StateError: SettingsCubit is not registered` in the two suites that build a
  // graph by hand (`navigation_injection_test.dart`) or through `routerHost`
  // (`auth_guard_test.dart`'s `/settings` arm). The failure names a *widget*, which is
  // what made it read as "the app cannot start" rather than "this fixture is half a
  // fixture".
  //
  // Unregistered first, in the same breath, because a suite that already configured the
  // production graph (`pumpApp` → `configureNavigation`) must keep **its** instances: this
  // runs only where a registration is missing, and a duplicate `registerSingleton` throws
  // on the second rather than replacing the first.
  if (getIt.isRegistered<SettingsCubit>()) {
    getIt.unregister<SettingsCubit>();
  }
  if (getIt.isRegistered<SettingsHandle>()) {
    getIt.unregister<SettingsHandle>();
  }
  getIt
    ..registerSingleton<SettingsCubit>(cubit)
    ..registerSingleton<SettingsHandle>(handle);
  addTearDown(() {
    if (getIt.isRegistered<SettingsCubit>()) {
      getIt.unregister<SettingsCubit>();
    }
    if (getIt.isRegistered<SettingsHandle>()) {
      getIt.unregister<SettingsHandle>();
    }
  });

  if (loadImmediately) {
    // Synchronously impossible — `load()` is async — so the caller's first
    // `pump()` is what lets it resolve. Suites that need the value present assert it
    // after a pump rather than reading `cubit.state` immediately.
    unawaited(cubit.load());
  }

  return SettingsHarness(
    cubit: cubit,
    handle: handle,
    store: store,
    repository: repository,
  );
}

/// Wraps [child] in the app's settings scope.
///
/// [SettingsScope.of] falls back to the locator when no scope is above the context,
/// which is what lets a bare-pumped page work — and that fallback is **not watched**,
/// so a page pumped bare would not rebuild when a setting changes. Every widget test
/// in this repository that exercises a settings-driven rebuild therefore wraps
/// explicitly, and this function is the one place that spelling lives.
Widget settingsScope(WidgetTester tester, Widget child) => SettingsScope(
  key: const Key('test-settings-scope'),
  handle: settingsHandleOf(tester),
  // ## THE `EvaTypeScale` INSTALL BELOW IS **THE POINT**, NOT A CONVENIENCE
  //
  // `app.dart` installs the reader's font step in `MaterialApp.builder`, above every
  // route, and `/reading` reads its own step back out of the installed `MediaQuery`
  // (`fontStepFromScaler`). So a harness that installs only the *scope* — and not the
  // type scale — pumps a page that does not exist in this app: the stepper writes the
  // setting, the handle announces, and the page keeps rendering the platform's own
  // scaler forever.
  //
  // That is not hypothetical. Six assertions in `reading_text_scale_test.dart` failed on
  // exactly it — `Expected: <1.0> Actual: <1.5>` for "the platform scale is not an input
  // any more", and `Expected: <1> Actual: <4>` for the knob/rendered-size agreement — and
  // every one of them was **right**, which is the part worth recording: the tests had
  // been written against a composition the harness did not build.
  //
  // `Builder` rather than reading `handle.fontStep` here, because `SettingsScope` is an
  // `InheritedNotifier`: a widget that *depends on it* rebuilds when `announce()`
  // notifies, and this one does. Reading the value out of the closure above would hand
  // every widget test a permanently stale step.
  child: Builder(
    builder: (BuildContext context) => EvaTypeScale(
      step: SettingsScope.of(context).read().fontStep,
      child: child,
    ),
  ),
);

/// The registered [SettingsHandle], building one if the test has not.
///
/// [settingsHarness] registers it. A test that never calls [settingsHarness] and only
/// reads — `/reading`'s own suites, which want the **defaults** — gets one here so
/// that `SettingsScope.of` has something to find rather than throwing out of `build`.
SettingsHandle settingsHandleOf(WidgetTester tester) {
  if (!getIt.isRegistered<SettingsHandle>()) {
    return settingsHarness().handle;
  }
  return getIt<SettingsHandle>();
}

/// Drops every settings registration, for a suite that resets the locator itself.
///
/// [resetServiceLocator] already empties it; this exists so a reader can see which
/// two types the settings feature puts in there.
void unregisterSettings() {
  if (getIt.isRegistered<SettingsCubit>()) getIt.unregister<SettingsCubit>();
  if (getIt.isRegistered<SettingsHandle>()) getIt.unregister<SettingsHandle>();
}

/// A [SettingsRepository] whose every call fails with [failure].
///
/// **Public here rather than duplicated per suite**, because `/settings` has three
/// of them after Phase 10 — the cubit's own, `settings_page_test.dart`'s and the
/// accessibility suite's — and `settings_cubit_test.dart` already keeps a private
/// copy with the same body. Two copies of a fake that decides whether a screen
/// reports a failure is one of the two things that can silently disagree about
/// whether this repository can fail at all.
///
/// The alternative is making `/settings`'s failure reachable through the **real**
/// repository, by pointing `SettingsRepositoryImpl` at a store that throws. That is
/// the better measurement and it is a different test: this fake is what drives a
/// *screen*, where the question is "does the notice appear", and
/// `settings_local_data_source_test.dart` already owns "does the real one throw".
final class FailingSettingsRepository implements SettingsRepository {
  /// Every `load()` and `save()` answers [failure].
  const FailingSettingsRepository(this.failure);

  /// The typed failure both methods return.
  final Failure failure;

  @override
  Future<Result<UserSettings>> load() async =>
      Result<UserSettings>.failure(failure);

  @override
  Future<Result<UserSettings>> save(UserSettings settings) async =>
      Result<UserSettings>.failure(failure);
}

/// Pumps `/settings` over a [SettingsCubit] and returns it.
///
/// ## WHY IT LIVES HERE AND NOT IN `settings_page_test.dart`
///
/// `settings_page_test.dart` has held a **private** `pumpSettings` since Phase 9,
/// written before this screen had a second suite. Phase 10 adds two more — the
/// §14 accessibility sweep and the 1.22×/320px text-scale gate — and a private
/// copy per suite is how the three drift apart on the two parameters that matter
/// most here: the `MediaQuery` the page reads its font step from, and whether
/// `SettingsScope` is actually above the page.
///
/// The `SettingsScope` is **not** optional here and is the whole reason this
/// function exists: `SettingsScope.of` falls back to the locator when nothing is
/// above the context, and that fallback is **not watched**, so a page pumped bare
/// never rebuilds when a setting changes. That fallback is what
/// `settings_harness.dart`'s own header records, and a suite that re-implements
/// the pump without the scope gets a screen that looks frozen.
///
/// [disableAnimations] is threaded through to `evaPrimitiveHarness` rather than
/// left at its default because §14's reduced-motion row is a standing gate and
/// `/settings` draws a switch, a segmented control and a stepper — all three of
/// which animate.
Future<SettingsCubit> pumpSettings(
  WidgetTester tester, {
  UserSettings? stored,
  SettingsCubit? cubit,
  Locale locale = const Locale('en'),
  Size size = kAmbientSurface,
  double textScale = 1.0,
  bool disableAnimations = false,
  int frames = 4,
}) async {
  final SettingsHarness harness = settingsHarness(
    initial: cubit == null ? stored : null,
    loadImmediately: false,
  );
  // The caller's cubit when there is one — that is how a suite drives the screen
  // into `SettingsStatus.failed` — and otherwise the harness's.
  final SettingsCubit subject = cubit ?? harness.cubit;
  //
  // `load()` runs in **both** cases, and that is the contract rather than an
  // oversight. `SettingsCubit` starts at `SettingsStatus.loading`, so a
  // caller-supplied cubit that nobody loaded would be pumped in a state it can
  // never actually be in — the first version of this function skipped the load
  // for a supplied cubit and the §14 failure group failed with
  // `Expected: SettingsStatus.failed / Actual: SettingsStatus.loading`, which is
  // a state-machine mistake rather than the missing notice it was looking for.
  // Loading unconditionally means the state a test sees is always one the cubit
  // reached by itself.
  await subject.load();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      textScale: textScale,
      disableAnimations: disableAnimations,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      // Derived from [locale] and **not** left to the default, for
      // `login_harness.dart`'s recorded reason: the harness wraps its child in an
      // explicit `Directionality` that overrides the one Material installs from the
      // locale, so an `ar` locale rendered LTR reads as "the page ignores RTL".
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: settingsScope(tester, SettingsPage(cubit: subject)),
    ),
  );
  await pumpSettingsFrames(tester, frames);
  return subject;
}

/// Advances [tester] by [count] frames.
///
/// Not `pumpAndSettle`: the ambient clocks under `NeuralScaffold` never settle, so
/// settling is a timeout rather than a green tick — `home_harness.dart` records the
/// measurement.
Future<void> pumpSettingsFrames(WidgetTester tester, int count) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
