import 'package:equatable/equatable.dart';

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
/// ## [role] IS NOT A CAPABILITY
///
/// `X-User-Role` is parsed by the backend and **never enforced**
/// (AGENT_CONTEXT §5, trap 7). It is carried because it goes on the wire, not
/// because it grants anything: no UI in this client may hide or disable a control
/// on it. [defaultRole] exists so the value is written down once.
final class AuthSession extends Equatable {
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

  /// The value this client sends as `X-User-Role`. Decorative; see the class doc.
  final String role;

  /// When the session was established.
  ///
  /// Locally meaningful only — it is the moment the client decided it was signed
  /// in, and nothing on the server records it.
  final DateTime createdAt;

  /// `kid` — the value `X-User-Role` carries. See the class doc for why this is
  /// not a permission.
  static const String defaultRole = 'kid';

  @override
  List<Object?> get props => <Object?>[
    userId,
    email,
    displayName,
    initials,
    role,
    createdAt,
  ];
}
