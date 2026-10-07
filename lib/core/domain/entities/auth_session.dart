import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';

/// Who the app currently believes it is.
///
/// ## WHAT IS DELIBERATELY ABSENT, AND WHY THAT IS THE DESIGN
///
/// There is **no token, no expiry and no refresh time**. This is not an omission:
/// it is the shape the protocol forces.
///
/// AGENT_CONTEXT §2, decision 3 — "Login and onboarding are UI-only. A
/// `FakeAuthRepository` returns a seeded session. There is **no auth endpoint**
/// on the backend." AGENT_CONTEXT §5 — identity on this backend is three headers
/// the client sets, and nothing validates any of them. A token would be a string
/// this client mints, sends and then ignores; an expiry would be a clock this
/// client checks against a server that has no opinion.
///
/// **So this entity carries exactly the values the client puts on the wire**,
/// which is also why it stays substitutable: a real `DioAuthRepository` added
/// later would post credentials and receive the same shape back, so `domain` and
/// `presentation` would not change. `docs/plans/05-domain-model.md` §9.1 says the
/// same thing in one line — "`AuthSession` is real as an interface, fake as an
/// implementation" — and this file is the reason that sentence is true rather
/// than aspirational.
///
/// ## [role] IS TYPED, AND IT NOW DRIVES CLIENT-SIDE NAVIGATION
///
/// [role] was a `String`, and this section used to forbid the UI from gating on
/// it at all. That is **no longer the rule**, and the rule that replaced it is
/// narrower and more useful:
///
/// * role is a [UserRole] — three named members rather than an equality guess
///   against a literal, and `grantsFor` answers "may this role open that
///   screen" as a **named capability** rather than as a comparison;
/// * a role gate **may** choose a landing route and **may** refuse a navigation.
///   That is what `grantsFor` is for;
/// * a role gate still **may not** be described, anywhere, as authorisation.
///
/// **And it is not a security boundary — the backend is the reason, and it is
/// one line of evidence.** `src/middleware/identity.middleware.ts:29` assigns
/// `request.user.role` and nothing ever reads it: `rg 'user\??\.role' src/`
/// returns no matches and `rg '403' src/` returns no matches, so there are zero
/// role guards and zero forbidden responses across all eighteen routes. Every
/// endpoint is callable by anyone who sends a user id. **This prevents a child
/// being dropped onto a scheduling screen that makes no sense for them; it
/// prevents nothing else.** A role gate here is advisory UX — it is right that
/// the reader never sees it fire, and it must not be mistaken for a wall.
///
/// The role is also not *known*. The backend has no `/auth`, no `/me` and no
/// `/login` endpoint (§2, decision 3), so the client cannot ask who anyone is
/// and the role is **chosen locally on the login screen**. See [UserRole] for
/// that and for the grant table.
///
/// [defaultRole] exists so the value is written down once, and it is
/// [UserRole.kid] because that is what `identity.middleware.ts:24` defaults to
/// when the header is absent — a client that defaulted to anything else would
/// disagree with the server about an empty header.
@freezed
final class AuthSession with _$AuthSession {
  /// A session for [userId].
  const AuthSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.initials,
    required this.createdAt,
    this.role = defaultRole,
  });

  /// The value this client sends as `X-User-Id`. **Must be a UUID** — see
  /// `isValidUserId` in `core/network/interceptors/identity_headers.dart`, which
  /// is the single implementation of that check for the whole client.
  ///
  /// "Must be" is not the backend's rule. D2, verified live against
  /// `HEAD = 4a1c834`: an absent `X-User-Id` is a 400, an empty one is a 401, and
  /// a **non-UUID one is accepted with 200 and echoed back**. The server enforces
  /// presence and nothing else, so the shape is this client's obligation.
  final String userId;

  /// The address the reader signed in with.
  ///
  /// `FakeAuthRepository` does **not** return the address that was typed. It
  /// returns the seeded one, because there is no server to have accepted the
  /// other. `LoginPage` therefore shows the seeded address after sign-in and
  /// never implies the typed one was verified.
  final String email;

  /// The reader's name, for the greeting and the avatar badge.
  final String displayName;

  /// The avatar's two-letter monogram.
  ///
  /// A field rather than a getter over [displayName] because the prototype draws
  /// `MK` at 11px (`ds.tsx:525`) and the mapping from a name to a monogram is a
  /// product decision — two letters, or one for a single-word name — not a
  /// string operation. Deriving it here would fix both answers at once.
  final String initials;

  /// The role this reader holds, as a [UserRole].
  ///
  /// Typed rather than a `String` because every question about a `String` role
  /// is an equality guess that fails silently — see [UserRole]'s own doc. It
  /// goes on the wire as [UserRole.wireValue], and the client gates navigation
  /// on [grantsFor]. **Advisory, not a security boundary**: the backend parses
  /// this header and never reads it again.
  final UserRole role;

  /// When the session was established.
  ///
  /// Locally meaningful only — it is the moment the client decided it was signed
  /// in, and nothing on the server records it.
  final DateTime createdAt;

  /// [UserRole.kid] — the role this client seeds, and the one
  /// `identity.middleware.ts:24` falls back to when the header is absent.
  ///
  /// A [UserRole] rather than the wire string: this is the **role**, and the
  /// wire spelling is one call away ([UserRole.wireValue]). Naming the wire
  /// value here would make the constant a second place a role is spelled.
  static const UserRole defaultRole = UserRole.kid;
}
