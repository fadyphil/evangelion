import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/leaderboard/data/datasources/leaderboard_remote_data_source.dart';
import 'package:evangelion/features/leaderboard/data/mappers/leaderboard_mapper.dart';
import 'package:evangelion/features/leaderboard/data/repositories/dio_leaderboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_dio.dart';

/// Unwraps a [Result] that must have failed.
///
/// A switch **statement**, and the pattern binds `failure` because that is
/// `FailureResult`'s field name: Dart's `:name` object patterns bind by field, so
/// `:final Failure f` looks for a field called `f` and reports `f` as undefined.
Failure unwrapFailure<T>(Result<T> result) {
  switch (result) {
    case FailureResult<T>(:final Failure failure):
      return failure;
    case Success<T>():
      fail('expected a failure, got a success');
  }
}

/// Unwraps a [Result] that must have succeeded.
T unwrapSuccess<T>(Result<T> result) {
  switch (result) {
    case Success<T>(:final T value):
      return value;
    case FailureResult<T>(:final Failure failure):
      fail('expected a success, got ${failure.kind}: ${failure.message}');
  }
}

void main() {
  setUpAll(registerRequestOptionsFallback);

  /// The request the adapter was asked for, cleared before each test so one test's
  /// capture cannot satisfy another's assertion.
  ///
  /// Shared rather than per-test because the stubs are written inline below, and a
  /// per-test list would have to be threaded through every one of them.
  final List<RequestOptions> seen = <RequestOptions>[];
  setUp(seen.clear);

  const LeaderboardMapper mapper = LeaderboardMapper();
  const ApiErrorMapper errors = ApiErrorMapper();

  /// A repository over [adapter], with the app's real interceptor still in place.
  DioLeaderboardRepository over(HttpClientAdapter adapter) =>
      DioLeaderboardRepository(
        dataSource: LeaderboardRemoteDataSource(dioWithAdapter(adapter)),
        mapper: mapper,
        errors: errors,
      );

  Future<Result<LeaderboardBoard>> boardOver(HttpClientAdapter adapter) =>
      over(adapter).board(window: LeaderboardWindow.weekly, limit: 3);

  group('the happy path is two arms and no others', () {
    test('a 200 becomes a success carrying the mapped board', () async {
      final MockAdapter adapter = MockAdapter();
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => jsonBody(
          '{"group_id":3,"window":"weekly","total_ranked":0,'
          '"my_standing":null,"leaderboard":[]}',
          200,
        ),
      );
      final Result<LeaderboardBoard> result = await boardOver(adapter);
      expect(unwrapSuccess(result).rows, isEmpty);
    });

    test('and the window and limit are what reaches the wire', () async {
      final MockAdapter adapter = MockAdapter();
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation invocation) async {
            seen.add(invocation.positionalArguments.first as RequestOptions);
            return jsonBody(
              '{"group_id":3,"window":"all_time","total_ranked":0,'
              '"my_standing":null,"leaderboard":[]}',
              200,
            );
          });
      await over(adapter).board(window: LeaderboardWindow.allTime, limit: 50);
      expect(seen.single.uri.query, 'window=all_time&limit=50');
    });

    test('and the cohort arrives on the header the interceptor adds', () async {
      // The server's schema *requires* `X-Group-Id` — omitting it is
      // `400 headers must have required property 'x-group-id'`. Nothing in this
      // feature can supply it, so this asserts the seam it actually relies on.
      final MockAdapter adapter = MockAdapter();
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((Invocation invocation) async {
            seen.add(invocation.positionalArguments.first as RequestOptions);
            return jsonBody(
              '{"group_id":3,"window":"weekly","total_ranked":0,'
              '"my_standing":null,"leaderboard":[]}',
              200,
            );
          });
      await boardOver(adapter);
      expect(seen.single.headers['X-Group-Id'], '3');
    });
  });

  group('a transport fault becomes a typed failure, never a throw', () {
    test('a 500 is `server`, carrying the server\'s own words', () async {
      final MockAdapter adapter = MockAdapter();
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => jsonBody('{"error":"Internal Server Error"}', 500),
      );
      final Result<LeaderboardBoard> result = await boardOver(adapter);
      final Failure failure = unwrapFailure(result);
      expect(failure.kind, FailureKind.server);
      expect(failure.statusCode, 500);
    });

    test(
      'a socket failure is `network`, with the mapper\'s fixed message',
      () async {
        final MockAdapter adapter = MockAdapter();
        when(() => adapter.fetch(any(), any(), any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/leaderboard'),
            type: DioExceptionType.connectionError,
          ),
        );
        final Result<LeaderboardBoard> result = await boardOver(adapter);
        final Failure failure = unwrapFailure(result);
        expect(failure.kind, FailureKind.network);
        expect(failure.message, 'Could not reach the server.');
      },
    );

    test('a timeout is `timeout`, not `network` — the retry differs', () async {
      // The distinction is the whole reason `ApiErrorMapper` switches on `type` rather
      // than testing for "something went wrong".
      final MockAdapter adapter = MockAdapter();
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/leaderboard'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final Result<LeaderboardBoard> result = await boardOver(adapter);
      expect(unwrapFailure(result).kind, FailureKind.timeout);
    });
  });

  group('a 200 that cannot be read', () {
    test(
      'is `serialization`, with the mapper\'s message and not a throw',
      () async {
        final MockAdapter adapter = MockAdapter();
        when(() => adapter.fetch(any(), any(), any()))
            .thenAnswer((_) async => rawBody('<html>502</html>', 200));
        final Result<LeaderboardBoard> result = await boardOver(adapter);
        final Failure failure = unwrapFailure(result);
        expect(failure.kind, FailureKind.serialization);
        expect(failure.message, contains('HTML'));
      },
    );
  });

  group('the seeded empty board', () {
    test('is a success with no rows, through the whole stack', () async {
      final MockAdapter adapter = MockAdapter();
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => jsonBody(
          '{"group_id":3,"window":"weekly","total_ranked":0,'
          '"my_standing":null,"leaderboard":[]}',
          200,
        ),
      );
      final Result<LeaderboardBoard> result = await boardOver(adapter);
      expect(unwrapSuccess(result).rows, isEmpty);
    });
  });
}
