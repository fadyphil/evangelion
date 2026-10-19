import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/journey/data/datasources/medal_local_data_source.dart';
import 'package:evangelion/features/journey/data/repositories/medal_repository_impl.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/domain/medal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The medal port, the shelf it hands over, and the one adapter that ships.
///
/// ## WHY THE ENUM GETS ITS OWN ROW
///
/// A fifth medal is a **compile-time** change to `medal.dart` and a
/// translation change in the ARB — and it must never be an accident in a list
/// literal somewhere in a widget. So the enum's size is asserted here, and
/// asserted by **name** rather than by count alone: a count would still pass if
/// a fifth medal replaced a fourth.
void main() {
  group('the enum', () {
    test('has exactly four entries, and they are the prototype\'s four', () {
      expect(
        Medal.values,
        hasLength(4),
        reason:
            'the prototype draws four (`:599-602`). A fifth is an edit to '
            '`medal.dart` and to the ARB, and it is never a fifth on its own.',
      );
      expect(Medal.values.map((Medal medal) => medal.name).toList(), <String>[
        'firstLight',
        'psalmist',
        'streakSeven',
        'john',
      ], reason: 'and they are these four, in the prototype\'s order');
    });

    test(
      'and each one carries the emblem and the bloom the prototype gave it',
      () {
        expect(
          <({MedalEmblem emblem, MedalBloom bloom})>[
            for (final Medal medal in Medal.values)
              (emblem: medal.emblem, bloom: medal.bloom),
          ],
          const <({MedalEmblem emblem, MedalBloom bloom})>[
            (emblem: MedalEmblem.fourPointedStar, bloom: MedalBloom.cream),
            (emblem: MedalEmblem.fleuron, bloom: MedalBloom.magenta),
            (emblem: MedalEmblem.malteseCross, bloom: MedalBloom.amber),
            (emblem: MedalEmblem.crossOfSaintJohn, bloom: MedalBloom.blue),
          ],
          reason:
              'the emblems and the blooms are per-entry design facts, and the '
              'suite that reads them out of the prototype is '
              '`medal_local_data_source_test.dart`',
        );
      },
    );
  });

  group('the shelf', () {
    test('is a value, and two shelves with the same medals are the same shelf', () {
      // **The value comparison is what stops a cubit from reporting a change
      // every time the same four medals are read again**, and `List`'s own `==`
      // is identity — so the shelf compares its medals one by one.
      expect(MedalLocalDataSource().shelf(), MedalLocalDataSource().shelf());
      expect(
        MedalLocalDataSource().shelf().hashCode,
        MedalLocalDataSource().shelf().hashCode,
      );
      expect(
        MedalLocalDataSource().shelf(),
        isNot(
          MedalShelf(
            earned: const <Medal>[
              Medal.firstLight,
              Medal.psalmist,
              Medal.streakSeven,
            ],
            total: 12,
          ),
        ),
        reason: 'three medals are not four, and the comparison is not vacuous',
      );
    });

    test('holds a list that cannot be edited from a widget', () {
      final MedalShelf shelf = MedalLocalDataSource().shelf();
      expect(
        () => shelf.earned.add(Medal.john),
        throwsUnsupportedError,
        reason:
            'the list is copied into an unmodifiable one, so the state a cubit '
            'holds cannot be edited from a widget',
      );
    });

    test('and it cannot hold more earned medals than exist', () {
      expect(
        () => MedalShelf(
          earned: const <Medal>[
            Medal.firstLight,
            Medal.psalmist,
            Medal.streakSeven,
            Medal.john,
          ],
          total: 3,
        ),
        throwsA(isA<AssertionError>()),
        reason:
            'four earned out of three is not a shelf the prototype could draw',
      );
    });
  });

  group('the repository', () {
    test('hands on the stub\'s shelf unchanged', () async {
      final MedalLocalDataSource dataSource = MedalLocalDataSource();
      final Result<MedalShelf> result = await MedalRepositoryImpl(dataSource)
          .shelf();

      expect(result.isRight(), isTrue, reason: 'the shipped stub cannot fail');
      final MedalShelf shelf = result.fold(
        (Failure failure) =>
            fail('the stub was not supposed to fail: $failure'),
        (MedalShelf shelf) => shelf,
      );
      expect(
        shelf,
        dataSource.shelf(),
        reason: 'the same four medals out of the same twelve',
      );
      expect(shelf.earned, <Medal>[
        Medal.firstLight,
        Medal.psalmist,
        Medal.streakSeven,
        Medal.john,
      ]);
      expect(shelf.total, 12);
    });

    test('answers a `Result`, and never a bare shelf', () async {
      final Result<MedalShelf> result = await MedalRepositoryImpl(
        MedalLocalDataSource(),
      ).shelf();
      expect(result, isA<Result<MedalShelf>>());
    });

    test('and a shelf it cannot read is a failing Result, not a crash', () async {
      // The whole point of the port's "never throws, always a `Result`" row:
      // the exception the data source raised stops here, and the caller sees a
      // failure it can render.
      final Result<MedalShelf> result = await MedalRepositoryImpl(
        _UnreadableMedalDataSource(),
      ).shelf();

      expect(result.isLeft(), isTrue, reason: 'the shelf could not be read');
      final Failure failure = result.fold(
        (Failure failure) => failure,
        (MedalShelf shelf) => fail('the shelf was expected to fail'),
      );
      expect(failure.kind, FailureKind.unknown);
      expect(
        failure.message,
        contains('The medal shelf could not be read'),
        reason: 'and the message says which shelf',
      );
    });

    test('and a data source that throws an Error is caught the same way', () async {
      // `catch (Object)` and not `catch (Exception)`: an `Error` escaping would
      // take the frame with it, and the port's promise does not say "unless it
      // is an `Error`".
      final Result<MedalShelf> result = await MedalRepositoryImpl(
        _BrokenMedalDataSource(),
      ).shelf();

      expect(result.isLeft(), isTrue);
      expect(
        result.fold(
          (Failure failure) => failure.kind,
          (MedalShelf shelf) => fail('the shelf was expected to fail'),
        ),
        FailureKind.unknown,
      );
    });
  });
}

/// A data source whose shelf cannot be produced.
///
/// **Not `const`**, and that is deliberate: a const constructor would make
/// `prefer_const_constructors` ask for a `const` at the call site, and a
/// `const` instance of a thing that always throws is a small lie.
final class _UnreadableMedalDataSource implements MedalLocalDataSource {
  @override
  MedalShelf shelf() => throw StateError('the shelf is unreadable');
}

/// A data source that fails with an `Error` rather than an `Exception`.
final class _BrokenMedalDataSource implements MedalLocalDataSource {
  @override
  MedalShelf shelf() => throw ArgumentError('the shelf is broken');
}
