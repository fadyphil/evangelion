import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';

/// The **only** [AuthRepository] that ships, because there is no auth endpoint.
///
/// AGENT_CONTEXT §2, decision 3 fixes login as UI-only over a
/// `FakeAuthRepository`, and AGENT_CONTEXT §5 says why: identity on this backend
/// is three headers the client sets, and nothing validates any of them. So no
/// HTTP call appears in this class, and its absence is the specification — a
/// `DioAuthRepository` that posted credentials would post them to a route that
/// does not exist.
///
/// ## THE CREDENTIALS ARE STILL JUDGED, AND THAT IS THE PART THAT MATTERS
///
/// `signIn` runs the same `features/auth/domain` rules the form shows and
/// returns a typed [Failure] for anything they reject. Without that, the failure
/// path would be a branch nothing can reach and `AuthBloc`'s error state would be
/// untestable — which is the difference between a fake that is *substitutable*
/// (AGENT_CONTEXT §3, LSP) and one that is merely present.
///
/// ## AND THERE IS NO USER-ID CHECK HERE, WHICH USED TO BE CLAIMED TWICE
///
/// An earlier version carried a second `isValidUserId(existing.userId)` guard
/// here and a doc section titled "and why the user id is checked here as well as
/// in `buildApiDio`". Both are gone, and the reason is worth writing down because
/// it is recorded decision 14's own defect class arriving one decision late.
///
/// **The branch was unreachable.** `signIn` builds `_session ??= seedAuthSession(
/// createdAt: …)`, and `seedAuthSession` hard-codes `kSeedUserId` — a valid UUID —
/// with no injection point anywhere on this path. So `isValidUserId(existing
/// .userId)` was tautologically true, the `Failure` below it was unreachable text,
/// and **deleting the whole block turned nothing red**: a fixture describing a
/// state the system cannot produce, which is exactly what §9's decision 14 was
/// written to forbid.
///
/// `buildApiDio` is the only place the check can fire, and it is tested — a
/// malformed seed throws `ArgumentError` there, at composition, which is the right
/// layer for a programmer error. Recording "both are tested" for a check that
/// cannot execute is worse than not recording it, because the next reader counts
/// two places instead of one.
final class FakeAuthRepository implements AuthRepository {
  /// A repository over [source], which defaults to a fresh in-memory store.
  FakeAuthRepository([AuthLocalDataSource? source])
    : _source = source ?? AuthLocalDataSource();

  final AuthLocalDataSource _source;

  /// The one session this repository hands out.
  ///
  /// Held so that a second successful `signIn` returns the **identical** object
  /// rather than an equal one. The session rides into bloc state, and a fresh-but-
  /// equal instance would still read as a change to anything comparing by
  /// identity — which is exactly the class of bug `Failure`'s `details` exclusion
  /// documents one layer down.
  AuthSession? _session;

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async {
    final LoginValidation verdict = LoginCredentials.from(
      email: email,
      password: password,
    ).validation();

    if (!verdict.isValid) {
      // `firstError` rather than `emailError ?? passwordError` at this call
      // site: the field order is the form's field order, and it is written down
      // once on the getter.
      return Result<AuthSession>.failure(
        Failure(kind: FailureKind.validation, message: verdict.firstError!),
      );
    }

    final AuthSession existing = _session ??= seedAuthSession(
      createdAt: DateTime.now().toUtc(),
    );

    await _source.writeSession(existing);
    return Result<AuthSession>.success(existing);
  }

  @override
  Future<Result<AuthSession>> getCurrentSession() async {
    final AuthSession? stored = await _source.readSession();
    final AuthSession? session = _session ?? stored;
    if (session == null) {
      return const Result<AuthSession>.failure(
        Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
      );
    }
    return Result<AuthSession>.success(session);
  }

  @override
  Future<Result<void>> signOut() async {
    _session = null;
    await _source.clearSession();
    // Succeeds even with nothing to end: the session is already in the state the
    // caller is asking for, so reporting a failure would describe a problem the
    // reader cannot do anything about.
    return const Result<void>.success(null);
  }
}
