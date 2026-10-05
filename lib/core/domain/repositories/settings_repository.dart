import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';

/// The reader's stored preferences, read and written.
///
/// ## WHY IT IS DECLARED IN `core/domain/` AND NOT IN `features/settings/`
///
/// Four consumers, which is §3's placement test and the reason this is not a
/// feature-local port:
///
/// | consumer | what it asks |
/// | --- | --- |
/// | `app` (`lib/app/app.dart`) | [load], once, before the first frame's palette is decided — and it decides theme, locale **and** text scale from the answer |
/// | `settings` (`/settings`) | [load] and [save] |
/// | `reading` (`/reading`'s `Aa`) | [save], for the font step |
/// | `app` (`SettingsCubit`) | both, through the feature's own use cases |
///
/// A port inside `features/settings/` would make `app` and `reading` import
/// `settings`, which §3 forbids with no exceptions and `tool/verify_purity.sh` Gate 2
/// fails on the line. This is the fourth port of §3's ISP row — four narrow ports, a
/// fat `EvangelionRepository` forbidden — and it is the fourth one to appear for the
/// same reason the other three did: the readers are spread across the app.
///
/// ## TWO METHODS, AND THERE IS NO `reset`
///
/// [load] and [save] are the whole surface. A `reset()` is rejected for a measured
/// reason rather than a stylistic one: `AppConfig`'s doc records the same shape for
/// the seeded identity — "a configuration file holding both makes 'which of these did
/// this build forget to override?' a question about a file that cannot answer it."
/// A third method would have to pick what "reset" means for a partially-migrated
/// store, and the honest answer is that the answer is per-field. A reader who wants
/// the defaults gets them by having never opened `/settings`, which is the same
/// mechanism [load] already has.
///
/// **No `refresh`, no `watch`, no stream.** §2 decision 4 fixes settings as **local
/// only**, with no server sync, so there is nothing to synchronize *with*; and
/// nothing in this app writes settings from anywhere but the reader's own hands, so a
/// `Stream` here would carry at most the values the same process just wrote. The
/// change signal that does exist is `SettingsCubit.stream`, which is a `Cubit`'s own
/// and needs no port.
///
/// ## WHAT AN IMPLEMENTATION OWES (AGENT_CONTEXT §3, LSP)
///
/// * **Never throw.** Every fault is a `Result.failure`. `shared_preferences` reaches
///   the platform over a channel, and a `MissingPluginException` on a platform that
///   has no implementation is a real possibility — it is exactly the shape of fault
///   `DioReadingRepository` turns into a typed `Failure` rather than an exception.
/// * **Always return a [Result]**, success included. There is no overload that hands
///   back a bare value, so "did this handle the failure arm?" is answered by the type
///   rather than by review.
/// * **[load] never throws for an unreadable *preference*.** An unknown theme mode, a
///   font step outside the table and a language code this build does not have are all
///   **defaults**, not failures — a reader whose stored preferences are unreadable has
///   a working app with default settings, which is a materially different thing from
///   an app that cannot read its store. Only the store itself being unreachable is a
///   [FailureResult], and `AppThemeMode.fromStored`'s doc says why.
///
/// PURE DART — Gate 1 holds `core/domain/` Flutter-free, so this file names no
/// `SharedPreferences` and no `Dio`. `features/settings/data/` is the only place the
/// store exists.
abstract interface class SettingsRepository {
  /// The stored preferences, or the defaults where nothing is stored.
  Future<Result<UserSettings>> load();

  /// Persists [settings], and returns what was persisted.
  ///
  /// Returning the stored value rather than `Future<void>` is what makes a write
  /// round-trip assertable: a repository that normalised a value on the way in — a
  /// clamped step, a mode string it did not recognise — is reported by its own
  /// return value, so a caller never has to re-read to find out what it actually
  /// saved.
  Future<Result<UserSettings>> save(UserSettings settings);
}
