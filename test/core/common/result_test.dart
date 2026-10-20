import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

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
/// needs `Right<Failure, String>` — and building that through an `int`-only helper is
/// how the generic-parameter check would have been written by accident.
Right<Failure, T> _builtSuccess<T>(T value) => Right<Failure, T>(value);

/// `Left` via a parameter, for the same reason as [_builtFailure], and
/// generic in [T] for the same reason as [_builtSuccess].
Left<Failure, T> _builtFailureResult<T>(Failure failure) =>
    Left<Failure, T>(failure);

void main() {
  group('construction', () {
    test('success() carries a value and reports isSuccess', () {
      // The per-arm flag IS the discriminating fact, and these two tests are
      // where it is asserted. An earlier version of this group *also* asserted
      // the relation `isFailure == !isSuccess`; that test was deleted rather than
      // rewritten, because swapping the two getters preserves the relation
      // exactly — it could never fail, and a third copy of these two assertions
      // would only have hidden that.
      const Result<int> result = Right<Failure, int>(7);

      expect(result.isRight(), isTrue);
      expect(result.isLeft(), isFalse);
    });

    test('failure() carries a Failure and reports isFailure', () {
      const Result<int> result = Left<Failure, int>(boom);

      expect(result.isLeft(), isTrue);
      expect(result.isRight(), isFalse);
    });

    test('neither arm is const-only', () {
      // The point is the negative space around `const`: a repository impl builds
      // its results out of decoded responses and clock reads, so both factories
      // must accept run-time values. (An earlier version of this test was named
      // "both factories are const-constructible" while containing no `const` and
      // asserting nothing about construction.)
      final int year = DateTime.now().year;
      final Result<int> runtimeSuccess = Result<int>.of(year);
      final Result<int> runtimeFailure = Result<int>.left(
        Failure(kind: FailureKind.unknown, message: runtimeSuccess.toString()),
      );

      expect(runtimeSuccess.isRight(), isTrue);
      expect(runtimeFailure.isLeft(), isTrue);
    });

    test('each arm puts its payload in props — that is what equality rests on', () {
      // The cross-arm equality tests cannot fail: `Equatable.operator ==`
      // compares `runtimeType` before `props`, so `Right<Failure, int>` and
      // `Left<Failure, int>` are unequal whatever they hold, an empty payload
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
      // `T` to `dynamic`, so the arm compared unequal to a `Left<Failure, int>` on
      // the *type* rather than on the payload it exists to test. The assertion
      // passed for the wrong reason — which is the failure mode this very test
      // was written to catch.
      const Failure boomWithStatus = Failure(
        kind: FailureKind.unknown,
        message: 'boom',
        statusCode: 500,
      );
      final Right<Failure, int> success = _builtSuccess<int>(4);
      final Left<Failure, int> failure = _builtFailureResult<int>(boom);

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
      final Result<int> result = const Right<Failure, int>(21)
          .map((int doubled) => doubled * 2);

      expect(result.fold<int>((Failure _) => -1, (int v) => v), 42);
    });

    test('does NOT run its function for a failure', () {
      bool called = false;

      final Result<int> result = const Left<Failure, int>(boom)
          .map((int value) {
            called = true;
            return value * 2;
          });

      expect(called, isFalse);
      expect(result.isLeft(), isTrue);
    });

    test('leaves the failure byte-for-byte identical', () {
      final Result<int> mapped = const Left<Failure, int>(boom)
          .map((int v) => v * 2);

      expect(mapped.failureOrElse(boom), boom);
    });

    test('changes the static type of the success arm', () {
      // Result<int>.map((int v) => '$v') is a Result<String>: the transform is
      // what retypes the value, and `fold` is where the two arms meet.
      final Result<String> mapped = const Right<Failure, int>(7)
          .map((int v) => 'id=$v');

      expect(
        mapped.fold<String>((Failure _) => 'failed', (String s) => s),
        'id=7',
      );
    });
  });

  group('mapFailure', () {
    test('does NOT run for a success', () {
      bool called = false;

      final Result<int> result = const Right<Failure, int>(1)
          .mapLeft((Failure f) {
            called = true;
            return f;
          });

      expect(called, isFalse);
      expect(result.isRight(), isTrue);
    });

    test('preserves the ORIGINAL kind when the transform rebuilds it', () {
      // The realistic use is adding context without reclassifying: a mapper
      // annotates a 409, it does not turn it into an `unknown`.
      final Result<int> result = const Left<Failure, int>(boom).mapLeft(
        (Failure f) => Failure(
          kind: f.kind,
          message: 'submit failed: ${f.message}',
          statusCode: f.statusCode,
        ),
      );

      expect(result.isLeft(), isTrue);
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
      final Result<int> result = const Left<Failure, int>(boom).mapLeft(
        (Failure f) => Failure(kind: FailureKind.unknown, message: f.message),
      );

      expect(result.failureOrElse(boom).kind, FailureKind.unknown);
    });

    test('keeps the success value untouched', () {
      // The transform must actually be handed to `mapFailure`. An earlier
      // version of this test built a bare `Result<int>.of(3)` and folded
      // it — it never called `mapFailure` at all, which is why replacing the
      // success arm with `Right<Failure, T>(0 as T)` left the suite green.
      final Result<int> result = const Right<Failure, int>(3)
          .mapLeft((Failure f) => Failure(kind: f.kind, message: 'never runs'));

      expect(result.fold<int>((Failure _) => -1, (int v) => v), 3);
      expect(result.isRight(), isTrue);
    });
  });

  group('fold', () {
    test('selects onSuccess for a success and ignores onFailure', () {
      bool onFailureRan = false;

      final String out = const Right<Failure, int>(5).fold<String>(
        (Failure _) {
          onFailureRan = true;
          return 'failed';
        },
        (int v) {
          return 'value=$v';
        },
      );

      expect(out, 'value=5');
      expect(onFailureRan, isFalse);
    });

    test('selects onFailure for a failure and hands over the Failure', () {
      String? seenKind;

      final String out = const Left<Failure, int>(boom)
          .fold<String>((Failure f) {
            seenKind = f.kind.name;
            return f.message;
          }, (int v) => 'unreachable');

      expect(out, 'internal server error');
      expect(seenKind, 'server');
    });

    test('unifies both arms into one static type', () {
      // This is the whole point of fold: the caller never writes a branch, and
      // the cubit can assign either arm to one field.
      final int fromSuccess = const Right<Failure, int>(2)
          .fold<int>((Failure _) => 0, (int v) => v);
      final int fromFailure = const Left<Failure, int>(boom)
          .fold<int>((Failure _) => 0, (int v) => v);

      expect(fromSuccess, 2);
      expect(fromFailure, 0);
    });
  });

  group('valueOrElse', () {
    test('returns the value for a success, ignoring the fallback', () {
      expect(const Right<Failure, int>(9).getOrElse((_) => -1), 9);
    });

    test('returns the fallback for a failure — the loss is explicit', () {
      // Named `valueOrElse`, never `getOrNull`, so the call site states that it
      // is discarding the Failure. AGENT_CONTEXT §3 (LSP) is why there is no
      // `value` getter that would silently null out.
      expect(const Left<Failure, int>(boom).getOrElse((_) => -1), -1);
    });

    test('a non-constant fallback of type T is accepted verbatim', () {
      // The fallback is `T`-typed on purpose, which is the whole design: it is
      // what makes the differing-arms case below a compile error rather than a
      // runtime `TypeError`. Anything genuinely of type [T] still works,
      // including one built at run time rather than a `const` literal.
      final int fallback = DateTime.now().year;

      expect(
        const Left<Failure, int>(boom).getOrElse((_) => fallback),
        fallback,
      );
      expect(const Right<Failure, int>(9).getOrElse((_) => fallback), 9);
    });

    group('the differing-arms case belongs to fold, not valueOrElse', () {
      // The sound half. `fold<R>` infers `R` from BOTH arms and is checked at
      // both, so a widget-returning failure arm and a value-returning success arm
      // are one honest branch.
      test('fold<Widget> serves it, and runs exactly one arm', () {
        const Result<int> success = Right<Failure, int>(24);
        const Result<int> failure = Left<Failure, int>(boom);

        // Different widget TYPES per arm, so picking the wrong arm is
        // unmistakable rather than a width that could coincide.
        final Widget fromSuccess = success.fold<Widget>(
          (Failure _) => const Text('failed'),
          (int value) => SizedBox(width: value.toDouble()),
        );
        final Widget fromFailure = failure.fold<Widget>(
          (Failure _) => const Text('failed'),
          (int value) => SizedBox(width: value.toDouble()),
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
        // Explicit on both arms, because the claim is about them: the point is
        // that `Left`'s value type is `String` and the fallback is typed `T` —
        // spelled `Left<Failure, String>` to match the `Right<Failure, String>`
        // it is compared against. Inferred, the same call reads as a widening.
        const stringFailure = Left<Failure, String>(boom);

        expect(stringFailure.getOrElse((_) => 'unavailable'), 'unavailable');
        expect(
          const Right<Failure, String>('ok').getOrElse((_) => 'unavailable'),
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

      final Failure out = const Left<Failure, int>(boom)
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

      expect(const Right<Failure, int>(1).failureOrElse(other), other);
    });
  });

  group('equality', () {
    // Every operand below comes from a builder, never from a `const` literal.
    // Two `const Right<Failure, int>(4)` expressions are canonicalised by the
    // compiler into ONE instance, so comparing them is `identical()` and passes
    // against any implementation — including `props => []`.

    test('two successes with equal values are equal — as distinct objects', () {
      final Right<Failure, int> a = _builtSuccess<int>(4);
      final Right<Failure, int> b = _builtSuccess<int>(4);

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(a, b);
    });

    test('equal successes share a hash code', () {
      final Right<Failure, int> a = _builtSuccess<int>(4);
      final Right<Failure, int> b = _builtSuccess<int>(4);

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
      final Left<Failure, int> a = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );
      final Left<Failure, int> b = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );

      expect(identical(a, b), isFalse, reason: 'otherwise this is vacuous');
      expect(identical(a.value, b.value), isFalse);
      expect(a, b);
    });

    test('equal failure results share a hash code', () {
      final Left<Failure, int> a = _builtFailureResult<int>(
        _builtFailure(FailureKind.server, 'internal server error'),
      );
      final Left<Failure, int> b = _builtFailureResult<int>(
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
      // `Success`'s `other is Right<Failure, T>` guard replaced by a bare
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

    test('fp_dart compares PAYLOADS, not type arguments — and that is pinned', () {
      // ## THIS ASSERTS fp_dart's BEHAVIOUR, NOT A BUG
      //
      // The hand-written `Result<T>` guarded `==` on `runtimeType`, because Dart's
      // generics are covariant: `Success<int> is Success<num>` is true, and `1 == 1.0`
      // is true, so without the guard two differently-typed Results compare EQUAL.
      // That guard was decision 131 and had mutation tests behind it.
      //
      // fp_dart's arms do not have it. `Right.operator ==` is
      // `(other is Right) && other._value == _value` (`either.dart:572`) — the type
      // parameters are never mentioned. Measured against 1.2.0:
      //
      //     Right<Failure, int>(1)  == Right<Failure, num>(1)   ->  true
      //     Left<Failure, int>(f)   == Left<Failure, Object>(f)  ->  true
      //
      // Subclassing `Right` to restore the guard was tried and DOES NOT WORK: a
      // subclass does not match the supertype's object pattern, so `switch` over the
      // alias stops being exhaustive ("does not match the pattern
      // `Right<Failure, T>()`"). Restoring equality would destroy the sealed
      // exhaustiveness the migration was undertaken to obtain.
      //
      // So the behaviour is pinned as-is and this is the file that says so. If a
      // future fp_dart release adds the type check, THIS TEST FAILS, which is the
      // point: the change is noticed instead of absorbed silently.
      final Right<Failure, int> narrow = _builtSuccess<int>(1);
      final Right<Failure, num> wide = _builtSuccess<num>(1);

      // The payload is genuinely `==`-equal, and the generic parameters genuinely
      // relate by covariance. Without both premises the assertion below would pass
      // for the wrong reason.
      expect(narrow.value, wide.value);
      expect(narrow, isA<Right<Failure, num>>());

      // The actual behaviour: equal, because only the payload is compared.
      expect(narrow, wide);
      // And symmetric — `==` here dispatches on the value being compared, not on a
      // left-operand override, so there is only one direction to state.
      expect(wide, narrow);

      // The same on the failure arm, where it is WORSE: both arms carry the
      // IDENTICAL `Failure`, so there is no payload that could separate them.
      final Left<Failure, int> fNarrow = _builtFailureResult<int>(boom);
      final Left<Failure, Object> fWide = _builtFailureResult<Object>(boom);

      expect(fNarrow.value, fWide.value);
      expect(fNarrow, fWide);
    });

    test('the two arms never compare equal to each other', () {
      // The property that DOES hold, and that the old `runtimeType` clause was
      // most load-bearing for: `Right` is never a `Left`. Losing the type
      // argument did not touch this.
      expect(_builtSuccess<int>(1), isNot(_builtFailureResult<int>(boom)));
      expect(_builtFailureResult<int>(boom), isNot(_builtSuccess<int>(1)));
    });

    test('differing payloads still compare unequal, and hash apart', () {
      // The half that catches a `hashCode` replaced by a constant — which
      // "equal values share a hash" would NOT catch. Unaffected by fp_dart.
      final Right<Failure, int> intArm = _builtSuccess<int>(1);
      final Right<Failure, String> stringArm = _builtSuccess<String>('1');

      expect(intArm, isNot(stringArm));
      expect(intArm.hashCode, isNot(stringArm.hashCode));

      // On the failure arm the payloads must actually DIFFER, or the pair
      // collapses into the covariance case pinned above — both arms carry the
      // identical `Failure`, so differing type arguments alone do not make
      // them unequal. That is the trap this arm-specific fixture exists to
      // avoid, and it is the reason the failure arm needs its own payload.
      final Left<Failure, int> fInt = _builtFailureResult<int>(boom);
      final Left<Failure, String> fString = _builtFailureResult<String>(
        _builtFailure(FailureKind.cancelled, 'other'),
      );

      expect(fInt, isNot(fString));
      expect(fInt.hashCode, isNot(fString.hashCode));
    });

    test('a collection payload compares by IDENTITY — recorded, not fixed', () {
      // fp_dart does NOT fix the identity comparison the hand-written type had,
      // and this is the pair that proves it. Both `Result<List<int>>` values carry
      // equal, deeply-equal lists, and they still compare unequal.
      //
      // `==` on a `List` is identity in plain Dart, and fp_dart's `==` delegates
      // to `==` on the payload, so nothing is gained here. This is asserted
      // because the claim "fp_dart fixes collection equality" is easy to believe
      // and is FALSE — and it is REACHABLE, because
      // `today_reading_mapper.dart` builds `Result<List<Verse>>`.
      final shared = <int>[1, 2];

      expect(
        _builtSuccess<List<int>>(shared),
        _builtSuccess<List<int>>(shared),
        reason: 'the same list instance is equal',
      );
      expect(
        _builtSuccess<List<int>>([1, 2]),
        isNot(_builtSuccess<List<int>>([1, 2])),
        reason:
            'but two equal, distinct lists are NOT — and fp_dart does not '
            'change that, contrary to what its type-parameter-free `==` '
            'suggests at first glance',
      );
    });
  });

  group('toString', () {
    // fp_dart's arms render as `Right(4)` / `Left(Failure(...))` — no type
    // arguments (`either.dart:578`, `:667`). That is what a log line and a
    // failed `expect` show, and it is pinned so a rewrite that DROPS THE VALUE
    // cannot pass unnoticed. The type arguments are deliberately not in the
    // rendering: they are noise in a log, and the payload is the part a reader
    // is looking for.

    test('Success names its value', () {
      expect(_builtSuccess<int>(4).toString(), 'Right(4)');
    });

    test('FailureResult names the failure it carries', () {
      expect(
        _builtFailureResult<int>(boom).toString(),
        'Left(Failure(kind: server, statusCode: 500, '
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
    // exactly `Right<Failure, T>` and `Left<Failure, T>`, adding a third subtype makes
    // this function fail to COMPILE — which is the guarantee the test guards.
    String describe(Result<int> result) => switch (result) {
      Right<Failure, int>(:final value) => 'success:$value',
      Left<Failure, int>(value: final failure) =>
        'failure:${failure.kind.name}',
    };

    test('a no-default switch exhausts the sealed type', () {
      expect(describe(const Right<Failure, int>(12)), 'success:12');
      expect(
        describe(
          const Left<Failure, int>(
            Failure(kind: FailureKind.conflict, message: 'already answered'),
          ),
        ),
        'failure:conflict',
      );
    });

    test('a no-default switch can also destructure the Failure', () {
      String code(Result<String> result) => switch (result) {
        Right<Failure, String>(:final value) => value,
        Left<Failure, String>(value: final failure) =>
          '${failure.statusCode ?? 0}:${failure.kind.name}',
      };

      expect(code(const Right<Failure, String>('ok')), 'ok');
      expect(
        code(
          const Left<Failure, String>(
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
