import 'package:dio/dio.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';

/// Builds the one [Dio] the app talks to.
///
/// ## WHY A FUNCTION AND NOT A CLASS
///
/// AGENT_CONTEXT §6, recorded decision 1: "The Dio client takes `baseUrl` as a
/// constructor parameter. It MUST NOT read `AppConfig.apiBaseUrl` inline inside
/// a DI module. `String.fromEnvironment` is resolved by the compiler, so the
/// override path cannot be varied at runtime from a unit test."
///
/// So every input is a parameter and this file never names `AppConfig` at all:
/// the composition root reads the globals and passes them here, which is what
/// makes the malformed-override path — empty, trailing slash, scheme-less — a
/// set of ordinary tests rather than a claim nobody could check. This file has
/// no reference to it in its signature, in its body, or in a doc comment that
/// matters, and that is the mechanism.
///
/// ## WHAT IT VALIDATES, AND WHY HERE
///
/// * **The base URL**, three ways a `--dart-define` can be wrong: no scheme
///   (`Uri.parse('localhost:3000')` reads `localhost` as the *scheme*), no host,
///   and a trailing slash that would produce `http://host//api/v1/...`.
/// * **The user id**, because the backend does not (D2 — a non-UUID `X-User-Id`
///   is accepted with 200 and echoed back).
///
/// Both throw [ArgumentError] naming the offending value. That is deliberate:
/// these are composition-time inputs supplied by code, so a wrong one is a
/// programmer error, and an exception from `configureDependencies()` fails the
/// process at a stack frame that names the mistake. Swallowing it into a
/// `Result` would be the repository contract's rule applied to the wrong layer.
///
/// ## THE `/api/v1` PREFIX IS NOT HERE
///
/// AGENT_CONTEXT §5: "Prefix: `/api/v1`" and "The `/api/v1` prefix belongs to
/// the endpoint definitions". So a call site writes
/// `dio.get('/api/v1/streak/summary')` and this function joins the two. If the
/// prefix moved in here, every call site would lose it and the base URL would
/// become a lie about which backend it addresses — and a deployed instance
/// behind a path-prefixed proxy could not be reached at all.
///
/// ## INTERCEPTOR ORDER: THERE IS ONE, AND IT IS THIS ONE
///
/// The list below is the whole of it, so "what runs before my request?" has one
/// answer rather than one per call site. A second interceptor — logging, retry —
/// belongs in this list, in a stated order, and nowhere else.
Dio buildApiDio({
  required String baseUrl,
  required IdentityHeadersInterceptor identity,
  required Duration connectTimeout,
  required Duration receiveTimeout,
}) {
  if (!isUsableBaseUrl(baseUrl)) {
    throw ArgumentError.value(
      baseUrl,
      'baseUrl',
      'must be an absolute http(s) URL with a host and no trailing slash. '
          'The /api/v1 prefix is not part of it — endpoint paths carry that. '
          'Received "$baseUrl".',
    );
  }
  if (!isValidUserId(identity.userId)) {
    throw ArgumentError.value(
      identity.userId,
      'identity.userId',
      'X-User-Id must be a UUID. This backend validates none of it: absent is a '
          '400, empty is a 401, and a non-UUID is accepted with 200 and echoed '
          'back, so a malformed id here becomes a mystery rather than an error. '
          'Received "${identity.userId}".',
    );
  }

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: connectTimeout > receiveTimeout
          ? connectTimeout
          : receiveTimeout,
      // Content-Type is declared rather than left to dio's transformer: a
      // `POST` without it is a **415** (AGENT_CONTEXT §5, trap 5), and a header
      // the app never sets is a 415 nobody debugged.
      contentType: Headers.jsonContentType,
    ),
  )..interceptors.add(identity);
  return dio;
}

/// Whether [baseUrl] is something dio can resolve an endpoint path against.
///
/// Three conditions, each of which has silently broken a `--dart-define`:
///
/// * **a scheme**, and specifically `http` or `https` — `hasScheme` alone is
///   toothless, because `Uri.parse('localhost:3000')` puts `localhost` in
///   `scheme` and `3000` in `path`;
/// * **a host**, which is what the same parse leaves empty;
/// * **no trailing slash**, because dio concatenates rather than resolving
///   relative references, and `http://host/` + `/api/v1/x` is
///   `http://host//api/v1/x`.
///
/// Exposed as its own function so the three conditions are separately nameable
/// in a failure, and so a caller can ask the question without building a client.
bool isUsableBaseUrl(String baseUrl) {
  final Uri? parsed = Uri.tryParse(baseUrl);
  if (parsed == null) {
    return false;
  }
  return (parsed.scheme == 'http' || parsed.scheme == 'https') &&
      parsed.host.isNotEmpty &&
      !baseUrl.endsWith('/');
}
