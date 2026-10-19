import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/repositories/cheer_repository.dart';
import 'package:evangelion/features/leaderboard/data/datasources/cheer_local_data_source.dart';
import 'package:fpdart/fpdart.dart';

/// A [CheerRepository] over the session's local set.
///
/// The two arms are the adapter's two arms: read the set, or add to it. There is no
/// transport, so there is no `DioException` and no failure arm to translate today —
/// but the signatures keep [Result] so the day a POST arrives the screen does not
/// change shape (ADR-0022 `:207-215`).
final class LocalCheerRepository implements CheerRepository {
  /// A repository over [dataSource].
  const LocalCheerRepository(this._dataSource);

  final CheerLocalDataSource _dataSource;

  @override
  Future<Result<Set<String>>> cheeredUserIds() async =>
      Result<Set<String>>.of(_dataSource.read());

  @override
  Future<Result<void>> cheer(String userId) async {
    _dataSource.add(userId);
    return const Right<Failure, void>(null);
  }
}
