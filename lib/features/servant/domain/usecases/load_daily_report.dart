import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_report_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'load_daily_report.freezed.dart';

/// Which cohort, and which day.
///
/// ## WHY THE DATE IS A STRING AND NOT A `DateTime`
///
/// The server's querystring schema types `date` as a plain string
/// (`admin.routes.ts:340`) and parses it with `queryParams.date || today`
/// (`:374`) — **no format check at all** on this route, unlike
/// `?date=` elsewhere in the backend (§5 trap 6). The client sends the same
/// `YYYY-MM-DD` shape it sends everywhere else, and the string keeps the
/// client's request and the server's echoed `report_date` byte-identical.
@freezed
final class DailyReportQuery with _$DailyReportQuery {
  /// A report request.
  const DailyReportQuery({required this.groupId, required this.date});

  /// The cohort the report is for.
  final int groupId;

  /// The day the report is for, `YYYY-MM-DD`.
  final String date;
}

/// The cohort's daily roster report.
///
/// ## IT ADDS NOTHING TO THE PORT, AND THAT IS THE POINT
///
/// §3's DIP row: the wire's meaning is decided once, in the mapper and the
/// error mapper. What the class buys is the **seam** — the cubit depends on
/// this, so a test can hold the report open without writing a repository, and
/// swapping the adapter is a change to one provider rather than to every
/// caller.
final class LoadDailyReport
    implements UseCase<DailyReportQuery, ServantReport> {
  /// Loads through [repository].
  const LoadDailyReport(this._repository);

  final ServantReportRepository _repository;

  @override
  Future<Result<ServantReport>> call(DailyReportQuery params) =>
      _repository.loadDailyReport(groupId: params.groupId, date: params.date);
}
