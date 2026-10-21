/// The servant portal's wire shapes, **transcribed from the backend's source**.
///
/// ## WHY THIS FILE EXISTS, AND WHY IT IS **NOT** A CAPTURE
///
/// Every payload here is a **transcription** of a declaration in
/// `/home/fady/Projects/EvangelionBackend`, and **not** a body a running server
/// returned. The distinction is the same one
/// `test/support/contract_payloads.dart` draws for the submit endpoint, and it
/// is drawn here for a sharper reason:
///
/// * the submit endpoint's shapes were transcribed because **a successful
///   submit has never been observed** — AGENT_CONTEXT §5 trap 10 records the
///   three reachable answers, and none of them is a `200`; and
/// * **none of the four routes in this feature has been observed at all** from
///   this client. The admin, AI and report routes were, until ADR-0026, "not
///   client surface" — §2's original decision 5 said so in those words.
///
/// So a fixture in this file describes **what the server declares it answers**,
/// and a test that reads it is a **contract test**: it holds the client to the
/// shape the backend declares, and it would not have caught a divergence
/// between the declaration and the running service — because that divergence
/// cannot be observed from here.
///
/// The **values** are plausible, not observed. The **names, types and shapes**
/// are the declarations'.
///
/// ## WHERE EACH ONE COMES FROM
///
/// | fixture | declaration |
/// | --- | --- |
/// | [kContractScheduleResponseJson] | `admin.routes.ts:218-221` (the `201` body) and the schema at `:91-98` |
/// | [kContractCommitResponseJson] | `admin.routes.ts:313-316` (the `201` body) and the schema at `:93-98` |
/// | [kContractAiDraftResponseJson] | `ai.routes.ts:49-54` (the `200` body), the schema at `:28-40`, and `ai.service.ts:5-11` (`GeneratedQuestionPayload`) |
/// | [kContractDailyReportResponseJson] | `admin.routes.ts:401-422` (the `200` body) and the schema at `:344-364` |
///
/// ## AND THE MESSAGES ARE THE SERVER'S OWN SENTENCES
///
/// `admin.routes.ts:219` writes
/// `Successfully scheduled reading for N groups`, with
/// ` with AI-generated questions` appended when the AI switch was on, and
/// `:315` writes `Committed N questions for reading`. Both are transcribed
/// verbatim, because a message the client rewords is a message the server did
/// not send.
library;

import 'dart:convert';

/// The `201` from `POST /api/v1/admin/readings/schedule`.
///
/// **Transcribed, not captured.** See the library doc.
const String kContractScheduleResponseJson = '''
{
  "message": "Successfully scheduled reading for 1 groups",
  "reading_ids": ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
}
''';

/// [kContractScheduleResponseJson] decoded, as the shape dio hands a mapper.
Map<String, Object?> contractScheduleResponse() =>
    jsonDecode(kContractScheduleResponseJson) as Map<String, Object?>;

/// The `201` from `POST /api/v1/admin/questions/commit`.
///
/// **Transcribed, not captured.** See the library doc.
const String kContractCommitResponseJson = '''
{
  "message": "Committed 1 questions for reading",
  "question_ids": ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
}
''';

/// [kContractCommitResponseJson] decoded, as the shape dio hands a mapper.
Map<String, Object?> contractCommitResponse() =>
    jsonDecode(kContractCommitResponseJson) as Map<String, Object?>;

/// The `200` from `POST /api/v1/admin/questions/ai-generate`.
///
/// **Transcribed, not captured.** See the library doc.
///
/// The `options` shape is `Record<string, {ar, en}>` — `ai.service.ts:9` and
/// the `responseSchema` at `:60-95` — which is **the same shape the commit
/// endpoint takes** (`admin.routes.ts:41-44`). That is what makes a draft
/// committable without a conversion.
const String kContractAiDraftResponseJson = '''
{
  "reading_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "draft_question": {
    "type": "mcq",
    "prompt_ar": "بِحَسَبِ الآيَةِ (٣: ١)، مَاذَا يُعَلِّمُنَا النَّصُّ؟",
    "prompt_en": "According to verse (3:1), what does the text show?",
    "options": {
      "A": {
        "ar": "أَنَّهُ وَصَلَ بِالْأَرْضِ",
        "en": "That he came to the earth"
      },
      "B": {
        "ar": "خَيْرٌ تَامٌّ",
        "en": "Perfect goodness"
      }
    },
    "correct_answer": "A"
  }
}
''';

/// [kContractAiDraftResponseJson] decoded, as the shape dio hands a mapper.
Map<String, Object?> contractAiDraftResponse() =>
    jsonDecode(kContractAiDraftResponseJson) as Map<String, Object?>;

/// The `200` from `GET /api/v1/servant/reports/daily`.
///
/// **Transcribed, not captured.** See the library doc.
///
/// The roster is the server's own `report` array (`admin.routes.ts:401-414`),
/// and `questions_progress` is the server's `` `${answeredQ}/${totalQ}` ``
/// string (`:412`) — carried here as the **string** it is.
const String kContractDailyReportResponseJson = '''
{
  "group_id": 3,
  "report_date": "2026-10-21",
  "total_students": 2,
  "completed_count": 1,
  "students": [
    {
      "user_id": "11111111-1111-1111-1111-111111111111",
      "full_name": "David Mina",
      "preferred_lang": "en",
      "total_points": 40,
      "current_streak": 4,
      "points_earned_today": 10,
      "completed_today": true,
      "questions_progress": "3/5"
    },
    {
      "user_id": "22222222-2222-2222-2222-222222222222",
      "full_name": "Peter George",
      "preferred_lang": "ar",
      "total_points": 25,
      "current_streak": 2,
      "points_earned_today": 0,
      "completed_today": false,
      "questions_progress": "0/0"
    }
  ]
}
''';

/// [kContractDailyReportResponseJson] decoded, as the shape dio hands a mapper.
Map<String, Object?> contractDailyReportResponse() =>
    jsonDecode(kContractDailyReportResponseJson) as Map<String, Object?>;
