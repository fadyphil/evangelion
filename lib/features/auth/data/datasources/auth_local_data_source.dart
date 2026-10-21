import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
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

  /// The session in hand, or `null` — **synchronously**.
  ///
  /// ## WHY A SYNCHRONOUS VIEW EXISTS, AND WHY IT IS HONEST HERE
  ///
  /// `RoleAccess` reads the role out of this store, and the identity
  /// interceptor reads it **per request** — so the reader it feeds cannot be
  /// awaited. A `Future` there would leave every request holding a future
  /// nobody awaits, and turn a header write into a loading state.
  ///
  /// **The store is an in-memory field by design** — see this class's own doc:
  /// `shared_preferences` is deliberately not used, precisely because a
  /// platform-channel write cannot be read inside a plain `test()`. So a
  /// synchronous read here is a read of a field, not a lie about a channel.
  ///
  /// ## AND THE ASYNC READ STAYS, BECAUSE THE PORT ASKS FOR IT
  ///
  /// [readSession] is the port's read and keeps its `Future`; this getter is an
  /// *additional* view for the one caller that cannot await. Two answers to one
  /// question is a state this client should not be able to reach, so they are
  /// asserted to agree in `fake_auth_repository_test.dart`.
  AuthSession? get currentSession => _session;

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
/// that**, because the backend's header check covers presence and not shape
/// (D2, verified live against `HEAD = 4a1c834`) — and because the deployed
/// backend's database is a `uuid` column, so a non-UUID `X-User-Id` there is a
/// **500** rather than an echo (ADR-0023, `docs/DRIFT.md` §11).
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

/// The role the seeded user holds.
///
/// Parsed by the backend and **never enforced** — `identity.middleware.ts:31`
/// assigns `request.user.role` and no route ever reads it back, so nothing here
/// is a permission. See `core/domain/entities/user_role.dart` for the whole
/// argument and for what a role gate in this client does and does not buy.
///
/// A [UserRole] and not the wire string, because the seed is a **role**, and the
/// guarantee that buys is narrower than "the literal appears once" — it was
/// never that, and an earlier draft of this comment claiming it was wrong:
/// `'kid'` is written literally in `user_role.dart`'s own `kid('kid')`, in
/// `identity_headers.dart`'s `defaultRole`, and in several tests. What is
/// actually held is **one conversion point**: the only place in `lib/` that turns
/// a role into a wire string is `core_module.dart`'s single
/// `roleAccess.role.wireValue` in the `buildApiDio` registration, so a caller
/// cannot send the Dart spelling by accident.
///
/// **AND THE SEED IS NO LONGER WHAT THE WIRE SENDS.** This constant is the
/// role the *seeded session* holds — and since the servant portal's Task 1 the
/// role is **chosen on the login screen**, so the session's role is whatever
/// the reader picked and the wire follows **that**. `kSeedUserRole` is the
/// default the seed falls back to, and `AuthSession.defaultRole` is the same
/// value.
///
/// `IdentityHeadersInterceptor.defaultRole` is still a `String` and is still
/// asserted equal to `kSeedUserRole.wireValue` by
/// `fake_auth_repository_test.dart` — that assertion, not a literal count, is
/// what keeps the seeded role and the sent header from drifting, and it is made
/// on [UserRole.wireValue] rather than on the role itself.
const UserRole kSeedUserRole = UserRole.kid;

/// The address the seeded session reports.
///
/// **Not** an address any reader types. There is no server to have accepted one,
/// so `AuthSession.email` carries this and never the input — see that field's
/// doc comment.
const String kSeedEmail = 'david.mina@evangelion.app';

/// The seeded user's name. The avatar monogram is derived from it by the caller
/// that has a monogram rule; see `AuthSession.initials`.
const String kSeedDisplayName = 'David Mina';

/// The seeded session, stamped at [createdAt], held by [role].
///
/// A function rather than a `const` because `AuthSession.createdAt` is a
/// `DateTime` and Dart has no `const DateTime`. Taking the instant as a
/// parameter is what makes "two calls return the identical object" assertable
/// without a clock.
///
/// ## AND WHY [role] IS A PARAMETER WITH A DEFAULT
///
/// The role is **chosen on the login screen** (AGENT_CONTEXT §2, decision 3 —
/// there is no auth endpoint), so the seed has to be able to be a servant's.
/// The default is [UserRole.kid] because that is what `identity.middleware.ts:24`
/// falls back to when the header is absent, and a client that defaulted to
/// anything else would disagree with the server about an empty header.
///
/// A default here — rather than a required parameter — because **this is a
/// factory, not a port**: the port's `signIn` requires the role explicitly (the
/// caller knows what the reader picked), while this helper is also used by
/// fixtures that want the seed. The two are not the same question, and the
/// difference is the whole of why the default is allowed here and not there.
AuthSession seedAuthSession({
  required DateTime createdAt,
  UserRole role = UserRole.kid,
}) => AuthSession(
  userId: kSeedUserId,
  email: kSeedEmail,
  displayName: kSeedDisplayName,
  initials: 'DM',
  createdAt: createdAt,
  role: role,
);
