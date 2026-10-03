import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';

/// The in-memory stand-in for a stored session, and the seeded identity.
///
/// ## WHY THE SEED LIVES HERE AND NOT IN `AppConfig`
///
/// AGENT_CONTEXT §6, recorded decision 2: "`seedUserId` / `seedGroupId` /
/// `seedUserRole` are not configuration. They move next to `FakeAuthRepository`
/// when that exists." This is that file.
///
/// The reason behind the decision is the one `AppConfig`'s own doc now states:
/// a base URL and a hard-coded `11111111-…` are two different kinds of fact —
/// one is chosen per deployment, the other is a fixture of the backend's
/// in-memory fallback. A deployment pointed at a real database keeps the first
/// and loses the second, and a config file holding both makes "which of these
/// did this build forget to override?" a question about a file that cannot
/// answer it.
///
/// ## WHY THE STORE IS A FIELD AND NOT `shared_preferences`
///
/// `shared_preferences` is an approved dependency and Phase 9 uses it for
/// settings. It is deliberately **not** used here, for a reason worth stating
/// rather than assuming: a session written through a platform channel cannot be
/// read inside a plain `test()`, so "the app is signed in on a cold launch"
/// would be untestable without a binding — and this phase's whole subject is
/// that claim. A field is a store with the same three operations and no channel,
/// and when a real adapter arrives it replaces this class, not the port.
///
/// The cost is stated: **a signed-in session does not survive a restart.** For
/// this app that is not a bug, because there is nothing to restore — no token,
/// no expiry (see `AuthSession`) — and a cold launch lands on the login form,
/// which is the app's documented entry point. The field being per-instance is
/// also what makes `FakeAuthRepository` substitutable rather than order-
/// dependent: two repositories never share a session.
final class AuthLocalDataSource {
  /// A store holding no session.
  AuthLocalDataSource();

  AuthSession? _session;

  /// The session in hand, or `null`.
  Future<AuthSession?> readSession() async => _session;

  /// Replaces the stored session.
  Future<void> writeSession(AuthSession session) async => _session = session;

  /// Forgets the stored session.
  Future<void> clearSession() async => _session = null;
}

/// `X-User-Id` for the seeded user — David Mina, group 3.
///
/// AGENT_CONTEXT §5 lists the three seeded users and names group 3 as the only
/// cohort with a real scheduled reading. **It is a UUID and the client checks
/// that**, because the backend does not: a non-UUID `X-User-Id` is accepted with
/// 200 and echoed back (D2, verified live against `HEAD = 4a1c834`).
const String kSeedUserId = '11111111-1111-1111-1111-111111111111';

/// `X-Group-Id` for the seeded user.
///
/// Group 3 is not a preference. Any other group is served a fabricated non-UUID
/// `reading_id` by the in-memory fallback, which `POST /readings/:id/submit`
/// then rejects with `400 body/question_id must match format "uuid"`
/// (AGENT_CONTEXT §5). So this is the only value that works end to end, and
/// [IdentityHeadersInterceptor.defaultGroupId] is the same number for the same
/// reason — asserted equal by `fake_auth_repository_test.dart` so the wire and
/// the session cannot drift.
const int kSeedGroupId = 3;

/// `X-User-Role` for the seeded user.
///
/// Parsed by the backend and **never enforced** (AGENT_CONTEXT §5, trap 7), so
/// it is decorative and nothing may gate UI on it.
const String kSeedUserRole = 'kid';

/// The address the seeded session reports.
///
/// **Not** an address any reader types. There is no server to have accepted one,
/// so `AuthSession.email` carries this and never the input — see that field's
/// doc comment.
const String kSeedEmail = 'david.mina@evangelion.app';

/// The seeded user's name. The avatar monogram is derived from it by the caller
/// that has a monogram rule; see `AuthSession.initials`.
const String kSeedDisplayName = 'David Mina';

/// The seeded session, stamped at [createdAt].
///
/// A function rather than a `const` because `AuthSession.createdAt` is a
/// `DateTime` and Dart has no `const DateTime`. Taking the instant as a
/// parameter is what makes "two calls return the identical object" assertable
/// without a clock.
AuthSession seedAuthSession({required DateTime createdAt}) => AuthSession(
  userId: kSeedUserId,
  email: kSeedEmail,
  displayName: kSeedDisplayName,
  initials: 'DM',
  role: kSeedUserRole,
  createdAt: createdAt,
);
