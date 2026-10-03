/// The identity-header interceptor and the `Dio` client — red-first
/// (AGENT_CONTEXT §6 names both explicitly).
///
/// ## IDENTITY IS THREE HEADERS, NOT A TOKEN
///
/// AGENT_CONTEXT §5: `X-User-Id` is required, `X-Group-Id` is required for
/// reading + leaderboard routes, and `X-User-Role` is parsed but **never
/// checked**. There is no `Authorization` header anywhere in this backend
/// because there is no auth endpoint at all (AGENT_CONTEXT §2, decision 3).
///
/// The reason this is an interceptor rather than something each data source
/// passes is in AGENT_CONTEXT §7.1: "forgetting `X-Group-Id` is a **400**, not a
/// 401". A missing identity header produces the same status as a malformed body,
/// so the failure it causes in a repository's error handling is invisible. One
/// interceptor is the only shape in which no call site *can* forget one.
///
/// ## THE PROOF IS ON THE WIRE, NOT ON THE INTERCEPTOR
///
/// Asserting that `onRequest` assigns three keys proves only that a method body
/// ran. The claim that matters is "every request carries them", and that is
/// asserted by driving a **real `Dio`** through a fake [HttpClientAdapter] and
/// reading the [RequestOptions] the adapter was handed — the same object the
/// socket writer reads. Three requests go out — a GET, a POST with a body, and a
/// third — because "every request" and "the first request" are different claims.
library;

import 'package:dio/dio.dart';
import 'package:evangelion/core/network/dio_client.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The seeded identity the app ships (AGENT_CONTEXT §5).
const String kSeededUserId = '11111111-1111-1111-1111-111111111111';

/// An adapter that answers every request with `200 {}` and remembers them.
///
/// A [Mock] over [HttpClientAdapter] rather than a hand-written subclass, so the
/// signature this file compiles against is dio's own — a hand-written `fetch`
/// that stopped matching dio's interface would compile here and break in the
/// app.
class MockAdapter extends Mock implements HttpClientAdapter {}

/// A [RequestInterceptorHandler] that counts `next` calls.
///
/// The real one cannot be constructed usefully from a test: its `next` completes
/// a private completer and asserts it has not already been completed — which is
/// exactly the behaviour worth checking, so the subclass records the call and
/// nothing else.
final class CountingRequestHandler extends RequestInterceptorHandler {
  /// Creates a handler that runs [onNext] each time `next` is called.
  CountingRequestHandler(this.onNext);

  /// The callback.
  final void Function() onNext;

  /// How many times `next` has been called.
  int calls = 0;

  @override
  void next(RequestOptions requestOptions) {
    calls++;
    onNext();
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) => throw UnimplementedError('the identity interceptor never rejects');
}

void main() {
  late MockAdapter adapter;
  late List<RequestOptions> sent;

  setUpAll(() {
    // mocktail needs a fallback for every non-nullable argument type it is asked
    // to match loosely. `fetch`'s first argument is `RequestOptions`, and the
    // other two are nullable so `any()` covers them without one.
    registerFallbackValue(RequestOptions(path: '/api/v1/fallback'));
  });

  setUp(() {
    sent = <RequestOptions>[];
    adapter = MockAdapter();
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((Invocation invocation) async {
          sent.add(invocation.positionalArguments.first as RequestOptions);
          return ResponseBody.fromString(
            '{}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        });
  });

  /// A client wired the way the app's is, with the adapter swapped so nothing
  /// leaves the process.
  Dio client({
    String userId = kSeededUserId,
    int groupId = 3,
    String role = 'kid',
    String baseUrl = 'http://localhost:3000',
  }) => buildApiDio(
    baseUrl: baseUrl,
    identity: IdentityHeadersInterceptor(
      userId: userId,
      groupId: groupId,
      role: role,
    ),
    connectTimeout: const Duration(seconds: 1),
    receiveTimeout: const Duration(seconds: 1),
  )..httpClientAdapter = adapter;

  /// The same client, for the tests that assert `buildApiDio` *refuses* to build
  /// one — so those call sites do not each restate two timeouts.
  Dio Function() building({required String baseUrl, required String userId}) =>
      () => buildApiDio(
        baseUrl: baseUrl,
        identity: IdentityHeadersInterceptor(userId: userId),
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
      );

  group('every request carries all three identity headers', () {
    test('a GET', () async {
      final Dio dio = client();
      await dio.get<Object?>('/api/v1/streak/summary');

      expect(sent, hasLength(1));
      expect(sent.single.headers['X-User-Id'], kSeededUserId);
      expect(sent.single.headers['X-Group-Id'], '3');
      expect(sent.single.headers['X-User-Role'], 'kid');
    });

    test('a POST with a JSON body', () async {
      final Dio dio = client();
      final Map<String, Object?> body = <String, Object?>{
        'question_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'answer': 'A',
      };
      await dio.post<Object?>(
        '/api/v1/readings/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/submit',
        data: body,
      );

      expect(sent.single.headers['X-User-Id'], kSeededUserId);
      expect(sent.single.headers['X-Group-Id'], '3');
      expect(sent.single.headers['X-User-Role'], 'kid');
      // The body is untouched — identity is *added*, not substituted for, the
      // request's own content.
      expect(sent.single.data, body);
    });

    test('and a third request, so "every" is not "the first"', () async {
      final Dio dio = client();
      await dio.get<Object?>('/api/v1/readings/today/en');
      await dio.get<Object?>('/api/v1/readings/today/ar');
      await dio.get<Object?>('/api/v1/streak/summary');

      expect(sent, hasLength(3));
      for (final RequestOptions request in sent) {
        expect(
          request.headers['X-User-Id'],
          kSeededUserId,
          reason: '${request.path} lost X-User-Id',
        );
        expect(request.headers['X-Group-Id'], '3', reason: request.path);
        expect(request.headers['X-User-Role'], 'kid', reason: request.path);
      }
    });

    test(
      'overwrites a caller-supplied X-User-Id rather than trusting it',
      () async {
        // Identity is the client's, not the caller's. A repository that put its
        // own `X-User-Id` into `options.headers` would otherwise be able to choose
        // whose identity the request carries. This is not a security boundary —
        // nothing validates the header (AGENT_CONTEXT §2, decision 3) — but two
        // answers to one question is a state the client should not be able to
        // reach, and one `[]=` settles it.
        final Dio dio = client();
        await dio.get<Object?>(
          '/api/v1/streak/summary',
          options: Options(
            headers: <String, Object?>{
              'X-User-Id': '22222222-2222-2222-2222-222222222222',
              'X-Group-Id': '9',
            },
          ),
        );

        expect(sent.single.headers['X-User-Id'], kSeededUserId);
        expect(sent.single.headers['X-Group-Id'], '3');
      },
    );

    test('the header values are Strings, because HTTP header values are', () async {
      // `X-Group-Id` is an `int` in Dart and has to reach the wire as `'3'`.
      // Dio would stringify it; the *interceptor* is the place that decides the
      // value, so the decision is asserted here rather than left to dio.
      final Dio dio = client();
      await dio.get<Object?>('/api/v1/streak/summary');

      for (final String header in <String>[
        'X-User-Id',
        'X-Group-Id',
        'X-User-Role',
      ]) {
        expect(sent.single.headers[header], isA<String>(), reason: header);
      }
    });
  });

  group('the identity the app actually sends', () {
    test('defaults to group 3 and role kid', () {
      // AGENT_CONTEXT §5: group 3 is the only cohort with a real scheduled
      // reading — every other group is served a fabricated non-UUID
      // `reading_id` that `POST /readings/:id/submit` rejects with 400.
      const IdentityHeadersInterceptor identity = IdentityHeadersInterceptor(
        userId: kSeededUserId,
      );

      expect(identity.groupId, 3);
      expect(identity.role, 'kid');
    });

    test('refuses to be built with an identity the backend will not check', () {
      // D2. A **non-UUID** `X-User-Id` is accepted by this backend with 200 and
      // echoed back — verified live today: `{"user_id":"not-a-uuid", …}` — while
      // only an *absent* header is a 400 and only an *empty* one a 401. The
      // server validates no format at all, so this is the only place a malformed
      // user id can be caught before it becomes a mystery 200.
      //
      // At **composition**, not in `onRequest`, because the value cannot change
      // between the two: it is a constructor parameter. A per-request check
      // would re-test the same immutable string on every call.
      final Dio Function() build = building(
        baseUrl: 'http://localhost:3000',
        userId: 'not-a-uuid',
      );

      expect(
        build,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message.toString(),
            'message',
            contains('not-a-uuid'),
          ),
        ),
      );
    });

    test('and the shape check accepts exactly the UUID grammar', () {
      expect(isValidUserId(kSeededUserId), isTrue);
      expect(
        isValidUserId('AAAAAAAA-BBBB-4CCC-8DDD-EEEEFFFF0000'),
        isTrue,
        reason: 'uppercase hex is the same UUID',
      );

      for (final String bad in <String>[
        '',
        'not-a-uuid',
        '11111111-1111-1111-1111-11111111111',
        '11111111-1111-1111-1111-1111111111111',
        '11111111_1111_1111_1111_111111111111',
        '11111111-1111-1111-1111-11111111111g',
        ' 11111111-1111-1111-1111-111111111111',
        '11111111-1111-1111-1111-111111111111 ',
        'not-a-uuid\nX-Injected: 1',
        '{11111111-1111-1111-1111-111111111111}',
      ]) {
        expect(isValidUserId(bad), isFalse, reason: 'accepted "$bad"');
      }
    });
  });

  group('the client', () {
    test('resolves a relative path against the configured base URL', () async {
      // The base URL is a **host**: `AppConfig.apiBaseUrl` is
      // `http://localhost:3000` and the `/api/v1` prefix belongs to the endpoint
      // definitions. A call site writes the full path and the client joins the
      // two. If the prefix ever moved into the base URL, every call site would
      // double it — and this is the assertion that would say so.
      final Dio dio = client(baseUrl: 'http://example.test:9999');
      await dio.get<Object?>('/api/v1/streak/summary');

      expect(sent.single.baseUrl, 'http://example.test:9999');
      expect(
        sent.single.uri.toString(),
        'http://example.test:9999/api/v1/streak/summary',
      );
    });

    test('takes the timeouts as parameters rather than reading a global', () async {
      // AGENT_CONTEXT §6, recorded decision 1: `String.fromEnvironment` is
      // resolved by the compiler, so an override read from inside the client is
      // untestable at runtime. Parameters are what make "an absurd timeout" and
      // "a malformed base URL" writable as tests at all.
      final Dio dio = buildApiDio(
        baseUrl: 'http://localhost:3000',
        identity: const IdentityHeadersInterceptor(userId: kSeededUserId),
        connectTimeout: const Duration(milliseconds: 321),
        receiveTimeout: const Duration(milliseconds: 654),
      )..httpClientAdapter = adapter;

      await dio.get<Object?>('/api/v1/streak/summary');

      expect(sent.single.connectTimeout, const Duration(milliseconds: 321));
      expect(sent.single.receiveTimeout, const Duration(milliseconds: 654));
    });

    test('declares a JSON content type, because a POST without one is a 415', () async {
      // AGENT_CONTEXT §5, trap 5. Declared on the client rather than left to
      // dio's transformer, because a header the app never sets is a 415 nobody
      // debugged.
      final Dio dio = client();
      await dio.post<Object?>('/api/v1/probe', data: <String, Object?>{'a': 1});

      expect(sent.single.contentType, Headers.jsonContentType);
    });

    test('rejects a base URL dio cannot resolve a path against', () {
      // `Uri.parse('localhost:3000')` reads `localhost` as the **scheme** and
      // `3000` as the path, so a scheme-less `--dart-define` is a value dio
      // cannot fail on cleanly — it fails later, per request, with a message
      // about the URL. At composition it is a one-line error naming the value.
      for (final String bad in <String>[
        'localhost:3000',
        '',
        '/api/v1',
        'http://',
      ]) {
        final Dio Function() build = building(
          baseUrl: bad,
          userId: kSeededUserId,
        );
        expect(build, throwsA(isA<ArgumentError>()), reason: 'accepted "$bad"');
      }
    });

    test('rejects a base URL with a trailing slash', () {
      // dio concatenates rather than resolving relative references, so a trailing
      // slash yields `http://host//api/v1/...`, which some routers 404.
      final Dio Function() build = building(
        baseUrl: 'http://localhost:3000/',
        userId: kSeededUserId,
      );

      expect(build, throwsA(isA<ArgumentError>()));
    });

    test('carries the identity interceptor, and it is last in the chain', () {
      // Order is the property, not the count. dio 5.11 installs its own
      // `ImplyContentTypeInterceptor` in the constructor, so "one interceptor" is
      // simply false against this version — and asserting a count would have
      // pinned a number that a dio upgrade could change for reasons of its own.
      //
      // What must hold is that the identity interceptor runs **last** among
      // request interceptors, so nothing downstream can strip or rewrite the
      // three headers, and that there is exactly one of it — a second copy would
      // set the headers twice, which is harmless today and a confusing thing to
      // debug tomorrow. A *different* interceptor added by a later phase shows up
      // here, which is the point: the chain is declared in one place so no
      // repository has to think about it.
      final Dio dio = client();

      expect(
        dio.interceptors.whereType<IdentityHeadersInterceptor>(),
        hasLength(1),
      );
      expect(dio.interceptors.last, isA<IdentityHeadersInterceptor>());
    });
  });

  group('the interceptor in isolation', () {
    test('calls handler.next exactly once, with the same options', () {
      // dio throws on a second `next`, so a double call is an error escaping a
      // request. Exercised directly because a full round trip would hide the
      // count behind one success.
      const IdentityHeadersInterceptor identity = IdentityHeadersInterceptor(
        userId: kSeededUserId,
      );
      final RequestOptions options = RequestOptions(
        path: '/api/v1/streak/summary',
      );
      final CountingRequestHandler handler = CountingRequestHandler(() {});

      identity.onRequest(options, handler);

      expect(handler.calls, 1);
      expect(options.headers['X-User-Id'], kSeededUserId);
    });

    test('does not add the /api/v1 prefix itself', () {
      // The prefix belongs to endpoint definitions (AGENT_CONTEXT §5), so the
      // interceptor must not touch the path. A path it rewrote would make every
      // call site shorter and every base URL longer, and one of the two would
      // then be a lie.
      const IdentityHeadersInterceptor identity = IdentityHeadersInterceptor(
        userId: kSeededUserId,
      );
      final RequestOptions options = RequestOptions(path: '/readings/today/en');

      identity.onRequest(options, CountingRequestHandler(() {}));

      expect(options.path, '/readings/today/en');
      expect(options.baseUrl, isEmpty);
    });
  });
}
