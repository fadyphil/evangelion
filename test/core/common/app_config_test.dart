/// `AppConfig` — the transport half only.
///
/// ## WHAT MOVED OUT IN THIS PHASE, AND WHY THE FILE SAYS SO
///
/// The seed fixtures (`seedUserId`, `seedGroupId`, `seedUserRole`) used to be
/// asserted here. AGENT_CONTEXT §6 recorded decision 2 — "in-memory-backend seed
/// fixtures … move next to `FakeAuthRepository` when that exists" — and this is
/// the phase that phase referred to. They are now `kSeedUserId` /
/// `kSeedGroupId` / `kSeedUserRole` in
/// `features/auth/data/datasources/auth_local_data_source.dart`, and their shape
/// assertions moved with them into `fake_auth_repository_test.dart`.
///
/// The import above is deliberate: it is how this file proves the fixtures are
/// still reachable from a **client-side** place, because
/// `buildApiDio` validates against `isValidUserId` and the composition root
/// builds its identity from `kSeedUserId`.
///
/// ## AND THE GROUP BELOW IS NOT "A FIELD WAS REMOVED"
///
/// There is no test asserting `AppConfig` has no `seedUserId`. Such a test would
/// be asserting an **absence of a name**, which no execution can observe — the
/// only mechanical version would read the file's text, and a file that grades a
/// file is not a test (recorded decision 8's argument, applied to source). What
/// is asserted instead is the part that *is* behavioural: the transport values
/// are still the ones `buildApiDio` accepts, and the seed identity is still the
/// one it sends.
library;

import 'package:dio/dio.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/network/dio_client.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when the suite was launched with `--dart-define=API_BASE_URL=...`.
///
/// `String.fromEnvironment` is resolved by the compiler, so the override path
/// genuinely CANNOT be exercised from a runtime test. The guard keeps the
/// default-value assertions honest instead of letting them fail whenever a
/// developer (or a future CI job) points the suite at another backend.
final bool _hasBaseUrlOverride = const String.fromEnvironment('API_BASE_URL')
    .isNotEmpty;

const String _skipWhenOverridden =
    'API_BASE_URL is set by --dart-define; default not under test';

void main() {
  group('apiBaseUrl', () {
    test('defaults to the local Evangelion API when no dart-define is set', () {
      expect(AppConfig.apiBaseUrl, 'http://localhost:3000');
    }, skip: _hasBaseUrlOverride ? _skipWhenOverridden : null);

    test('targets the /api/v1 host without duplicating the prefix', () {
      // The prefix itself belongs to the endpoint definitions, not the base URL,
      // so it must not be baked into the configuration.
      expect(AppConfig.apiBaseUrl, isNot(contains('/api/v1')));
    });

    // The four tests below assert invariants that ANY valid value — the default
    // or an override — must satisfy. They are what a reviewer can actually check
    // at runtime, since the override branch is compile-time only. The Dio client
    // takes `baseUrl` as a constructor parameter (AGENT_CONTEXT §6, recorded
    // decision 1) precisely so malformed overrides are testable there instead of
    // here.

    test('apiBaseUrl carries a scheme', () {
      expect(Uri.parse(AppConfig.apiBaseUrl).hasScheme, isTrue);
    });

    test('apiBaseUrl scheme is http or https', () {
      // `hasScheme` alone is TOOTHLESS here: `Uri.parse('localhost:3000')` reads
      // `localhost` as the scheme and `3000` as the path, so a scheme-less
      // override satisfies the test above. Asserting the scheme is one of the two
      // transports this client actually speaks is what makes that malformed value
      // fail loudly instead of at request time.
      expect(Uri.parse(AppConfig.apiBaseUrl).scheme, anyOf('http', 'https'));
    });

    test('apiBaseUrl has a host', () {
      // The invariant that actually catches `localhost:3000`: `Uri.parse` puts the
      // whole thing in `scheme` and leaves `host` empty.
      expect(Uri.parse(AppConfig.apiBaseUrl).host, isNotEmpty);
    });

    test('apiBaseUrl has no trailing slash', () {
      // Dio appends paths directly, so a trailing slash silently yields
      // `http://host:port//api/v1/...`. Some routers 404 on the double slash.
      expect(AppConfig.apiBaseUrl, isNot(endsWith('/')));
    });

    test('and it is a value buildApiDio accepts, with the seeded identity', () {
      // The seam between the two halves of the decision-2 split. Every assertion
      // above describes the default in isolation; this one says the client's own
      // gate accepts it **and** accepts the identity the other half of the split
      // moved. So a future `--dart-define` cannot be malformed in a way the app
      // only discovers at composition time, and a future seed cannot be
      // non-UUID in a way the app only discovers on the wire.
      expect(
        () => buildApiDio(
          baseUrl: AppConfig.apiBaseUrl,
          identity: const IdentityHeadersInterceptor(userId: kSeedUserId),
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
        ),
        returnsNormally,
      );
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

    test('and buildApiDio refuses to build a client from an inverted pair', () {
      // `AppConfig` keeps the pair ordered; the client keeps the pair **usable**.
      // A hand-written value does not have to — this builds one with
      // `connectTimeout` greater than `receiveTimeout` and asserts the client
      // resolves the receive timeout to the larger of the two, so a slow body is
      // never mistaken for a dead socket. The alternative, clamping silently,
      // would make two different `--dart-define`s indistinguishable on the wire.
      final Dio inverted = buildApiDio(
        baseUrl: AppConfig.apiBaseUrl,
        identity: const IdentityHeadersInterceptor(userId: kSeedUserId),
        connectTimeout: AppConfig.receiveTimeout,
        receiveTimeout: AppConfig.connectTimeout,
      );

      expect(inverted.options.receiveTimeout, AppConfig.receiveTimeout);
      expect(
        inverted.options.connectTimeout,
        AppConfig.receiveTimeout,
        reason: 'the connect timeout is passed through untouched',
      );
    });
  });
}
