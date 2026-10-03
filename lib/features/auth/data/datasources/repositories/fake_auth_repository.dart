import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/network/interceptors/identity_headers.dart';
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
/// ## AND WHY THE USER ID IS CHECKED HERE AS WELL AS IN `buildApiDio`
///
/// Two places decide identity and both call `isValidUserId`: the composition
/// root, which throws because a mistyped seed is a programmer error, and here,
/// which returns a `Failure` because a repository **never throws across its
/// seam**. Same function, same reason for the difference — the layer decides what
/// kind of wrong it is.
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

    // The backend does not check this — a non-UUID `X-User-Id` is accepted with
    // 200 and echoed back (D2) — so the client does, and this is the second of
    // the two places that decide identity. If the seed ever stopped being a
    // UUID, this is where it becomes a typed failure a caller can read, instead
    // of a header that mysteriously works.
    if (!isValidUserId(existing.userId)) {
      _session = null;
      return const Result<AuthSession>.failure(
        Failure(
          kind: FailureKind.validation,
          message: 'The signed-in identity is malformed.',
        ),
      );
    }

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
