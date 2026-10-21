import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/features/servant/domain/entities/servant_report.dart';

/// The cohort's daily roster completion report.
///
/// ## WHY THIS IS ITS OWN PORT AND NOT A FOURTH METHOD ON THE ADMIN ONE
///
/// A `viewer_servant` may read the report and may **not** schedule a reading or
/// author a question. A single port carrying all four would give that reader
/// three operations it must never call, and the only thing keeping it from
/// calling them would be the UI's own care — which is exactly the kind of
/// accident the role gate is there to prevent.
///
/// The admin half is `ServantAdminRepository`.
///
/// ## AND WHY IT LIVES HERE AND NOT IN `core/domain/`
///
/// §3's placement test: one consumer — the `servant` feature — so it belongs
/// to that feature's `domain/`, not to the shared kernel.
abstract interface class ServantReportRepository {
  /// The roster for [groupId] on [date].
  ///
  /// [date] is `YYYY-MM-DD`, and the server **echoes the date it was given**
  /// (`admin.routes.ts:374`, `:418`) — it defaults to its own today when the
  /// querystring omits it, so a report for a past day and a report for today
  /// are distinguishable by the answer.
  Future<Result<ServantReport>> loadDailyReport({
    required int groupId,
    required String date,
  });
}
