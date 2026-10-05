/// Where the sign-in form's state lives, and who owns it.
///
/// AGENT_CONTEXT §6, recorded decision 10: `LoginScreen.tsx:49-52` writes the
/// email field's focus and the password field's error as **literals** — a field
/// that is always drawn focused and an error the reader cannot cause. That is
/// prototype defect #10. This bloc exists so the second one becomes state rather
/// than a string baked into a widget tree.
///
/// ## WHAT THE BLOC OWNS
///
/// * **the typed values** — so validation runs on every keystroke rather than on
///   submit, which is the whole difference between a live form and a post-mortem;
/// * **per-field errors** — the literal's replacement. `passwordError` becomes the
///   exact string the prototype hard-coded, now derived from what was typed;
/// * **which fields have been touched** — so a blank field is not red before the
///   reader has typed in it. Without this, `LoginPage` would have to make that
///   judgement in `build`, and §6 forbids logic in a widget;
/// * **the submission status**, because "can this button be pressed" is a question
///   about state, and answering it in the widget is how a double-tap ships;
/// * **password visibility** — the prototype's `useState(showPw)` at
///   `LoginScreen.tsx:6`, moved somewhere it can be asserted;
/// * **the repository's failure**, so `LoginPage` renders a message rather than
///   dropping it.
///
/// ## WHAT IT DELIBERATELY DOES **NOT** OWN: FOCUS
///
/// The prototype's `focused` literal is **removed, not relocated**, and the
/// reason is worth stating because the instruction behind defect #10 could be
/// read either way.
///
/// `EvaTextField` already reads a real `FocusNode` through its own
/// `ListenableBuilder` and derives its rim from `focusNode.hasFocus`. That is
/// Phase 3's own fix for the same defect — `eva_text_field.dart`'s doc names
/// defect #10 explicitly. Mirroring it into a bloc field would leave **two
/// sources of truth for one fact**, and this repository has recorded twice why
/// that class of bug is invisible: an off-by-one in `orbGroupFor` hands
/// `/settings` the Profile orbs and *nothing fails*, and `Failure`'s excluded
/// `details` field exists precisely because a value outside an equality contract
/// reads as a state change.
///
/// It is not actable either. `EvaTextField` owns its `FocusNode` privately and
/// exposes no handle, so a bloc flag meaning "focus the email field" would have
/// nothing to obey it — decoration that only looks load-bearing. So the claim is
/// the honest one: **the literal is gone, real focus drives the field, and the
/// bloc owns everything the literal stood in for that was not focus.**
///
/// ## AND THE STATE IS ONE CLASS, NOT A SEALED SET
///
/// `bloc_test` asserts whole states, so a sealed hierarchy would make every
/// assertion reach into a subtype for one field. A single [AuthState] with an
/// exhaustive [AuthSessionStatus] keeps the session question machine-checkable —
/// [AuthState.isSignedIn] and [AuthState.canSubmit] switch over the enum with no
/// `default` — while the form's independent fields stay plain data.
library;

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_bloc.freezed.dart';

/// Where the session is, as far as the UI is concerned.
///
/// Deliberately **not** named `AuthStatus`: that name belongs to the
/// one-member interface in `core/navigation/auth_status.dart` that the navigation
/// guard asks (AGENT_CONTEXT §9, decision 9). Two same-named types meaning "is
/// there a session" and "what is the form doing" is a trap at every import.
enum AuthSessionStatus {
  /// Nothing has been decided yet — the state a cold launch starts in.
  ///
  /// Distinct from [signedOut] rather than a synonym for it. The guard asks
  /// [AuthState.isSignedIn] on a cold launch, so a bloc that defaulted to
  /// [signedIn] would let the app skip `/login` entirely; and a default of
  /// [signedOut] would be a *claim* about the session made before anything has
  /// looked for one.
  unknown,

  /// No session, and the reader is looking at the form.
  signedOut,

  /// A sign-in is in flight. The form is disabled.
  signingIn,

  /// There is a session.
  signedIn,
}

/// Everything [AuthState] can be asked. Sealed, so adding an event is a
/// compile error everywhere it is handled.
///
/// ## EACH EVENT IS A `freezed` CLASS AND THE BASE OWNS NOTHING BUT THE
/// ## CONSTRUCTOR
///
/// The base used to extend `Equatable` and return `const []` from `props`. It does
/// not now: each event below is a `freezed` class whose `==` is derived from its
/// constructor, so there is no `props` list for a new event to forget — which was
/// the whole of the risk this shape carried (see [HomeEvent] for the longer
/// version of the same argument).
///
/// **The generated `_$AuthEvent` mixin is deliberately unused.** `freezed` emits a
/// mixin for the base of a `sealed` class whether or not anything mixes it in, and
/// the alternative — leaving this base un-annotated, as `Result<T>` is in
/// `core/common/result.dart` — trades ~15 lines of generated code nobody reads for
/// a base that does not advertise a contract it does not honour. The cost is
/// bounded and confined to a file marked `GENERATED CODE - DO NOT MODIFY`; the
/// benefit is that the next event added here gets the same treatment as the ones
/// above without a second decision.
@freezed
sealed class AuthEvent with _$AuthEvent {
  const AuthEvent._();
}

/// Ask whether a session already exists, so a cold launch can restore instead of
/// forcing the form.
///
/// Dispatched once, when the composition root builds the bloc. Emits no state of
/// its own when there is none: the form is already what is on screen, and a
/// second emit would be a rebuild for nothing.
@freezed
final class AuthStarted extends AuthEvent with _$AuthStarted {
  /// Creates the start-up request.
  const AuthStarted() : super._();
}

/// The email field's text changed.
@freezed
final class AuthEmailChanged extends AuthEvent with _$AuthEmailChanged {
  /// The reader typed [email].
  const AuthEmailChanged(this.email) : super._();

  /// The whole field's text, not a delta.
  final String email;
}

/// The password field's text changed.
@freezed
final class AuthPasswordChanged extends AuthEvent with _$AuthPasswordChanged {
  /// The reader typed [password].
  const AuthPasswordChanged(this.password) : super._();

  /// The whole field's text, not a delta.
  ///
  /// **In the generated `==`, and never in a `toString`.** freezed derives the
  /// equality from the constructor, so two events carrying different secrets are
  /// different events — which is correct and what `Equatable.props` did. The
  /// printing is the other half, and it is the half that must not be generated.
  final String password;

  /// Never prints [password], and this declaration is what stops freezed
  /// generating one that does.
  ///
  /// `Equatable`'s default `toString` rendered every entry in `props`, so without
  /// an override the reader's typed password reached any log line, crash report,
  /// or failed `expect` that happened to print the event. Found by
  /// `test/core/common/secret_masking_test.dart`, which scans `lib/` for classes
  /// holding a `password` field — the same rule `LoginCredentials` and
  /// `AuthState` already honour, and the reason this event had quietly become the
  /// third class that did not.
  ///
  /// **freezed skips a member the class declares itself**, verified by generation
  /// rather than by reading its documentation: this class's generated part contains
  /// an `==`, a `hashCode` and a `copyWith` and **no** `toString`. Deleting these
  /// five lines is the mutation that gate exists to catch, and it turns it red.
  @override
  String toString() => 'AuthPasswordChanged(password: ********)';
}

/// The show/hide-password control was activated.
@freezed
final class AuthPasswordVisibilityToggled extends AuthEvent
    with _$AuthPasswordVisibilityToggled {
  /// Creates the toggle request.
  const AuthPasswordVisibilityToggled() : super._();
}

/// The reader pressed "Sign in" — or submitted the form from the keyboard, which
/// is the same act through a different control.
@freezed
final class AuthSubmitted extends AuthEvent with _$AuthSubmitted {
  /// Creates the submit request.
  const AuthSubmitted() : super._();
}

/// The reader asked to sign out.
@freezed
final class AuthSignedOut extends AuthEvent with _$AuthSignedOut {
  /// Creates the sign-out request.
  const AuthSignedOut() : super._();
}

/// The sign-in form, as one immutable value.
///
/// Every field has a `const` default, so the bloc can emit `const AuthState()` for
/// "nothing has happened" and a test can compare whole states without naming nine
/// arguments.
///
/// ## WHY THE GENERATED `copyWith` IS **SWITCHED OFF**
///
/// `@Freezed(copyWith: false)`, and this is the one state in the migration where
/// freezed's `copyWith` was declined rather than adopted.
///
/// The hand-rolled `copyWith` it replaces took **six** parameters and carried the
/// four nullable fields — `emailError`, `passwordError`, `formError`, `session` —
/// by copying them verbatim. That exclusion was the point, and the argument is the
/// one its own doc used to make: a `String? = null` parameter cannot express "clear
/// it", so a field that must be cleared is written by exactly one writer that
/// builds the whole state. freezed's generated `copyWith` is precisely the
/// mechanism that doc names as rejected — **"the fix is not sentinel objects or
/// casts"** — and it is a *wider* one: it takes all ten fields and its sentinel
/// defaults make `copyWith(emailError: null)` **clear** the error.
///
/// Nothing in `lib/` or in `test/` calls it that way, so behaviour is identical
/// either way today. The decision is about what the type permits: with
/// `copyWith` switched off, "the four nullable fields have exactly one writer" is
/// **mechanical** — the method physically cannot name them — rather than a
/// convention every future caller has to remember. `withFormError` below is the
/// second writer, and it exists precisely because `formError` is the one nullable
/// field a second code path legitimately writes.
///
/// **Rejected: adopting the generated one.** It is one fewer method and it is what
/// freezed emits for every other class here, and the answer is that the six
/// parameters are not the value — the *exclusion* is, and it is worth more than the
/// twelve lines it costs. See AGENT_CONTEXT §2.1 hazard 3 and decision 97.
///
/// ## `toString` IS DECLARED, AND THAT IS WHAT KEEPS THE SECRET OUT
///
/// freezed generates one for every class that does not declare its own, and its
/// generated `toString` lists **every** property. One of the ten is [password].
/// The override below is the whole defence, freezed honours it, and
/// `test/core/common/secret_masking_test.dart` is the structural half that says so
/// for every secret-holder in `lib/` rather than for this class alone.
@Freezed(copyWith: false)
final class AuthState with _$AuthState {
  /// A form state.
  const AuthState({
    this.status = AuthSessionStatus.unknown,
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.emailTouched = false,
    this.passwordTouched = false,
    this.emailError,
    this.passwordError,
    this.formError,
    this.session,
  });

  /// Where the session is. See [AuthSessionStatus].
  final AuthSessionStatus status;

  /// The email field's text.
  final String email;

  /// The password field's text.
  ///
  /// Never logged and never printed — [toString] is overridden below. This is the
  /// one state field a reader would mind seeing in a crash report.
  final String password;

  /// Whether the password is shown in the clear.
  final bool isPasswordVisible;

  /// Whether the email field has been edited at least once.
  final bool emailTouched;

  /// Whether the password field has been edited at least once.
  final bool passwordTouched;

  /// What is wrong with the address, or `null`.
  ///
  /// `null` until the reader has touched the field **or** a submit was attempted.
  /// That rule is applied by the bloc rather than by this getter, so the value
  /// here and the value that produced it cannot disagree.
  final String? emailError;

  /// What is wrong with the password, or `null`. Same rule as [emailError].
  final String? passwordError;

  /// A failure belonging to no single field — the repository's own message.
  ///
  /// Separate from the field errors because it has to be announced once rather
  /// than attached to a box, and because clearing one must not clear the other:
  /// retyping a password must not erase the last attempt's answer.
  final String? formError;

  /// The session, when [status] is [AuthSessionStatus.signedIn].
  final AuthSession? session;

  /// Whether there is a session. A pure read — see `AuthStatus.isAuthenticated`
  /// for the contract the navigation guard relies on.
  bool get isSignedIn => status == AuthSessionStatus.signedIn;

  /// Whether a sign-in is in flight.
  bool get isBusy => status == AuthSessionStatus.signingIn;

  /// Whether the fields would pass validation, ignoring whether they have been
  /// touched.
  ///
  /// "This form is wrong" and "this box is red" are different questions, and the
  /// prototype's bug was conflating them — `error="That password's too short"` on
  /// a field nobody had typed into.
  bool get isValid => validateLogin(email: email, password: password).isValid;

  /// Whether the "Sign in" control can be activated.
  ///
  /// False while busy, so a second press cannot start a second attempt; false
  /// with an empty field, because there is nothing to submit; and false while
  /// either field is in error, which means a reader with a three-character
  /// password cannot press the button to be told why. That last part is
  /// deliberate — the error is already on screen, live, as they type.
  bool get canSubmit =>
      !isBusy && email.trim().isNotEmpty && password.isNotEmpty && isValid;

  /// [next] with [formError] set, and nothing else changed.
  ///
  /// ## WHY THIS IS A METHOD AND NOT A `copyWith` PARAMETER
  ///
  /// A `String? formError = null` parameter cannot express "clear it": `null`
  /// means both "leave it" and "set it to null", so a `copyWith(formError: null)`
  /// would silently keep the old error. That is not hypothetical — it is exactly
  /// the bug this class's own first version had, where a field error could never
  /// be cleared and the form accused the reader of a mistake they had fixed.
  ///
  /// The fix is not sentinel objects or casts — see the class doc for why the
  /// generated sentinel `copyWith` is switched off rather than adopted. It is that
  /// the four nullable fields — `emailError`, `passwordError`, `formError`,
  /// `session` — are written by exactly one writer, [AuthBloc._revalidated],
  /// which builds the whole state, plus this method. A writer that can only be
  /// wrong in one place is worth more than a writer that is right in every place
  /// it is called from.
  ///
  /// Its own method because `formError` is the one nullable field a **second**
  /// code path legitimately writes: it is the repository's answer rather than a
  /// verdict derived from the two typed values, so folding it into [copyWith]
  /// would put a cached judgement next to computed ones.
  AuthState withFormError(String? formError) => AuthState(
    status: status,
    email: email,
    password: password,
    isPasswordVisible: isPasswordVisible,
    emailTouched: emailTouched,
    passwordTouched: passwordTouched,
    emailError: emailError,
    passwordError: passwordError,
    formError: formError,
    session: session,
  );

  /// [next] with the six fields this state does not vary changed.
  ///
  /// ## THE HAZARD IS STILL REAL AND THE METHOD IS STILL NEEDED
  ///
  /// `null` on any of these six still means "leave it", so nothing here can clear a
  /// field — and that is the intent, not an oversight: the four nullable fields are
  /// not parameters at all (class doc), and the six that are here are non-nullable
  /// or have no "clear it" meaning. `AuthBloc` calls this from four handlers, all
  /// of which vary exactly one or two of these six, so every call site is inside
  /// what the method can express.
  AuthState copyWith({
    AuthSessionStatus? status,
    String? email,
    String? password,
    bool? isPasswordVisible,
    bool? emailTouched,
    bool? passwordTouched,
  }) => AuthState(
    status: status ?? this.status,
    email: email ?? this.email,
    password: password ?? this.password,
    isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
    emailTouched: emailTouched ?? this.emailTouched,
    passwordTouched: passwordTouched ?? this.passwordTouched,
    emailError: emailError,
    passwordError: passwordError,
    formError: formError,
    session: session,
  );

  /// Deliberately not the generated one, which freezed skips precisely because
  /// this declaration exists.
  ///
  /// A generated `toString` lists every property, and one of them is the reader's
  /// password. A bloc state is printed by `bloc_test` on every mismatch and by
  /// `flutter_bloc`'s debug transition logging, so the generated one would put a
  /// secret in a build's console as a matter of course. This prints the shape and
  /// the address — which is the one field a failing test usually needs.
  @override
  String toString() =>
      'AuthState(status: ${status.name}, email: $email, password: ********, '
      'emailError: $emailError, passwordError: $passwordError, '
      'formError: $formError, signedIn: $isSignedIn)';
}

/// The sign-in form's state machine.
///
/// ## NOTHING IS CAUGHT HERE, AND THAT IS A DECISION
///
/// `analysis_options.yaml` enables `avoid_catching_errors` and
/// `avoid_catches_without_on_clauses`, and the port promises never to throw
/// (AGENT_CONTEXT §3, LSP). So every arm here is a `Result` and there is no
/// `try`. If a real adapter ever breaks that promise the error reaches
/// `BlocObserver.onError` — the error console — which is strictly more useful
/// than a "something went wrong" the reader cannot act on, and it is the same
/// reasoning `AuthStatus` records for the guard refusing to catch.
///
/// ## AND THE SUBMIT GUARD IS NOT ONLY ABOUT `onSubmitted`
///
/// [_onSubmitted] drops the event while [AuthSessionStatus.signingIn]. In this
/// app the fake repository completes without yielding, so that window is empty
/// and the guard is unreachable through the real port — it exists because the
/// window opens the moment the repository does any work, which is the first thing
/// a real adapter will do. `auth_bloc_test.dart` holds the window open with a
/// use case that never completes, which is the only way to reach the guard at all.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Drives the form through [_signIn], [_getCurrentSession] and [_signOut].
  ///
  /// Takes the **use cases**, not the repository, so this file never names
  /// `FakeAuthRepository` (AGENT_CONTEXT §3, DIP) and a test can substitute a
  /// slow one without a class of its own.
  AuthBloc({
    required SignIn signIn,
    required GetCurrentSession getCurrentSession,
    required SignOut signOut,
  }) : this._(signIn, getCurrentSession, signOut);

  /// The real constructor.
  ///
  /// Positional and private, reached only by the redirect above, and that is the
  /// point: `this._signIn` in a **named** parameter would publish the parameter
  /// name `_signIn`, which no file outside this library could pass — so the
  /// natural spelling of this constructor is not a usable one. The redirect keeps
  /// the public signature readable and satisfies `prefer_initializing_formals`
  /// without an ignore.
  AuthBloc._(this._signIn, this._getCurrentSession, this._signOut)
    : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthEmailChanged>(_onEmailChanged);
    on<AuthPasswordChanged>(_onPasswordChanged);
    on<AuthPasswordVisibilityToggled>(_onVisibilityToggled);
    on<AuthSubmitted>(_onSubmitted);
    on<AuthSignedOut>(_onSignedOut);
  }

  final SignIn _signIn;
  final GetCurrentSession _getCurrentSession;
  final SignOut _signOut;

  /// Counts the session-ending events this bloc has handled.
  ///
  /// ## WHY A GENERATION AND NOT A `cancel()` ON THE EMITTER
  ///
  /// `_onSubmitted` holds an `await` across a `Future` it does not own, and a
  /// reader can end the session while that await is open. Measured without the
  /// counter: dispatch a submit, let it reach the await, dispatch `AuthSignedOut`,
  /// let it settle, then resolve the sign-in — the bloc emits `signedOut` and
  /// **then `signedIn`**, so the reader is left signed in by an attempt they
  /// abandoned, with `signOut` having run exactly once.
  ///
  /// Two alternatives were rejected rather than weighed:
  ///
  /// * **`Emitter.isDone` / cancelling the handler.** That answers "did *this*
  ///   emitter stop", which is a statement about the bloc's lifecycle rather than
  ///   about the session. A sign-out does not close the submitting handler; the
  ///   handler is perfectly alive and simply holds an answer that is no longer
  ///   wanted.
  /// * **A `bool _signedOut` flag.** Correct, but it cannot express the general
  ///   case, and the general case is one event away: a second `AuthSignedOut`, a
  ///   future `AuthStarted` restoring a session under an in-flight sign-in, a
  ///   "cancel this attempt" control. A counter distinguishes "the session changed
  ///   while you were away" from any specific way it changed, and costs one
  ///   integer.
  ///
  /// Incremented by [_onSignedOut] alone, because that is the only handler that
  /// ends a session. Read by [_onSubmitted] alone, because that is the only
  /// handler that awaits across a session change.
  ///
  /// **MEDIUM, not HIGH, and the reason is recorded rather than remembered:**
  /// `rg 'AuthSignedOut' lib/` finds the declaration and the handler and nothing
  /// that dispatches it, so no shipping control reaches this path today. It becomes
  /// reachable the moment a sign-out button exists. `auth_bloc_test.dart` drives it
  /// with a held-open `Completer` so the answer is pinned before the control is.
  int _sessionGeneration = 0;

  /// Answers the one question a cold launch asks: is anybody already signed in?
  ///
  /// "No session" and "the check failed" are the same answer here, and the port's
  /// doc says a real adapter must not make them differ — so both land on
  /// [AuthSessionStatus.signedOut].
  ///
  /// **It emits rather than leaving [AuthSessionStatus.unknown] standing.**
  /// That was the first version, and it left [AuthSessionStatus.signedOut]
  /// reachable only by pressing "Sign in" with a bad password or by signing out —
  /// so "no session" and "the form is up" were different states depending on how
  /// the reader arrived, and `unknown` outlived the only moment it described.
  /// `auth_bloc_test.dart` pins the transition instead.
  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final Result<AuthSession> current = await _getCurrentSession();
    switch (current) {
      case Success<AuthSession>(:final AuthSession value):
        emit(AuthState(status: AuthSessionStatus.signedIn, session: value));
      case FailureResult<AuthSession>():
        emit(const AuthState(status: AuthSessionStatus.signedOut));
    }
  }

  void _onEmailChanged(AuthEmailChanged event, Emitter<AuthState> emit) {
    emit(_revalidated(state.copyWith(email: event.email, emailTouched: true)));
  }

  void _onPasswordChanged(AuthPasswordChanged event, Emitter<AuthState> emit) {
    emit(
      _revalidated(
        state.copyWith(password: event.password, passwordTouched: true),
      ),
    );
  }

  void _onVisibilityToggled(
    AuthPasswordVisibilityToggled event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  Future<void> _onSubmitted(
    AuthSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    // The double-fire guard. See the class doc.
    if (state.isBusy) {
      return;
    }

    // Held because neither the invalid branch nor the failure branch may invent a
    // session status: an attempt that does not happen, or that is refused, says
    // nothing about whether there is a session. The first version of this set
    // `signedOut` on both, which made a refused sign-in look like a state change
    // even from `unknown` — and `unknown` is what the state is when a test (or a
    // future caller) skips `AuthStarted`.
    final AuthSessionStatus before = state.status;

    if (!state.isValid) {
      // A submit reveals **both** fields at once. The reader asked to be told, so
      // answering only the field they happened to be standing in would be less
      // than they asked for. The password is kept verbatim so the reader does not
      // have to retype it.
      emit(
        _revalidated(
          state.copyWith(emailTouched: true, passwordTouched: true),
          revealAll: true,
        ).withFormError(null),
      );
      return;
    }

    // The form error is dropped here, not on the next keystroke: this is a new
    // attempt, and the previous attempt's answer no longer describes it.
    emit(
      _revalidated(
        state.copyWith(status: AuthSessionStatus.signingIn),
        revealAll: true,
      ).withFormError(null),
    );

    // Read **before** the `await` and checked **after** it. See [_sessionGeneration].
    final int generation = _sessionGeneration;

    final Result<AuthSession> result = await _signIn(
      SignInParams(email: state.email, password: state.password),
    );

    if (generation != _sessionGeneration) {
      // A sign-out landed while this attempt was in flight, so its answer
      // describes a session the reader has already ended. Returning is the whole
      // fix: the alternative — applying it — leaves the bloc `signedIn` after a
      // `signOut` that ran, with `signOuts == 1`.
      return;
    }

    switch (result) {
      case Success<AuthSession>(:final AuthSession value):
        emit(AuthState(status: AuthSessionStatus.signedIn, session: value));
      case FailureResult<AuthSession>(:final Failure failure):
        emit(
          _revalidated(
            state.copyWith(status: before),
            revealAll: true,
          ).withFormError(failure.message),
        );
    }
  }

  /// Ends the session.
  ///
  /// The result is **not** switched on. With no auth endpoint a sign-out cannot
  /// fail, and the session is gone whether or not it could — so a failure arm
  /// here would be a branch nothing can reach. When a real adapter arrives this
  /// is the line that grows one, and [AuthRepository.signOut] already returns
  /// `Result<void>` so nothing else changes.
  Future<void> _onSignedOut(
    AuthSignedOut event,
    Emitter<AuthState> emit,
  ) async {
    // Before the `await`, not after: the point is that any in-flight attempt is
    // stale the moment the reader asks to sign out, whether or not the repository
    // has finished clearing the session.
    _sessionGeneration++;
    await _signOut();
    emit(const AuthState(status: AuthSessionStatus.signedOut));
  }

  /// Builds the state that follows [next] with its errors recomputed.
  ///
  /// A field's error appears when the reader has touched it, or when [revealAll]
  /// is set by a submit. This builds the **whole** state rather than copying, and
  /// that is deliberate — see [AuthState]'s doc for why the nullable
  /// fields are not its parameters. It also means `emailError` and
  /// `passwordError` can never disagree with the values that produced them: the
  /// state *is* the rule applied, not a cached judgement a second code path could
  /// write.
  AuthState _revalidated(AuthState next, {bool revealAll = false}) {
    final LoginValidation verdict = validateLogin(
      email: next.email,
      password: next.password,
    );
    return AuthState(
      status: next.status,
      email: next.email,
      password: next.password,
      isPasswordVisible: next.isPasswordVisible,
      emailTouched: next.emailTouched,
      passwordTouched: next.passwordTouched,
      emailError: (next.emailTouched || revealAll) ? verdict.emailError : null,
      passwordError: (next.passwordTouched || revealAll)
          ? verdict.passwordError
          : null,
      formError: next.formError,
      session: next.session,
    );
  }
}
