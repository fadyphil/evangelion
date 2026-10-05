import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 5xx with the shape AGENT_CONTEXT §5 documents.
const Failure boom = Failure(
  kind: FailureKind.server,
  message: 'internal server error',
  statusCode: 500,
);

/// Builds a [Failure] the compiler cannot canonicalise.
///
/// `const` arguments to the same constructor call are **canonicalised**: two
/// `const Failure(kind: k, message: m)` expressions compile down to one
/// instance, so `expect(a, b)` between them is really `identical(a, b)` and
/// passes against *any* `props`, an empty list included. Threading the fields
/// through parameters makes each call a genuinely distinct object, so the
/// comparison exercises equality rather than identity.
Failure _builtFailure(FailureKind kind, String message, {int? statusCode}) =>
    Failure(kind: kind, message: message, statusCode: statusCode);

/// [Success] via a parameter, for the same reason as [_builtFailure].
///
/// Generic in [T] rather than fixed at `int` because the hash-agreement test
/// needs `Success<String>` — and building that through an `int`-only helper is
/// how the generic-parameter check would have been written by accident.
Success<T> _builtSuccess<T>(T value) => Success<T>(value);

/// [FailureResult] via a parameter, for the same reason as [_builtFailure], and
/// generic in [T] for the same reason as [_builtSuccess].
FailureResult<T> _builtFailureResult<T>(Failure failure) =>
    FailureResult<T>(failure);

void main() {
  group('construction', () {
    test('success() carries a value and reports isSuccess', () {
      // The per-arm flag IS the discriminating fact, and these two tests are
      // where it is asserted. An earlier version of this group *also* asserted
      // the relation `isFailure == !isSuccess`; that test was deleted rather than
      // rewritten, because swapping the two getters preserves the relation
      // exactly — it could never fail, and a third copy of these two assertions
      // would only have hidden that.
      const Result<int> result = Result<int>.success(7);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('failure() carries a Failure and reports isFailure', () {
      const Result<int> result = Result<int>.failure(boom);

      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('neither arm is const-only', () {
      // The point is the negative space around `const`: a repository impl builds
      // its results out of decoded responses and clock reads, so both factories
      // must accept run-time values. (An earlier version of this test was named
      // "both factories are const-constructible" while containing no `const` and
      // asserting nothing about construction.)
      final int year = DateTime.now().year;
      final Result<int> runtimeSuccess = Result<int>.success(year);
      final Result<int> runtimeFailure = Result<int>.failure(
        Failure(kind: FailureKind.unknown, message: runtimeSuccess.toString()),
      );

      expect(runtimeSuccess.isSuccess, isTrue);
      expect(runtimeFailure.isFailure, isTrue);
    });

    test('each arm puts its payload in props — that is what equality rests on', () {
      // The cross-arm equality tests cannot fail: `Equatable.operator ==`
      // compares `runtimeType` before `props`, so `Success<int>` and
      // `FailureResult<int>` are unequal whatever they hold, an empty payload
      // included. What makes equality meaningful is that each arm compares its
      // payload, so two instances of the *same* arm with different payloads
      // differ. Asserted through `==` rather than a `props` list, because
      // `Equatable` is gone and the arms now own their `==` — asserting on
      // `props` would have been asserting on an API that no longer exists, and
      // the cross-arm relation above cannot express this fact on its own:
      // emptying both arms' comparison used to leave the suite green.
      // `T` given EXPLICITLY at every call site in this test, and that is the
      // fix for a failure this test hit while being written: with `_builtSuccess`
      // inferred from its argument, `_builtFailureResult<int>(someFailure)` resolved
      // `T` to `dynamic`, so the arm compared unequal to a `FailureResult<int>` on
      // the *type* rather than on the payload it exists to test. The assertion
      // passed for the wrong reason — which is the failure mode this very test
      // was written to catch.
      const Failure boomWithStatus = Failure(
        kind: FailureKind.unknown,
        message: 'boom',
        statusCode: 500,
      );
      final Success<int> success = _builtSuccess<int>(4);
      final FailureResult<int> failure = _builtFailureResult<int>(boom);

      expect(success, isNot(_builtSuccess<int>(5)));
      // Same [Failure] fields but a different `statusCode` — which IS one of the
      // three fields that decide `Failure` equality, so the two genuinely differ.
      expect(failure, isNot(_builtFailureResult<int>(boomWithStatus)));
      // Same payload, therefore equal — the other half of the claim.
      expect(success, _builtSuccess<int>(4));
      expect(failure, _builtFailureResult<int>(boom));
    });
  });

  group('map', () {
    test('transforms the success value', () {
      final Result<int> result = const Result<int>.success(21)
          .map((int doubled) => doubled * 2);

      expect(
        result.fold<int>(onSuccess: (int v) => v, onFailure: (Failure _) => -1),
        42,
      );
    });

    test('does NOT run its function for a failure', () {
      bool called = false;

      final Result<int> result = const Result<int>.failure(boom)
          .map((int value) {
            called = true;
            return value * 2;
          });

      expect(called, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('leaves the failure byte-for-byte identical', () {
      final Result<int> mapped = const Result<int>.failure(boom)
          .map((int v) => v * 2);

      expect(mapped.failureOrElse(boom), boom);
    });

    test('changes the static type of the success arm', () {
      // Result<int>.map((int v) => '$v') is a Result<String>: the transform is
      // what retypes the value, and `fold` is where the two arms meet.
      final Result<String> mapped = const Result<int>.success(7)
          .map((int v) => 'id=$v');

      expect(
        mapped.fold<String>(
          onSuccess: (String s) => s,
          onFailure: (Failure _) => 'failed',
        ),
        'id=7',
      );
    });
  });

  group('mapFailure', () {
    test('does NOT run for a success', () {
      bool called = false;

      final Result<int> result = const Result<int>.success(1)
          .mapFailure((Failure f) {
            called = true;
            return f;
          });

      expect(called, isFalse);
      expect(result.isSuccess, isTrue);
    });

    test('preserves the ORIGINAL kind when the transform rebuilds it', () {
      // The realistic use is adding context without reclassifying: a mapper
      // annotates a 409, it does not turn it into an `unknown`.
      final Result<int> result = const Result<int>.failure(boom).mapFailure(
        (Failure f) => Failure(
          kind: f.kind,
          message: 'submit failed: ${f.message}',
          statusCode: f.statusCode,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrElse(boom).kind, FailureKind.server);
      expect(
        result.failureOrElse(boom).message,
        'submit failed: internal server error',
      );
      expect(result.failureOrElse(boom).statusCode, 500);
    });

    test('a transform is free to change the kind', () {
      // Proves the previous test is not vacuous: kind is carried by the
      // transform's return value, so equality of kind there was a real
      // decision and not a copy of the original.
      final Result<int> result = const Result<int>.failure(boom).mapFailure(
        (Failure f) => Failure(kind: FailureKind.unknown, message: f.message),
      );

      expect(result.failureOrElse(boom).kind, FailureKind.unknown);
    });

    test('keeps the success value untouched', () {
      // The transform must actually be handed to `mapFailure`. An earlier
      // version of this test built a bare `Result<int>.success(3)` and folded
      // it — it never called `mapFailure` at all, which is why replacing the
      // success arm with `Success<T>(0 as T)` left the suite green.
      final Result<int> result = const Result<int>.success(
        3,
      ).mapFailure((Failure f) => Failure(kind: f.kind, message: 'never runs'));

      expect(
        result.fold<int>(onSuccess: (int v) => v, onFailure: (Failure _) => -1),
        3,
      );
      expect(result.isSuccess, isTrue);
    });
  });

  group('fold', () {
    test('selects onSuccess for a success and ignores onFailure', () {
      bool onFailureRan = false;

      final String out = const Result<int>.success(5).fold<String>(
        onSuccess: (int v) => 'value=$v',
        onFailure: (Failure _) {
          onFailureRan = true;
          return 'failed';
        },
      );

      expect(out, 'value=5');
      expect(onFailureRan, isFalse);
    });

    test('selects onFailure for a failure and hands over the Failure', () {
      String? seenKind;

      final String out = const Result<int>.failure(boom).fold<String>(
        onSuccess: (int v) => 'value=$v',
        onFailure: (Failure f) {
          seenKind = f.kind.name;
          return f.message;
        },
      );

      expect(out, 'internal server error');
      expect(seenKind, 'server');
    });

    test('unifies both arms into one static type', () {
      // This is the whole point of fold: the caller never writes a branch, and
      // the cubit can assign either arm to one field.
      final int fromSuccess = const Result<int>.success(2)
          .fold<int>(onSuccess: (int v) => v, onFailure: (Failure _) => 0);
      final int fromFailure = const Result<int>.failure(boom)
          .fold<int>(onSuccess: (int v) => v, onFailure: (Failure _) => 0);

      expect(fromSuccess, 2);
      expect(fromFailure, 0);
    });
  });

  group('valueOrElse', () {
    test('returns the value for a success, ignoring the fallback', () {
      expect(const Result<int>.success(9).valueOrElse(-1), 9);
    });

    test('returns the fallback for a failure — the loss is explicit', () {
      // Named `valueOrElse`, never `getOrNull`, so the call site states that it
      // is discarding the Failure. AGENT_CONTEXT §3 (LSP) is why there is no
      // `value` getter that would silently null out.
      expect(const Result<int>.failure(boom).valueOrElse(-1), -1);
    });

    test('a non-constant fallback of type T is accepted verbatim', () {
      // The fallback is `T`-typed on purpose, which is the whole design: it is
      // what makes the differing-arms case below a compile error rather than a
      // runtime `TypeError`. Anything genuinely of type [T] still works,
      // including one built at run time rather than a `const` literal.
      final int fallback = DateTime.now().year;

      expect(const Result<int>.failure(boom).valueOrElse(fallback), fallback);
      expect(const Result<int>.success(9).valueOrElse(fallback), 9);
    });

    group('the differing-arms case belongs to fold, not valueOrElse', () {
      // The sound half. `fold<R>` infers `R` from BOTH arms and is checked at
      // both, so a widget-returning failure arm and a value-returning success arm
      // are one honest branch.
      test('fold<Widget> serves it, and runs exactly one arm', () {
        const Result<int> success = Result<int>.success(24);
        const Result<int> failure = Result<int>.failure(boom);

        // Different widget TYPES per arm, so picking the wrong arm is
        // unmistakable rather than a width that could coincide.
        final Widget fromSuccess = success.fold<Widget>(
          onSuccess: (int value) => SizedBox(width: value.toDouble()),
          onFailure: (Failure _) => const Text('failed'),
        );
        final Widget fromFailure = failure.fold<Widget>(
          onSuccess: (int value) => SizedBox(width: value.toDouble()),
          onFailure: (Failure _) => const Text('failed'),
        );

        expect(fromSuccess, isA<SizedBox>());
        expect((fromSuccess as SizedBox).width, 24.0);
        expect(fromFailure, isA<Text>());
        expect((fromFailure as Text).data, 'failed');
      });

      test('valueOrElse CANNOT serve it, and the shape does not compile', () {
        // The unsafe half. `valueOrElse`'s fallback is typed `T`, so the shape
        // the old unconstrained `<R>` advertised is now rejected by the ANALYSER
        // — three type errors on a `Result<Reading>`:
        //
        // ```dart
        // // R inferred from the fallback alone:
        // //   error - The argument type 'CircularProgressIndicator' can't be
        // //           assigned to the parameter type 'Reading'.
        // result.valueOrElse(const CircularProgressIndicator());
        //
        // // R inferred from the context type:
        // //   error - A value of type 'Reading' can't be assigned to a variable
        // //           of type 'Widget'.
        // //   error - The argument type 'SizedBox' can't be assigned to the
        // //           parameter type 'Reading'.
        // final Widget w = result.valueOrElse(const SizedBox.shrink());
        // ```
        //
        // Under the old signature BOTH shapes analysed clean and shape 2 threw
        // `type 'Reading' is not a subtype of type 'Widget' in type cast` from
        // `Result.valueOrElse` — reproduced against this package. No test can
        // observe a static type error from inside the VM, so that negative half
        // lives in the comment above rather than in an assertion.
        //
        // What IS observable at run time is asserted here: both arms hand back a
        // value of the value type, never a fallback smuggled in through a
        // widening type parameter.
        const Result<String> stringFailure = Result<String>.failure(boom);

        expect(stringFailure.valueOrElse('unavailable'), 'unavailable');
        expect(
          const Result<String>.success('ok').valueOrElse('unavailable'),
          'ok',
        );
      });
    });
  });

  group('failureOrElse', () {
    test('returns the stored failure for a failure, not the fallback', () {
      // A DISTINCT sentinel. An earlier version passed `boom` as the `orElse`
      // as well, so `identical(..., boom)` held whether the method returned the
      // stored failure or the fallback — the assertion could not fail. Asserting
      // on the returned *kind* removes the ambiguity completely.
      const Failure sentinel = Failure(
        kind: FailureKind.cancelled,
        message: 'sentinel, never stored',
      );

      final Failure out = const Result<int>.failure(boom)
          .failureOrElse(sentinel);

      expect(out.kind, FailureKind.server);
      expect(out.message, 'internal server error');
      expect(out.statusCode, 500);
    });

    test('returns the fallback for a success', () {
      const Failure other = Failure(
        kind: FailureKind.cancelled,
        message: 'left',
      );

      expect(const Result<int>.success(1).failureOrElse(other), other);
    });
  });

  group('equality', () {
    // Every operand below comes from a builder, never from a `const` literal.
    // Two `const Result<int>.success(4)` expressions are canonicalised by the
    // compiler into ONE instance, so comparing them is `identical()` and passes
    // against any implementation — including `props => []`.

    test('two successes with equal values are equal — as distinct objects', () {
      final Success<int> a = _builtSuccess<int>(4);
      final Success<int> b = _builtSuccess<int>(4);

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a, b);
    });

    test('equal successes share a hash code', () {
      final Success<int> a = _builtSuccess<int>(4);
      final Success<int> b = _builtSuccess<int>(4);

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a.hashCode, b.hashCode);
    });

    test('successes with different values are NOT equal', () {
      expect(_builtSuccess<int>(4), isNot(_builtSuccess(5)));
    });

    test('two failures carrying structurally equal Failures are equal', () {
      // Both the wrapping `FailureResult` AND the `Failure` it carries are
      // built separately. Reusing the `const` `boom` on both sides would
      // compare one `Failure` instance with itself and prove nothing about
      // `Failure`'s own equality.
      final FailureResult<int> a = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );
      final FailureResult<int> b = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(identical(a.failure, b.failure), isFalse);
      expect(a, b);
    });

    test('equal failure results share a hash code', () {
      final FailureResult<int> a = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );
      final FailureResult<int> b = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a.hashCode, b.hashCode);
    });

    test('failures carrying different Failures are NOT equal', () {
      expect(
        _builtFailureResult<int>(_builtFailure(FailureKind.server, 'boom')),
        isNot(
          _builtFailureResult<int>(
            _builtFailure(FailureKind.conflict, 'already answered'),
          ),
        ),
      );
    });

    test(
      'failures carrying Failures that differ only in status are NOT equal',
      () {
        // The other discriminating field, so `props` cannot be reduced to
        // `[kind, message]` without this failing.
        expect(
          _builtFailureResult<int>(
            _builtFailure(FailureKind.validation, 'bad request'),
          ),
          isNot(
            _builtFailureResult<int>(
              _builtFailure(
                FailureKind.validation,
                'bad request',
                statusCode: 400,
              ),
            ),
          ),
        );
      },
    );

    test('a success is NEVER equal to a failure, in EITHER order', () {
      // BOTH ORDERS ARE ASSERTED, and that is the whole point of this test.
      //
      // `==` is called on the LEFT operand, so `Success == FailureResult` runs
      // `Success`'s override and `FailureResult == Success` runs
      // `FailureResult`'s. Two independent `==` implementations are therefore
      // doing the rejecting, and asserting one order exercises exactly one of
      // them. The old version asserted both orders but proved nothing: while this
      // class extended `Equatable`, BOTH arms inherited ONE implementation, so a
      // single `runtimeType` check in the base class answered both directions and
      // the suite was green no matter what each arm did.
      //
      // Now that each arm owns its `==`, the cross-arm guard is per-arm code, and
      // dropping either one is invisible to a one-directional test. VERIFIED: with
      // `Success`'s `other is Success<T>` guard replaced by a bare
      // `runtimeType` comparison plus an unchecked cast, this file stayed fully
      // green — because `runtimeType` happened to answer it anyway. Both
      // directions are asserted below precisely so that mutation cannot hide
      // behind the base-class comparison it used to rely on.
      final Result<int> success = _builtSuccess(0);
      final Result<int> failure = _builtFailureResult<int>(boom);

      expect(success, isNot(failure));
      expect(failure, isNot(success));
      // Stated as a fact about the *type*, not about equality: this is what the two
      // `==` overrides lean on, and it holds independently of either of them.
      expect(success.runtimeType, isNot(failure.runtimeType));
    });

    test('the two arms do not equal each other when a payload would match', () {
      // The adversarial half of the test above. `Success(0)` and
      // `FailureResult(someFailure)` cannot have equal payloads by construction —
      // one holds an `int`, the other a `Failure` — so the natural assertions pass
      // for the wrong reason: any `==` that compares payloads finds them
      // different and never reaches the arm check.
      //
      // This test manufactures the coincidence the type system normally prevents,
      // by comparing two Results whose payload is the SAME value on both sides.
      // A `==` that has *lost* its arm guard and fallen back to payload comparison
      // would report these equal; a correct one reports unequal because the arms
      // differ, which is what the runtimeType assertion below establishes
      // independently of the `==` implementations.
      //
      // The `Failure` here is compared against itself, so the only thing that can
      // make the two Results differ is the arm.
      final Result<Failure> asSuccess = _builtSuccess<Failure>(boom);
      final Result<Failure> asFailure = _builtFailureResult<Failure>(boom);

      expect(asSuccess, isNot(asFailure));
      expect(asFailure, isNot(asSuccess));
      expect(asSuccess.runtimeType, isNot(asFailure.runtimeType));
    });

    test('a narrow generic does not equal a wider one holding an equal value', () {
      // THE TEST THAT HOLDS `runtimeType` IN `==`, and it exists because two
      // successive attempts to remove that clause both needed correcting.
      //
      // ## WHY THE OBVIOUS REASONING IS WRONG
      //
      // "The clause is redundant: `other is Success<T>` already rejects a
      // mismatched generic." It does — in the NARROWING direction.
      // `Success<String> is Success<int>` is false. So that half of the argument
      // is right, which is exactly what makes it convincing and exactly what makes
      // it wrong: **Dart's generic parameters are covariant**, so
      // `Success<int> is Success<num>` is **true**. With `int` on the left the
      // type test passes, and since `1 == 1.0` is also true, `value == other.value`
      // says yes as well. Without `runtimeType` these two compare EQUAL.
      //
      // Both facts are measured, not recalled — `is` on the widened pair, and `==`
      // on the two numeric literals — because the whole claim turns on them.
      //
      // ## WHY THIS PAIRED PAYLOAD IS THE ONLY ONE THAT WORKS
      //
      // The natural test, `Success<int>(1)` against `Success<String>('1')`, proves
      // nothing about the generic parameter: the payloads differ, so `value ==
      // other.value` rejects the pair on its own and the type check is never
      // consulted. VERIFIED — rewriting `Success`'s `==` to drop the type-argument
      // check entirely left that version of the test fully green. Two payloads
      // that `==` *cannot* distinguish are the only pair that forces the question
      // out to the type.
      final Success<int> narrow = _builtSuccess<int>(1);
      final Success<num> wide = _builtSuccess<num>(1);

      expect(narrow, isNot(wide));
      // Both directions, because `==` dispatches on the LEFT operand and the
      // covariance trap only opens in one of them.
      expect(wide, isNot(narrow));

      // The hash is the quieter half of the same clause. Two Results that compare
      // unequal and share a bucket is legal Dart; it degrades a `HashMap<Result>`
      // into a linear scan and fails nothing. Since the payloads are `==`-equal,
      // `runtimeType` is the only thing that can separate these hashes at all.
      expect(narrow.hashCode, isNot(wide.hashCode));

      // And the widening direction is checked for real rather than assumed:
      // `narrow is Success<num>` is what makes the mutation above reachable, so
      // this asserts the premise the whole test rests on.
      expect(narrow, isA<Success<num>>());
    });

    test('a narrow generic does not equal a wider failure arm', () {
      // The same covariance trap on `FailureResult`, where it is *worse*: both
      // arms carry the IDENTICAL `Failure`, so once the type test is passed the
      // payload comparison agrees unconditionally. Dropping `runtimeType` here
      // makes two differently-typed Results equal on every payload there is.
      final FailureResult<int> narrow = _builtFailureResult<int>(boom);
      final FailureResult<Object> wide = _builtFailureResult<Object>(boom);

      expect(narrow, isNot(wide));
      expect(wide, isNot(narrow));
      expect(narrow.hashCode, isNot(wide.hashCode));
      // Premise, asserted: the payload really is the same object, so nothing but
      // the type can be doing the work.
      expect(narrow.failure, wide.failure);
      expect(narrow, isA<FailureResult<Object>>());
    });

    test('a hash separates arms of different generic parameters', () {
      // The plain version, for the case where the payloads differ outright — and
      // the half that fails if a `hashCode` is replaced by a constant, which
      // "equal values share a hash" would NOT catch. VERIFIED: `Success`'s
      // `hashCode` replaced with the literal `0` makes exactly this fail while
      // every equality assertion in the file stays green.
      final Success<int> intArm = _builtSuccess<int>(1);
      final Success<String> stringArm = _builtSuccess<String>('1');

      expect(intArm, isNot(stringArm));
      expect(intArm.hashCode, isNot(stringArm.hashCode));

      final FailureResult<int> fInt = _builtFailureResult<int>(boom);
      final FailureResult<String> fString = _builtFailureResult<String>(boom);

      expect(fInt, isNot(fString));
      expect(fInt.hashCode, isNot(fString.hashCode));
    });
  });

  group('toString', () {
    // Equatable's default is `Instance of 'Success<int>'`, which is what a log
    // line and a failed `expect` would otherwise show. Pinned so a rewrite that
    // drops the value cannot pass unnoticed.

    test('Success names its value', () {
      expect(_builtSuccess<int>(4).toString(), 'Success<int>(4)');
    });

    test('FailureResult names the failure it carries', () {
      expect(
        _builtFailureResult<int>(boom).toString(),
        'FailureResult<int>(Failure(kind: server, statusCode: 500, '
        'message: internal server error))',
      );
    });

    test('a Success is distinguishable from a FailureResult in a log', () {
      // The whole reason these renderings exist: two adjacent log lines must be
      // tellable apart without knowing which call produced them.
      expect(_builtSuccess<int>(4).toString(), isNot(contains('Failure')));
      expect(_builtFailureResult<int>(boom).toString(), contains('Failure'));
    });
  });

  group('sealed exhaustiveness', () {
    // [describe] has NO `default` arm. Because `Result<T>` is `sealed` with
    // exactly `Success<T>` and `FailureResult<T>`, adding a third subtype makes
    // this function fail to COMPILE — which is the guarantee the test guards.
    String describe(Result<int> result) => switch (result) {
      Success<int>(:final value) => 'success:$value',
      FailureResult<int>(:final failure) => 'failure:${failure.kind.name}',
    };

    test('a no-default switch exhausts the sealed type', () {
      expect(describe(const Result<int>.success(12)), 'success:12');
      expect(
        describe(
          const Result<int>.failure(
            Failure(kind: FailureKind.conflict, message: 'already answered'),
          ),
        ),
        'failure:conflict',
      );
    });

    test('a no-default switch can also destructure the Failure', () {
      String code(Result<String> result) => switch (result) {
        Success<String>(:final value) => value,
        FailureResult<String>(:final failure) =>
          '${failure.statusCode ?? 0}:${failure.kind.name}',
      };

      expect(code(const Result<String>.success('ok')), 'ok');
      expect(
        code(
          const Result<String>.failure(
            Failure(
              kind: FailureKind.unauthorized,
              message: 'bad id',
              statusCode: 401,
            ),
          ),
        ),
        '401:unauthorized',
      );
    });
  });
}
