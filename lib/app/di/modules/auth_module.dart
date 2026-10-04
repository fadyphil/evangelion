import 'package:evangelion/app/di/injection.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:injectable/injectable.dart';

/// The `auth` feature's registrations.
///
/// ## WHAT IS HERE, AND WHAT IS NOT, AND WHY THE LINE IS WHERE IT IS
///
/// **Here:** the store, the repository and the three use cases. All five are pure
/// Dart, so all five are reachable from `injection.dart`'s graph without violating
/// the Flutter-free rule AGENT_CONTEXT §6 recorded decision 4 makes part of the
/// contract — `injection_test.dart` walks that whole transitive project-local
/// graph and fails on any Flutter import it reaches.
///
/// **Not here:** [`AuthBloc`]. `flutter_bloc` re-exports the framework's widget
/// layer alongside the bloc, and `bloc` itself is a transitive dependency this
/// project may not promote to a direct one — so a provider here would put
/// `package:flutter/material.dart` inside the composition root's closure. It is
/// registered by hand from `lib/app/di/navigation_injection.dart`, the
/// Flutter-permitted half of the graph, which is the fix already taken for the
/// router.
///
/// The split is not a preference. Phase 4 measured it: registering the router
/// from a module makes `verify_purity.sh` report seven violations, because
/// `auto_route_generator` names its output after the router's own file and emits
/// a `.gr.dart` beside it that imports all six feature pages.
///
/// ## THE REPOSITORY IS REGISTERED **AGAINST THE PORT**
///
/// [authRepository] returns `AuthRepository`, not `FakeAuthRepository`. That is
/// the substitution AGENT_CONTEXT §2 decision 3 depends on: when a real adapter
/// arrives, this provider's body changes and **nothing else in the app does** —
/// no use case, no bloc, no page names `FakeAuthRepository`. A
/// `FakeAuthRepository`-typed registration would make every one of those types
/// part of the graph and the swap a change to each of them.
@module
abstract class AuthModule {
  /// The in-memory session store.
  ///
  /// `@lazySingleton`, and the lifetime matters: the store *is* the session. A
  /// factory would hand out a fresh empty store per lookup and a signed-in
  /// reader would appear signed out, with no error anywhere to explain it.
  @lazySingleton
  AuthLocalDataSource get authLocalDataSource => AuthLocalDataSource();

  /// The one [AuthRepository] that ships.
  ///
  /// Typed as the port. See the class doc.
  @lazySingleton
  AuthRepository get authRepository =>
      FakeAuthRepository(getIt<AuthLocalDataSource>());

  /// Signs in.
  @lazySingleton
  SignIn get signIn => SignIn(getIt<AuthRepository>());

  /// Reads an existing session.
  @lazySingleton
  GetCurrentSession get getCurrentSession =>
      GetCurrentSession(getIt<AuthRepository>());

  /// Ends a session.
  @lazySingleton
  SignOut get signOut => SignOut(getIt<AuthRepository>());
}
