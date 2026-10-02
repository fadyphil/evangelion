import 'package:equatable/equatable.dart';
import 'package:evangelion/core/common/failure.dart';

/// The outcome of an operation that can fail: either a [Success] or a
/// [FailureResult] carrying a typed [Failure].
///
/// This type is the reason no repository ever throws across the seam
/// (AGENT_CONTEXT §3, the LSP row). A `ReadingRepository` implementation is
/// substitutable for any other precisely because both arms of the contract —
/// never throwing, always returning a `Result` — are enforced by the type, not
/// by convention.
///
/// ### Why sealed
///
/// `Result<T>` is `sealed` with exactly two subtypes, so the exhaustive
/// `switch` expressions below need no `default` arm. Add a third subtype and
/// this file stops compiling — which is the point. Every transformation is
/// written once, here, as a total function over the closed set of states,
/// instead of being re-derived as an `if`-chain at every call site
/// (AGENT_CONTEXT §4: no `if`-chains for state branching).
///
/// ### What this type deliberately does NOT have
///
/// There is **no `value` getter and no `getOrNull`**. Either would let a
/// caller write `result.value` and silently turn a [FailureResult] into a null
/// that surfaces three frames later in a widget build. The two unwrapping
/// accessors that do exist ([valueOrElse], [failureOrElse]) are named so the
/// information loss is written at the call site, and [fold] is the API a caller
/// should reach for first.
///
/// ### Where the "exactly two members" guarantee is proved
///
/// In this file, not in the test suite. Every `switch` below is an exhaustive
/// switch *expression* over a `sealed` type with no `default` arm, so adding a
/// third subtype breaks the build of `result.dart` itself — five independent
/// compile errors before a single test is compiled. `result_test.dart` restates
/// the same pattern in two local functions; that is useful documentation of the
/// property and it would catch the same change, but it adds nothing the
/// switches here do not already enforce.
sealed class Result<T> extends Equatable {
  const Result();

  /// The operation succeeded and produced [value].
  const factory Result.success(T value) = Success<T>;

  /// The operation failed, typed as [failure].
  ///
  /// Named `FailureResult` rather than `Failure` because [Failure] is already
  /// the type it carries.
  const factory Result.failure(Failure failure) = FailureResult<T>;

  /// Whether this result holds a value.
  bool get isSuccess => this is Success<T>;

  /// Whether this result holds a [Failure].
  bool get isFailure => this is FailureResult<T>;

  /// Applies [transform] to the success value, producing a [Result] of the
  /// transform's return type.
  ///
  /// [transform] is **not** run for a failure, and the [Failure] is carried
  /// across untouched — identity preserved, so `map` can never reclassify an
  /// error on its way through.
  ///
  /// This is the retyping primitive: `Result<int>.map((int v) => '$v')` is a
  /// `Result<String>`. Use it to cross a layer boundary without a cast.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(value: final value) => Success<R>(transform(value)),
    FailureResult<T>(:final failure) => FailureResult<R>(failure),
  };

  /// Applies [transform] to the failure, producing a [Result] of the same value
  /// type.
  ///
  /// [transform] is **not** run for a success, and the success value is carried
  /// across untouched. The realistic use is annotating a failure with context
  /// (which route it came from, what was being submitted) *without* changing
  /// its [Failure.kind] — the kind is the machine-readable contract, the
  /// message is what the player reads.
  Result<T> mapFailure(Failure Function(Failure failure) transform) =>
      switch (this) {
        Success<T>(:final value) => Success<T>(value),
        FailureResult<T>(:final failure) => FailureResult<T>(
          transform(failure),
        ),
      };

  /// Collapses both arms into a single value, so the caller never branches.
  ///
  /// This is the preferred way to read a [Result]. Exactly one of [onSuccess]
  /// or [onFailure] runs, and the other is never even called — which is what
  /// lets a caller omit side effects from the arm it does not take without
  /// guarding them.
  ///
  /// [R] is inferred from whichever arm the caller assigns to, so the two arms
  /// and the result share one static type:
  ///
  /// ```dart
  /// final String label = result.fold<String>(
  ///   onSuccess: (Reading r) => r.reference,
  ///   onFailure: (Failure f) => f.message,   // verbatim, never reworded
  /// );
  /// ```
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    FailureResult<T>(:final failure) => onFailure(failure),
  };

  /// The success value, or [orElse] if this is a failure.
  ///
  /// **This accessor discards the [Failure].** It is named so the discard is
  /// visible at the call site.
  ///
  /// [orElse] is typed as [T] on purpose, and that is the whole design. An
  /// unconstrained `<R>` looks more capable — it is what lets
  /// `result.valueOrElse(const CircularProgressIndicator())` compile against a
  /// `Result<Reading>` — but it is unsound. With `R` inferred from the fallback
  /// argument *and* the context type, `R` settles on `Widget` and the success
  /// arm runs `value as Widget`, which throws
  /// `type 'Reading' is not a subtype of type 'Widget'`. That conversion is only
  /// sound when the caller already holds a `Reading`, which is exactly the case
  /// in which they did not need a fallback.
  ///
  /// So the differing-arms case — a widget on one arm, a value on the other —
  /// does not compile here, and that is the honest outcome: it is not a
  /// conversion, it is a branch. Write the branch with [fold], whose [R] is
  /// inferred from *both* arms and is therefore checked at both:
  ///
  /// ```dart
  /// final Widget child = result.fold<Widget>(
  ///   onSuccess: (Reading r) => ReadingView(r),
  ///   onFailure: (Failure f) => const CircularProgressIndicator(),
  /// );
  /// ```
  ///
  /// Reach for `valueOrElse` when both arms really are the same type and the
  /// caller has decided, in one word at the call site, that losing the failure
  /// is acceptable.
  T valueOrElse(T orElse) => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => orElse,
  };

  /// The [Failure], or [orElse] if this is a success.
  ///
  /// The mirror of [valueOrElse] and the same caveat: it can discard the value.
  /// Mostly for asserting on the failure arm in tests and for logging.
  Failure failureOrElse(Failure orElse) => switch (this) {
    Success<T>() => orElse,
    FailureResult<T>(:final failure) => failure,
  };
}

/// The success arm of [Result].
///
/// `final` so the sealed set cannot grow past two members without a deliberate
/// change here.
final class Success<T> extends Result<T> {
  /// Wraps [value] as a success.
  const Success(this.value);

  /// The value the operation produced.
  final T value;

  @override
  List<Object?> get props => <Object?>[value];

  @override
  String toString() => 'Success<$T>($value)';
}

/// The failure arm of [Result].
///
/// Carries a typed [Failure], never a bare `String` and never a thrown
/// exception, so the caller cannot get the failure detail without also getting
/// its classification.
final class FailureResult<T> extends Result<T> {
  /// Wraps [failure] as a failure of an operation that would have produced a [T].
  const FailureResult(this.failure);

  /// What went wrong.
  final Failure failure;

  @override
  List<Object?> get props => <Object?>[failure];

  @override
  String toString() => 'FailureResult<$T>($failure)';
}
