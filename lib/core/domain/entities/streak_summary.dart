import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_summary.freezed.dart';

/// Where today sits in the streak, as the streak endpoint reports it.
///
/// ## WHY THIS IS AN ENUM AND NOT A `String`
///
/// `today_status` ∈ `completed | pending | off_day | broken` (AGENT_CONTEXT §5),
/// and every consumer of it is a `switch` that has to be exhaustive. A `String`
/// makes that a `default` arm, and a `default` arm is a guess: the first status
/// this client has never heard of would report whatever the guess says. As an
/// enum, adding a fifth value is a compile error in every `switch` that consumes
/// it and in [fromCode]'s own callers, which is the point.
enum StreakTodayStatus {
  /// `completed` — today's reading is finished and the streak has moved.
  completed('completed'),

  /// `pending` — scheduled, and not yet done. What the live payload says.
  pending('pending'),

  /// `off_day` — no reading is scheduled for today at all.
  offDay('off_day'),

  /// `broken` — a scheduled day was missed, so the streak is at zero.
  broken('broken');

  const StreakTodayStatus(this.code);

  /// The wire value, snake_case included. Spelled out rather than derived from
  /// the member name: `.name` would give `offDay`, and the server sends
  /// `off_day`.
  final String code;

  /// The status [code] names, or `null` if it names none of them.
  ///
  /// ## WHY `null` AND NOT A DEFAULT
  ///
  /// This value arrives inside a **2xx body**. A body this client cannot read is
  /// `FailureKind.serialization` — `failure.dart` documents that kind as "a 2xx
  /// response body could not be parsed into a domain entity" — and the only way
  /// to reach it is for this function to say "no". Defaulting an unknown status
  /// to [pending] would report *nothing done today* for a server that has said
  /// something this client does not understand, and `/result`'s streak pill would
  /// then draw a claim rather than an error.
  static StreakTodayStatus? fromCode(String code) => switch (code) {
    'completed' => completed,
    'pending' => pending,
    'off_day' => offDay,
    'broken' => broken,
    _ => null,
  };
}

/// The reader's streak, as `GET /streak/summary` reports it.
///
/// ## THE BACKEND DISAGREES WITH ITSELF, AND THIS TYPE DOES NOT RECONCILE IT
///
/// Two live readings, same user, same group, same day, `HEAD = 4a1c834`:
///
/// ```
/// GET /api/v1/streak/summary
///   current_streak: 0   longest_streak: 6   today_status: 'pending'
///   today_completed: false   today_scheduled: true
///   next_milestone: 3   days_to_milestone: 3
///
/// GET /api/v1/readings/today/en
///   current_streak: 4   is_fully_completed: true
/// ```
///
/// **Four** fields disagree between two endpoints that describe one day. This is
/// not a transcription slip — both readings were taken from the running server,
/// and the same disagreement is recorded in AGENT_CONTEXT §5.
///
/// ## THE RESOLUTION, AND WHY IT IS "NEITHER"
///
/// **Each field comes from the endpoint whose job it is, and the two are never
/// reconciled.** The top-bar flame reads [currentStreak] from here. The panel's
/// status line reads `TodayReading.isFullyCompleted` from the *other* endpoint.
/// Nothing sums them, nothing prefers one, and nothing cross-checks them.
///
/// Three alternatives were rejected, and the reason is the same for all of them:
///
/// * **Prefer the reading endpoint's streak (`4`).** It agrees with the reading
///   the reader is actually looking at, and it looks like a *fix*. It is a
///   choice made in the client about a disagreement the server owns, and it would
///   silently change every number the top bar shows the moment either endpoint
///   is corrected.
/// * **Prefer the streak endpoint's (`0`).** Same objection, and worse: it is the
///   endpoint whose entire job is the streak, so preferring it here means Home
///   reads the summary and ignores the reading it is named for.
/// * **Reconcile** — take the max, or "completed if either says completed". This
///   is the worst of the three. It invents a third source of truth that matches
///   neither response, so a reader sees a number the server has never sent, and
///   the client cannot be debugged by looking at the wire.
///
/// The property that makes this safe is that **it is also the cheapest**: a
/// backend fix changes the response, not this client. The test that holds it is
/// a widget test with the two fakes built to contradict each other —
/// `home_page_test.dart` — because a test that only checks the fields are stored
/// is asserting `props`.
@freezed
final class StreakSummary with _$StreakSummary {
  /// A streak summary as the endpoint reports it.
  const StreakSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDate,
    required this.todayStatus,
    required this.todayCompleted,
    required this.todayScheduled,
    required this.nextMilestone,
    required this.daysToMilestone,
  });

  /// `current_streak` — **the streak endpoint's own copy**, and the one the top
  /// bar's flame draws.
  ///
  /// `0` on the live payload, against `4` from `readings/today/*`. See the class
  /// doc for why neither wins.
  final int currentStreak;

  /// `longest_streak` — the best run this reader has had.
  final int longestStreak;

  /// `last_completed_date`, as the `YYYY-MM-DD` string the wire carries.
  ///
  /// ## WHY A STRING AND NOT A `DateTime`
  ///
  /// There is **no `DateTime.parse` anywhere in this entity**, and that is the
  /// design. `DateTime.parse('2026-09-29')` yields **local** midnight: a different
  /// *instant* on every device, and a different *calendar day* for a reader far
  /// from UTC. The payload carries a date with no zone and no time, and the only
  /// thing this app would do with it is show it. Converting it would pull a
  /// timezone dependency into the shared kernel to obtain a value no caller uses.
  final String lastCompletedDate;

  /// `today_status`. `pending` on the live payload.
  final StreakTodayStatus todayStatus;

  /// `today_completed` — `false` on the live payload, while
  /// `readings/today/*.is_fully_completed` is `true`.
  ///
  /// **Nothing on `/` reads it.** The panel's completion state comes from the
  /// reading endpoint (see the class doc), which is the whole of the recorded
  /// contradiction. It is carried because the payload carries it and Phase 8's
  /// result screen is the other consumer of a streak.
  final bool todayCompleted;

  /// `today_scheduled` — whether a reading is scheduled for today at all.
  ///
  /// `false` with [todayStatus] [StreakTodayStatus.offDay] is the only reading
  /// in which Home's panel has nothing to show, and Phase 7's sanctuary is where
  /// that would be handled; `/` today renders the same panel either way.
  final bool todayScheduled;

  /// `next_milestone` — the streak length at which the next badge is earned.
  ///
  /// ## CARRIED BEFORE ANYBODY READS IT, AND WHY
  ///
  /// §3 says "nothing enters `core/domain/` speculatively", and this field has no
  /// Phase-6 reader. It is here anyway, for the measured reason: the values are
  /// **recorded in AGENT_CONTEXT §5** as Phase 8's `StreakPill` input, they are
  /// on this payload today, and discarding them would mean a second request to
  /// draw a pill this object could already carry. The cheaper alternative —
  /// adding them in Phase 8 — would need a *wider* projection of the same payload
  /// later, and this one is already the projection of this endpoint.
  ///
  /// `/` renders neither. `home_page_test.dart` asserts no milestone text reaches
  /// the screen, so the deferred reader cannot find them already drawn.
  final int nextMilestone;

  /// `days_to_milestone` — how many more days until [nextMilestone].
  ///
  /// Read by nothing yet; see [nextMilestone] for the same argument, and for why
  /// carrying them is recorded rather than done quietly.
  final int daysToMilestone;
}
