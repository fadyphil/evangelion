library;

import 'dart:convert';

/// Payloads captured from the running backend at `HEAD = 4a1c834`, group 3,
/// user `11111111-1111-1111-1111-111111111111`, on 2026-10-03.
///
/// ## WHY THESE ARE FROZEN HERE AND NOT WRITTEN PER-TEST
///
/// Three suites need the same bodies — the reading mapper, the streak mapper and
/// the two repositories — and a fixture written twice is a fixture that can
/// disagree with itself. More importantly they must be **the shapes the server
/// actually sent**, including the two asymmetries §5 records and that no
/// hand-written map would contain by accident:
///
/// * **`text_clean` is absent from English and present in Arabic.** A fixture
///   that included it in both arms would make the mapper's AR-only branch
///   untested, and one that omitted it from both would make the bug it guards
///   against invisible. It is a *missing key*, so it cannot be spelled as
///   `null` here either — the whole point is that the key is not there.
/// * **`streak/summary` and `readings/today` disagree.** `current_streak` is `0`
///   against `4`; `today_completed: false` against `is_fully_completed: true`.
///   Both are reproduced exactly, so a suite that reads only one of them cannot
///   accidentally rely on them agreeing.
///
/// Every other suite that needs a reading or a streak should read from here too.

/// The live `GET /api/v1/readings/today/en` body, as JSON.
///
/// Note the absence of any `text_clean` key on the verses — that is the live
/// English shape and not an omission from this file.
const String kLiveReadingEnJson = '''
{
  "reading_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "group_id": 3,
  "scheduled_date": "2026-10-03",
  "language": "en",
  "reference": "John 3:1-5",
  "translation": "NKJV (New King James Version)",
  "verses": [
    { "book_number": 43, "chapter": 3, "verse": 1,
      "text": "There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:" },
    { "book_number": 43, "chapter": 3, "verse": 2,
      "text": "The same came to Jesus by night, and said unto him, Rabbi, we know that thou art a teacher come from God: for no man can do these miracles that thou doest, except God be with him." },
    { "book_number": 43, "chapter": 3, "verse": 3,
      "text": "Jesus answered and said unto him, ‹Verily, verily, I say unto thee, Except a man be born again, he cannot see the kingdom of God.›" },
    { "book_number": 43, "chapter": 3, "verse": 4,
      "text": "Nicodemus saith unto him, How can a man be born when he is old? can he enter the second time into his mother's womb, and be born?" },
    { "book_number": 43, "chapter": 3, "verse": 5,
      "text": "Jesus answered, ‹Verily, verily, I say unto thee, Except a man be born of water and› [of] ‹the Spirit, he cannot enter into the kingdom of God.›" }
  ],
  "questions": [
    {
      "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "sort_order": 1,
      "type": "mcq",
      "prompt": "What was the name of the Pharisee who came to Jesus by night?",
      "options": {
        "A": "Nicodemus",
        "B": "Paul",
        "C": "Peter",
        "D": "Lazarus"
      },
      "points_value": 10,
      "already_answered": true,
      "user_answer": "A",
      "is_correct": true
    }
  ],
  "is_fully_completed": true,
  "total_points_earned_today": 10,
  "current_streak": 4
}
''';

/// The live `GET /api/v1/readings/today/ar` body, as JSON.
///
/// Same reading, same group, same day. Two differences from the English arm and
/// both are load-bearing:
///
/// * `reference` is `يوحنا 3: 1-5` — note the space after the colon, which the
///   English arm does not have. Shown verbatim rather than normalised.
/// * every verse carries **`text_clean`**, which the English arm has no key for.
const String kLiveReadingArJson = '''
{
  "reading_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "group_id": 3,
  "scheduled_date": "2026-10-03",
  "language": "ar",
  "reference": "يوحنا 3: 1-5",
  "translation": "Smith & Van Dyck (فانديك)",
  "verses": [
    { "book_number": 43, "chapter": 3, "verse": 1,
      "text": "كَانَ إِنْسَانٌ مِنَ ٱلْفَرِّيسِيِّينَ ٱسْمُهُ نِيقُودِيمُوسُ، رَئِيسٌ",
      "text_clean": "كان إنسان من الفريسيين اسمه نيقوديموس، رئيس" },
    { "book_number": 43, "chapter": 3, "verse": 2,
      "text": "جَاءَ هَذَا إِلَىٰ يَسُوعَ لَيْلاً وَقَالَ لَهُ يَا مُعَلِّمُ، قَدْ نَعْلَمُ أَنَّكَ قَدْ أَتَيْتَ مِنَ ٱللَّهِ مُعَلِّمًا، لأَنَّهُ لَيْسَ أَحَدٌ يَقْدِرُ أَنْ يَعْمَلَ هَذِهِ ٱلْآيَاتِ ٱلَّتِ أَنْتَ تَعْمَلُ إِلَّا إِنْ كَانَ ٱللَّهُ مَعَهُ.",
      "text_clean": "جاء هذا إلى يسوع لياً وقال له يا معلم، قد نعلم أنك قد أتيت من الله معلماً، لأنه ليس أحد يقدر أن يعمل هذه الآيات التي أنت تعمل إلا إن كان الله معه" },
    { "book_number": 43, "chapter": 3, "verse": 3,
      "text": "أَجَابَ يَسُوعُ وَقَالَ لَهُ: «اَلْحَقَّ ٱلْحَقَّ، أَقُولُ لَكَ: إِنْ كَانَ أَحَدٌ لا يُولَدُ مِنْ فَوْقُ لَا يَقْدِرُ أَنْ يَرَى مَلَكُوتَ ٱللَّهِ.»",
      "text_clean": "أجاب يسوع وقال له: «الحق الحق أقول لك إن كان أحد لا يولد من فوق لا يقدر أن يرى ملكوت الله.»" },
    { "book_number": 43, "chapter": 3, "verse": 4,
      "text": "قَالَ لَهُ نِيقُودِيمُوسُ: كَيْفَ يُولَدُ ٱلْإِنْسَانُ وَهُوَ شَيْخٌ؟ أَلَعَلَّهُ يَقْدِرُ أَنْ يَدْخُلَ بَطْنَ أُمِّهِ ثَانِيَةً وَيَلِدَ؟",
      "text_clean": "قال له نيقوديموس: كيف يولد الإنسان وهو شيخ؟ ألاعله يقدر أن يدخل بطن أمه ثانية ويولد؟" },
    { "book_number": 43, "chapter": 3, "verse": 5,
      "text": "أَجَابَ يَسُوعُ: «اَلْحَقَّ ٱلْحَقَّ، أَقُولُ لَكَ: إِنْ كَانَ أَحَدٌ لا يُولَدُ مِنَ ٱلْمَاءِ وَٱلرُّوحِ لَا يَقْدِرُ أَنْ يَدْخُلَ مَلَكُوتَ ٱللَّهِ.»",
      "text_clean": "أجاب يسوع: «الحق الحق أقول لك إن كان أحد لا يولد من الماء والروح لا يقدر أن يدخل ملكوت الله.»" }
  ],
  "questions": [
    {
      "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "sort_order": 1,
      "type": "mcq",
      "prompt": "ما اسم الفريسي الذي جاء إلى يسوع ليلاً؟",
      "options": {
        "A": "نيقوديموس",
        "B": "بولس",
        "C": "بطرس",
        "D": "لعازر"
      },
      "points_value": 10,
      "already_answered": true,
      "user_answer": "A",
      "is_correct": true
    }
  ],
  "is_fully_completed": true,
  "total_points_earned_today": 10,
  "current_streak": 4
}
''';

/// The live `GET /api/v1/streak/summary` body, as JSON.
///
/// **This is the body that disagrees with [kLiveReadingEnJson].** `current_streak`
/// is `0` where the reading endpoint says `4`, and `today_completed` is `false`
/// where the reading says `is_fully_completed: true`. Both were read from the
/// running server in the same minute and neither is a transcription error; see
/// `lib/core/domain/entities/streak_summary.dart` for the whole of it.
const String kLiveStreakSummaryJson = '''
{
  "user_id": "11111111-1111-1111-1111-111111111111",
  "group_id": 3,
  "current_streak": 0,
  "longest_streak": 6,
  "last_completed_date": "2026-09-29",
  "today_status": "pending",
  "today_completed": false,
  "today_scheduled": true,
  "next_milestone": 3,
  "days_to_milestone": 3
}
''';

/// [kLiveReadingEnJson] decoded, as the shape dio hands a mapper.
Map<String, Object?> liveReadingEn() =>
    jsonDecode(kLiveReadingEnJson) as Map<String, Object?>;

/// [kLiveReadingArJson] decoded.
Map<String, Object?> liveReadingAr() =>
    jsonDecode(kLiveReadingArJson) as Map<String, Object?>;

/// [kLiveStreakSummaryJson] decoded.
Map<String, Object?> liveStreakSummary() =>
    jsonDecode(kLiveStreakSummaryJson) as Map<String, Object?>;

/// [body] with one top-level key removed, for the "a required key is missing"
/// cases. A copy, so a suite that mutates its fixture cannot affect another's.
Map<String, Object?> withoutKey(Map<String, Object?> body, String key) =>
    <String, Object?>{
      for (final MapEntry<String, Object?> entry in body.entries)
        if (entry.key != key) entry.key: entry.value,
    };

/// [body] with one top-level key replaced. Shallow on purpose — every field these
/// mappers read is top-level or inside a list of flat maps.
Map<String, Object?> withKey(
  Map<String, Object?> body,
  String key,
  Object? value,
) => <String, Object?>{
  for (final MapEntry<String, Object?> entry in body.entries)
    entry.key: entry.key == key ? value : entry.value,
};

/// [body] with its `verses` list replaced by [verses].
///
/// The interesting cases are combinations the live payload does not contain: no
/// verses at all, a first verse with `text_clean` absent where the Arabic arm has
/// one, and — since Phase 7's wide projection reads every verse — an entry that is
/// **not an object**, which is what a malformed response looks like.
///
/// **`List<Object>` and not `List<Map<String, Object?>>`**, because Phase 7's mapper
/// has a skip branch for an unreadable entry and a fixture typed to exclude one
/// could not reach it. The widening costs nothing to the callers that pass real
/// maps (`List<Map<…>>` is a `List<Object>`) and buys the malformed cases, and the
/// widened parameter is exactly the shape `TodayReadingMapper._verses` accepts.
Map<String, Object?> withVerses(
  Map<String, Object?> body,
  List<Object> verses,
) => withKey(body, 'verses', verses);

/// [body] with its `questions` list replaced by [questions].
///
/// A fixture the caller builds by hand, because the interesting cases are
/// combinations the live payload does not contain: zero questions, one answered of
/// two, `already_answered` missing, and — since Phase 7 — entries that are not
/// objects or are missing a required field, which the wide mapper **skips**.
///
/// Widened to `List<Object>` for the same reason as [withVerses].
Map<String, Object?> withQuestions(
  Map<String, Object?> body,
  List<Object> questions,
) => withKey(body, 'questions', questions);

/// A question object shaped like the live one, with the one flag a projection
/// reads left to the caller.
Map<String, Object?> aQuestion({Object? alreadyAnswered = false}) =>
    <String, Object?>{
      'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'sort_order': 1,
      'type': 'mcq',
      'prompt': 'What was the name of the Pharisee who came to Jesus by night?',
      'options': <String, Object?>{'A': 'Nicodemus', 'B': 'Paul'},
      'points_value': 10,
      'already_answered': alreadyAnswered,
      'user_answer': null,
      'is_correct': null,
    };
