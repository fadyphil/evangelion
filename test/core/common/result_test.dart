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
Success<int> _builtSuccess(int value) => Success<int>(value);

/// [FailureResult] via a parameter, for the same reason as [_builtFailure].
FailureResult<int> _builtFailureResult(Failure failure) =>
    FailureResult<int>(failure);

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
      // `FailureResult<int>` are unequal whatever their props hold, an empty
      // list included. What makes equality meaningful is that each arm's props
      // carry its payload, so two instances of the *same* arm with different
      // payloads differ. Asserted here directly, because that is the fact the
      // cross-arm relation cannot express — emptying both props lists used to
      // leave the suite green.
      final Success<int> success = _builtSuccess(4);
      final FailureResult<int> failure = _builtFailureResult(boom);

      expect(success.props, <Object?>[4]);
      expect(failure.props, <Object?>[boom]);
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
      final Success<int> a = _builtSuccess(4);
      final Success<int> b = _builtSuccess(4);

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a, b);
    });

    test('equal successes share a hash code', () {
      final Success<int> a = _builtSuccess(4);
      final Success<int> b = _builtSuccess(4);

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a.hashCode, b.hashCode);
    });

    test('successes with different values are NOT equal', () {
      expect(_builtSuccess(4), isNot(_builtSuccess(5)));
    });

    test('two failures carrying structurally equal Failures are equal', () {
      // Both the wrapping `FailureResult` AND the `Failure` it carries are
      // built separately. Reusing the `const` `boom` on both sides would
      // compare one `Failure` instance with itself and prove nothing about
      // `Failure`'s own equality.
      final FailureResult<int> a = _builtFailureResult(
        _builtFailure(FailureKind.server, 'internal server error'),
      );
      final FailureResult<int> b = _builtFailureResult(
        _builtFailure(FailureKind.server, 'internal server error'),
      );

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(identical(a.failure, b.failure), isFalse);
      expect(a, b);
    });

    test('equal failure results share a hash code', () {
      final FailureResult<int> a = _builtFailureResult(
        _builtFailure(FailureKind.server, 'internal server error'),
      );
      final FailureResult<int> b = _builtFailureResult(
        _builtFailure(FailureKind.server, 'internal server error'),
      );

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a.hashCode, b.hashCode);
    });

    test('failures carrying different Failures are NOT equal', () {
      expect(
        _builtFailureResult(_builtFailure(FailureKind.server, 'boom')),
        isNot(
          _builtFailureResult(
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
          _builtFailureResult(
            _builtFailure(FailureKind.validation, 'bad request'),
          ),
          isNot(
            _builtFailureResult(
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

    test('a success is NEVER equal to a failure', () {
      // KEPT, but stated honestly about its own strength: `Equatable.operator ==`
      // compares `runtimeType` before `props`, so the two arms can never be equal
      // for ANY props — including an empty list. It is a guard against someone
      // collapsing the two arms onto a shared supertype, not evidence that props
      // carry anything. The tests that do carry that evidence are
      // "successes with different values are NOT equal", "failures carrying
      // different Failures are NOT equal" and the `props` test in `construction`.
      final Result<int> success = _builtSuccess(0);
      final Result<int> failure = _builtFailureResult(boom);

      expect(success, isNot(failure));
      expect(failure, isNot(success));
      expect(success.runtimeType, isNot(failure.runtimeType));
    });
  });

  group('toString', () {
    // Equatable's default is `Instance of 'Success<int>'`, which is what a log
    // line and a failed `expect` would otherwise show. Pinned so a rewrite that
    // drops the value cannot pass unnoticed.

    test('Success names its value', () {
      expect(_builtSuccess(4).toString(), 'Success<int>(4)');
    });

    test('FailureResult names the failure it carries', () {
      expect(
        _builtFailureResult(boom).toString(),
        'FailureResult<int>(Failure(kind: server, statusCode: 500, '
        'message: internal server error))',
      );
    });

    test('a Success is distinguishable from a FailureResult in a log', () {
      // The whole reason these renderings exist: two adjacent log lines must be
      // tellable apart without knowing which call produced them.
      expect(_builtSuccess(4).toString(), isNot(contains('Failure')));
      expect(_builtFailureResult(boom).toString(), contains('Failure'));
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
