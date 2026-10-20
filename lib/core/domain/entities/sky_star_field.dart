/// Where down the screen stars may sit.
///
/// `eva/redesign.html:1131` — `starPos='crown'` at the boot, re-pinned at
/// `:1515` where the reset restores it; and `:677-678` — the segmented
/// control's three `data-v` values.
///
/// ## WHY IT MOVED HERE, OUT OF `core/design_system/widgets/witness_sky.dart`
///
/// The same reason as `SkyStarShape`, and it is the same single fact: Task
/// 5.7's `UserSettings` holds it — `eva.sky.pref.field`, the Star field
/// preference — and `core/domain/` is **pure Dart** under Gate 1, so an enum
/// declared beside a Flutter widget could not be named from
/// `core/domain/entities/user_settings.dart`.
///
/// **It is imported BY PATH and is NOT re-exported through the barrel**, for
/// the reason `sky_star_shape.dart` gives in full: a re-export from a
/// design-system file would make the analyzer report that file's own imports
/// as `unnecessary_import`, and `barrel_test.dart` holds the barrel to
/// re-exporting nothing from a domain.
enum SkyStarField {
  /// The default (`eva/redesign.html:1131`, re-pinned at `:1515`).
  crown('crown'),

  /// A taller band.
  high('high'),

  /// The whole upper field.
  full('full');

  const SkyStarField(this.storedValue);

  /// What `shared_preferences` holds, and what [fromStored] accepts.
  ///
  /// **The prototype's own `data-v` values** — `crown`, `high`, `full` — which
  /// are also the keys of `POSRANGE` (`eva/redesign.html:1133`).
  final String storedValue;

  /// The field [storedValue] names, or `null` when it names none of them.
  ///
  /// `null` and not a fallback, for `AppThemeMode.fromStored`'s reason: a
  /// preference naming a field this build does not have must not be silently
  /// answered with [crown], because a reader whose preference was mangled
  /// would see a different sky and nothing would say the preference was not
  /// read.
  static SkyStarField? fromStored(String storedValue) => switch (storedValue) {
    'crown' => crown,
    'high' => high,
    'full' => full,
    _ => null,
  };
}
