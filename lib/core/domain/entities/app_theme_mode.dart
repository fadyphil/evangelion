/// Which of the two Eva palettes the app renders in.
///
/// `SettingsScreen.tsx:52-61` — `useState<'Light' | 'Dark' | 'System'>('Dark')`
/// and three `<button>`s. All three are transcribed, and all three ship.
///
/// ## WHY THE **DEFAULT** IS [dark] AND NOT [system]
///
/// The prototype's own initial state is `'Dark'`, so this is the prototype's value
/// and not a preference of this client's. It also preserves what
/// `app.dart` hard-coded for eight phases — `ThemeMode.dark`, with its doc's
/// measured reason: "this design is dark by identity … and shipping 'follow the OS'
/// first would mean the app opened light on every light-mode machine for no
/// reason."
///
/// [system] therefore means "the reader asked to follow the OS", not "the app has no
/// opinion". A reader who never opens `/settings` gets `dark`; a reader who picks
/// `System` gets the device. Both are reachable and neither is a default.
///
/// ## PURE DART, AND THE `ThemeMode` MAPPING IS **NOT** IN HERE
///
/// `ThemeMode` is a `flutter/material.dart` enum and Gate 1 holds `core/domain/`
/// Flutter-free. So this file declares the three values and nothing else, and the
/// switch onto `ThemeMode` lives at the one edge where a `ThemeMode` exists —
/// `lib/app/app.dart`. An exhaustive `switch` there over this enum means a fourth
/// member is a **compile error at the app root** rather than a screen that quietly
/// keeps the previous palette.
///
/// The wire value is [name] (`'light'` / `'dark'` / `'system'`) and it is read from
/// `shared_preferences`, so it is pinned by a test against the literal: §4 forbids
/// `describeEnum`, and a stored value written by hand has to survive a rename or be
/// reported as unreadable rather than silently becoming [dark].
enum AppThemeMode {
  /// The light palette — `EvaThemeLight`.
  light('light'),

  /// The dark palette — `EvaThemeDark`. The prototype's initial value.
  dark('dark'),

  /// Whatever the device reports. `MediaQuery.platformBrightnessOf`.
  system('system');

  const AppThemeMode(this.storedValue);

  /// What `shared_preferences` holds, and what [fromStored] accepts.
  ///
  /// Spelled out rather than derived from the member name, for `ReadingLanguage`'s
  /// reason: `.name` gives `light`/`dark`/`system` here by luck, and a member called
  /// `followSystem` would silently stop being readable.
  final String storedValue;

  /// The mode [storedValue] names, or `null` when it names none of them.
  ///
  /// ## WHY `null` AND NOT A FALLBACK, ON A **PREFERENCE**
  ///
  /// `ReadingLanguage.fromCode` returns `null` for the same reason — a wrong answer
  /// is worse than no answer — and this is the preference-side twin of it. A
  /// hand-edited or version-skewed preference naming a mode this build does not have
  /// must not be silently answered with [dark]: a reader who chose `light` and whose
  /// preference was mangled would be told the app is dark, and there is nothing on
  /// screen that says the preference was not read.
  ///
  /// `SettingsLocalDataSource` turns a `null` into **the default** and no more, so
  /// the failure is visible exactly once — in the state, as a preference that came
  /// back at its default — and never as a wrong palette.
  ///
  /// The case-sensitivity is deliberate and asserted: `'Dark'` is not `'dark'`, and a
  /// value that arrives capitalised was written by something that does not know the
  /// format.
  static AppThemeMode? fromStored(String storedValue) => switch (storedValue) {
    'light' => light,
    'dark' => dark,
    'system' => system,
    _ => null,
  };
}
