import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/datasources/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seeded identity and the only [AuthRepository] that ships — red-first
/// (AGENT_CONTEXT §6 names `FakeAuthRepository` explicitly).
///
/// ## THERE IS NO AUTH ENDPOINT, AND THIS FILE IS WHAT THAT MEANS
///
/// AGENT_CONTEXT §2, decision 3: "Login and onboarding are UI-only. A
/// `FakeAuthRepository` returns a seeded session. There is **no auth endpoint**
/// on the backend." So no HTTP call appears anywhere below, and the absence is
/// the specification rather than a gap: a `DioAuthRepository` that posts
/// credentials would be posting them to a route that does not exist.
///
/// ## WHAT IS STILL REAL, AND WHY THAT IS THE POINT
///
/// The credentials are **judged**. `signIn` runs the same
/// `features/auth/domain` rules the form shows, and returns a typed
/// `Failure` for anything they reject. That makes the failure path executable
/// code rather than a branch nothing can reach, which is what lets `AuthBloc`'s
/// error state be tested as behaviour instead of as a constructor argument.
///
/// A `FakeAuthRepository` must be substitutable for a real one (AGENT_CONTEXT §3,
/// LSP) — and it is, because it honours the whole contract including the part
/// that is inconvenient: it never throws and always returns a `Result`.
///
/// **It used to also claim that "a malformed user id is a `Failure` rather than
/// an exception". That claim is deleted, not weakened.** `signIn` seeds the
/// session from `seedAuthSession`, which hard-codes `kSeedUserId` with no
/// injection point, so a malformed id was not reachable from this class at all —
/// deleting the guard turned nothing red. The obligation it described is real and
/// it lives in `buildApiDio`, which throws `ArgumentError` at composition and is
/// tested there; see `dio_client_test.dart`.
void main() {
  /// A well-formed address, reused so the rule tests read as the rule and not as
  /// a fixture.
  const String goodEmail = 'david@evangelion.app';
  const String goodPassword = 'correct horse';

  group('the seeded identity', () {
    test('is the user whose reading works end to end', () {
      // AGENT_CONTEXT §5: `11111111-1111-1111-1111-111111111111` is David Mina,
      // group 3, and group 3 + John 3:1-5 is the only path the in-memory
      // fallback serves. Any other group gets a fabricated non-UUID reading id
      // that `POST /readings/:id/submit` then rejects with 400.
      expect(kSeedUserId, '11111111-1111-1111-1111-111111111111');
      expect(kSeedGroupId, 3);
      expect(kSeedUserRole, 'kid');
    });

    test('has a user id the client is willing to send', () {
      // The claim the previous test cannot make: `X-User-Id` is *not* validated
      // by the backend — a non-UUID is accepted with 200 and echoed back (D2) —
      // so "is a UUID" is this client's own obligation and it starts here.
      expect(isValidUserId(kSeedUserId), isTrue);
    });

    test('and a group id the wire and the session cannot disagree about', () {
      // Two files now carry the number 3: the session's fixtures here, and
      // `IdentityHeadersInterceptor.defaultGroupId` on the wire. They are the
      // same fact about the same backend, so they are asserted equal rather than
      // left as two copies of a literal — the disagreement this catches is a
      // seeded session whose group the interceptor would not send, and nothing
      // else in the app would notice.
      expect(kSeedGroupId, IdentityHeadersInterceptor.defaultGroupId);
      expect(kSeedUserRole, IdentityHeadersInterceptor.defaultRole);
    });
  });

  group('AuthLocalDataSource', () {
    late AuthLocalDataSource source;

    setUp(() => source = AuthLocalDataSource());

    test('holds no session to begin with', () async {
      expect(await source.readSession(), isNull);
    });

    test('round-trips a session', () async {
      final AuthSession session = seedAuthSession(
        createdAt: DateTime.utc(2026),
      );
      await source.writeSession(session);

      expect(await source.readSession(), session);
    });

    test('clears it', () async {
      await source.writeSession(seedAuthSession(createdAt: DateTime.utc(2026)));
      await source.clearSession();

      expect(await source.readSession(), isNull);
    });

    test('survives being constructed with no session', () async {
      // A second instance starts empty — which is what makes it substitutable
      // for a `shared_preferences` one in Phase 9: swapping the backing store
      // must not change what "no session" reads as.
      await source.writeSession(seedAuthSession(createdAt: DateTime.utc(2026)));

      expect(await AuthLocalDataSource().readSession(), isNull);
    });
  });

  group('FakeAuthRepository.signIn', () {
    late FakeAuthRepository repository;

    setUp(() => repository = FakeAuthRepository());

    test('returns the seeded session for credentials the form accepts', () async {
      final Result<AuthSession> result = await repository.signIn(
        email: goodEmail,
        password: goodPassword,
      );

      final AuthSession session = result.valueOrElse(_impossible);
      expect(session.userId, kSeedUserId);
      expect(session.role, kSeedUserRole);
      // NOT the address that was typed. There is no server that accepted it, so
      // reporting it back would claim a verification that never happened.
      expect(session.email, isNot(goodEmail));
      expect(session.email, kSeedEmail);
    });

    test('returns the SAME session object on a second sign-in', () async {
      // Two calls must not mint two sessions: the session rides into bloc state,
      // and a fresh-but-equal one would still be a state change by identity
      // wherever anything compares with `identical`.
      final Result<AuthSession> first = await repository.signIn(
        email: goodEmail,
        password: goodPassword,
      );
      final Result<AuthSession> second = await repository.signIn(
        email: goodEmail,
        password: goodPassword,
      );

      expect(
        identical(
          first.valueOrElse(_impossible),
          second.valueOrElse(_impossible),
        ),
        isTrue,
      );
    });

    test('refuses a blank email with a typed validation failure', () async {
      final Result<AuthSession> result = await repository.signIn(
        email: '',
        password: goodPassword,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrElse(_impossibleFailure).kind,
        FailureKind.validation,
      );
      expect(
        result.failureOrElse(_impossibleFailure).message,
        kRequiredMessage,
      );
    });

    test('refuses a malformed address the same way', () async {
      final Result<AuthSession> result = await repository.signIn(
        email: 'david@evangelion',
        password: goodPassword,
      );

      expect(
        result.failureOrElse(_impossibleFailure).kind,
        FailureKind.validation,
      );
    });

    test('refuses a short password with the prototype\'s own message', () async {
      // `LoginScreen.tsx:52`, verbatim — the same string the form's helper text
      // shows, so a player who sees it after pressing "Sign in" is reading the
      // sentence they would have read while typing.
      final Result<AuthSession> result = await repository.signIn(
        email: goodEmail,
        password: 'short',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrElse(_impossibleFailure).message,
        kShortPasswordMessage,
      );
    });

    test('does not write the session when it refuses', () async {
      await repository.signIn(email: goodEmail, password: 'short');

      final Result<AuthSession> current = await repository.getCurrentSession();

      expect(
        current.isFailure,
        isTrue,
        reason: 'a refused sign-in must leave the app exactly as it was',
      );
    });

    test('never throws, whatever it is handed', () async {
      // The LSP row in AGENT_CONTEXT §3, as an assertion rather than a promise.
      for (final (String, String) credentials in <(String, String)>[
        ('', ''),
        ('   ', '   '),
        ('not-an-email', ''),
        ('a@b.co', 'ok'),
        ('david@evangelion.app', 'short'),
      ]) {
        await expectLater(
          repository.signIn(email: credentials.$1, password: credentials.$2),
          completes,
          reason: 'threw for ${credentials.$1}/${credentials.$2}',
        );
      }
    });

    test('does not validate the address by trimming it away first', () async {
      // `LoginCredentials.from` trims. The repository is handed raw strings by
      // the use case, so it trims too — and a value that is *only* whitespace
      // must still be refused rather than becoming valid.
      final Result<AuthSession> result = await repository.signIn(
        email: '   ',
        password: goodPassword,
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('FakeAuthRepository — the rest of the port', () {
    late FakeAuthRepository repository;

    setUp(() => repository = FakeAuthRepository());

    test(
      'getCurrentSession fails before a sign-in and succeeds after',
      () async {
        expect((await repository.getCurrentSession()).isFailure, isTrue);

        await repository.signIn(email: goodEmail, password: goodPassword);

        expect((await repository.getCurrentSession()).isSuccess, isTrue);
      },
    );

    test(
      'getCurrentSession returns the session that was signed in to',
      () async {
        final Result<AuthSession> signedIn = await repository.signIn(
          email: goodEmail,
          password: goodPassword,
        );
        final Result<AuthSession> current = await repository
            .getCurrentSession();

        expect(
          current.valueOrElse(_impossible),
          signedIn.valueOrElse(_impossible),
        );
      },
    );

    test('signOut ends the session', () async {
      await repository.signIn(email: goodEmail, password: goodPassword);
      final Result<void> result = await repository.signOut();

      expect(result.isSuccess, isTrue);
      expect((await repository.getCurrentSession()).isFailure, isTrue);
    });

    test(
      'signOut on a fresh repository succeeds rather than failing',
      () async {
        // A sign-out with nothing to end is not an error. Failing it would make
        // `AuthBloc`'s sign-out path report a problem the reader can do nothing
        // about, and the session is already in the state it is asking for.
        expect((await repository.signOut()).isSuccess, isTrue);
      },
    );

    test('two repositories do not share a session', () async {
      // The in-memory field is per instance. A `static` would make one test's
      // sign-in another's fixture — which is the failure a
      // `shared_preferences` backing store would *not* have, and therefore the
      // one worth catching while the fake is in place.
      final FakeAuthRepository other = FakeAuthRepository();
      await repository.signIn(email: goodEmail, password: goodPassword);

      expect((await other.getCurrentSession()).isFailure, isTrue);
    });
  });
}

/// A session that cannot be real, for `valueOrElse`.
final AuthSession _impossible = AuthSession(
  userId: '',
  email: '',
  displayName: '',
  initials: '',
  createdAt: _epoch,
);

/// The epoch, so a "cannot be real" session has a [DateTime] without reaching
/// for a clock.
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// A failure that cannot be real, for `failureOrElse`.
const Failure _impossibleFailure = Failure(
  kind: FailureKind.unknown,
  message: 'impossible',
);
