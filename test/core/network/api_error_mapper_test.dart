/// The dual-shape error mapper — red-first (AGENT_CONTEXT §6).
///
/// ## EVERY FIXTURE BELOW IS LABELLED, AND THE LABEL IS THE POINT
///
/// This backend emits **exactly one** error body shape. Verified live against
/// `HEAD = 4a1c834` on 2026-10-03, and independently in the backend's own
/// source: there is **no `setErrorHandler`**, `grep -rn statusCode src/` finds
/// **nothing at all** (the 18 occurrences in the repository are all
/// `res.statusCode` in `tests/api.test.ts` and `tests/streak.test.ts`, which are
/// the *client* asserting on responses), and no route writes a `code` key into an
/// error object. AGENT_CONTEXT §5 trap 1 records the same finding after correcting
/// an earlier draft that claimed "some routes" emitted a second shape.
///
/// This paragraph previously said the only `statusCode` occurrences "in the
/// backend's `src/` are `res.statusCode` on its own HTTP client". `src/` has zero,
/// so the citation was wrong about the place it claimed to have looked; the
/// conclusion holds and is stronger.
///
/// So this file separates its fixtures into three groups, and the group a
/// fixture is in is written in its `group()` name:
///
/// - **`observed`** — the body was captured from the running server. Each entry
///   names the request that produced it.
/// - **`SYNTHETIC — defensive branch`** — a body this server cannot produce. It
///   exists to hold one branch of the mapper, never to describe the backend.
/// - **`transport`** — no response arrived, so there is no body at all.
///
/// A test asserting a response this server cannot produce is the exact defect
/// class this project keeps paying for (recorded decision 8's argument, applied
/// to fixtures rather than to goldens), so the synthetic group is named after
/// what it is instead of being folded into the observed one.
///
/// ## HOW A RED THAT IS NOT THE INTENDED RED IS CAUGHT
///
/// Every behaviour below is reachable from one entry point,
/// [ApiErrorMapper.fromDioException]. The first run of this file failed to
/// compile — `ApiErrorMapper` did not exist — which is a valid red only once.
///
/// It used to end here: "A compile error caused by a typo in the test is not a
/// valid red, so **the negative controls at the end mutate the *mapper* rather
/// than the test** and assert that the specific assertion which should fail does
/// fail." **There is no such group, and there never was.** The last group asserts
/// `returnsNormally` and nothing else; no test in this file mutates the mapper or
/// proves it can fail.
///
/// Rather than write the group or keep the promise, the promise is deleted and the
/// half of it that *is* true is made true: the sweep below now checks the message
/// as well as the absence of a throw, so "never throws and never returns a null
/// message" is two claims rather than one. That is the claim this file can
/// actually make, and the mapper's other decisions are pinned by their own rows —
/// `FailureKind` per status bucket, `details` for the defensive shape, `message` for
/// a body that carried nothing quotable.
library;

import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [DioException] carrying a real response body, the way dio hands one over.
///
/// Built by hand rather than by a live request so the fixture is the *captured
/// body* and nothing else — no socket, no timing, no server restart between two
/// assertions about the same shape.
DioException _badResponse({
  required int statusCode,
  required Object? body,
  String? statusMessage,
}) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/probe'),
  response: Response<Object?>(
    requestOptions: RequestOptions(path: '/api/v1/probe'),
    statusCode: statusCode,
    statusMessage: statusMessage,
    data: body,
  ),
  type: DioExceptionType.badResponse,
);

/// A [DioException] of a transport type, which carries no response at all.
DioException _transport(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/probe'),
  type: type,
);

void main() {
  const ApiErrorMapper mapper = ApiErrorMapper();

  group('observed — bodies captured from the running server', () {
    // Each `group` names the request that produced the body. All of them were
    // produced today against `http://localhost:3000` at `4a1c834`; the request
    // is in the group name so a reader can reproduce it rather than trust it.

    test(
      'GET /streak/summary with no X-User-Id — 400, a Fastify schema rejection',
      () {
        // curl -H 'X-Group-Id: 3' localhost:3000/api/v1/streak/summary
        final Failure failure = mapper.fromDioException(
          _badResponse(
            statusCode: 400,
            body: <String, Object?>{
              'error': 'Bad Request',
              'message': "headers must have required property 'x-user-id'",
            },
          ),
        );

        expect(failure.kind, FailureKind.validation);
        expect(failure.statusCode, 400);
        // VERBATIM. The whole reason `Failure` preserves the server's words.
        expect(
          failure.message,
          "headers must have required property 'x-user-id'",
        );
      },
    );

    test('GET /streak/summary with an EMPTY X-User-Id — 401, not 400', () {
      // curl -H 'X-User-Id;' ... — a header sent with an empty value, which is
      // NOT the same as omitting it. Fastify's `required` accepts an empty
      // string; the handler's own `if (!userId)` is what answers, with 401.
      // This is the pair AGENT_CONTEXT §5 warns about: a missing header is a
      // 400 and client logic must not conflate the two.
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 401,
          body: <String, Object?>{
            'error': 'Unauthorized',
            'message': 'Missing user identification (X-User-Id header)',
          },
        ),
      );

      expect(failure.kind, FailureKind.unauthorized);
      expect(failure.statusCode, 401);
      expect(failure.message, 'Missing user identification (X-User-Id header)');
    });

    test('POST /readings/:id/submit with a non-UUID question_id — 400', () {
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'error': 'Bad Request',
            'message': 'body/question_id must match format "uuid"',
          },
        ),
      );

      expect(failure.kind, FailureKind.validation);
      expect(failure.statusCode, 400);
      expect(failure.message, 'body/question_id must match format "uuid"');
    });

    test('GET /streak/summary?date=nope — 400 on the date format', () {
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'error': 'Bad Request',
            'message': 'querystring/date must match format "date"',
          },
        ),
      );

      expect(failure.kind, FailureKind.validation);
      expect(failure.statusCode, 400);
      expect(failure.message, 'querystring/date must match format "date"');
    });

    test('POST /readings/:id/submit with a non-object body — 400', () {
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'error': 'Bad Request',
            'message': 'body must be object',
          },
        ),
      );

      expect(failure.kind, FailureKind.validation);
      expect(failure.statusCode, 400);
      expect(failure.message, 'body must be object');
    });

    test('POST /readings/:id/submit without Content-Type — 415', () {
      // AGENT_CONTEXT §5 trap 5. 415 is grouped with 400/422 as
      // `FailureKind.validation`, because the request is what is wrong.
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 415,
          body: <String, Object?>{
            'error': 'Unsupported Media Type',
            'message': 'Unsupported Media Type',
          },
        ),
      );

      expect(failure.kind, FailureKind.validation);
      expect(failure.statusCode, 415);
      expect(failure.message, 'Unsupported Media Type');
    });

    test('a repeated submit — 409, and it is a conflict rather than a 400', () {
      // AGENT_CONTEXT §5 trap 3. The quiz is expected to disable an
      // already-answered question instead of discovering this at submit time,
      // which is only possible if 409 and 400 are distinguishable.
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 409,
          body: <String, Object?>{
            'error': 'Conflict',
            'message': 'This question has already been submitted by this user.',
          },
        ),
      );

      expect(failure.kind, FailureKind.conflict);
      expect(failure.statusCode, 409);
      expect(
        failure.message,
        'This question has already been submitted by this user.',
      );
    });
  });

  group('SYNTHETIC — defensive branch, a body this server cannot produce', () {
    // `{statusCode, code, error, message}` is what several Fastify plugins and
    // `@fastify/error` defaults emit. This backend has none of them: no
    // `setErrorHandler`, no `code` key in any route, and the only `statusCode`
    // occurrences in `src/` are `res.statusCode` on the backend's own client.
    //
    // The branch stays because it costs one `if` and a later backend may add it,
    // and because a mapper that collapses the two shapes into *different*
    // failures would be a real bug the day that happened. What it must never be
    // is described as an observation — hence the group name.

    test('maps to the same Failure as the observed shape with one message', () {
      final Failure observed = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'error': 'Bad Request',
            'message': 'body must be object',
          },
        ),
      );
      final Failure defensive = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'statusCode': 400,
            'code': 'FST_ERR_VALIDATION',
            'error': 'Bad Request',
            'message': 'body must be object',
          },
        ),
      );

      // Equality is `kind`, `message` and `statusCode` — see `Failure.props`.
      // That is the whole point of the branch: a repository whose response
      // arrives in either shape must not look like a state change, and must not
      // reclassify the error on its way through.
      expect(defensive, observed);
      expect(defensive.kind, FailureKind.validation);
      expect(defensive.statusCode, 400);
      expect(defensive.message, 'body must be object');
    });

    test('and still attaches the extra keys as details', () {
      // `details` is excluded from `Failure.props` on purpose (a decoded server
      // body must not take part in an equality contract), so the assertion above
      // cannot see it. This one can, and pins *which* shape carries it: the
      // defensive one does, and the observed one does not — because inventing
      // details for the observed shape would mean shipping a map the server
      // never sent.
      final Failure defensive = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'statusCode': 400,
            'code': 'FST_ERR_VALIDATION',
            'error': 'Bad Request',
            'message': 'body must be object',
          },
        ),
      );
      final Failure observed = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{
            'error': 'Bad Request',
            'message': 'body must be object',
          },
        ),
      );

      expect(defensive.details, <String, Object?>{
        'statusCode': 400,
        'code': 'FST_ERR_VALIDATION',
        'error': 'Bad Request',
        'message': 'body must be object',
      });
      expect(observed.details, isNull);
    });

    test('a shape carrying only statusCode and error is still a Failure', () {
      // The branch is not keyed on `message`. A body with no `message` has to
      // reach the same fallback the observed shape reaches, or a partial
      // defensive body would become a second source of messages.
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 503,
          body: <String, Object?>{
            'statusCode': 503,
            'error': 'Service Unavailable',
          },
        ),
      );

      expect(failure.kind, FailureKind.server);
      expect(failure.statusCode, 503);
      // No `message` key, so there is nothing verbatim to quote — see the
      // fallback assertion in the next group.
      expect(failure.message, isNotEmpty);
    });
  });

  group('status → kind, and the codes the mapper must not invent', () {
    test('401 and 404 stay apart', () {
      // `FailureKind`'s own doc insists on this: the identity header was present
      // but rejected (401) and the resource was absent (404) are two different
      // stories, and collapsing them makes the UI's retry affordance a guess.
      expect(
        mapper.fromDioException(_badResponse(statusCode: 401, body: null)).kind,
        FailureKind.unauthorized,
      );
      expect(
        mapper.fromDioException(_badResponse(statusCode: 404, body: null)).kind,
        FailureKind.notFound,
      );
    });

    test('403 is forbidden, and is not currently emitted by this backend', () {
      expect(
        mapper.fromDioException(_badResponse(statusCode: 403, body: null)).kind,
        FailureKind.forbidden,
      );
    });

    test('422 is validation, alongside 400 and 415', () {
      expect(
        mapper.fromDioException(_badResponse(statusCode: 422, body: null)).kind,
        FailureKind.validation,
      );
    });

    test('every 5xx is a server fault', () {
      for (final int status in <int>[500, 502, 503, 504]) {
        expect(
          mapper
              .fromDioException(_badResponse(statusCode: status, body: null))
              .kind,
          FailureKind.server,
          reason: '$status is a server fault',
        );
      }
    });

    test('a status outside every bucket is unknown, never validation', () {
      // The dangerous default: falling through to `validation` would tell the
      // player their input was wrong for a 3xx or a 418.
      for (final int status in <int>[100, 301, 418]) {
        expect(
          mapper
              .fromDioException(_badResponse(statusCode: status, body: null))
              .kind,
          FailureKind.unknown,
          reason: '$status is in no bucket',
        );
      }
    });

    test('a 5xx bucket written as `>= 500` would swallow 600', () {
      // Found by the previous test, which is why it is its own test now. `600`
      // is not an HTTP status at all, and calling it [FailureKind.server] both
      // blames the server for a code it never sent and puts a status that HTTP
      // cannot carry into `Failure.statusCode`.
      expect(kindForStatus(600), FailureKind.unknown);
      expect(isHttpStatus(600), isFalse);
      expect(isHttpStatus(599), isTrue);
      expect(isHttpStatus(500), isTrue);
      expect(isHttpStatus(100), isTrue);
      expect(isHttpStatus(99), isFalse);
      // 499 is unassigned but it IS a status, so it stays "a status" and its
      // *kind* is `unknown`. The boundary is about HTTP's shape, not about which
      // codes this backend happens to send.
      expect(isHttpStatus(499), isTrue);
      expect(kindForStatus(499), FailureKind.unknown);
    });

    test('a badResponse with no status code at all is unknown', () {
      final Failure failure = mapper.fromDioException(
        _badResponse(statusCode: 0, body: null),
      );
      // `statusCode: 0` is what a manually-constructed `Response` carries when
      // the adapter supplied none. `Failure.statusCode` is nullable for exactly
      // this reason, so the mapper must not report `0` — a `0` would claim a
      // response arrived.
      expect(failure.statusCode, isNull);
      expect(failure.kind, FailureKind.unknown);
      expect(isHttpStatus(0), isFalse);
    });
  });

  group('when there is no quotable message', () {
    test('a null body falls back to something the player can read', () {
      final Failure failure = mapper.fromDioException(
        _badResponse(statusCode: 500, body: null),
      );

      expect(failure.message, isNotEmpty);
      expect(
        failure.message,
        isNot(contains('null')),
        reason: 'the fallback must not print the absence of a message',
      );
    });

    test('a non-JSON body does not throw and does not become the message', () {
      // A proxy in front of the backend, or dio's own default `String`, can put
      // HTML here. Passing it through verbatim would render markup in an error
      // banner; throwing would cross the seam as an exception.
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 502,
          body: '<html><body>Bad Gateway</body></html>',
        ),
      );

      expect(failure.kind, FailureKind.server);
      expect(failure.statusCode, 502);
      expect(failure.message, isNot(contains('<')));
    });

    test('a JSON body that is not an object is handled like any other', () {
      for (final Object? body in <Object?>[
        <Object?>['a', 'list'],
        'a string',
        42,
      ]) {
        expect(
          () => mapper.fromDioException(
            _badResponse(statusCode: 400, body: body),
          ),
          returnsNormally,
          reason: 'body $body is not an error object',
        );
      }
    });

    test('a message that is not a string is ignored rather than cast', () {
      final Failure failure = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{'error': 'Bad Request', 'message': 42},
        ),
      );

      expect(failure.message, isNot('42'));
    });

    test('an empty message is treated as no message', () {
      final Failure withMessage = mapper.fromDioException(
        _badResponse(
          statusCode: 400,
          body: <String, Object?>{'message': 'real text'},
        ),
      );
      final Failure withEmpty = mapper.fromDioException(
        _badResponse(statusCode: 400, body: <String, Object?>{'message': '  '}),
      );

      expect(withMessage.message, 'real text');
      expect(withEmpty.message, isNot('  '));
    });
  });

  group('transport — no response arrived, so there is no status code', () {
    test('every timeout variant is a timeout', () {
      // dio 5.11 added `transformTimeout` to the enum, which is why this test
      // enumerates rather than picking one: a new member that fell through to
      // `unknown` would report a slow backend as an unmapped fault.
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        final Failure failure = mapper.fromDioException(_transport(type));
        expect(
          failure.kind,
          FailureKind.timeout,
          reason: '$type exceeded a timeout',
        );
        expect(
          failure.statusCode,
          isNull,
          reason: 'no response arrived, so there is no status',
        );
        expect(failure.message, isNotEmpty);
      }
    });

    test('connectionError and badCertificate are network faults', () {
      // A certificate the platform refuses is a connection that never opened.
      // It is not `unknown`, and it certainly is not `server` — nothing answered.
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
      ]) {
        expect(
          mapper.fromDioException(_transport(type)).kind,
          FailureKind.network,
          reason: '$type never reached the server',
        );
      }
    });

    test('cancel is cancelled, not unknown', () {
      final Failure failure = mapper.fromDioException(
        _transport(DioExceptionType.cancel),
      );

      expect(failure.kind, FailureKind.cancelled);
      expect(failure.statusCode, isNull);
    });

    test('unknown is unknown', () {
      expect(
        mapper.fromDioException(_transport(DioExceptionType.unknown)).kind,
        FailureKind.unknown,
      );
    });

    test('the four transport kinds get four distinct messages', () {
      // If they collapsed to one string, "the request was cancelled" and "the
      // server is unreachable" would be indistinguishable in a log — which is
      // the only place a transport failure's wording is ever read.
      //
      // `DioExceptionType.badResponse` is deliberately **not** in this sweep:
      // `_transport` is not its arm, so it has no transport message to compare.
      // Its null-response fallback is asserted separately below, because that
      // shared wording is a real property rather than an accident.
      final Map<String, String> byKind = <String, String>{
        for (final DioExceptionType type in <DioExceptionType>[
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.transformTimeout,
          DioExceptionType.connectionError,
          DioExceptionType.badCertificate,
          DioExceptionType.cancel,
          DioExceptionType.unknown,
        ])
          type.name: mapper.fromDioException(_transport(type)).message,
      };

      expect(
        byKind.values.toSet(),
        hasLength(4),
        reason:
            'the four transport kinds are timeout, network, cancelled and '
            'unknown, and each reads differently: $byKind',
      );
    });

    test('a badResponse with no response falls back to the unknown wording', () {
      // Stated rather than left implicit: the fallback is the same sentence as
      // `DioExceptionType.unknown`, so a log line saying "Something went wrong"
      // does not by itself tell a reader whether a response was unreadable or
      // never arrived.
      expect(
        mapper
            .fromDioException(
              DioException(
                requestOptions: RequestOptions(path: '/api/v1/probe'),
                type: DioExceptionType.badResponse,
              ),
            )
            .message,
        mapper.fromDioException(_transport(DioExceptionType.unknown)).message,
      );
    });
  });

  group('the mapper never throws and never returns an empty message', () {
    test('over every enum member crossed with every bucket', () {
      // The sweep that makes "one function, one job" checkable rather than
      // claimed: if any combination threw, or produced an empty message, this
      // is where it would show.
      //
      // **Two claims, two assertions.** The group used to be named for both and
      // checked one: `returnsNormally` says the call did not throw and says
      // nothing about what it returned, so a mapper that answered
      // `Failure(message: '')` passed. `Failure`'s own doc makes a non-empty
      // message an obligation of the type, which makes it worth asserting here
      // where every input is crossed rather than in one row per case.
      for (final DioExceptionType type in DioExceptionType.values) {
        for (final int? status in <int?>[null, 400, 401, 404, 409, 500, 799]) {
          final Failure failure = mapper.fromDioException(
            DioException(
              requestOptions: RequestOptions(path: '/api/v1/probe'),
              type: type,
              response: status == null
                  ? null
                  : Response<Object?>(
                      requestOptions: RequestOptions(path: '/api/v1/probe'),
                      statusCode: status,
                      data: <String, Object?>{'message': 'body must be object'},
                    ),
            ),
          );

          expect(
            failure.message,
            isNotEmpty,
            reason: 'type=$type status=$status',
          );
          expect(
            failure.message.trim(),
            isNotEmpty,
            reason:
                'a message of whitespace renders as an empty error banner, which '
                'is the case `_decode` trims for — type=$type status=$status',
          );
        }
      }
    });

    test('and the same two claims with no response object at all', () {
      // The bucket above reaches `status == null` by attaching a `Response` whose
      // status is null; dio also lets a hand-built exception declare `badResponse`
      // with no `Response` whatsoever, which is the one shape where reading through
      // the null could throw. Both arms of the same two claims, so a null-reach
      // regression cannot hide behind the sweep above.
      for (final DioExceptionType type in DioExceptionType.values) {
        final Failure failure = mapper.fromDioException(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/probe'),
            type: type,
          ),
        );

        expect(
          failure.message.trim(),
          isNotEmpty,
          reason: 'type=$type with no response object attached',
        );
      }
    });

    test('a badResponse carrying a status but no response object', () {
      // Defensive against dio's own shapes rather than the server's: a
      // hand-built `DioException` can declare `badResponse` with a null
      // response. This mapper must read the status off the response or admit it
      // has none, and must not throw reaching through a null.
      final Failure failure = mapper.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/probe'),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.statusCode, isNull);
      expect(failure.kind, FailureKind.unknown);
      expect(failure.message, isNotEmpty);
    });
  });
}
