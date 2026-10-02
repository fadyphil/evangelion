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
/// The three pairs the backend actually distinguishes are kept apart on purpose
/// so UI can react differently: [unauthorized] (401 — the identity header was
/// present but malformed), [forbidden] (403), and [notFound] (404) are three
/// different stories and the mapper must not collapse them.
enum FailureKind {
  /// The socket could not be opened or was cut. No response was received.
  network,

  /// The connection or the response body exceeded `AppConfig.receiveTimeout`.
  timeout,

  /// HTTP 401. The backend returns this for a present-but-invalid
  /// `X-User-Id`; a *missing* header is a 400, not a 401 (AGENT_CONTEXT §5).
  unauthorized,

  /// HTTP 403. The server understood the identity and refused the request.
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
  /// without widening the public shape. It is compared deeply, because
  /// `equatable ^3.0.0` compares `props` with a deep collection equality: two
  /// separately-built but identical maps are equal, and two maps that differ in
  /// any entry are not.
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

  /// Anything the mapper wanted to attach, such as a decoded error body.
  final Object? details;

  /// Every field participates in equality. Nothing here is diagnostic noise
  /// that equality may safely ignore — `message` is the user's only clue and
  /// `statusCode` is what distinguishes [FailureKind.conflict] from
  /// [FailureKind.validation] when both carry the same message.
  @override
  List<Object?> get props => <Object?>[kind, message, statusCode, details];

  @override
  String toString() =>
      'Failure(kind: ${kind.name}, statusCode: $statusCode, '
      'message: $message)';
}
