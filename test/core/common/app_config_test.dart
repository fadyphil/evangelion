import 'package:evangelion/core/common/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when the suite was launched with `--dart-define=API_BASE_URL=...`.
///
/// `String.fromEnvironment` is resolved by the compiler, so the override path
/// genuinely CANNOT be exercised from a runtime test. The guard below keeps the
/// default-value assertions honest instead of letting them fail whenever a
/// developer (or a future CI job) points the suite at another backend.
final bool _hasBaseUrlOverride = const String.fromEnvironment('API_BASE_URL')
    .isNotEmpty;

const String _skipWhenOverridden =
    'API_BASE_URL is set by --dart-define; '
    'default not under test';

void main() {
  group('AppConfig', () {
    group('apiBaseUrl', () {
      test(
        'defaults to the local Evangelion API when no dart-define is set',
        () {
          expect(AppConfig.apiBaseUrl, 'http://localhost:3000');
        },
        skip: _hasBaseUrlOverride ? _skipWhenOverridden : null,
      );

      test('targets the /api/v1 host without duplicating the prefix', () {
        // The prefix itself belongs to the endpoint definitions, not the base
        // URL, so it must not be baked into the configuration.
        expect(AppConfig.apiBaseUrl, isNot(contains('/api/v1')));
      });

      // The four tests below assert invariants that ANY valid value — the
      // default or an override — must satisfy. They are what a reviewer can
      // actually check at runtime, since the override branch is compile-time
      // only. The Dio client takes `baseUrl` as a constructor parameter
      // (see AGENT_CONTEXT §6, "Recorded decisions") precisely so malformed
      // overrides are testable there instead of here.

      test('apiBaseUrl carries a scheme', () {
        expect(Uri.parse(AppConfig.apiBaseUrl).hasScheme, isTrue);
      });

      test('apiBaseUrl scheme is http or https', () {
        // `hasScheme` alone is TOOTHLESS here: Uri.parse('localhost:3000')
        // reads `localhost` as the scheme and `3000` as the path, so a
        // scheme-less override satisfies the test above. Asserting the scheme
        // is one of the two transports this client actually speaks is what
        // makes that malformed value fail loudly instead of at request time.
        expect(Uri.parse(AppConfig.apiBaseUrl).scheme, anyOf('http', 'https'));
      });

      test('apiBaseUrl has a host', () {
        // This is the invariant that actually catches 'localhost:3000':
        // Uri.parse puts the whole thing in `scheme` and leaves host empty.
        expect(Uri.parse(AppConfig.apiBaseUrl).host, isNotEmpty);
      });

      test('apiBaseUrl has no trailing slash', () {
        // Dio appends paths directly, so a trailing slash silently yields
        // "http://host:port//api/v1/...". Some routers 404 on the double slash.
        expect(AppConfig.apiBaseUrl, isNot(endsWith('/')));
      });
    });

    group('timeouts', () {
      test('connectTimeout is 10 seconds', () {
        expect(AppConfig.connectTimeout, const Duration(seconds: 10));
      });

      test('receiveTimeout is 15 seconds', () {
        expect(AppConfig.receiveTimeout, const Duration(seconds: 15));
      });

      test('receiveTimeout is strictly greater than connectTimeout', () {
        expect(AppConfig.receiveTimeout, greaterThan(AppConfig.connectTimeout));
      });
    });

    group('seeded in-memory-backend identity', () {
      test('seedUserId is the David Mina UUID known to the backend', () {
        expect(AppConfig.seedUserId, '11111111-1111-1111-1111-111111111111');
      });

      test('seedUserId is a valid UUID shape', () {
        // The backend rejects a malformed X-User-Id with 401.
        expect(
          AppConfig.seedUserId,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            ),
          ),
        );
      });

      test('seedGroupId is 3, the only cohort with a working reading', () {
        expect(AppConfig.seedGroupId, 3);
      });

      test('seedUserRole is kid', () {
        expect(AppConfig.seedUserRole, 'kid');
      });
    });
  });
}
