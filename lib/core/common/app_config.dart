/// Transport configuration for the Evangelion client.
///
/// Pure Dart by design: no Flutter import, so this can be read from
/// `core/domain/` and from plain unit tests without dragging in a binding.
///
/// ## WHAT MOVED OUT, AND WHY (AGENT_CONTEXT §6, recorded decision 2)
///
/// The seed fixtures — `seedUserId`, `seedGroupId`, `seedUserRole` — used to
/// live here, and decision 2 deferred the split to "the phase that first
/// transcribes a screen", which is this one. They are now
/// `kSeedUserId` / `kSeedGroupId` / `kSeedUserRole` in
/// `features/auth/data/datasources/auth_local_data_source.dart`, beside the
/// `FakeAuthRepository` that is the only thing which consumes them.
///
/// The reason is not tidiness. A `DIO_BASE_URL` and a hard-coded
/// `11111111-1111-1111-1111-111111111111` are two different kinds of fact: one
/// is chosen per deployment and the other is a fixture of the backend's
/// in-memory fallback. A real deployment pointed at a real database would keep
/// the first and lose the second, and a config file that mixed them would make
/// "which of these did this build forget to override?" a question about a file
/// that cannot answer it.
///
/// So the split is by **reason to change**, which is what SRP means for a
/// constant table: transport tuning (base URL, timeouts) is one, and the
/// in-memory-backend fixtures are another, and they now have one file each.
///
/// `app_config_test.dart` lost its seed group with this change, and the seed's
/// shape assertions moved to `auth_local_data_source_test.dart` beside the code
/// that owns them.
abstract final class AppConfig {
  /// Base URL of the Evangelion API. Override at build time with
  /// `--dart-define=API_BASE_URL=...`. The `/api/v1` prefix belongs to the
  /// endpoint definitions and is deliberately not part of this value.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// How long to wait for the TCP/TLS handshake before giving up.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// How long to wait for response bytes before giving up. Must stay greater
  /// than [connectTimeout] so a slow body is not mistaken for a dead socket.
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// What `/settings`'s About group shows, in the prototype's `1.0.0 (42)` shape.
  ///
  /// ## A CONSTANT AND NOT `package_info_plus`, AND THE COST IS ZERO BECAUSE A TEST
  /// ## HOLDS IT TO `pubspec.yaml`
  ///
  /// `package_info_plus` would read the real version off the bundle at runtime. It is
  /// not added: §8.4 makes an unlisted dependency a hard stop, and this app has a
  /// **release** build path that does not need it — the value is a label, not a
  /// behaviour.
  ///
  /// What keeps the constant honest is `settings_page_test.dart`, which parses
  /// `pubspec.yaml` and asserts this string is its `version:` with a `+N` build
  /// suffix, so bumping the version without bumping this is red. A hard-coded version
  /// with nothing holding it to `pubspec.yaml` would be a lie the first release after
  /// this one.
  ///
  /// **The `(42)` is not carried.** `SettingsScreen.tsx:115` writes `1.0.0 (42)` and
  /// that build number is a fabricated fixture of a React preview; this package's is
  /// `1`, from `version: 1.0.0+1`. Transcribing `42` would show a build number this
  /// app has never had.
  static const String appVersion = '1.0.0 (1)';
}
