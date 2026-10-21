import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/usecase/usecase.dart';
import 'package:evangelion/features/servant/domain/entities/reading_schedule.dart';
import 'package:evangelion/features/servant/domain/entities/schedule_result.dart';
import 'package:evangelion/features/servant/domain/repositories/servant_admin_repository.dart';

/// Schedules a reading for one or more cohorts.
///
/// ## IT ADDS NOTHING TO THE PORT, AND THAT IS THE POINT
///
/// §3's DIP row: a use case that reclassified an error or reshaped an entity
/// would be a **second** place where the wire's meaning is decided, and
/// `ApiErrorMapper` plus `ScheduleMapper` are already it. What the class buys
/// is the **seam** — the cubit depends on this, so a test can hold the
/// schedule open without writing a repository, and swapping the adapter is a
/// change to one provider in `servant_module.dart` rather than to every
/// caller.
///
/// `LoadLeaderboard`'s doc gives the same argument at greater length, and this
/// is the same instance of it in this feature.
///
/// ## AND THE INPUT IS THE SCHEDULE ITSELF
///
/// One value in, one value out, so there is no params object here. The other
/// three use cases in this feature need two inputs each and do have one.
final class ScheduleReading
    implements UseCase<ReadingSchedule, ScheduleResult> {
  /// Schedules through [repository].
  const ScheduleReading(this._repository);

  final ServantAdminRepository _repository;

  @override
  Future<Result<ScheduleResult>> call(ReadingSchedule params) =>
      _repository.scheduleReading(params);
}
