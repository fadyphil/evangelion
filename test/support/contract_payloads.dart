/// A `POST /api/v1/readings/:id/submit` body, and the shapes around it.
///
/// ## WHY THIS FILE EXISTS AND WHY IT IS **NOT** `live_payloads.dart`
///
/// Every other fixture in `test/support/` is a body a running server returned, and
/// `live_payloads.dart` says so at the top. **A successful submit has never been
/// observed**, so there is nothing to capture here and writing one as though there
/// were would be a fabricated observation.
///
/// Recorded in AGENT_CONTEXT §5 trap 10, measured live against `HEAD = 4a1c834`,
/// group 3, user `11111111-1111-1111-1111-111111111111`. The endpoint is
/// `POST /api/v1/readings/:id/submit` and its three reachable answers are:
///
/// | `question_id` sent | response |
/// | --- | --- |
/// | `question-group-3` — **the id `GET /readings/today/en` had just handed out** | `400 {"error":"Bad Request","message":"body/question_id must match format \"uuid\""}` |
/// | `dddddddd-dddd-dddd-dddd-dddddddddddd` — well-formed, absent from the store | `404 {"error":"Not Found","message":"QUESTION_NOT_FOUND: Specified question does not exist."}` |
/// | `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb` — the seeded record | `409 {"error":"Conflict","message":"This question has already been submitted by this user."}` |
///
/// ## THE CAUSE IS IN THE BACKEND'S OWN SOURCE, NOT IN A PROBE
///
/// * `src/db/memory_db.ts:320` fabricates `id: \`question-group-${groupId}\`` and
///   `:304` fabricates `` `reading-group-${groupId}-${scheduledDate}` ``.
/// * `src/modules/submissions/submissions.routes.ts:7` validates
///   `question_id: z.string().uuid()`.
///
/// The in-memory fallback hands out ids its own submit route rejects. `reading_id`
/// is non-UUID for the same reason and it **moves**: §5 trap 11 records the
/// rollover between two probes of the same endpoint.
///
/// ## SO WHAT IS [kContractSubmitAnswerJson]?
///
/// A transcription of the interface the backend compiles against —
/// `SubmitAnswerResult` in `src/modules/submissions/submissions.service.ts:5-13`:
///
/// ```dart
/// export interface SubmitAnswerResult {
///   question_id: string;          is_correct: boolean;
///   points_earned: number;       current_total_points: number;
///   current_streak: number;      longest_streak: number;
///   reading_completed: boolean;
/// }
/// ```
///
/// The **field names, types and order** are the declaration's. The **values** are
/// plausible, not observed. A test reading this file is testing the client against
/// a declaration, which is the only contract there is — and saying so here is the
/// difference between a recorded fact and an invented one.
///
/// The request body is fixed by the same route's `submitSchema`
/// (`submissions.routes.ts:6-8`): `question_id: z.string().uuid()`,
/// `answer: z.string().min(1)`, with `answer` documented at `:35` as *"Selected
/// option (A, B, C, D) or boolean"*.
library;

import 'dart:convert';

import 'package:evangelion/core/domain/entities/submit_result.dart';

/// A `200` from `POST /api/v1/readings/:id/submit`, transcribed from
/// `SubmitAnswerResult`.
///
/// **Not captured.** See the library doc. `question_id` is the **fabricated**
/// `question-group-3` the live endpoint actually hands out, so even this fixture's
/// echo value is the real one — it is the `200` around it that has never existed.

const String kContractSubmitAnswerJson = '''
{
  "question_id": "question-group-3",
  "is_correct": true,
  "points_earned": 10,
  "current_total_points": 40,
  "current_streak": 4,
  "longest_streak": 6,
  "reading_completed": true
}
''';

/// [kContractSubmitAnswerJson] decoded, as the shape dio hands a mapper.
Map<String, Object?> contractSubmitAnswer() =>
    jsonDecode(kContractSubmitAnswerJson) as Map<String, Object?>;

/// [kContractSubmitAnswerJson] as the entity a mapper produces.
///
/// **The one shared fixture for every quiz suite**, and it lives here rather than in
/// a quiz harness because it is a **transcription**: a fixture whose provenance is a
/// declaration must not sit in a file whose header says "captured from a running
/// server". `reading_harness.dart` and `quiz_harness.dart` both read it from here.
///
/// Two of its numbers are not the point and are the point elsewhere:
/// `current_streak: 4` is `readings/today`'s value against `streak/summary`'s `0`
/// (§5 trap 8), so a suite asserting `4` on `/result` is asserting the **submit
/// response**'s copy and not either read — which is the whole of decision 22's
/// extension — and `longest_streak: 6` is above `current_streak`, so
/// `/result`'s "your longest yet" sentence is the *false* arm unless a suite moves
/// it.
const SubmitResult contractSubmitAnswerFixture = SubmitResult(
  questionId: 'question-group-3',
  isCorrect: true,
  pointsEarned: 10,
  currentTotalPoints: 40,
  currentStreak: 4,
  longestStreak: 6,
  readingCompleted: true,
);

/// A **wrong** answer's response, for the arm where the reader got it wrong.
///
/// Same transcriptions, with `is_correct: false` and `points_earned: 0` — the two
/// values that move together, because `points_value` on the question is `10` and the
/// service awards nothing for a wrong answer. `current_total_points` is
/// **unchanged**, which is the half a mapper that copied "wrong → 0" into every
/// number would get wrong, and `reading_completed` is `false` because one wrong
/// answer out of four has not finished anything (§5 trap 4).
const SubmitResult contractWrongAnswerFixture = SubmitResult(
  questionId: 'question-group-3',
  isCorrect: false,
  pointsEarned: 0,
  currentTotalPoints: 40,
  currentStreak: 4,
  longestStreak: 6,
  readingCompleted: false,
);

/// [body] with one key removed — a copy, so a suite that mutates its fixture cannot
/// affect another's. `live_payloads.dart`'s `withoutKey` is the same function with
/// the same reason; it is **not** shared, because importing a *capture* file from a
/// *contract* file would put the two provenances in one import and lose the
/// distinction this whole file exists to keep.
Map<String, Object?> contractWithKey(
  Map<String, Object?> body,
  String key,
  Object? value,
) => <String, Object?>{
  for (final MapEntry<String, Object?> entry in body.entries)
    entry.key: entry.key == key ? value : entry.value,
};

/// [contractWithKey] with the key **removed** rather than replaced.
Map<String, Object?> contractWithoutKey(
  Map<String, Object?> body,
  String key,
) => <String, Object?>{
  for (final MapEntry<String, Object?> entry in body.entries)
    if (entry.key != key) entry.key: entry.value,
};
