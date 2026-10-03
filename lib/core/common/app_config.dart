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
}
