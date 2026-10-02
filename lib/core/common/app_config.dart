/// Environment configuration for the Evangelion client.
///
/// Pure Dart by design: no Flutter import, so this can be read from
/// `core/domain/` and from plain unit tests without dragging in a binding.
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

  // Seeded in-memory-backend identity that works end-to-end (group 3, John 3:1-5).

  /// `X-User-Id` for the seeded user. The backend rejects an absent header with
  /// 400 and an empty or malformed one with 401, so this must stay a valid UUID.
  static const String seedUserId = '11111111-1111-1111-1111-111111111111';

  /// `X-Group-Id`. Group 3 is the only cohort with a real scheduled reading in
  /// the in-memory fallback; any other group fabricates non-UUID ids that the
  /// submit endpoint then rejects.
  static const int seedGroupId = 3;

  /// `X-User-Role`. The backend parses this but never enforces it; it is
  /// decorative and must never gate the UI.
  static const String userRole = 'kid';
}
