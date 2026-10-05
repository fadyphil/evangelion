import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
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
  // Phase 9, with the settings feature: the local preference store, not a
  // transport. See `FailureKind.storage`'s doc for why `network` was rejected.
  'storage',
  'unknown',
};

/// A backend message copied verbatim out of AGENT_CONTEXT §5. Tests must never
/// reword it — the string is a contract, not prose.
const String _verbatimMessage = 'body/question_id must match format "uuid"';

/// Builds a [Failure] whose identity the compiler cannot fold away.
///
/// `const` arguments to the same constructor call are **canonicalised**: two
/// `const Failure(kind: k, message: m)` expressions compile down to one
/// instance, so `expect(a, b)` between them is really `identical(a, b)` and
/// passes for *any* `props` whatsoever — an empty list included. Every field is
/// therefore threaded through a parameter, which makes each call a genuinely
/// distinct object and the comparison structural. The mutation-testing
/// counterpart to this helper: rewriting `props` to `<Object?>[]` used to leave
/// the const-based suite green.
Failure _built({
  required FailureKind kind,
  required String message,
  int? statusCode,
  Map<String, Object?>? details,
}) => Failure(
  kind: kind,
  message: message,
  statusCode: statusCode,
  details: details,
);

/// A `details` value with no `==` override and no structural equality of its own
/// — the shape that made the old untyped `Object? details` field unsafe.
///
/// The constructor is deliberately non-`const`, so a value built here is a fresh
/// instance rather than a canonicalised one. That matters: a `const` version
/// would be canonicalised, and the whole point is two *equal but distinct*
/// bodies.
final class DecodedBody {
  DecodedBody(this.code);

  final String code;
}

/// A fresh body per call, so two of them are structurally identical but never
/// the same object.
DecodedBody decodedBody() => DecodedBody('E_VALIDATION');

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
        FailureKind.storage => 'storage',
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

      test('details carries the decoded body the mapper attached', () {
        expect(
          const Failure(
            kind: FailureKind.validation,
            message: _verbatimMessage,
            details: <String, Object?>{'field': 'question_id', 'code': 'E_BAD'},
          ).details,
          <String, Object?>{'field': 'question_id', 'code': 'E_BAD'},
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
      // Every operand below comes from [_built], never from a `const` literal.
      // See that helper for why: `const` canonicalisation turns these
      // comparisons into `identical()` and they would pass against any
      // implementation, including one with `props => []`.

      test('identical fields are equal — as distinct objects', () {
        final Failure a = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );
        final Failure b = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );

        // Asserted first: if this ever fails, every equality test below it is
        // comparing an object with itself and proves nothing.
        expect(identical(a, b), isFalse);
        expect(a, b);
      });

      test('equal failures share a hash code', () {
        final Failure a = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );
        final Failure b = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );

        expect(identical(a, b), isFalse);
        expect(a.hashCode, b.hashCode);
      });

      test('a differing kind makes them unequal', () {
        final Failure a = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );
        final Failure b = _built(
          kind: FailureKind.server,
          message: 'question already answered',
        );

        expect(a, isNot(b));
      });

      test('a differing message makes them unequal', () {
        final Failure a = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );
        final Failure b = _built(
          kind: FailureKind.conflict,
          message: 'question already answered.',
        );

        expect(a, isNot(b));
      });

      test('a differing statusCode makes them unequal', () {
        final Failure a = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );
        final Failure b = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
          statusCode: 409,
        );

        expect(a, isNot(b));
      });

      test('absent and present statusCode make them unequal', () {
        // The other direction of the same field: [statusCode] is what separates
        // [FailureKind.conflict] from [FailureKind.validation] when both carry
        // the same message, so a null must not compare equal to a value.
        final Failure withNone = _built(
          kind: FailureKind.validation,
          message: 'bad request',
        );
        final Failure withFourHundred = _built(
          kind: FailureKind.validation,
          message: 'bad request',
          statusCode: 400,
        );

        expect(withNone, isNot(withFourHundred));
      });

      group('details does NOT take part in equality', () {
        // Rationale, once: `Failure` lives inside bloc state, and Equatable
        // compares the whole state graph. `details` rides along for the mapper's
        // benefit, not to be compared. If it participated, a mapper that rebuilt
        // an equivalent body would make two logically identical states unequal —
        // a spurious emit and a rebuild, for no change the player can observe.

        test('structurally identical detail maps leave them equal', () {
          final Failure a = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'field': 'question_id'},
          );
          final Failure b = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'field': 'question_id'},
          );

          expect(identical(a, b), isFalse);
          expect(a, b);
        });

        test('detail maps with different content leave them equal too', () {
          final Failure a = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'field': 'question_id'},
          );
          final Failure b = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'field': 'user_id'},
          );

          expect(a, b);
        });

        test('an absent details and a present one leave them equal', () {
          final Failure absent = _built(
            kind: FailureKind.validation,
            message: 'bad request',
          );
          final Failure present = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'field': 'question_id'},
          );

          expect(absent, present);
        });

        test('a details value with no == override cannot break equality', () {
          // The defect this design removes. `equatable ^3.0.0` deep-compares
          // `Map`, `Set` and `Iterable` props but falls through to plain `==`
          // for anything else, so while `details` sat in `props` this pair
          // compared UNEQUAL — a rebuilt body read as a state change. Note the
          // maps themselves differ too: `identical` is false for each value.
          final Failure a = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'body': decodedBody()},
          );
          final Failure b = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'body': decodedBody()},
          );

          expect(identical(a.details, b.details), isFalse);
          expect(
            identical((a.details!['body']), (b.details!['body'])),
            isFalse,
          );
          expect(a, b);
          expect(a.hashCode, b.hashCode);
        });

        test('and details is still carried along for the mapper', () {
          // The point of excluding it from equality is not to drop it.
          final Failure failure = _built(
            kind: FailureKind.validation,
            message: 'bad request',
            details: <String, Object?>{'code': 'E_BAD'},
          );

          expect(failure.details, <String, Object?>{'code': 'E_BAD'});
        });
      });

      test('a failure is equal to itself', () {
        // Trivially true — but Equatable short-circuits on `identical` before it
        // ever reaches `props`, so this is the one comparison `const`
        // canonicalisation cannot invalidate. Stated so the difference from the
        // tests above is on the record.
        final Failure a = _built(
          kind: FailureKind.conflict,
          message: 'question already answered',
        );

        expect(a, a);
      });
    });

    group('toString', () {
      // Equatable's default is `Instance of 'Failure'`, which tells a reader of
      // a failed assertion nothing. These three renderings are what a log line
      // and an `expect` failure will actually show, so they are pinned.

      test('Failure names its kind, status and message', () {
        expect(
          const Failure(
            kind: FailureKind.conflict,
            message: 'question already answered',
            statusCode: 409,
          ).toString(),
          'Failure(kind: conflict, statusCode: 409, '
          'message: question already answered)',
        );
      });

      test('Failure prints a null statusCode rather than omitting it', () {
        // The alignment of a transport fault with a response fault is the whole
        // job of this string: `statusCode: null` is what marks "never got a
        // reply" as distinct from "replied with nothing useful".
        expect(
          const Failure(
            kind: FailureKind.network,
            message: 'connection refused',
          ).toString(),
          'Failure(kind: network, statusCode: null, '
          'message: connection refused)',
        );
      });

      test('Failure EXCLUDES details, so a decoded body never leaks', () {
        // Deliberate, and pinned so it is not "fixed" later. `details` is a
        // decoded server response body; inlining it would pour that body into
        // every log line and every failed `expect` that prints a `Failure`.
        final Failure withBody = _built(
          kind: FailureKind.validation,
          message: 'bad request',
          details: <String, Object?>{
            'code': 'E_BAD',
            'raw': 'SECRET-TOKEN-SHOULD-NOT-APPEAR',
          },
        );

        expect(withBody.toString(), isNot(contains('E_BAD')));
        expect(
          withBody.toString(),
          isNot(contains('SECRET-TOKEN-SHOULD-NOT-APPEAR')),
        );
        // …while still naming everything that IS safe to log.
        expect(withBody.toString(), contains('kind: validation'));
        expect(withBody.toString(), contains('message: bad request'));
      });

      test('Success names its value', () {
        expect(const Result<int>.success(4).toString(), 'Success<int>(4)');
      });

      test('FailureResult names its failure', () {
        expect(
          const Result<int>.failure(
            Failure(
              kind: FailureKind.server,
              message: 'internal server error',
              statusCode: 500,
            ),
          ).toString(),
          'FailureResult<int>(Failure(kind: server, statusCode: 500, '
          'message: internal server error))',
        );
      });
    });
  });
}
