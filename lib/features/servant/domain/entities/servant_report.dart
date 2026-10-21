import 'package:evangelion/features/servant/domain/entities/roster_student.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'servant_report.freezed.dart';

/// The cohort's roster for one day.
///
/// ## THE RESPONSE, FIELD FOR FIELD
///
/// `admin.routes.ts:416-422` sends:
///
/// ```text
/// group_id, report_date, total_students, completed_count, students[]
/// ```
///
/// and the schema at `:344-351` declares the same five keys.
///
/// ## THE TWO TOTALS ARE **THE SERVER'S**, AND THE CLIENT DOES NOT ADD THEM UP
///
/// `total_students` is `report.length` and `completed_count` is
/// `report.filter(r => r.completed_today).length` (`:419-420`) — both
/// computed **over the rows the server sent**. The query is a `LEFT JOIN` on
/// the day's reading (`:396`), so a cohort with no reading that date still
/// produces rows, with `0/0` progress and `completed_today: false`.
///
/// So the totals and the rows are the same fact counted twice, and a client
/// that recomputed either from the rows would be a second implementation of a
/// query it cannot see. They are carried as the server sent them.
///
/// ## AND `reportDate` IS THE **DATE ASKED FOR**, ECHOED
///
/// The route defaults it to the server's today when the querystring omits it
/// (`:374`) and otherwise echoes what it was given, so the report's date is
/// the date the request named — which is what makes a report for a past day
/// distinguishable from today's.
@freezed
final class ServantReport with _$ServantReport {
  /// A cohort's roster for one day.
  const ServantReport({
    required this.groupId,
    required this.reportDate,
    required this.totalStudents,
    required this.completedCount,
    required this.students,
  });

  /// The cohort the report is for.
  final int groupId;

  /// The date the report is for, `YYYY-MM-DD`.
  final String reportDate;

  /// How many children are on the roster.
  final int totalStudents;

  /// How many of them completed the day's questions.
  final int completedCount;

  /// The roster itself, one row per child.
  final List<RosterStudent> students;
}
