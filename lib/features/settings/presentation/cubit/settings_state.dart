import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

/// Where the settings are in their own short lifecycle.
///
/// Two values and **not** one, and `ReadingStatus` gives the argument verbatim: a
/// two-value enum has to encode "still asking" as "no data", which is how a screen
/// ends up unable to tell *still asking* from *asked and there was nothing*.
///
/// Here the distinction is smaller but it is the same one. [loading] means the app has
/// **not yet applied** the stored palette — which is a fact a reader can see, because
/// the app opens on [UserSettings]'s default `dark` and a reader who chose `light`
/// sees dark for a frame. [ready] means the stored answer is on screen.
///
/// **[loading] is not a spinner and there is no `idle`.** The first frame after launch
/// is [loading]; every state change after it is [ready] or [failed]. There is no
/// "loading again", because `SettingsCubit` **never empties the settings** — see
/// that class's doc, which is where the decision and its reason live.
enum SettingsStatus {
  /// The stored preferences have not been read yet, so the app is rendering the
  /// defaults and says so.
  loading,

  /// The stored preferences are on screen.
  ready,

  /// The store could not be reached. [SettingsState.failure] is non-null, the defaults
  /// are still on screen, and the reader's next write may still succeed.
  failed,
}

/// `/settings`' state, and the whole of what is app-wide about it.
///
/// ## [settings] IS **ALWAYS** POPULATED, INCLUDING ON FAILURE
///
/// The first version had `UserSettings?` and emptied it while loading, which is the
/// shape `ReadingState` uses and the shape that is **wrong** here for a measured
/// reason: this cubit is not the only reader of its value. `app.dart` reads the
/// settings on every frame to decide the theme mode, the locale and the text scale,
/// and `ReadingPage` reads the font step from the same source. A nullable
/// `UserSettings` would make all three handle "there is nothing yet", and the theme in
/// particular has no honest answer for it — a `MaterialApp` with no palette is not a
/// state this app can render.
///
/// So [settings] carries the **defaults** while loading and keeps them after a
/// failure, and [status] says which of the two the reader is looking at. The cost is
/// named: a reader whose store is unreachable sees the app in its default palette,
/// and [failure] is the only record that it happened.
///
/// **AND THE COST IS PAID, SINCE PHASE 10 — [SettingsPage] reads `status`.** This
/// paragraph used to end "and is never told, because there is no surface on this
/// screen for it (the failure is in [failure], which `/settings` does not draw — see
/// its page for why)", and the page it pointed at had no such reason: it is a
/// dangling cross-reference, which is worse than an admitted gap because it reads as
/// a settled decision. `/settings` drew nothing for [SettingsStatus.failed] through
/// Phase 9, which was the one genuinely unwired async page of the six — `/`, `/reading`
/// and `/quiz` each had an `ErrorView`, `/login` has no failure status at all, and
/// `/result` cannot exist without a result.
///
/// [SettingsPage] now renders `_SettingsFailureNotice` above its groups when
/// [status] is [SettingsStatus.failed], and that widget's doc gives the three measured
/// reasons it is a notice and not an `ErrorView` — the load-bearing one being that a
/// **failed write** springs the control the reader just tapped back to where it was,
/// and replacing the form would have erased the cause of its own error.
@freezed
final class SettingsState with _$SettingsState {
  /// The reader's current preferences, with [status] saying whether they came from
  /// the store.
  ///
  /// ## [settings] IS **REQUIRED**, AND THAT IS A GENERATOR CONSTRAINT MADE HONEST
  ///
  /// It reads as though `this.settings = const UserSettings()` would do, and it does
  /// not — measured, not assumed. `freezed` moves a constructor default into its
  /// generated `copyWith`/`==` and then **revives** the constant expression, and
  /// reviving `UserSettings()` fails while `user_settings.freezed.dart` is itself being
  /// generated. The build reported
  /// `FormatException: Failed to revive constant UserSettings ()`.
  ///
  /// So the default is written at the one place that constructs the first state — the
  /// cubit's `super(...)` — which is where it reads better anyway: "the app starts on
  /// `UserSettings()`" is a statement about the app, and it is visible there.
  const SettingsState({
    required this.settings,
    this.status = SettingsStatus.loading,
    this.failure,
  });

  /// Where the read is.
  final SettingsStatus status;

  /// The reader's preferences — never null, per the class doc.
  final UserSettings settings;

  /// Why the store could not be reached, or `null`.
  final Failure? failure;
}
