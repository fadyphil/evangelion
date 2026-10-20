import 'package:evangelion/app/settings_scope.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/home/data/datasources/library_catalogue_local_data_source.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/domain/library_catalogue_repository.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_last_light.dart';
import 'package:evangelion/features/home/domain/usecases/load_library_catalogue.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'design_system_harness.dart';
import 'settings_harness.dart';

/// The shared fixture for every `/` widget test.
///
/// ## WHY THE BLOC IS BUILT **IN THE TEST BODY**
///
/// `login_harness.dart` records the measurement: a bloc created in `setUp` runs its
/// events on a microtask queue outside the fake-async zone `tester.pump()` drains,
/// so `bloc.state` is correct and `find.text(…)` returns **zero** widgets. The
/// harness therefore builds it in the body, with `addTearDown(bloc.close)`.
///
/// ## WHY IT TAKES FAKES AND NOT A MOCKTAIL `Mock`
///
/// Because these tests are about **what is on screen**, and a `Mock` implements
/// whatever it is told to: it can satisfy `ReadingRepository` and answer nothing,
/// which is the same vacuous-pass shape `home_bloc_test.dart` documents. These are
/// hand-written and always answer, and each records **how many times** it was asked
/// so "one retry re-fetches only what failed" is assertable at the widget level.
///
/// ## AND WHY [pumpHome] DOES NOT SETTLE
///
/// `evaPrimitiveHarness` mounts with `animationsEnabled: false`, so the shared
/// ambient clocks never tick — `pumpAndSettle` is therefore safe here. The
/// prohibition is on the **app root**, where `NeuralMotionScope` runs three
/// `repeat()`ing controllers; `app_harness.dart`'s `pumpUntilFound` is for that.
/// [pumpHome] still advances a fixed number of frames rather than settling, because
/// the `ErrorView` a failed section renders carries a `CircularProgressIndicator` in
/// its retry control and settling would wait for it.
final class HomeHarness {
  /// The fakes, so a test can read their counters or re-stub them.
  const HomeHarness({
    required this.bloc,
    required this.readings,
    required this.streaks,
    required this.catalogue,
    required this.auth,
  });

  /// The bloc under test. Close it with `addTearDown`.
  final HomeBloc bloc;

  /// `GET /readings/today/{lang}`.
  final CountingReadingRepository readings;

  /// `GET /streak/summary` and `GET /streak` — two counters on one fake, because
  /// they are one port.
  final CountingStreakRepository streaks;

  /// The library catalogue, behind [LibraryCatalogueRepository].
  final CountingLibraryCatalogueRepository catalogue;

  /// The session the greeting's name comes from.
  final CountingAuthRepository auth;
}

/// [ReadingRepository] that answers [scripture] and counts its calls.
///
/// ## WHY IT STORES THE **WIDE** ANSWER
///
/// `ReadingRepository` has two methods since Phase 7 and [today] is defined as a
/// narrowing of [todayScripture], so a fake that stored a `Result<TodayReading>`
/// and answered `today` from it would be answering `/`'s question by a route the
/// production adapter does not take — which is the substitution hazard §3's LSP row
/// is about, in a fixture rather than in an adapter. Storing the wide result and
/// narrowing is one line and makes the fake drive exactly the production shape.
final class CountingReadingRepository implements ReadingRepository {
  /// Starts out answering [scripture].
  CountingReadingRepository({required this.scripture});

  /// What the next call answers.
  Result<ScriptureText> scripture;

  /// How many times either method has been called.
  int calls = 0;

  /// The languages the port has been asked for, in order.
  final List<ReadingLanguage> asked = <ReadingLanguage>[];

  @override
  Future<Result<ScriptureText>> todayScripture({
    required ReadingLanguage language,
  }) async {
    calls++;
    asked.add(language);
    return scripture;
  }

  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async =>
      (await todayScripture(language: language))
          .map((ScriptureText text) => text.toTodayReading());

  /// Phase 8's third port method.
  ///
  /// **Present and answering rather than absent**, because this fake exists to be a
  /// substitutable `ReadingRepository` and a port method a substitute cannot answer
  /// is not substitutable — it is a compile error in every caller. No `home` suite
  /// calls it (nothing on `/` submits an answer), which is exactly why it must still
  /// compile: the port growing is a cost every fake in the tree pays, and this is
  /// where that cost is paid.
  @override
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  }) async => const Left<Failure, SubmitResult>(
    Failure(
      kind: FailureKind.network,
      message:
          'This fake does not submit: no home screen calls the submit path.',
    ),
  );
}

/// [StreakRepository] over **two** endpoints, counting each separately.
///
/// The counters are separate and that is the point: `HomeRetried` re-fetches only
/// the sections that failed, and "the streak section" is now two requests
/// (`GET /streak/summary` for the chip, `GET /streak` for the card). A single
/// `calls` counter could not tell a suite whether a retry re-asked for the summary,
/// the history or both.
final class CountingStreakRepository implements StreakRepository {
  /// Starts out answering [answer] for the summary and [history] for the rows.
  CountingStreakRepository({
    required this.answer,
    Result<List<StreakHistoryEntry>>? history,
  }) : historyAnswer =
           history ??
           const Right<Failure, List<StreakHistoryEntry>>(<StreakHistoryEntry>[
             liveStreakHistoryEntry,
           ]);

  /// What [summary] answers.
  Result<StreakSummary> answer;

  /// What [history] answers.
  ///
  /// **Named `historyAnswer` and not `history`**, because the port method is called
  /// `history` and a fake that cannot hold the answer under the method's own name
  /// is a fake whose tests read `fake.history()` for the method and
  /// `fake.history` for the field with a two-letter difference between them.
  Result<List<StreakHistoryEntry>> historyAnswer;

  /// How many times [summary] has been called.
  int summaryCalls = 0;

  /// How many times [history] has been called.
  int historyCalls = 0;

  @override
  Future<Result<StreakSummary>> summary() async {
    summaryCalls++;
    return answer;
  }

  @override
  Future<Result<List<StreakHistoryEntry>>> history() async {
    historyCalls++;
    return historyAnswer;
  }
}

/// [LibraryCatalogueRepository] that answers [answer] and counts its calls.
///
/// **Defaulted to the shipped adapter**, not to a literal: the catalogue *is*
/// `ADR-0022`'s fiction and a widget test that asserted six cards against its own
/// hand-written list would be asserting its own list. So the default arm of
/// [harness] is the real `LibraryCatalogueRepositoryImpl` over the real data
/// source, and only the **failure** arm needs this fake — which is also why the
/// catalogue's failed state is unreachable in production and reachable here.
final class CountingLibraryCatalogueRepository
    implements LibraryCatalogueRepository {
  /// Starts out answering [answer].
  CountingLibraryCatalogueRepository({required this.answer});

  /// What the next call answers.
  Result<List<LibraryBook>> answer;

  /// How many times [books] has been called.
  int calls = 0;

  @override
  Future<Result<List<LibraryBook>>> books() async {
    calls++;
    return answer;
  }
}

/// The catalogue the shipped adapter returns, for tests that want the entity rather
/// than the call.
List<LibraryBook> get liveCatalogue =>
    const LibraryCatalogueLocalDataSource().books();

/// [AuthRepository] that answers one session, or `null` for "no session".
final class CountingAuthRepository implements AuthRepository {
  /// Starts out answering [session], or `Result.failure` when it is `null`.
  CountingAuthRepository({AuthSession? session})
    : _session = session,
      _signedIn = session != null;

  AuthSession? _session;
  bool _signedIn;

  /// How many times [getCurrentSession] has been called.
  int calls = 0;

  /// Adopts [session], so a test can give the fake a name where it had none.
  ///
  /// **Not named `signIn`.** The port declares `signIn({email, password})` and Dart
  /// has no overloading, so a second method with that name would not compile — the
  /// collision is the reason this exists as a test-only verb rather than as the port
  /// method with a default argument list, which `avoid_positional_boolean_parameters`
  /// and §4's named-parameter rule would both have opinions about.
  void adoptSession(AuthSession session) {
    _session = session;
    _signedIn = true;
  }

  @override
  Future<Result<AuthSession>> getCurrentSession() async {
    calls++;
    final AuthSession? session = _session;
    return _signedIn && session != null
        ? Result<AuthSession>.of(session)
        : const Left<Failure, AuthSession>(
            Failure(kind: FailureKind.unauthorized, message: 'Not signed in.'),
          );
  }

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async => getCurrentSession();

  @override
  Future<Result<void>> signOut() async {
    _signedIn = false;
    return const Right<Failure, void>(null);
  }
}

/// The live English payload, as an entity. `John 3:1-5`, five verses, one question
/// already answered, finished.
const TodayReading liveEnglishReading = TodayReading(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  groupId: 3,
  scheduledDate: '2026-10-03',
  language: ReadingLanguage.english,
  reference: 'John 3:1-5',
  translation: 'NKJV (New King James Version)',
  verseCount: 5,
  firstVerseText:
      'There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:',
  questionCount: 1,
  answeredQuestionCount: 1,
  isFullyCompleted: true,
  pointsEarnedToday: 10,
  currentStreak: 4,
);

/// The same reading in Arabic, with the `text_clean` preview the live payload
/// carries for that arm.
const TodayReading liveArabicReading = TodayReading(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  groupId: 3,
  scheduledDate: '2026-10-03',
  language: ReadingLanguage.arabic,
  reference: 'يوحنا 3: 1-5',
  translation: 'Smith & Van Dyck (فانديك)',
  verseCount: 5,
  firstVerseText: 'كان إنسان من الفريسيين اسمه نيقوديموس، رئيس',
  questionCount: 3,
  answeredQuestionCount: 1,
  isFullyCompleted: false,
  pointsEarnedToday: 0,
  currentStreak: 4,
);

/// The live streak summary — `current_streak: 0`, where the reading says `4`.
///
/// [liveEnglishReading] and this are **deliberately contradictory**; see
/// `streak_summary.dart`.
const StreakSummary liveStreakSummary = StreakSummary(
  currentStreak: 0,
  longestStreak: 6,
  lastCompletedDate: '2026-09-29',
  todayStatus: StreakTodayStatus.pending,
  todayCompleted: false,
  todayScheduled: true,
  nextMilestone: 3,
  daysToMilestone: 3,
);

/// The most recent scheduled day — `/`'s **last light**.
///
/// ## IT IS A **TRANSCRIPTION**, AND THE REFERENCE SPELLING IS THE SERVER'S
///
/// `streak.service.ts:116-124` builds `reference.en` as
/// `` `${bookNameEn} ${startChapter}:${startVerse}-${endVerse}` `` and
/// `reference.ar` with a space after the chapter's colon. The two below are
/// therefore **not** the same string with a script swapped, and the card picks
/// between them by direction — see `LastLightCard.referenceFor`.
///
/// The counts are the shape the live schema declares (`streak.routes.ts:40-52`):
/// `total_questions`, `answered_questions`, `correct_answers`, `points_earned`,
/// `is_completed`. The fixture does not have to satisfy a live server — no dev run
/// has a submitted reading — so it is a transcription of the *schema*, which is
/// what `test/support/contract_payloads.dart` says about its own fixtures.
const StreakHistoryEntry liveStreakHistoryEntry = StreakHistoryEntry(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  scheduledDate: '2026-10-03',
  bookNumber: 43,
  bookNameEn: 'John',
  bookNameAr: 'يوحنا',
  referenceEn: 'John 3:1-5',
  referenceAr: 'يوحنا 3: 1-5',
  totalQuestions: 1,
  answeredQuestions: 1,
  correctAnswers: 1,
  pointsEarned: 10,
  isCompleted: true,
);

/// The history the chip's endpoint and the card's endpoint disagree about: the
/// summary says the reader is **behind** and the most recent day is **finished**.
///
/// `home_bloc_test.dart`'s subject, with the roles the redesign gave the two
/// sections. Nothing reconciles them, for the reason `streak_summary.dart` records.
const StreakHistoryEntry completedStreakHistoryEntry = liveStreakHistoryEntry;

/// The seeded session's identity — `auth_local_data_source.dart`'s
/// `seedAuthSession` values, spelled out.
///
/// ## WHY IT IS A SPOKEN-FOR AND NOT A CALL, AND WHY IT IS NOT `const`
///
/// A test **may** import what production may not, so calling `seedAuthSession` here
/// would be legal. It is spelled out instead for two reasons: a shared fixture that
/// reaches into another feature's data layer is a fixture whose value changes when
/// that seed does — and the greeting's name is one of the three prototype literals
/// this phase removed, so it deserves a value that is *read* by the tests rather
/// than inherited from a fake.
///
/// Not `const`, because `AuthSession.createdAt` is a `DateTime` and Dart has no
/// `const DateTime` — which is exactly why `seedAuthSession` is a function taking
/// the instant. Nothing on `/` reads the field.
final AuthSession liveSession = AuthSession(
  userId: '11111111-1111-1111-1111-111111111111',
  email: 'david.mina@evangelion.app',
  displayName: 'David Mina',
  initials: 'DM',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// A [Failure] that says what it is, for the "one section failed" fixtures.
const Failure homeReadingFailure = Failure(
  kind: FailureKind.serialization,
  message:
      "Could not read today's reading: `verses` is absent, and a non-empty "
      'list was expected.',
);

/// [liveEnglishReading] as the wide entity the repository actually returns.
///
/// **Not a conversion.** The wide payload is the one the server sends and
/// `TodayReadingMapper.mapScripture` produces, so the fixture is written as what
/// comes out of the mapper rather than derived from the narrow entity — deriving it
/// would mean inventing verses to satisfy a constructor, and the whole point of the
/// fixture is that its verses are the live ones.
const ScriptureText liveEnglishScripture = ScriptureText(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  groupId: 3,
  scheduledDate: '2026-10-03',
  language: ReadingLanguage.english,
  reference: 'John 3:1-5',
  translation: 'NKJV (New King James Version)',
  verses: liveEnglishVerses,
  questions: liveEnglishQuestions,
  isFullyCompleted: true,
  pointsEarnedToday: 10,
  currentStreak: 4,
);

/// The five live English verses, `text_clean` **absent** on every one.
///
/// The absence is the point: the English payload has no `text_clean` key at all
/// (§5, trap 2), so a fixture that spelled `null` would be describing a shape the
/// server never sends.
const List<Verse> liveEnglishVerses = <Verse>[
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 1,
    text: 'There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 2,
    text:
        'The same came to Jesus by night, and said unto him, Rabbi, we know that '
        'thou art a teacher come from God: for no man can do these miracles that '
        'thou doest, except God be with him.',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 3,
    text:
        'Jesus answered and said unto him, ‹Verily, verily, I say unto thee, '
        'Except a man be born again, he cannot see the kingdom of God.›',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 4,
    text:
        'Nicodemus saith unto him, How can a man be born when he is old? can he '
        "enter the second time into his mother's womb, and be born?",
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 5,
    text:
        'Jesus answered, ‹Verily, verily, I say unto thee, Except a man be born '
        'of water and› [of] ‹the Spirit, he cannot enter into the kingdom of God.›',
  ),
];

/// The one live question, **already answered and carrying the answer**.
///
/// `user_answer: 'A'` and `is_correct: true` are inside the reading response —
/// verified live against `HEAD = 4a1c834` — so the fixture has to carry them, or
/// `/reading`'s "the answer is not on the screen" gate would be asserting against a
/// payload that never had an answer to hide.
const List<Question> liveEnglishQuestions = <Question>[
  Question(
    id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    sortOrder: 1,
    type: 'mcq',
    prompt: 'What was the name of the Pharisee who came to Jesus by night?',
    options: <String, String>{
      'A': 'Nicodemus',
      'B': 'Paul',
      'C': 'Peter',
      'D': 'Lazarus',
    },
    pointsValue: 10,
    alreadyAnswered: true,
    userAnswer: 'A',
    isCorrect: true,
  ),
];

/// [base] with its first verse's text emptied.
///
/// `TodayReading.firstVerseText` is a **view** of the wide entity's first verse
/// now, so the fixture that used to say `liveEnglishReading.copyWith(
/// firstVerseText: '')` has to be written against [ScriptureText] instead — and
/// that is the right place for it, because the empty verse it describes is a
/// property of the wire rather than of the panel's projection.
ScriptureText withEmptyFirstVerse(ScriptureText base) {
  if (base.verses.isEmpty) return base;
  return base.copyWith(
    verses: <Verse>[
      base.verses.first.copyWith(text: ''),
      ...base.verses.skip(1),
    ],
  );
}

/// [liveArabicReading] as the wide entity.
///
/// The Arabic verses carry **`text_clean` on every one**, which the English arm has
/// no key for at all — and that asymmetry is the whole reason the wide fixture
/// cannot be generated from the narrow one.
const ScriptureText liveArabicScripture = ScriptureText(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  groupId: 3,
  scheduledDate: '2026-10-03',
  language: ReadingLanguage.arabic,
  reference: 'يوحنا 3: 1-5',
  translation: 'Smith & Van Dyck (فانديك)',
  verses: liveArabicVerses,
  questions: liveArabicQuestions,
  isFullyCompleted: false,
  pointsEarnedToday: 0,
  currentStreak: 4,
);

/// The five live Arabic verses, each with a diacritic-stripped `text_clean`.
const List<Verse> liveArabicVerses = <Verse>[
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 1,
    text: 'كَانَ إِنْسَانٌ مِنَ ٱلْفَرِّيسِيِّينَ ٱسْمُهُ نِيقُودِيمُوسُ، رَئِيسٌ',
    textClean: 'كان إنسان من الفريسيين اسمه نيقوديموس، رئيس',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 2,
    text: 'جَاءَ هَذَا إِلَىٰ يَسُوعَ لَيْلاً وَقَالَ لَهُ يَا مُعَلِّمُ، قَدْ نَعْلَمُ أَنَّكَ قَدْ أَتَيْتَ مِنَ ٱللَّهِ مُعَلِّمًا، لأَنَّهُ لَيْسَ أَحَدٌ يَقْدِرُ أَن يَعْمَلَ هَذِهِ ٱلْآيَاتِ ٱلَّتِي أَنْتَ تَعْمَلُ إِلَّا إِنْ كَانَ ٱللَّهُ مَعَهُ.',
    textClean:
        'جاء هذا إلى يسوع لياً وقال له يا معلم، نعلم أنك قد أتيت من الله معلماً، '
        'لأنه ليس أحد يقدر أن يعمل هذه الآيات التي أنت تعمل إلا إن كان الله معه',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 3,
    text: 'أَجَابَ يَسُوعُ وَقَالَ لَهُ: «اَلْحَقَّ ٱلْحَقَّ، أَقُولُ لَكَ: إِنْ كَانَ أَحَدٌ لَا يُولَدُ مِنْ فَوْقُ لَا يَقْدِرُ أَن يَرَى مَلَكُوتَ ٱللَّهِ.»',
    textClean:
        'أجاب يسوع وقال له: «الحق الحق أقول لك إن كان أحد لا يولد من فوق لا يقدر '
        'أن يرى ملكوت الله.»',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 4,
    text: 'قَالَ لَهُ نِيقُودِيمُوسُ: كَيْفَ يُولَدُ ٱلْإِنْسَانُ وَهُوَ شَيْخٌ؟ أَلَعَلَّهُ يَقْدِرُ أَن يَدْخُلَ بَطْنَ أُمِّهِ ثَانِيَةً وَيَلِدُ؟',
    textClean:
        'قال له نيقوديموس: كيف يولد الإنسان وهو شيخ؟ ألاعله يقدر أن يدخل بطن أمه '
        ' ثانية ويولد؟',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 5,
    text: 'أَجَابَ يَسُوعُ: «اَلْحَقَّ ٱلْحَقَّ، أَقُولُ لَكَ: إِنْ كَانَ أَحَدٌ لَا يُولَدُ مِنَ ٱلْمَاءِ وَٱلرُّوحِ لَا يَقْدِرُ أَن يَدْخُلَ مَلَكُوتَ ٱللَّهِ.»',
    textClean:
        'أجاب يسوع: «الحق الحق أقول لك إن كان أحد لا يولد من الماء والروح لا يقدر '
        'أن يدخل ملكوت الله.»',
  ),
];

/// The Arabic arm's questions, of which one is answered.
const List<Question> liveArabicQuestions = <Question>[
  Question(
    id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    sortOrder: 1,
    type: 'mcq',
    prompt: 'ما اسم الفريسي الذي جاء إلى يسوع ليلاً؟',
    options: <String, String>{
      'A': 'نيقوديموس',
      'B': 'بولس',
      'C': 'بطرس',
      'D': 'لعازر',
    },
    pointsValue: 10,
    alreadyAnswered: true,
    userAnswer: 'A',
    isCorrect: true,
  ),
];

/// The streak endpoint's own failure, for the mirror-image fixture.
const Failure streakFailure = Failure(
  kind: FailureKind.network,
  message: 'Could not reach the server.',
);

/// Builds a [HomeBloc] over counting fakes, and registers the teardown.
HomeHarness harness({
  Result<ScriptureText>? reading,
  Result<StreakSummary>? streak,
  Result<List<StreakHistoryEntry>>? history,
  Result<List<LibraryBook>>? catalogue,
  AuthSession? session,
  // **Not `session: null`.** A nullable parameter with a default cannot tell "the
  // caller passed null" from "the caller passed nothing", and the default here is
  // the seeded session. So "no session" is a separate flag — and the first version
  // of `home_page_test.dart`'s no-session test passed `session: null`, got the
  // seeded session anyway, and asserted against a greeting that named David Mina.
  bool signedIn = true,
  DateTime? at,
}) {
  final CountingReadingRepository readings = CountingReadingRepository(
    scripture:
        reading ?? const Right<Failure, ScriptureText>(liveEnglishScripture),
  );
  final CountingStreakRepository streaks = CountingStreakRepository(
    answer: streak ?? const Right<Failure, StreakSummary>(liveStreakSummary),
    history:
        history ??
        const Right<Failure, List<StreakHistoryEntry>>(<StreakHistoryEntry>[
          liveStreakHistoryEntry,
        ]),
  );
  final CountingAuthRepository auth = CountingAuthRepository(
    session: signedIn ? (session ?? liveSession) : null,
  );
  // The **real data source** by default and the suite's own answer when one is
  // given: the catalogue is ADR-0022's fiction and its data source is the one file
  // that holds it, so a widget test asserting six cards should be reading that
  // file's list rather than a second copy of it.
  final CountingLibraryCatalogueRepository library =
      CountingLibraryCatalogueRepository(
        answer:
            catalogue ??
            Result<List<LibraryBook>>.of(
              const LibraryCatalogueLocalDataSource().books(),
            ),
      );
  final LibraryCatalogueRepository repo = library;
  final HomeBloc bloc = HomeBloc(
    loadTodayReading: LoadTodayReading(readings),
    loadStreakSummary: LoadStreakSummary(streaks),
    loadLastLight: LoadLastLight(streaks),
    loadLibraryCatalogue: LoadLibraryCatalogue(repo),
    getReaderSession: GetReaderSession(auth),
    now: () => at ?? DateTime(2026, 10, 3, 9, 30),
  );
  addTearDown(bloc.close);
  return HomeHarness(
    bloc: bloc,
    readings: readings,
    streaks: streaks,
    // **The very object the bloc was given**, so `calls` counts the screen's asks.
    // The first version built a second, identically-seeded fake here and the count
    // stayed `0` while the carousel rendered — a counter that cannot see the call it
    // is meant to count is worse than no counter, because it looks like evidence.
    catalogue: library,
    auth: auth,
  );
}

/// Mounts [HomePage] over [bloc] at §14's narrow surface, and pumps the frames a
/// `HomeStarted` needs.
///
/// [frames] is a parameter rather than a constant because the *loading* state is
/// reached and left inside one frame, while the *failed* state has to be reached and
/// then re-read — and a suite that hard-codes a number here fails in whichever of
/// those it did not think about.
///
/// ## AND THE **SETTINGS SCOPE** IS INSTALLED, BECAUSE `/` READS THE READER'S
/// CHOICES
///
/// Phase 7's ritual put the selah's length and the haptics switch on this
/// screen, and both live in `UserSettings`. `SettingsScope.of` falls back to
/// the locator when no scope is above the context — and the fallback is
/// **not watched**, so a page pumped bare would not rebuild when a setting
/// changes.
///
/// **The scope is installed WITHOUT the `EvaTypeScale`** that
/// `settings_harness.dart`'s own `settingsScope` installs, and that is
/// deliberate: the type scale would override the harness's own `textScale`
/// with the step's own 1.0, and `home_text_scale_test.dart` exists to prove
/// that a 1.22× surface survives.
Future<void> pumpHome(
  WidgetTester tester, {
  required HomeBloc bloc,
  Locale locale = const Locale('en'),
  Size size = kNarrowSurface,
  double textScale = 1.0,
  bool disableAnimations = false,
  int frames = 6,
  UserSettings? settings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The reader's own preferences, over the **real** store — the same fixture
  // `/settings` uses, so a test that says "the reader chose a 30-second
  // selah" is asserting against a persisted choice rather than against a
  // value the test handed the widget.
  final SettingsHarness harness = settingsHarness(initial: settings);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      textScale: textScale,
      disableAnimations: disableAnimations,
      locale: locale,
      // Derived from [locale] and **not** left to the default, for the reason
      // `login_harness.dart` records: the harness wraps its child in an
      // explicit `Directionality` that overrides the one Material installs, so
      // an `ar` locale with the harness's `ltr` default renders Arabic
      // left-to-right and the failure reads as "the page ignores RTL".
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: SettingsScope(
        key: const Key('test-settings-scope'),
        handle: harness.handle,
        child: HomePage(bloc: bloc),
      ),
    ),
  );
  await pumpFrames(tester, frames);
}

/// Advances [tester] by [count] frames.
///
/// Not `pumpAndSettle`: a failed section's `ErrorView` retry control carries a
/// `CircularProgressIndicator`, an animation that never ends, so settling here is a
/// ten-minute timeout rather than a green tick. See this file's library doc.
Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
