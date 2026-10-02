import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 5xx with the shape AGENT_CONTEXT §5 documents.
const Failure boom = Failure(
  kind: FailureKind.server,
  message: 'internal server error',
  statusCode: 500,
);

void main() {
  group('construction', () {
    test('success() carries a value and reports isSuccess', () {
      const Result<int> result = Result<int>.success(7);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('failure() carries a Failure and reports isFailure', () {
      const Result<int> result = Result<int>.failure(boom);

      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('both factories are const-constructible', () {
      // Repository impls return results from non-constant expressions too;
      // neither arm may be const-only.
      final Result<int> runtimeSuccess = Result<int>.success(
        DateTime.now().year,
      );
      final Result<int> runtimeFailure = Result<int>.failure(
        Failure(kind: FailureKind.unknown, message: runtimeSuccess.toString()),
      );

      expect(runtimeSuccess.isSuccess, isTrue);
      expect(runtimeFailure.isFailure, isTrue);
    });

    test('isFailure is always the negation of isSuccess', () {
      for (final Result<int> result in <Result<int>>[
        const Result<int>.success(1),
        const Result<int>.failure(boom),
      ]) {
        expect(result.isFailure, isNot(result.isSuccess));
      }
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
      const Result<int> result = Result<int>.success(3);

      expect(
        result.fold<int>(onSuccess: (int v) => v, onFailure: (Failure _) => -1),
        3,
      );
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

    test('accepts any fallback type and returns it verbatim', () {
      expect(
        const Result<int>.failure(boom).valueOrElse('unavailable'),
        'unavailable',
      );
    });
  });

  group('failureOrElse', () {
    test('returns the failure for a failure', () {
      expect(
        identical(const Result<int>.failure(boom).failureOrElse(boom), boom),
        isTrue,
      );
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
    test('two successes with equal values are equal', () {
      expect(const Result<int>.success(4), const Result<int>.success(4));
    });

    test('equal successes share a hash code', () {
      expect(
        const Result<int>.success(4).hashCode,
        const Result<int>.success(4).hashCode,
      );
    });

    test('successes with different values are NOT equal', () {
      expect(const Result<int>.success(4), isNot(const Result<int>.success(5)));
    });

    test('two failures carrying equal Failures are equal', () {
      expect(const Result<int>.failure(boom), const Result<int>.failure(boom));
    });

    test('failures carrying different Failures are NOT equal', () {
      expect(
        const Result<int>.failure(boom),
        isNot(
          const Result<int>.failure(
            Failure(kind: FailureKind.conflict, message: 'already answered'),
          ),
        ),
      );
    });

    test('a success is NEVER equal to a failure', () {
      expect(
        const Result<int>.success(0),
        isNot(const Result<int>.failure(boom)),
      );
    });

    test('a failure is never equal to a success', () {
      expect(
        const Result<int>.failure(boom),
        isNot(const Result<int>.success(0)),
      );
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
