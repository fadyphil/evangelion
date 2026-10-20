import 'package:dio/dio.dart';

/// Attaches the three identity headers to **every** request.
///
/// ## IDENTITY IS THREE HEADERS, AND NOTHING VALIDATES THEM
///
/// AGENT_CONTEXT §5:
///
/// | header | rule |
/// | --- | --- |
/// | `X-User-Id` | required, non-empty |
/// | `X-Group-Id` | required for reading + leaderboard routes; integer string |
/// | `X-User-Role` | parsed, **never checked** |
///
/// There is no `Authorization` header on this client because there is no auth
/// endpoint on the backend at all (AGENT_CONTEXT §2, decision 3). `X-User-Role`
/// is `kid` for the same reason `Sign in` is a fake: it is part of the protocol's
/// shape, not a capability.
///
/// ## WHY AN INTERCEPTOR RATHER THAN A CALL-SITE ARGUMENT
///
/// `docs/plans/07-file-map.md` §7.1 gives the reason and it is the sharp one:
/// **forgetting `X-Group-Id` is a `400`, not a `401`.** A missing identity
/// header and a malformed request body arrive as the *same* status, so a
/// repository that forgot one would report "the request was invalid" and have no
/// way to tell the player anything useful. Four repositories in Phases 6–8 all
/// need these three headers and none of them should be able to forget one, which
/// is only expressible if no call site is given the choice.
///
/// ## WHY THE USER ID IS VALIDATED BY THE CLIENT (D2)
///
/// Verified live against `HEAD = 4a1c834` on 2026-10-03, with the seeded route
/// `/api/v1/streak/summary`:
///
/// | `X-User-Id` sent | response |
/// | --- | --- |
/// | *absent* | **400** `headers must have required property 'x-user-id'` |
/// | *empty* | **401** `Missing user identification (X-User-Id header)` |
/// | `not-a-uuid` | **200**, echoed back as `"user_id":"not-a-uuid"` |
///
/// So the server performs **no format validation at all**: a malformed user id
/// is not rejected, it is *accepted and stored*. The client therefore has to
/// check the shape itself, and [buildApiDio] is where it does — see
/// [isValidUserId].
///
/// ## AND THE THIRD ROW IS **TRUE OF THE LOCAL BACKEND ONLY**
///
/// Measured live on 2026-10-20 against the deployed backend,
/// `https://evangelion-backend.vercel.app` (ADR-0023), same route:
///
/// | `X-User-Id` sent | response |
/// | --- | --- |
/// | *absent* | **400** — same |
/// | *empty* | **401** — same |
/// | *not-a-uuid* | **500** `Failed to retrieve streak summary` |
///
/// **The third row changed, and the reason is a database.** The local
/// backend's in-memory fallback stores the id as a string and echoes it. The
/// deployed backend is real Postgres, where the column is `uuid`, so a
/// non-UUID is a cast error and the request faults. Nothing about the API
/// changed — what changed is that the server behind it enforces a type the
/// fallback did not.
///
/// **So the check is worth MORE now, not less, and the paragraph above gives
/// the wrong reason for it.** The reason used to be "the server will accept
/// anything, so a malformed id here becomes a mystery rather than an error".
/// The reason now is "the deployed server will **fault** on it, and a 500 is
/// not a thing a reader can be shown". The check itself is unchanged, and
/// [buildApiDio] is still where it happens. `docs/DRIFT.md` §11 carries the
/// entry.
///
/// ## AND WHERE ELSE IT IS CHECKED, SO THE ANSWER IS ONE PLACE
///
/// Two places decide identity, and both call [isValidUserId]:
///
/// 1. **[buildApiDio]** — the composition root decides the wire identity. It
///    throws `ArgumentError`, because a malformed `--dart-define` or a
///    mistyped seed is a programmer error and belongs at composition, not in a
///    request's error handling.
/// 2. **`FakeAuthRepository`** — the domain decides whose session it hands out.
///    It returns `Result.failure`, because a repository never throws across its
///    seam (AGENT_CONTEXT §3, the LSP row).
///
/// Both are tested. A third call site is not forbidden, but it must reach for
/// this function rather than open-coding the pattern.
///
/// ## THE UUID GRAMMAR IS DELIBERATELY NARROW
///
/// RFC 4122 §3 and §4.1 give `8-4-4-4-12` hex digits with dashes. This accepts
/// both cases and nothing else — no braces, no `urn:uuid:` prefix, no
/// surrounding whitespace, and no trailing newline. A looser matcher would let
/// `" <uuid>\r\nX-Injected: 1"` through, which is a header-injection shape, and
/// the cost of strictness here is one regex in a codebase that already treats
/// "the server will catch it" as a mistake.
final class IdentityHeadersInterceptor extends Interceptor {
  /// Sends `X-User-Id: userId`, `X-Group-Id: groupId` and
  /// `X-User-Role: role` on every request.
  ///
  /// [groupId] and [role] default to the values the seeded backend needs, so a
  /// call site that has no reason to change them does not have to say them out
  /// loud. [groupId]'s default is **3** because group 3 is the only cohort with
  /// a real scheduled reading — every other group is served a fabricated
  /// non-UUID `reading_id` that `POST /readings/:id/submit` then rejects with
  /// `400 body/question_id must match format "uuid"` (AGENT_CONTEXT §5).
  ///
  /// [userId] is **not** validated here. See [buildApiDio]: the value cannot
  /// change between construction and the first request, so the check belongs at
  /// composition where a failure can name the offending value.
  const IdentityHeadersInterceptor({
    required this.userId,
    this.groupId = defaultGroupId,
    this.role = defaultRole,
  });

  /// The value of `X-User-Id`. Must be a UUID — see [isValidUserId].
  final String userId;

  /// The value of `X-Group-Id`. Sent as a decimal string, because HTTP header
  /// values are strings and `int` would rely on dio to stringify it.
  final int groupId;

  /// The value of `X-User-Role`.
  ///
  /// Decorative **on the wire**: the backend parses this header
  /// (`identity.middleware.ts:24`), assigns it to `request.user.role` at `:31`,
  /// and never reads it again — so it decides nothing about what this request may
  /// do. See `core/domain/entities/user_role.dart` for the measurements.
  ///
  /// **It is still not to be ignored.** Because the server enforces nothing, a
  /// client-side check on the role is the *only* place the value is ever used,
  /// and it is what stops this client putting a reader on a screen that makes no
  /// sense for them. So the field is advisory UX — it prevents accidents, and it
  /// is never authorisation: the header is set by the client, so a client that
  /// refused to set it would refuse to set the identity too. Treating this value
  /// as meaningful is correct; describing what a role gate here buys as
  /// *permission* is not.
  final String role;

  /// The header names, spelled once.
  ///
  /// HTTP header names are case-insensitive, so `X-User-Id` and `x-user-id`
  /// reach the same wire value — but the backend's Fastify schema names the
  /// lower-case form in its error message
  /// (`headers must have required property 'x-user-id'`), and a reader comparing
  /// a failing response with this class needs the spelling to line up.
  static const String userIdHeader = 'X-User-Id';
  static const String groupIdHeader = 'X-Group-Id';
  static const String roleHeader = 'X-User-Role';

  /// `X-Group-Id: 3` — the only group whose reading works end to end.
  static const int defaultGroupId = 3;

  /// `X-User-Role: kid` — parsed by the backend, enforced by nothing.
  static const String defaultRole = 'kid';

  /// Sets the three headers and passes the request on.
  ///
  /// **Overwrites rather than merges.** A caller that had put its own
  /// `X-User-Id` into `options.headers` would otherwise be able to choose whose
  /// identity the request carries. That is not a security boundary — nothing
  /// validates the header — but two answers to one question is a state this
  /// client should not be able to reach, and the cost of settling it here is one
  /// `[]=`.
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[userIdHeader] = userId;
    options.headers[groupIdHeader] = groupId.toString();
    options.headers[roleHeader] = role;
    // The path is untouched on purpose: `/api/v1` belongs to endpoint
    // definitions (AGENT_CONTEXT §5), not to the host.
    handler.next(options);
  }
}

/// Whether [value] is a UUID in the RFC 4122 §3 canonical form.
///
/// Anchored, and not `contains`/`endsWith`: a substring match would accept a
/// valid UUID buried in a longer string, which for a **header** value is the
/// difference between a user id and a smuggled header.
///
/// Deliberately *not* a version check. RFC 4122 §4.1.3 makes the version nibble
/// optional for nil (all-zero) UUIDs and servers routinely mint non-RFC-4122
/// ones; the backend's own Fastify schema declares
/// `'x-user-id': { type: 'string' }` with **no** `format`, so it imposes no
/// version rule either, and inventing one here would reject ids the server would
/// happily echo back.
bool isValidUserId(String value) => _uuid.hasMatch(value);

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
