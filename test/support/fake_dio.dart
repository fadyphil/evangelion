import 'package:dio/dio.dart';
import 'package:evangelion/core/network/dio_client.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';
import 'package:mocktail/mocktail.dart';

/// The seeded identity the app ships (AGENT_CONTEXT §5).
const String kSeededUserId = '11111111-1111-1111-1111-111111111111';

/// A [Mock] over [HttpClientAdapter].
///
/// A mock rather than a hand-written subclass, and the reason is the same as
/// `identity_headers_test.dart`'s: the signature this file compiles against is
/// dio's own, so a hand-written `fetch` that stopped matching dio's interface
/// would compile in the test and break in the app.
class MockAdapter extends Mock implements HttpClientAdapter {}

/// Builds a `Dio` wired the way the app's is, with [adapter] swapped in so
/// nothing leaves the process.
///
/// The identity interceptor is **kept**, deliberately. Several of the assertions
/// downstream are about the headers reaching the adapter, and a fixture that
/// dropped the interceptor would have those pass for the wrong reason.
Dio dioWithAdapter(
  HttpClientAdapter adapter, {
  String baseUrl = 'http://localhost:3000',
}) => buildApiDio(
  baseUrl: baseUrl,
  identity: const IdentityHeadersInterceptor(
    userId: kSeededUserId,
    groupId: 3,
    role: 'kid',
  ),
  connectTimeout: const Duration(seconds: 1),
  receiveTimeout: const Duration(seconds: 1),
)..httpClientAdapter = adapter;

/// Registers mocktail's fallback for [RequestOptions].
///
/// `fetch`'s first argument is a non-nullable `RequestOptions`, so `any()`
/// cannot match it without one. Called from each suite's `setUpAll`; calling it
/// twice is harmless.
void registerRequestOptionsFallback() {
  registerFallbackValue(RequestOptions(path: '/api/v1/fallback'));
}

/// A [ResponseBody] carrying [json] with [status].
ResponseBody jsonBody(String json, int status) => ResponseBody.fromString(
  json,
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

/// A [ResponseBody] carrying bytes that are not JSON at all.
ResponseBody rawBody(String bytes, int status) => ResponseBody.fromString(
  bytes,
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
  },
);
