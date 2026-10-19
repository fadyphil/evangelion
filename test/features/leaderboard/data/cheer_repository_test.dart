import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/leaderboard/data/datasources/cheer_local_data_source.dart';
import 'package:evangelion/features/leaderboard/data/repositories/local_cheer_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Unwraps a [Result] that must have succeeded, failing the test with the reason.
T unwrapSuccess<T>(Result<T> result) {
  switch (result) {
    case Right<Failure, T>(:final T value):
      return value;
    case Left<Failure, T>(value: final failure):
      fail('expected a success, got ${failure.kind}: ${failure.message}');
  }
}

void main() {
  group('CheerLocalDataSource is the prototype set, transcribed', () {
    test('starts empty', () {
      expect(CheerLocalDataSource().read(), isEmpty);
    });

    test('records a cheer, and reports the first one as new', () {
      final CheerLocalDataSource data = CheerLocalDataSource();
      expect(data.add('youssef'), isTrue);
      expect(data.read(), <String>{'youssef'});
    });

    test('a second cheer for the same witness is not new', () {
      // `if(cheered.has(p.id)) return;` — `redesign.html:1120`.
      final CheerLocalDataSource data = CheerLocalDataSource();
      expect(data.add('youssef'), isTrue);
      expect(data.add('youssef'), isFalse);
      expect(data.read(), hasLength(1));
    });

    test('keeps every distinct witness, and never clears on read', () {
      final CheerLocalDataSource data = CheerLocalDataSource();
      data.add('youssef');
      data.add('abbas');
      data.read();
      expect(data.read(), <String>{'youssef', 'abbas'});
    });

    test('hands out a snapshot a caller cannot write through', () {
      final CheerLocalDataSource data = CheerLocalDataSource();
      data.add('youssef');
      expect(() => data.read().add('abbas'), throwsUnsupportedError);
      expect(data.read(), <String>{'youssef'});
    });
  });

  group('LocalCheerRepository projects the set through Result', () {
    test('an untouched session reads as an empty success', () async {
      final LocalCheerRepository repository = LocalCheerRepository(
        CheerLocalDataSource(),
      );
      expect(unwrapSuccess(await repository.cheeredUserIds()), isEmpty);
    });

    test('a cheer is a success and is visible to the next read', () async {
      final LocalCheerRepository repository = LocalCheerRepository(
        CheerLocalDataSource(),
      );
      unwrapSuccess(await repository.cheer('theodora'));
      expect(unwrapSuccess(await repository.cheeredUserIds()), <String>{
        'theodora',
      });
    });

    test('two repositories over one data source share the session', () async {
      // The DI graph makes the data source a singleton, so this is the ownership
      // that makes a route pop and push remember the cheer. If the repository had
      // held its own set, this would fail while the screen still looked right.
      final CheerLocalDataSource data = CheerLocalDataSource();
      await LocalCheerRepository(data).cheer('ruth');
      expect(
        unwrapSuccess(await LocalCheerRepository(data).cheeredUserIds()),
        <String>{'ruth'},
      );
    });

    test('a repeated cheer stays a success, with one member', () async {
      // The prototype's first-tap-only guard is the cubit's, but a retry of a
      // dropped request must not become a failure. See the port's doc.
      final LocalCheerRepository repository = LocalCheerRepository(
        CheerLocalDataSource(),
      );
      unwrapSuccess(await repository.cheer('salim'));
      unwrapSuccess(await repository.cheer('salim'));
      expect(unwrapSuccess(await repository.cheeredUserIds()), hasLength(1));
    });
  });
}
