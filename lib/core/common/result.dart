import 'package:evangelion/core/common/failure.dart';
import 'package:fpdart/fpdart.dart';

/// The outcome of an operation that can fail: a `Right<T>` carrying the value,
/// or a `Left<Failure>` carrying a typed [Failure].
///
/// A `typedef` for `Either<Failure, T>`, which is a **sealed** class in fpdart
/// (`either.dart:39`). That is the property the whole error contract rests on:
/// a `switch` over a `Result` is an exhaustive switch *expression* with no
/// `default` arm, so the compiler enforces that both states are handled at
/// every seam rather than discovered at some later runtime.
///
/// ## WHY THE ALIAS, AND NOT A SPELL-OUT
///
/// `Result<Reading>` is one token where `Either<Failure, Reading>` is two, and
/// the shorter name is the one that appears in every repository signature. A
/// `typedef` is an alias, not a wrapper, so `Result<T>` and `Either<Failure, T>`
/// are the same type and a switch over the alias is still exhaustive — verified
/// before this file was committed.
///
/// ## WHAT CHANGED, AND WHAT THE DOC GOT WRONG
///
/// This replaced a 297-line hand-written type. The recorded reason for the
/// hand-written one was that "`sealed` + exhaustive switch is strictly stronger
/// than `dartz`'s `Either`" — but that comparison was made against **dartz**,
/// not against fpdart, whose `Either` is itself `sealed`. The claim was true of
/// dartz and irrelevant here.
///
/// ## WHAT fp_dart GIVES THAT THE HAND-WRITTEN TYPE NEVER HAD
///
/// * `flatMap`, so fallible steps chain without a pyramid.
/// * `traverse` / `sequence` / `rights` / `lefts` over collections.
/// * `Either.Do` for a readable multi-step computation.
/// * **Value-based equality on collections.** The hand-written `Success` fell
///   through to `==` on its payload, and `==` on a `List` is identity — so
///   `Success(<int>[1,2]) != Success(<int>[1,2])` was true of the old type and
///   is false of this one.
///
/// ## WHAT IT COSTS, MEASURED AGAINST 1.2.0
///
/// **`Right.operator ==` is `(other is Right) && other._value == _value`**
/// (`either.dart:572`) — it never mentions the type parameters. Because Dart's
/// generics are **covariant**, `Right<Failure,int>(1) == Right<Failure,num>(1)`
/// is `true`, and so is `Left<Failure,int>(f) == Left<Failure,Object>(f)`.
///
/// The hand-written type guarded on `runtimeType` for exactly this reason
/// (decision 131), and the repo has mutation tests behind that guard. A
/// `Result` inside bloc state that compares equal across a type change costs a
/// spurious emit and a rebuild.
///
/// **Subclassing `Right`/`Left` to restore the guard DOES NOT WORK**, and the
/// reason is worth recording because it looks like it should:
///
/// ```dart
/// final class Success<L, R> extends Right<L, R> { ... }
///
/// String f(Result<int> r) => switch (r) {
///   Success<Failure, int>(:final value) => ...,   // <-- compile error
///   Left<Failure, int>(:final value) => ...,
/// };   // 'Result<int>' is not exhaustively matched since it does not match
///       // the pattern 'Right<Failure, int>()'
/// ```
///
/// A subclass does not match the supertype's object pattern, so restoring the
/// equality guard **destroys the sealed exhaustiveness** — the property the
/// migration was undertaken to obtain. The two requirements are in direct
/// conflict and cannot both be met by subclassing.
///
/// ## WHERE THE TWO CONTRACTS MEET
///
/// [Failure] stays hand-written, and must. Three properties of it are not
/// fp_dart's to give:
///
/// * [Failure.details] is excluded from equality, so a mapper that rebuilds an
///   equivalent decoded body does not look like a state change inside bloc
///   state (`failure.dart:137`).
/// * [Failure.toString] deliberately omits `details`, so a server response
///   body never reaches a log line or a failed `expect` (`failure.dart:181`).
/// * [Failure.operator ==] guards on `runtimeType`, for the same covariance
///   reason above.
///
/// ## THE API, AND WHAT IT DELIBERATELY DOES NOT HAVE
///
/// **There is no `value` getter and no `getOrNull` in use across this app.**
/// Either would let a caller write `result.value` and silently turn a failure
/// into a `null` that surfaces three frames later in a widget build. Read a
/// `Result` with [`Either.fold`], or with [ResultUnwrap.valueOrElse] when you
/// have decided, in one word at the call site, that losing the failure is
/// acceptable.
typedef Result<T> = Either<Failure, T>;

/// The two unwrapping accessors, named so that discarding information is
/// written down at the call site rather than inferred from the shape of a
/// method name.
///
/// **There is deliberately no `fold` extension here.** fp_dart's `Either` ships
/// its own `fold`, and an extension member of the same name is *shadowed* by
/// the type's own member — it would compile, never be called, and give no
/// warning. So this library adds only what fp_dart does not already have.
///
/// ## READING A RESULT: USE `fold`, AND NOTE THE ARM ORDER
///
/// `Either.fold` takes its arguments **failure first**:
///
/// ```dart
/// final String label = result.fold(
///   (Failure f) => f.message,   // verbatim, never reworded
///   (Reading r) => r.reference,
/// );
/// ```
///
/// The hand-written type took `fold({onSuccess:, onFailure:})`, which named the
/// arms and could not be read in the wrong order. The positional form is
/// fp_dart's and is not being wrapped back up; the arm names live in the
/// closure parameter types.
extension ResultUnwrap<T> on Result<T> {
  /// The right's value, or [orElse] on a left.
  ///
  /// **This accessor discards the [Failure].** It is named so the discard is
  /// visible at the call site.
  ///
  /// [orElse] is typed as [T] on purpose, and that is the whole design. An
  /// unconstrained `<R>` looks more capable — it is what would let
  /// `result.valueOrElse(const CircularProgressIndicator())` compile against a
  /// `Result<Reading>` — but it is unsound. With `R` inferred from the
  /// fallback argument *and* the context type, `R` settles on `Widget` and the
  /// success arm runs `value as Widget`, which throws
  /// `type 'Reading' is not a subtype of type 'Widget'`. That conversion is
  /// only sound when the caller already holds a `Reading`, which is exactly the
  /// case in which they did not need a fallback.
  ///
  /// So the differing-arms case — a widget on one arm, a value on the other —
  /// does not compile here, and that is the honest outcome: it is not a
  /// conversion, it is a branch. Write the branch with `fold`, whose `R` is
  /// inferred from *both* arms and is therefore checked at both.
  ///
  /// Reach for `valueOrElse` when both arms really are the same type and the
  /// caller has decided, in one word at the call site, that losing the failure
  /// is acceptable.
  T valueOrElse(T orElse) => getOrElse((_) => orElse);

  /// The left's [Failure], or [orElse] on a right.
  ///
  /// The mirror of [valueOrElse] and the same caveat: it can discard the value.
  /// Mostly for asserting on the failure arm in tests and for logging.
  Failure failureOrElse(Failure orElse) =>
      match((Failure f) => f, (T _) => orElse);
}
