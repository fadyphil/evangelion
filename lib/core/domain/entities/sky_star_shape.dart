/// The four star silhouettes the reader can choose.
///
/// `eva/redesign.html:672-673` — the segmented control carries four values,
/// `s-dot` / `s-star` / `s-cross` / `s-diamond`, labelled *dot* / *star* /
/// *cross* / **gem**. The prototype's fourth class is `s-diamond` and its
/// label is `gem`; the class name is the one that reaches the geometry, so it is
/// the one this enum uses, and the label is the settings row's
/// (`eva/redesign.html:673` — the prototype's own untranslated English, kept as
/// it is; see Task 5.7's brief, D11).
///
/// ## WHY IT MOVED HERE, OUT OF `core/design_system/widgets/witness_sky.dart`
///
/// It was declared in the widget file, and Task 5.7's `UserSettings` needs to
/// hold it — `eva.sky.pref.shape`, the Star shape preference. `UserSettings` is
/// in `core/domain/`, which **Gate 1 holds Flutter-free**, so an enum declared
/// beside a Flutter widget could not be named from
/// `core/domain/entities/user_settings.dart` at all. The move is §3's
/// placement test with two consumers on both sides of the boundary: the design
/// system draws the stars and the domain holds the preference.
///
/// **It is imported BY PATH and is NOT re-exported through the barrel**, and
/// the reason is the same one `witness_sky.dart`'s own header gives. A
/// re-export from a design-system file would make the analyzer report that
/// file's own two `import` lines as `unnecessary_import` — the barrel would
/// already provide the enums, through that very file — and `--fatal-infos`
/// makes that an error. `barrel_test.dart` also holds the barrel to
/// re-exporting nothing from a domain, so it cannot export this path
/// directly.
///
/// So a consumer that names `SkyStarShape` — `features/reading`,
/// `features/settings`, the sky's own tests — imports
/// `package:evangelion/core/domain/entities/sky_star_shape.dart`, exactly as
/// it imports `core/domain/entities/sky_entry.dart`.
enum SkyStarShape {
  /// `s-dot` — `eva/redesign.html:120`, `border-radius: 50%`. **Not a polygon**,
  /// which is the one shape whose transcription is a circle rather than a point
  /// list; see [skyStarPathFor].
  dot('s-dot'),

  /// `s-star` — `eva/redesign.html:121`, an eight-point polygon.
  star('s-star'),

  /// `s-cross` — `eva/redesign.html:122`, an eight-point polygon.
  cross('s-cross'),

  /// `s-diamond` — `eva/redesign.html:123`, the four-point "gem".
  diamond('s-diamond');

  const SkyStarShape(this.storedValue);

  /// What `shared_preferences` holds, and what [fromStored] accepts.
  ///
  /// **The prototype's own class names**, and not this enum's member names:
  /// `s-dot` is the class the geometry is written against
  /// (`eva/redesign.html:120-123`) and `dot` is the word the reader sees. A
  /// stored value that names the class is a value that can be checked against
  /// the prototype's markup by eye.
  final String storedValue;

  /// The shape [storedValue] names, or `null` when it names none of them.
  ///
  /// `null` and not a fallback, for `AppThemeMode.fromStored`'s reason: a
  /// preference naming a shape this build does not have must not be silently
  /// answered with [dot], because a reader whose preference was mangled would
  /// see a different sky and nothing would say the preference was not read.
  static SkyStarShape? fromStored(String storedValue) => switch (storedValue) {
    's-dot' => dot,
    's-star' => star,
    's-cross' => cross,
    's-diamond' => diamond,
    _ => null,
  };
}
