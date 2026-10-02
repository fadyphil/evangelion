import 'package:evangelion/core/common/failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// The closed vocabulary the dual-shape error mapper (Phase 5) must be able to
/// produce. Asserted as a set of wire names so this pins the *contract* without
/// pinning the declaration order.
const Set<String> _expectedKinds = <String>{
  'network',
  'timeout',
  'unauthorized',
  'forbidden',
  'notFound',
  'conflict',
  'validation',
  'server',
  'serialization',
  'cancelled',
  'unknown',
};

/// A backend message copied verbatim out of AGENT_CONTEXT §5. Tests must never
/// reword it — the string is a contract, not prose.
const String _verbatimMessage = 'body/question_id must match format "uuid"';

void main() {
  group('FailureKind', () {
    test('declares exactly the kinds the mapper can need', () {
      expect(
        FailureKind.values.map((FailureKind k) => k.name).toSet(),
        _expectedKinds,
      );
    });

    test('every kind round-trips through its wire name', () {
      // `byName` is an extension on `Iterable<Enum>`, so the lookup is
      // `values.byName(...)`, never `FailureKind.byName(...)`. An enum value
      // is a singleton, so the round trip must return the identical instance.
      for (final FailureKind kind in FailureKind.values) {
        expect(identical(FailureKind.values.byName(kind.name), kind), isTrue);
      }
    });

    test('is closed: an exhaustive switch needs no default', () {
      // If a kind is ever ADDED, [describe] stops compiling. That is the point:
      // this is a compile-time gate disguised as a test.
      String describe(FailureKind kind) => switch (kind) {
        FailureKind.network => 'network',
        FailureKind.timeout => 'timeout',
        FailureKind.unauthorized => 'unauthorized',
        FailureKind.forbidden => 'forbidden',
        FailureKind.notFound => 'notFound',
        FailureKind.conflict => 'conflict',
        FailureKind.validation => 'validation',
        FailureKind.server => 'server',
        FailureKind.serialization => 'serialization',
        FailureKind.cancelled => 'cancelled',
        FailureKind.unknown => 'unknown',
      };

      expect(describe(FailureKind.conflict), 'conflict');
      expect(FailureKind.values.map(describe).toSet(), _expectedKinds);
    });
  });

  group('Failure', () {
    const Failure sample = Failure(
      kind: FailureKind.conflict,
      message: 'question already answered',
    );

    group('construction', () {
      test('exposes kind and message', () {
        expect(sample.kind, FailureKind.conflict);
        expect(sample.message, 'question already answered');
      });

      test('statusCode is null when the backend gave none', () {
        expect(sample.statusCode, isNull);
      });

      test('statusCode carries the HTTP status when there was one', () {
        expect(
          const Failure(
            kind: FailureKind.unauthorized,
            message: 'missing or malformed X-User-Id',
            statusCode: 401,
          ).statusCode,
          401,
        );
      });

      test('details defaults to null', () {
        expect(sample.details, isNull);
      });

      test('details accepts any object', () {
        expect(
          const Failure(
            kind: FailureKind.validation,
            message: _verbatimMessage,
            details: <String, String>{'field': 'question_id'},
          ).details,
          <String, String>{'field': 'question_id'},
        );
      });

      test('is not const-only: runtime values construct it just as well', () {
        // `backendMessage()` is not a constant expression, so this cannot be
        // collapsed into a `const`. If `Failure` were const-only by
        // construction, the Phase 5 mapper could never build one out of a
        // decoded response body.
        String backendMessage() => _verbatimMessage;

        final Failure runtime = Failure(
          kind: FailureKind.validation,
          message: backendMessage(),
          statusCode: 400,
        );

        expect(runtime.message, 'body/question_id must match format "uuid"');
        expect(runtime.statusCode, 400);
      });

      test('preserves a backend message verbatim', () {
        expect(
          const Failure(
            kind: FailureKind.validation,
            message: _verbatimMessage,
            statusCode: 400,
          ).message,
          'body/question_id must match format "uuid"',
        );
      });
    });

    group('equality', () {
      const Failure twin = Failure(
        kind: FailureKind.conflict,
        message: 'question already answered',
      );

      test('identical fields are equal', () {
        expect(sample, twin);
      });

      test('equal failures share a hash code', () {
        expect(sample.hashCode, twin.hashCode);
      });

      test('a differing kind makes them unequal', () {
        expect(
          sample,
          isNot(
            const Failure(
              kind: FailureKind.server,
              message: 'question already answered',
            ),
          ),
        );
      });

      test('a differing message makes them unequal', () {
        expect(
          sample,
          isNot(
            const Failure(
              kind: FailureKind.conflict,
              message: 'question already answered.',
            ),
          ),
        );
      });

      test('a differing statusCode makes them unequal', () {
        expect(
          sample,
          isNot(
            const Failure(
              kind: FailureKind.conflict,
              message: 'question already answered',
              statusCode: 409,
            ),
          ),
        );
      });

      test('structurally identical details maps compare EQUAL', () {
        // `equatable ^3.0.0` compares `props` with a deep collection equality,
        // so two separately-built but identical maps are equal. (Equatable 2.x
        // used plain `==` and would have said no.) This is the behaviour worth
        // pinning: the mapper can attach a decoded body and rebuild an
        // equivalent `Failure` without accidentally breaking equality.
        expect(
          const Failure(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, String>{'field': 'question_id'},
          ),
          const Failure(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, String>{'field': 'question_id'},
          ),
        );
      });

      test('details with different content make them unequal', () {
        expect(
          const Failure(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, String>{'field': 'question_id'},
          ),
          isNot(
            const Failure(
              kind: FailureKind.validation,
              message: 'bad request',
              details: <String, String>{'field': 'user_id'},
            ),
          ),
        );
      });

      test('absent details and present details make them unequal', () {
        expect(
          const Failure(kind: FailureKind.validation, message: 'bad request'),
          isNot(
            const Failure(
              kind: FailureKind.validation,
              message: 'bad request',
              details: <String, String>{'field': 'question_id'},
            ),
          ),
        );
      });

      test('the SAME details instance keeps them equal', () {
        final Object details = <String, String>{'field': 'question_id'};

        expect(
          Failure(
            kind: FailureKind.validation,
            message: 'bad request',
            details: details,
          ),
          Failure(
            kind: FailureKind.validation,
            message: 'bad request',
            details: details,
          ),
        );
      });
    });
  });
}
