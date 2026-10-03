import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';

/// Turns one non-2xx [DioException] into one typed [Failure].
///
/// ## WHY ONE MAPPER AND NOT ONE PER REPOSITORY
///
/// The mapping has two halves and neither of them belongs to any repository: the
/// **status** decides the [FailureKind], and the **body** decides the verbatim
/// [Failure.message]. AGENT_CONTEXT §5 documents the exact strings the backend
/// sends — `body/question_id must match format "uuid"` is a contract the player
/// can be shown, not prose to reword — so they are preserved here rather than
/// rewritten at each call site. Four repositories in Phase 6–8 all needing the
/// same translation is what makes this a seam rather than a helper.
///
/// ## THE TWO BODY SHAPES, AND WHICH ONE IS REAL
///
/// AGENT_CONTEXT §5 trap 1, as corrected: **every** error this backend emits is
/// `{error, message}` — Fastify's default reply, plus the four hand-written 401s
/// in `streak.routes.ts` and `submissions.routes.ts`. The second shape,
/// `{statusCode, code, error, message}`, **appears nowhere**: there is no
/// `setErrorHandler`, no route writes a `code` key into an error object, and
/// `grep -rn statusCode src/` returns **nothing at all** — the backend's own source
/// never writes that key. The 18 occurrences in the repository are all
/// `res.statusCode` in `tests/api.test.ts` and `tests/streak.test.ts`, which are the
/// *client* asserting on the responses. Re-verified against `HEAD = 4a1c834`.
///
/// The previous version of this paragraph said the only `statusCode` occurrences
/// "in the backend's `src/` are `res.statusCode` on its own HTTP client". That was
/// **false as written** — `src/` has zero — and the conclusion it supported is
/// *stronger* than the sentence claimed: there is no `statusCode` anywhere in the
/// server, so the second shape cannot be produced by anything but a future change.
/// A citation that is wrong about where it looked is worth correcting even when the
/// conclusion survives, because the next reader repeats the search and finds
/// nothing.
///
/// The second shape is therefore **defensive**, and the branch that accepts it is
/// labelled as such here rather than described as a thing the server does. It
/// stays because it costs one `if` and a later backend may add it, and because a
/// mapper that answered the two shapes *differently* would be a real bug the day
/// it did.
///
/// ## WHAT "THE SAME FAILURE" MEANS HERE, EXACTLY
///
/// The two shapes produce a [Failure] that compares **equal** — equal `kind`,
/// `message` and `statusCode`, which is what `Failure.props` holds — and differ
/// only in `details`, which `Failure` deliberately excludes from equality. That
/// matters because a [Failure] rides inside bloc state: a mapper that rebuilt an
/// equivalent body on either arm would look like a state change and cost a
/// spurious emit and a rebuild.
///
/// ## THE MESSAGES THIS CLASS INVENTS, AND WHY THAT IS NOT A CONTRADICTION
///
/// `Failure` preserves the backend's wording. A **transport** fault has no
/// backend wording, because no backend answered, so this class supplies its own
/// — short, distinct, and never a reworded server string. The alternative
/// (inventing a message for a 4xx whose body was unreadable) is the same thing
/// and is labelled the same way: [Failure.message] for a body that carried
/// nothing quotable is this class's own text, not the server's.
final class ApiErrorMapper {
  /// Creates a mapper. Stateless and `const`, so it can be a `@lazySingleton`.
  const ApiErrorMapper();

  /// Maps [error] to a [Failure].
  ///
  /// Never throws and never returns a `Failure` with an empty
  /// [Failure.message] — both are obligations of the seam this sits behind
  /// (AGENT_CONTEXT §3, the LSP row), and both are swept in
  /// `api_error_mapper_test.dart` over every [DioExceptionType] crossed with
  /// every status bucket.
  Failure fromDioException(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => _transport(
      FailureKind.timeout,
      _timeoutMessage,
    ),
    DioExceptionType.connectionError || DioExceptionType.badCertificate =>
      _transport(FailureKind.network, _networkMessage),
    DioExceptionType.cancel => _transport(
      FailureKind.cancelled,
      _cancelledMessage,
    ),
    DioExceptionType.unknown => _transport(
      FailureKind.unknown,
      _unknownMessage,
    ),
    DioExceptionType.badResponse => _fromResponse(error.response),
  };

  /// Maps a response, or the absence of one.
  ///
  /// [response] is nullable because dio lets a hand-built [DioException] declare
  /// `badResponse` with no [Response] attached, and reaching through a null to
  /// read a status is the one way this function could throw.
  Failure _fromResponse(Response<Object?>? response) {
    final int? status = response?.statusCode;
    if (status == null || !isHttpStatus(status)) {
      return _transport(FailureKind.unknown, _unknownMessage);
    }

    final DecodedError? decoded = _decode(response?.data);
    return Failure(
      kind: kindForStatus(status),
      // The server's own words when it sent any; this class's when it did not.
      message: decoded?.message ?? 'HTTP $status',
      statusCode: status,
      details: decoded?.details,
    );
  }

  /// A transport fault: no response, so no [Failure.statusCode].
  Failure _transport(FailureKind kind, String message) =>
      Failure(kind: kind, message: message);

  /// The two shapes, decoded.
  ///
  /// Split out so the "is this the defensive shape?" question is answered in one
  /// place and cannot be answered differently by `message` and by `details`.
  DecodedError? _decode(Object? body) {
    if (body is! Map) {
      // A proxy in front of the backend, or dio's own default `String` transform,
      // can put HTML here. Passing it through would render markup in an error
      // banner; throwing would cross the seam as an exception.
      return null;
    }

    final Object? rawMessage = body['message'];
    final String? message = switch (rawMessage) {
      // Trimmed, because a server that sends `"  "` has sent nothing, and a
      // message of whitespace renders as an empty error banner.
      final String text when text.trim().isNotEmpty => text,
      _ => null,
    };

    // `statusCode` is the defensive shape's own marker. `docs/plans/07-file-map.md`
    // §7.1 names this second shape as real; AGENT_CONTEXT §5 trap 1 supersedes it
    // and says it is not, so the check is keyed on the key's presence rather than
    // on the whole shape, which keeps working if a future body carries both.
    final bool isDefensiveShape = body.containsKey('statusCode');

    return DecodedError(
      message: message,
      details: isDefensiveShape ? _stringKeyed(body) : null,
    );
  }

  /// A copy of [body] with only its `String`-keyed entries.
  ///
  /// Written out rather than `Map<String, Object?>.of(body)`, which does not
  /// compile here: a bare `is Map` test narrows to `Map<dynamic, dynamic>`, and
  /// dio hands over whatever `responseType` produced — so a non-`String` key is
  /// reachable even though JSON cannot produce one. Dropping those entries is
  /// also the honest answer, because `Failure.details` is a map a reader may
  /// print, and `Map<dynamic, dynamic>` has no key type to promise.
  Map<String, Object?> _stringKeyed(Map<Object?, Object?> body) {
    final Map<String, Object?> result = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in body.entries) {
      final Object? key = entry.key;
      if (key is String) {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

/// Whether [status] is a status HTTP can actually carry.
///
/// RFC 9110 §15 says the status code is three digits, and 600+ was never
/// assigned. This is load-bearing twice over, because both ends of it are
/// reachable and both are wrong if unchecked:
///
/// * a manually-built `Response` — dio's `Response.statusCode` is `int?` and
///   nothing stops a test double or an adapter supplying `0` — would otherwise
///   reach [Failure.statusCode] as `0`, and [Failure] documents that field as
///   "present only when the backend actually sent a response". `0` says one
///   did.
/// * [kindForStatus]'s 5xx bucket would swallow `600` and report the server as
///   faulted for a code that is not a status at all.
///
/// A test that missed the second half of this is the same failure as one that
/// missed the first: the boundary was written as `status >= 500` and nobody
/// asked what `700` does.
bool isHttpStatus(int status) => status >= 100 && status <= 599;

/// The status → [FailureKind] table.
///
/// Every bucket the backend can produce, and nothing else:
///
/// | status | kind | observed? |
/// | --- | --- | --- |
/// | 400, 415, 422 | [FailureKind.validation] | 400 and 415 are, daily |
/// | 401 | [FailureKind.unauthorized] | yes |
/// | 403 | [FailureKind.forbidden] | **no** — kept so a future 403 is its own kind |
/// | 404 | [FailureKind.notFound] | yes |
/// | 409 | [FailureKind.conflict] | yes |
/// | 500–599 | [FailureKind.server] | yes |
/// | anything else | [FailureKind.unknown] | — |
///
/// **The default is [FailureKind.unknown], never
/// [FailureKind.validation].** Falling through to `validation` would tell the
/// player their input was wrong for a 3xx or a 418, and "the request was
/// malformed" is the one conclusion a client must never reach by default.
///
/// Bounded at both ends by [isHttpStatus] rather than written as `>= 500`, for
/// the reason that function's doc gives.
FailureKind kindForStatus(int status) {
  if (status >= 500 && isHttpStatus(status)) {
    return FailureKind.server;
  }
  return switch (status) {
    400 || 415 || 422 => FailureKind.validation,
    401 => FailureKind.unauthorized,
    403 => FailureKind.forbidden,
    404 => FailureKind.notFound,
    409 => FailureKind.conflict,
    _ => FailureKind.unknown,
  };
}

/// What one decoded error body yielded.
final class DecodedError {
  /// The server's message, or `null` when it sent nothing quotable.
  final String? message;

  /// The whole decoded body, **only** for the defensive second shape. `null`
  /// for the observed `{error, message}` shape, because inventing a map the
  /// server never sent would put a body in front of a reader who has not asked
  /// for one.
  final Map<String, Object?>? details;

  /// Creates a decoded error.
  const DecodedError({required this.message, required this.details});
}

/// The client's own wording for a fault the backend never heard about.
///
/// `Failure`'s doc requires the *server's* strings to be preserved verbatim.
/// These four are the other case: no response arrived, so there is nothing to
/// preserve, and a mapper that reused a server message here would be quoting a
/// backend that did not answer. Each is distinct because the only place a
/// transport message is read is a log, where "cancelled" and "unreachable" are
/// different incidents.
const String _timeoutMessage = 'The request timed out.';
const String _networkMessage = 'Could not reach the server.';
const String _cancelledMessage = 'The request was cancelled.';
const String _unknownMessage = 'Something went wrong.';
