import 'package:equatable/equatable.dart';

/// The closed vocabulary of everything that can go wrong at a repository seam.
///
/// A Dart enum is sealed by construction: `values` is exhaustive, so a
/// `switch` over a `FailureKind` needs no `default` and adding a member is a
/// compile-time break everywhere it is consumed. `failure_test.dart` pins both
/// halves of that promise.
///
/// The vocabulary is deliberately wider than the HTTP status codes the backend
/// produces, because two things reach this seam that a status code cannot
/// describe:
///
/// * **Transport faults** ([network], [timeout], [cancelled]) never got a
///   response at all, so they carry no `statusCode`.
/// * **Client-side faults** ([serialization]) happen *after* a 2xx arrived, in
///   the parser. `GET /readings/today/en` has no `text_clean` key at all
///   (AGENT_CONTEXT §5 trap 2), so a response can be perfectly successful and
///   still fail to map.
///
/// The three status codes the backend really does emit are kept apart on
/// purpose so UI can react differently: [unauthorized] (401 — the identity
/// header was present but malformed) and [notFound] (404) are two different
/// stories and the mapper must not collapse them. [forbidden] sits beside them
/// for completeness even though the live backend never sends it — see there.
enum FailureKind {
  /// The socket could not be opened or was cut. No response was received.
  network,

  /// The connection or the response body exceeded `AppConfig.receiveTimeout`.
  timeout,

  /// HTTP 401. The backend returns this for a present-but-invalid
  /// `X-User-Id`; a *missing* header is a 400, not a 401 (AGENT_CONTEXT §5).
  unauthorized,

  /// HTTP 403. The server understood the identity and refused the request.
  ///
  /// **Not currently emitted.** The live backend answers with 201, 400, 401,
  /// 404, 409 and 500, plus Fastify's own 415 for a `POST` without
  /// `Content-Type: application/json` (AGENT_CONTEXT §5). The member is kept so
  /// the mapper has somewhere to put a 403 if one is ever added, and so an
  /// unexpected 403 would surface as its own kind rather than as [unknown].
  /// Do not write client logic that expects to receive one.
  forbidden,

  /// HTTP 404. No reading, question or group matched.
  notFound,

  /// HTTP 409. On `POST /readings/:id/submit` this means the question was
  /// already answered — the quiz disables such questions up front rather than
  /// discovering this as an error (AGENT_CONTEXT §5 trap 3).
  conflict,

  /// HTTP 400 / 415 / 422. The request was malformed — a bad UUID, a missing
  /// header, or a `POST` without `Content-Type: application/json`.
  validation,

  /// HTTP 5xx. The backend faulted.
  server,

  /// A 2xx response body could not be parsed into a domain entity.
  serialization,

  /// The caller abandoned the request (navigation away, bloc closed).
  cancelled,

  /// The device's own preference store could not be reached.
  ///
  /// **Not an HTTP kind, and that is the point.** Every kind above is a fact about a
  /// response or a socket, and this app has no request to make when a reader's
  /// preferences cannot be read: `shared_preferences` reads from disk over a platform
  /// channel (`AGENT_CONTEXT` §2, decision 4 — settings are local only, no server
  /// sync). Reusing [network] would be a claim about a transport this client never
  /// uses for settings, and reusing [serialization] would claim the stored *value*
  /// was unreadable — which `SettingsLocalDataSource.read` deliberately answers with
  /// a default instead, precisely so a mangled preference is not an error.
  ///
  /// So it is a kind of its own: **the store was unreachable, and nothing inside it
  /// was at fault.** Added in Phase 9 with the settings feature that needs it, and
  /// `failure_test.dart`'s exhaustive `switch` stops compiling if a fourth synonym
  /// ever appears.
  storage,

  /// A fault with no better classification. Never a fallback for "success".
  unknown,
}

/// One typed failure at a repository seam.
///
/// A repository returns this instead of throwing (AGENT_CONTEXT §3, the LSP
/// row): every caller is forced to deal with the failure arm rather than
/// discovering it as an unhandled exception.
///
/// **Messages are preserved verbatim.** AGENT_CONTEXT §5 documents exact backend
/// strings — `body/question_id must match format "uuid"` is a contract the
/// player can be shown, not prose to be reworded. Never "improve" one here.
///
/// Instances are immutable and `const`-constructible; see
/// `failure_test.dart` for the equality and nullability guarantees.
final class Failure extends Equatable {
  /// Creates a failure.
  ///
  /// [message] is shown to the player as-is. [statusCode] is present only when
  /// the backend actually sent a response, so a [FailureKind.network] has none.
  /// [details] is an escape hatch for the mapper to attach a decoded body
  /// without widening the public shape. It does **not** take part in equality —
  /// see [details] and [props].
  const Failure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.details,
  });

  /// What went wrong, in the vocabulary of [FailureKind].
  final FailureKind kind;

  /// The human-readable message, preserved verbatim from the backend.
  final String message;

  /// The HTTP status, when the failure came from a response.
  final int? statusCode;

  /// A decoded error body the mapper wanted to attach, such as the second of
  /// AGENT_CONTEXT §5's two error shapes (`{statusCode, code, error, message}`).
  ///
  /// Typed rather than `Object?` on purpose. `equatable ^3.0.0` deep-compares
  /// `Map`, `Set` and `Iterable` props but falls through to plain `==` for
  /// everything else, so an untyped field makes two logically identical
  /// `Failure`s unequal the moment the attached value has no `==` override.
  /// [Failure] lives inside bloc state, where Equatable compares the whole
  /// state graph: a mapper that rebuilt an equivalent body would then look like
  /// a state change and cost a spurious emit and a rebuild. The field still
  /// rides along — it is there for the mapper, not to be compared.
  final Map<String, Object?>? details;

  /// [kind], [message] and [statusCode] decide equality. [details] does not.
  ///
  /// Nothing in that list is diagnostic noise: `message` is the player's only
  /// clue, and `statusCode` is what separates [FailureKind.conflict] from
  /// [FailureKind.validation] when both carry the same message.
  ///
  /// Leaving [details] out also *satisfies* `test_types_in_equals` rather than
  /// hiding from it. That lint exists to keep runtime-type-varying values out
  /// of an equality contract, and an `Object?` field is precisely such a value —
  /// but `List<Object?> get props` erased its type, so the lint never saw it.
  @override
  List<Object?> get props => <Object?>[kind, message, statusCode];

  /// Renders kind, status and message, and **deliberately omits [details]**.
  ///
  /// `details` is a decoded server response body. A `toString` that inlined it
  /// would pour that body into every log line and every failed `expect` that
  /// prints a [Failure], and a response body is not ours to re-publish. Omit it
  /// deliberately; if you need it in a log, log the field explicitly and
  /// knowingly.
  @override
  String toString() =>
      'Failure(kind: ${kind.name}, statusCode: $statusCode, '
      'message: $message)';
}
