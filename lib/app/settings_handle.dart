/// The app's settings seam: one value, one writer, and a way to say "it changed".
///

/// The reader's app-wide preferences, as something a widget can read and write.
///
/// ## WHY IT EXISTS AT ALL, GIVEN `SettingsCubit` ALREADY HOLDS THEM
///
/// `SettingsCubit` holds the state and is the only writer. This is the **widget-facing
/// projection** of it, and it exists because of one fact about this repository's
/// architecture that no amount of care in `features/settings/` can route around:
///
/// * `features/settings/` may not be named by `features/reading/` — AGENT_CONTEXT §3
///   forbids a feature importing another with no exceptions, and
///   `tool/verify_purity.sh` Gate 2 fails on the line;
/// * `/reading`'s `Aa` control is a reader-facing control that must **write** the font
///   step and **read** it back (Phase 7's recorded debt, and the reason `ReadingCubit`
///   owned a step "for the life of the cubit"); and
/// * the step is now installed app-wide, so `/reading` must show where the reader is
///   on §5.2's table rather than a value of its own.
///
/// So the writer has to be reachable from three places that may not know each other.
/// `lib/app/` is the **only** directory Gate 2 exempts — `app_router.dart`'s doc says
/// it "is the one directory Gate 2 exempts, because the composition root is *supposed*
/// to reach into features to wire them up" — and this file is composition-root wiring
/// with a `BuildContext`-shaped surface.
///
/// ## AND IT NAMES **NO FEATURE**, which is the property that keeps it honest
///
/// [UserSettings], [AppThemeMode] and [ReadingLanguage] are all in `core/domain/`,
/// which §3's placement test puts there precisely because four consumers read them.
/// The two closures are the seam: `app.dart` supplies `read` and `write` over the
/// `SettingsCubit`, and this file never learns what a `Cubit` is.
///
/// **The alternative and why it was rejected.** Putting the handle in
/// `features/settings/` and letting `reading` import it is Gate 2. Putting it in
/// `core/design_system/` is app *state* in a widget library, and the barrel exists so
/// pure-Dart files never reach Flutter through it — a handle that is a `ChangeNotifier`
/// would make that worse, not better. Putting it in `core/domain/` is impossible:
/// Gate 1 holds that directory Flutter-free and `ChangeNotifier` is Flutter. And
/// letting `ReadingCubit` take a `SettingsRepository` and write through the port
/// directly is the one that was weighed hardest and rejected on measurement: two
/// writers to one store, with `app.dart` reading a **third** copy, is the "two sources
/// of truth for one fact" hazard `ReadingCubit`'s own doc names — and unlike the
/// vault-vocabulary cases in this repository, it has a visible failure (a theme toggle
/// that springs back), so nothing would remain silent about it.
///
/// ## [settings] IS A **CALL THROUGH**, NOT A CACHED FIELD
///
/// [read] is invoked on every access, so there is exactly one copy of the answer in
/// the process — the `SettingsCubit`'s state. A cached field would be a second
/// `UserSettings` that could disagree with it, and this file is the seam where the two
/// halves of "one persisted preference" would quietly become two.
///
/// ## WHY THIS IS ITS OWN FILE, AND WHY IT IMPORTS **NO** FLUTTER
///
/// `injection_test.dart`'s "the composition root is Flutter-free" gate walks the whole
/// project-local import graph from `lib/app/di/injection.dart` and fails on any
/// transitive `package:flutter` import. `navigation_injection.dart` is in that graph,
/// and it has to **register** the handle — a handle nobody registers is a handle
/// resolved lazily, which is two instances and therefore two truths.
///
/// So the handle is here, pure Dart, and `SettingsScope` — the `InheritedNotifier`, the
/// `ChangeNotifier`, the `BuildContext` — is the other file. The measurement that
/// forced the split: with both in `settings_scope.dart`, the gate failed naming
/// `package:flutter/foundation.dart` on a file the composition root imports.

// ## AND `fontScale` IS **GONE FROM HERE**, WHICH IS WHY THE TWO TESTS THAT READ IT
// ## NOW READ THE TABLE THEMSELVES
//
// `evaScalerFor` lives in `core/design_system/tokens/eva_typography.dart`, which imports
// `package:flutter/material.dart` for its `TextStyle` slots — so a convenience getter
// that restates the table would put Flutter back under the composition root and undo
// this whole split. A getter whose only two callers are tests is not worth that: they
// call `evaScalerFor(handle.settings.fontStep)` directly, which is also the honest
// assertion, since it is the table's row and not a hand-copied number.
library;

import 'package:evangelion/core/domain/entities/app_theme_mode.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';

final class SettingsHandle {
  /// A handle over whatever holds the settings.
  ///
  /// [read] answers the current value and [write] hands a mutation to whoever owns
  /// it. The mutation is a **function of the current value** rather than a new value
  /// so that a caller cannot write a record built from a stale read.
  SettingsHandle({required this.read, required this.write});

  /// Answers the current settings. See the class doc for why it is a call through
  /// rather than a cached field.
  ///
  /// **Public because a test builds one of these directly.** A private pair with
  /// named parameters would need a `// ignore:` for `prefer_initializing_formals` —
  /// Dart has no initialising formal for a named parameter that becomes a private
  /// field — and this repository's answer to a lint it does not want to satisfy is a
  /// better shape, not a suppression.
  final UserSettings Function() read;

  /// Hands a mutation to whoever owns the settings.
  ///
  /// The mutation is a **function of the current value** rather than a new value, so
  /// a caller cannot write a record built from a stale read.
  final Future<void> Function(UserSettings Function(UserSettings)) write;

  /// The reader's preferences, as the owning cubit currently holds them.
  UserSettings get settings => read();

  /// Reports a new font [step].
  ///
  /// **Clamped here as well as in `SettingsCubit`.** That is a deliberate duplication
  /// and the only one in the app: `SettingsCubit.apply` is the authoritative boundary
  /// and it clamps, and this clamps so that the value a caller *reads back
  /// synchronously* from [settings] is inside §5.2's table. `ReadingPage` reads the
  /// step straight after writing it — the `Aa` panel re-renders on the next frame —
  /// and a handle that reported an out-of-table step for one frame would put the
  /// stepper's knob at a position no step owns, which is the exact defect
  /// `clampFontStep`'s doc is about.
  Future<void> setFontStep(int step) =>
      write((UserSettings current) => current.copyWith(fontStep: step));

  /// Reports a new palette.
  Future<void> setThemeMode(AppThemeMode mode) =>
      write((UserSettings current) => current.copyWith(themeMode: mode));

  /// Reports a new language.
  Future<void> setLanguage(ReadingLanguage language) =>
      write((UserSettings current) => current.copyWith(language: language));

  /// Reports a new reduce-motion preference.
  Future<void> setReducedMotion({required bool reduced}) =>
      write((UserSettings current) => current.copyWith(reducedMotion: reduced));

  /// Tells every [SettingsScope] descendant that [settings] may have changed.
  ///
  /// ## PUBLIC BECAUSE `ChangeNotifier.notifyListeners` IS **PROTECTED**, AND A
  /// ## SUPPRESSION WOULD HAVE BEEN THE WRONG ANSWER
  ///
  /// This handle holds no state of its own — [read] and [write] are the cubit's — so
  /// nothing here can notice a change. The **cubit** notices, and `app.dart` owns the
  /// subscription to it; that is the only place in the app that can tell a change
  /// happened, and it cannot call the protected member.
  ///
  /// The alternative was a `// ignore: invalid_use_of_protected_member` on the one
  /// line that needs it, which is a hole in the lint shaped exactly like the problem.
  /// A named method with this doc is a seam instead: it says what the notification
  /// **means** ("what you read may have changed") rather than exposing a framework
  /// primitive, and it is where a future cache would invalidate.
  void announce() {
    for (final void Function() listener in List<void Function()>.of(
      _listeners,
    )) {
      listener();
    }
  }

  /// Registers [listener] to be called by [announce].
  ///
  /// **A `List` and not `ChangeNotifier`, and that is the whole reason this file
  /// exists.** `injection_test.dart`'s "the composition root is Flutter-free" gate walks
  /// the import graph from `lib/app/di/injection.dart` and fails on any transitive
  /// `package:flutter` import — so a handle that extended `ChangeNotifier` could not be
  /// registered by `navigation_injection.dart` at all, and the options were both bad: put
  /// a Flutter dependency under the composition root, or leave the handle unregistered and
  /// resolve it lazily from a page.
  ///
  /// The second option is worse in a way that would have shipped: a handle resolved
  /// lazily means two lookups can hand back two instances, and `app.dart` and
  /// `/settings` would each hold one — the "two sources of truth for one fact" hazard
  /// this class was written to prevent, arriving through the back door.
  ///
  /// So the notifier is a three-line list and the Flutter-side adapter is
  /// [SettingsScope]'s private bridge, which turns a listener call into
  /// `notifyListeners`. The listener contract is deliberately identical to
  /// `ChangeNotifier`'s, so the Flutter file reads as the adapter it is.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Undoes [addListener].
  ///
  /// Required, and asserted by `settings_scope.dart`'s disposal: a notifier that cannot
  /// drop a listener is a leak, and the Flutter bridge is exactly the kind of short-lived
  /// object that registers one.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  final List<void Function()> _listeners = <void Function()>[];

  /// Drops every listener.
  ///
  /// ## NAMED FOR THE `ChangeNotifier` METHOD IT REPLACES, AND THE NAME IS THE POINT
  ///
  /// The handle used to *be* a `ChangeNotifier`, so `EvangelionApp.dispose` called this
  /// and the compiler found it. The split into a pure file kept the call site and threw
  /// away the method, which is what an unused-disposal bug looks like halfway: the scope
  /// stays subscribed to a handle nobody listens to any more, and the next theme change
  /// rebuilds nothing. Clearing the list is the whole of it — there is no `_debugDisposed`
  /// assert to set, because there is no framework notifier here to assert on.
  ///
  /// **Clearing rather than freezing:** a late `announce()` after disposal is a no-op
  /// instead of a throw, which is what the Flutter bridge in `settings_scope.dart` also
  /// guards for. Two files dropping listeners quietly beats one throwing inside a
  /// framework assertion the reader has to decode.
  void dispose() => _listeners.clear();
}
