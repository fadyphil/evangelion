import 'package:evangelion/core/common/failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins [Failure]'s **equality contract**, which is narrower than its shape.
///
/// ## WHY THIS FILE EXISTS
///
/// `Failure` has four fields and its `props` lists three. That is not an
/// oversight and it is not a lint accident — `failure.dart` says so in three
/// places, and the reason is good: `equatable ^3.0.0` deep-compares `Map`, `Set`
/// and `Iterable` props but falls through to plain `==` for everything else, so
/// an untyped field would make two logically identical failures unequal the
/// moment the attached value has no `==` override. [Failure] lives inside bloc
/// state, so that would look like a state change and cost a spurious emit.
///
/// **Nothing asserted any of it.** A consequence of that is the failure mode
/// this file exists to prevent: the exclusion is a *decision* with no test, so
/// the next agent — or the next code generator — can reverse it silently and
/// every suite stays green. `freezed` is exactly that generator: it derives
/// `==` from the constructor and offers no per-field exclusion, so migrating
/// `Failure` without keeping `==`, `hashCode` and `props` hand-written would
/// put a decoded server body into the equality contract on purpose.
///
/// These assertions are therefore **deliberately narrow**. Each one says what
/// the exclusion buys, so reversing it has to be a visible edit rather than a
/// silent one.
void main() {
  group('Failure equality', () {
    const Failure base = Failure(
      kind: FailureKind.server,
      message: 'boom',
      statusCode: 500,
    );

    test('two identical failures are equal', () {
      expect(
        const Failure(
          kind: FailureKind.server,
          message: 'boom',
          statusCode: 500,
        ),
        base,
      );
    });

    test('[kind] decides equality — the mapper must not reuse a kind', () {
      expect(
        const Failure(
          kind: FailureKind.validation,
          message: 'boom',
          statusCode: 500,
        ),
        isNot(base),
      );
    });

    test('[message] decides equality — it is the only clue the player has', () {
      expect(
        const Failure(
          kind: FailureKind.server,
          message: 'other',
          statusCode: 500,
        ),
        isNot(base),
      );
    });

    test('[statusCode] decides equality — it is what separates conflict from '
        'validation when both carry the same message', () {
      // The two cases that are indistinguishable without it. `01-source-analysis.md`
      // and Phase 7 both record the 409, and this pair is the reason the field
      // earns a place in the contract.
      const Failure conflict = Failure(
        kind: FailureKind.conflict,
        message: 'This question has already been submitted by this user.',
        statusCode: 409,
      );
      const Failure validation = Failure(
        kind: FailureKind.validation,
        message: 'This question has already been submitted by this user.',
        statusCode: 400,
      );
      expect(conflict, isNot(validation));
    });

    test('[details] does NOT decide equality, and that is the decision this file '
        'exists to pin', () {
      // Two failures a mapper produced from two responses carrying the same
      // kind, message and status but different decoded bodies. They compare
      // EQUAL, on purpose: `details` rides along for a logger, not for
      // comparison, and nothing in `lib/` reads it. If this assertion ever has
      // to flip, the change is a decision with a reason and a release note —
      // not a codegen side effect.
      const Failure first = Failure(
        kind: FailureKind.server,
        message: 'boom',
        statusCode: 500,
        details: <String, Object?>{'body': 1},
      );
      const Failure second = Failure(
        kind: FailureKind.server,
        message: 'boom',
        statusCode: 500,
        details: <String, Object?>{'body': 2},
      );

      expect(first, base);
      expect(second, base);
      expect(first, second);
      expect(first.hashCode, second.hashCode);

      // And the field is still there for the mapper — the exclusion is about
      // equality, not about dropping data on the floor.
      expect(first.details, const <String, Object?>{'body': 1});
      expect(base.details, isNull);
    });

    test(
      'toString omits [details], so a decoded server body cannot reach a log '
      'line or a failed expect',
      () {
        const Failure withBody = Failure(
          kind: FailureKind.server,
          message: 'boom',
          statusCode: 500,
          details: <String, Object?>{'secret': 'do-not-log-me'},
        );
        expect(withBody.toString(), contains('boom'));
        expect(withBody.toString(), isNot(contains('do-not-log-me')));
      },
    );
  });
}
