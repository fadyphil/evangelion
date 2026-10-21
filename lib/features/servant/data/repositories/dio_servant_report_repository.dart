import 'package:dio/dio.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/network/api_error_mapper.dart';
import 'package:evangelion/features/servant/data/datasources/servant_remote_data_source.dart';
import 'package:evangelion/features/servant/data/mappers/report_mapper.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';

/// The live [ServantReportRepository].
///
/// ## THE BODY IS TWO ARMS, AND THAT IS THE WHOLE OF THE CONTRACT
///
/// ```dart
/// try   → Result.left(errors.fromDioException(e))   // transport, or non-2xx
/// body  → mapper.map(body)                          // 2xx that cannot be read
/// ```
///
/// §3's LSP row: never throws, always returns a `Result`.
///
/// ## AND IT IS A SEPARATE ADAPTER BECAUSE THE PORT IS A SEPARATE ONE
///
/// The report is a **viewer's** job as much as an admin's, and the port says so
/// (`servant_report_repository.dart`). A single adapter over a single fat port
/// would hand the viewer servant the scheduling methods, and the only thing
/// keeping her from pressing them would be the screen's own care — which is
/// exactly the accident the role gate exists to prevent.
final class DioServantReportRepository implements ServantReportRepository {
  /// A repository over [dataSource], projecting with [mapper] and translating
  /// faults with [errors].
  const DioServantReportRepository({
    required this.dataSource,
    required this.mapper,
    required this.errors,
  });

  /// Where the request goes. Injected rather than built, so the endpoint path
  /// has exactly one home.
  final ServantRemoteDataSource dataSource;

  /// Report body → [ServantReport]. `const`, and shared by every
  /// `DioServantReportRepository`.
  final ReportMapper mapper;

  /// Exception → [Failure]. `const`, and the one place a status becomes a kind.
  final ApiErrorMapper errors;

  @override
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  }) async {
    try {
      final Object? body = await dataSource.dailyReport(
        groupId: groupId,
        date: date,
      );
      return mapper.map(body);
    } on DioException catch (error) {
      return Result<ServantReport>.left(errors.fromDioException(error));
    }
  }
}
