import 'package:evangelion/core/common/result.dart';

/// A single unit of application behaviour, from presentation to domain.
///
/// Two properties are load-bearing. One is enforced by the type; the other is
/// house style, and the difference is worth stating rather than blurring:
///
/// 1. **It returns a [Result]; it never throws — enforced by the type.** A
///    repository implementation can hand back a [Failure] for every fault and
///    nothing escapes across the seam (AGENT_CONTEXT §3, the LSP row).
/// 2. **It is a callable object — convention, not enforcement.** Invoke it as
///    `usecase(params)`, not `usecase.execute(params)`: the method is named
///    `call`, so a bare expression already reads as an action, and there is no
///    `execute` alias. Nothing *forbids* an implementation from also declaring
///    one — `abstract interface class` constrains what an implementation must
///    provide, not what it may add. What the type does enforce is the call
///    site: `execute` does not exist through a `UseCase<In, Out>` or
///    `NoParamsUseCase<Out>` reference. So renaming the seam breaks every fake
///    in the tree as a **compile error**, not as a failing test — which means
///    review the addition of an `execute`, do not expect a gate to reject it.
///
/// [In] is whatever the caller must supply; [Out] is what the operation
/// produces. [In] = `void` means "nothing", which [NoParamsUseCase] spells out
/// properly.
///
/// `abstract interface class`, not `abstract class`: implementations `implement`
/// this, they never `extend` it. That keeps the contract free of inherited
/// state and stops a use case being subclassed into something that is no longer
/// one use case.
abstract interface class UseCase<In, Out> {
  /// Runs the use case.
  ///
  /// Returns [Result.success] with the produced value, or [Result.failure]
  /// with a typed [Failure] — never a thrown exception and never a bare value.
  Future<Result<Out>> call(In params);
}

/// A [UseCase] that needs nothing from the caller.
///
/// This is **not** a subtype of `UseCase<void, Out>`, and it cannot be. Dart's
/// function subtyping requires a subtype to accept at least as many positional
/// parameters as its supertype, so
/// `Future<Result<Out>> Function()` is not a subtype of
/// `Future<Result<Out>> Function(void)`, and an `extends` clause is rejected
/// outright:
///
/// ```text
/// 'NoParamsUseCase.call' ('Future<Result<Out>> Function()') isn't a valid
/// override of 'UseCase.call' ('Future<Result<Out>> Function(void)')
/// ```
///
/// The only way to "keep" the inheritance — declaring the override as
/// `call([void params])` — makes the call site `usecase()` fail with
/// "1 positional argument expected by 'call', but 0 found", because a `void`
/// parameter is treated as required at the call site. That trades a broken
/// declaration for a broken invocation, so neither form is worth having.
///
/// The structural relationship is still there for the reader: a
/// `NoParamsUseCase<Out>` is the `UseCase<In, Out>` whose [In] is nothing.
/// Anything that genuinely needs to accept both shapes should accept a
/// `Future<Result<Out>> Function()` closure, which both satisfy.
abstract interface class NoParamsUseCase<Out> {
  /// Runs the use case with no input.
  ///
  /// Returns [Result.success] with the produced value, or [Result.failure]
  /// with a typed [Failure].
  Future<Result<Out>> call();
}
