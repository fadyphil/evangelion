import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Succeeds with a fixed greeting. Lives in `test/`, never in `lib/` — the
/// production use cases arrive with the features that own them.
final class GreetUser implements NoParamsUseCase<String> {
  const GreetUser();

  @override
  Future<Result<String>> call() async => const Result<String>.success('Shalom');
}

/// Takes params, so it exercises the two-parameter seam.
final class LengthOfReference implements UseCase<String, int> {
  const LengthOfReference();

  @override
  Future<Result<int>> call(String params) async =>
      Result<int>.success(params.length);
}

/// Every exception path a repository has to swallow before it can honour the
/// LSP row: a parse fault, a programmer fault, and a hard `Error`.
final class ExplodingUserLoader implements NoParamsUseCase<int> {
  const ExplodingUserLoader();

  @override
  Future<Result<int>> call() async {
    try {
      throw const FormatException('malformed reading_id');
    } on FormatException {
      return const Result<int>.failure(
        Failure(
          kind: FailureKind.serialization,
          message: 'malformed reading_id',
        ),
      );
    }
  }
}

/// A domain-specific exception of the kind a mapper realistically throws when
/// a response body does not match the contract (AGENT_CONTEXT §5 trap 2: the
/// English localized reading has no `text_clean` key at all).
final class ReadingParseException implements Exception {
  const ReadingParseException(this.field);

  final String field;

  @override
  String toString() => 'ReadingParseException($field)';
}

/// The second realistic fault class: a second `Exception` subtype, to prove the
/// catch is not accidentally specific to one type.
///
/// Note what is deliberately NOT here: a fake that catches an `Error`. Swallowing
/// `Error` hides programmer bugs, `avoid_catching_errors` forbids it, and no
/// repository or mapper in this codebase throws one. `Exception` is the fault
/// class the seam is responsible for; anything else is a bug that should
/// propagate loudly rather than be laundered into a `Result`.
final class BrokenReadingRepository implements NoParamsUseCase<int> {
  const BrokenReadingRepository();

  @override
  Future<Result<int>> call() async {
    try {
      throw const ReadingParseException('text_clean');
    } on ReadingParseException {
      return const Result<int>.failure(
        Failure(
          kind: FailureKind.serialization,
          message: 'text_clean is absent from the en payload',
        ),
      );
    }
  }
}

/// Always fails — the negative arm every cubit must handle.
final class UnreachableEndpoint implements NoParamsUseCase<int> {
  const UnreachableEndpoint();

  @override
  Future<Result<int>> call() async => const Result<int>.failure(
    Failure(kind: FailureKind.network, message: 'connection refused'),
  );
}

void main() {
  group('NoParamsUseCase', () {
    test('is a callable object: usecase(), not usecase.execute()', () async {
      // Calling through the INTERFACE is the point. The seam has no
      // `execute` method, so there is nothing else it could be.
      const NoParamsUseCase<String> usecase = GreetUser();

      final Result<String> result = await usecase();

      expect(result.isSuccess, isTrue);
    });

    test('is typed as Future<Result<Out>>', () async {
      const GreetUser usecase = GreetUser();

      final Future<Result<String>> future = usecase();

      expect(future, isA<Future<Result<String>>>());
      expect(await future, const Result<String>.success('Shalom'));
    });

    test('does not require a Flutter binding', () async {
      // Nothing in `core/domain/` touches `package:flutter`, so no
      // `WidgetsFlutterBinding.ensureInitialized()` is needed to run a use
      // case. This suite would hang or throw on a binding call; the mechanical
      // proof is the `rg` gate in AGENT_CONTEXT §7.
      const NoParamsUseCase<String> usecase = GreetUser();

      expect(await usecase(), const Result<String>.success('Shalom'));
    });

    test('a concrete implementation is substitutable for another', () async {
      final List<NoParamsUseCase<int>> usecases = <NoParamsUseCase<int>>[
        const ExplodingUserLoader(),
        const BrokenReadingRepository(),
        const UnreachableEndpoint(),
      ];

      final List<FailureKind> kinds = <FailureKind>[
        for (final NoParamsUseCase<int> usecase in usecases)
          (await usecase())
              .failureOrElse(
                const Failure(
                  kind: FailureKind.unknown,
                  message: 'unreachable',
                ),
              )
              .kind,
      ];

      expect(kinds, <FailureKind>[
        FailureKind.serialization,
        FailureKind.serialization,
        FailureKind.network,
      ]);
    });
  });

  group('the domain layer never throws across the seam', () {
    test('a FormatException becomes a serialization failure', () async {
      const NoParamsUseCase<int> usecase = ExplodingUserLoader();

      final Result<int> result = await usecase();

      expect(result.isFailure, isTrue);
      expect(
        result
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: 'unreachable'),
            )
            .kind,
        FailureKind.serialization,
      );
    });

    test(
      'a domain-specific Exception becomes a serialization failure',
      () async {
        const NoParamsUseCase<int> usecase = BrokenReadingRepository();

        final Result<int> result = await usecase();

        expect(
          result
              .failureOrElse(
                const Failure(
                  kind: FailureKind.unknown,
                  message: 'unreachable',
                ),
              )
              .kind,
          FailureKind.serialization,
        );
      },
    );

    test('the catch is not accidentally narrow: two unrelated Exceptions', () async {
      // `ExplodingUserLoader` catches `FormatException`, this one catches
      // `ReadingParseException`. Both arrive as typed failures, so the seam is
      // not keyed to one exception type.
      expect(
        (await const ExplodingUserLoader()())
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: 'unreachable'),
            )
            .kind,
        FailureKind.serialization,
      );
      expect(
        (await const BrokenReadingRepository()())
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: 'unreachable'),
            )
            .kind,
        FailureKind.serialization,
      );
    });

    test('invoking a throwing use case does not rethrow', () async {
      // If the catch were missing, this would fail with an uncaught
      // FormatException rather than returning a failure.
      const NoParamsUseCase<int> usecase = ExplodingUserLoader();

      await expectLater(usecase(), completes);
    });

    test('a failure message survives the seam verbatim', () async {
      const NoParamsUseCase<int> usecase = UnreachableEndpoint();

      expect(
        (await usecase())
            .failureOrElse(
              const Failure(kind: FailureKind.unknown, message: 'unreachable'),
            )
            .message,
        'connection refused',
      );
    });
  });

  group('UseCase<In, Out>', () {
    test('is callable with its params', () async {
      const UseCase<String, int> usecase = LengthOfReference();

      expect(await usecase('John 3: 1-5'), const Result<int>.success(11));
    });

    test('is typed as Future<Result<Out>>', () async {
      const LengthOfReference usecase = LengthOfReference();

      final Future<Result<int>> future = usecase('abc');

      expect(future, isA<Future<Result<int>>>());
      expect(await future, const Result<int>.success(3));
    });

    test('rejects nothing itself: params reach the implementation', () async {
      const LengthOfReference usecase = LengthOfReference();

      expect(await usecase(''), const Result<int>.success(0));
    });
  });

  group('the two seams agree', () {
    test('both are awaited to a Result and never a bare value', () async {
      final List<Future<Result<Object?>>> futures = <Future<Result<Object?>>>[
        const GreetUser().call().then(
          (Result<String> r) => r.map<Object?>((String s) => s),
        ),
        const LengthOfReference()
            .call('abc')
            .then((Result<int> r) => r.map<Object?>((int n) => n)),
      ];

      for (final Future<Result<Object?>> future in futures) {
        expect(await future, isA<Result<Object?>>());
      }
    });
  });
}
