import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_system_harness.dart';

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
/// ## AND WHY `pumpHome` DOES NOT SETTLE
///
/// `evaPrimitiveHarness` mounts with `animationsEnabled: false`, so the three
/// shared ambient clocks never tick — `pumpAndSettle` is therefore safe here. The
/// prohibition is on the **app root**, where `NeuralMotionScope` runs three
/// `repeat()`ing controllers; `app_harness.dart`'s `pumpUntilFound` is for that.
/// [pumpHome] still advances a fixed number of frames rather than settling, because
/// the panel's own loading spinner is an infinite animation and settling would wait
/// for it.
final class HomeHarness {
  /// The fakes, so a test can read their counters or re-stub them.
  const HomeHarness({
    required this.bloc,
    required this.readings,
    required this.streaks,
    required this.auth,
  });

  /// The bloc under test. Close it with `addTearDown`.
  final HomeBloc bloc;

  /// `GET /readings/today/{lang}`.
  final CountingReadingRepository readings;

  /// `GET /streak/summary`.
  final CountingStreakRepository streaks;

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
  }) async => const Result<SubmitResult>.failure(
    Failure(
      kind: FailureKind.network,
      message:
          'This fake does not submit: no home screen calls the submit path.',
    ),
  );
}

/// [StreakRepository] that answers [answer] and counts its calls.
final class CountingStreakRepository implements StreakRepository {
  /// Starts out answering [answer].
  CountingStreakRepository({required this.answer});

  /// What the next call answers.
  Result<StreakSummary> answer;

  /// How many times [summary] has been called.
  int calls = 0;

  @override
  Future<Result<StreakSummary>> summary() async {
    calls++;
    return answer;
  }
}

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
        ? Result<AuthSession>.success(session)
        : const Result<AuthSession>.failure(
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
    return const Result<void>.success(null);
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
/// carries for that arm and an **unfinished** state so both branches of the
/// eyebrow are exercised by the fakes and not only by the entity test.
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

/// [base] with its first verse's text **opened by an emoji** and padded so the
/// emoji lands inside `previewText`'s 56-code-unit budget rather than at the cut.
///
/// ## WHY THE PADDING, AND WHY IT IS NOT COSMETIC
///
/// `previewText` cuts at a **code unit**, so the defect needs the emoji's high
/// surrogate to be the last unit taken: `'x' * 55 + '\u{1F600}'` does exactly that
/// and is the shortest string that reaches it. A fixture of `'\u{1F600} There was…'`
/// would put the emoji at index 0, which is the *other* half of the same bug — the
/// one `/reading`'s drop cap has — and would leave the truncation untested.
///
/// So this is the **wider surface** the review measured: an emoji anywhere in the
/// first 56 code units of verse one, not only at its start.
ScriptureText withAstralFirstVerse(ScriptureText base) {
  if (base.verses.isEmpty) return base;
  return base.copyWith(
    verses: <Verse>[
      base.verses.first.copyWith(
        text: '${'x' * 55}\u{1F600} There was a man of the Pharisees',
      ),
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
  // **Three** questions against the payload's one, and one answered. The narrow
  // fixture says three too, and the mismatch with the wire is deliberate: `/`'s
  // Arabic arm needs an *unfinished* reading so both branches of the eyebrow are
  // reachable, and inventing that through the entity would mean inventing verses.
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
    text: 'جَاءَ هَذَا إِلَىٰ يَسُوعَ لَيْلاً وَقَالَ لَهُ يَا مُعَلِّمُ، قَدْ نَعْلَمُ أَنَّكَ قَدْ أَتَيْتَ مِنَ ٱللَّهِ مُعَلِّمًا، لأَنَّهُ لَيْسَ أَحَدٌ يَقْدِرُ أَنْ يَعْمَلَ هَذِهِ ٱلْآيَاتِ ٱلَّتِ أَنْتَ تَعْمَلُ إِلَّا إِنْ كَانَ ٱللَّهُ مَعَهُ.',
    textClean:
        'جاء هذا إلى يسوع لياً وقال له يا معلم، نعلم أنك قد أتيت من الله معلماً، '
        'لأنه ليس أحد يقدر أن يعمل هذه الآيات التي أنت تعمل إلا إن كان الله معه',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 3,
    text: 'أَجَابَ يَسُوعُ وَقَالَ لَهُ: «اَلْحَقَّ ٱلْحَقَّ، أَقُولُ لَكَ: إِنْ كَانَ أَحَدٌ لا يُولَدُ مِنْ فَوْقُ لَا يَقْدِرُ أَنْ يَرَى مَلَكُوتَ ٱللَّهِ.»',
    textClean:
        'أجاب يسوع وقال له: «الحق الحق أقول لك إن كان أحد لا يولد من فوق لا يقدر '
        'أن يرى ملكوت الله.»',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 4,
    text: 'قَالَ لَهُ نِيقُودِيمُوسُ: كَيْفَ يُولَدُ ٱلْإِنْسَانُ وَهُوَ شَيْخٌ؟ أَلَعَلَّهُ يَقْدِرُ أَنْ يَدْخُلَ بَطْنَ أُمِّهِ ثَانِيَةً وَيَلِدُ؟',
    textClean:
        'قال له نيقوديموس: كيف يولد الإنسان وهو شيخ؟ ألاعله يقدر أن يدخل بطن أمه '
        ' ثانية ويولد؟',
  ),
  Verse(
    bookNumber: 43,
    chapter: 3,
    number: 5,
    text: 'أَجَابَ يَسُوعُ: «اَلْحَقَّ ٱلْحَقَّ، أَقُولُ لَكَ: إِنْ كَانَ أَحَدٌ لا يُولَدُ مِنْ ٱلْمَاءِ وَٱلرُّوحِ لَا يَقْدِرُ أَنْ يَدْخُلَ مَلَكُوتَ ٱللَّهِ.»',
    textClean:
        'أجاب يسوع: «الحق الحق أقول لك إن كان أحد لا يولد من الماء والروح لا يقدر '
        'أن يدخل ملكوت الله.»',
  ),
];

/// The Arabic arm's questions: **three**, of which one is answered.
///
/// Deliberately three where the payload carries one, and the reason is written on
/// [liveArabicScripture]: `/`'s Arabic arm must reach both branches of the
/// eyebrow's status line, and `is_fully_completed: false` with one answered question
/// out of three is the only fixture that does. The wide entity makes the
/// inconsistency **visible** where the narrow one hid it behind a count.
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
  Question(
    id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
    sortOrder: 2,
    type: 'mcq',
    prompt: 'ماذا قال الرب لنيقوديموس؟',
    options: <String, String>{'A': 'اذهب', 'B': 'تابعني'},
    pointsValue: 10,
    alreadyAnswered: false,
  ),
  Question(
    id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    sortOrder: 3,
    type: 'mcq',
    prompt: 'ما معنى الولادة الجديدة؟',
    options: <String, String>{
      'A': 'من الماء والروح',
      'B': 'من الماء والروح أيضًا',
    },
    pointsValue: 10,
    alreadyAnswered: false,
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
  AuthSession? session,
  // **Not `session: null`.** A nullable parameter with a default cannot tell "the
  // caller passed null" from "the caller passed nothing", and the default here is
  // the seeded session. So "no session" is a separate flag — and the first version
  // of `home_page_test.dart`'s no-session test passed `session: null`, got the
  // seeded session anyway, and asserted against a greeting that said
  // `Good morning, David Mina`.
  bool signedIn = true,
  DateTime? at,
}) {
  final CountingReadingRepository readings = CountingReadingRepository(
    scripture:
        reading ?? const Result<ScriptureText>.success(liveEnglishScripture),
  );
  final CountingStreakRepository streaks = CountingStreakRepository(
    answer: streak ?? const Result<StreakSummary>.success(liveStreakSummary),
  );
  final CountingAuthRepository auth = CountingAuthRepository(
    session: signedIn ? (session ?? liveSession) : null,
  );
  final HomeBloc bloc = HomeBloc(
    loadTodayReading: LoadTodayReading(readings),
    loadStreakSummary: LoadStreakSummary(streaks),
    getReaderSession: GetReaderSession(auth),
    now: () => at ?? DateTime(2026, 10, 3, 9, 30),
  );
  addTearDown(bloc.close);
  return HomeHarness(
    bloc: bloc,
    readings: readings,
    streaks: streaks,
    auth: auth,
  );
}

/// Mounts [HomePage] over [bloc] at §14's narrow surface, and pumps the four frames
/// a `HomeStarted` needs.
///
/// [frames] is a parameter rather than a constant because the *loading* state is
/// reached and left inside one frame, while the *failed* state has to be reached and
/// then re-read — and a suite that hard-codes a number here fails in whichever of
/// those it did not think about.
Future<void> pumpHome(
  WidgetTester tester, {
  required HomeBloc bloc,
  Locale locale = const Locale('en'),
  Size size = kNarrowSurface,
  double textScale = 1.0,
  bool disableAnimations = false,
  int frames = 6,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: HomePage(bloc: bloc),
    ),
  );
  await pumpFrames(tester, frames);
}

/// Advances [tester] by [count] frames.
///
/// Not `pumpAndSettle`: the panel's loading state is a `CircularProgressIndicator`,
/// an animation that never ends, so settling here is a ten-minute timeout rather
/// than a green tick. See this file's library doc.
Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
