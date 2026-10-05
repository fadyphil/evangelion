import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/features/reading/domain/usecases/load_scripture.dart';
import 'package:evangelion/features/reading/presentation/bloc/reading_cubit.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_payloads.dart';
import 'design_system_harness.dart';
import 'settings_harness.dart';

/// The shared fixture for every `/reading` widget test.
///
/// ## WHY THE CUBIT IS BUILT **IN THE TEST BODY**
///
/// Recorded decision 20 measured it on `/login` and `HomePage` repeated it: a bloc
/// built in `setUp` runs its events on a microtask queue outside the fake-async zone
/// `tester.pump()` drains, so `bloc.state` is correct and `find.text(…)` returns
/// **zero** widgets. Every suite here builds its cubit through [readingHarness] in
/// the body, with the teardown registered by that function.
final class ReadingHarness {
  /// Builds the fixture. [cubit] is the cubit under test — close it with
  /// `addTearDown` — and [readings] is the fake behind it.
  const ReadingHarness({required this.cubit, required this.readings});

  /// The cubit under test. Close it with `addTearDown`.
  final ReadingCubit cubit;

  /// `GET /readings/today/{lang}`.
  final CountingReadingRepository readings;
}

/// [ReadingRepository] that answers [scripture] and counts its calls.
///
/// Hand-written rather than a `mocktail` mock, for `home_harness.dart`'s reason: a
/// mock implements whatever it is told to, so it can satisfy the port and answer
/// nothing. This one always answers, and records **which language** it was asked for,
/// because "the Arabic arm is on screen" and "the Arabic arm was requested" are
/// different claims and the locale change is the trigger this screen has to honour.
final class CountingReadingRepository implements ReadingRepository {
  /// Starts out answering [scripture].
  CountingReadingRepository({required this.scripture});

  /// What the next call answers.
  Result<ScriptureText> scripture;

  /// How many times either method has been called.
  int calls = 0;

  /// The languages the port has been asked for, in order.
  final List<ReadingLanguage> asked = <ReadingLanguage>[];

  /// What [submitAnswer] answers. Settable, because the bloc tests need both a
  /// graded answer and a 409-shaped failure and neither is the interesting default.
  Result<SubmitResult> submission = const Result<SubmitResult>.success(
    contractSubmitAnswerFixture,
  );

  /// How many times [submitAnswer] has been called.
  int submitCalls = 0;

  /// What [submitAnswer] was asked, in order.
  final List<({String readingId, String questionId, String answer})>
  submissions = <({String readingId, String questionId, String answer})>[];

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

  /// Phase 8's third port method, and this fake is the one the **quiz** suites
  /// drive rather than merely compile against — so unlike its two siblings it
  /// answers with something and counts what it was asked.
  ///
  /// It records every `(readingId, questionId, answer)` triple, because the two
  /// claims a quiz suite needs are "the body sent was the contract's" and "the
  /// answer went out **verbatim**", and a count alone says neither. It is also the
  /// only place a test can see the request at all: §5 trap 10 records that no
  /// successful submit has ever been observed, so nothing may be verified against a
  /// socket.
  @override
  Future<Result<SubmitResult>> submitAnswer({
    required String readingId,
    required String questionId,
    required String answer,
  }) async {
    submitCalls++;
    submissions.add((
      readingId: readingId,
      questionId: questionId,
      answer: answer,
    ));
    return submission;
  }
}

/// Builds a [ReadingCubit] over a counting fake, and registers the teardown.
ReadingHarness readingHarness({Result<ScriptureText>? scripture}) {
  final CountingReadingRepository readings = CountingReadingRepository(
    scripture:
        scripture ?? const Result<ScriptureText>.success(liveEnglishPassage),
  );
  final ReadingCubit cubit = ReadingCubit(
    loadScripture: LoadScripture(readings),
  );
  addTearDown(cubit.close);
  return ReadingHarness(cubit: cubit, readings: readings);
}

/// A [Failure] that says what it is, for the "the passage would not load" fixture.
///
/// `api_error_mapper_test.dart`'s wording, so a reader comparing the two suites sees
/// the same server rather than two invented ones.
const Failure readingFailure = Failure(
  kind: FailureKind.network,
  message: 'Could not reach the server.',
);

/// Mounts [ReadingPage] over [cubit] at the given surface and locale, and pumps the
/// frames a `load` needs.
///
/// [frames] is a parameter rather than a constant because the *loading* state is
/// reached and left inside one frame while the *failed* state has to be reached and
/// then re-read — and a suite that hard-codes a number here fails in whichever of
/// those it did not think about. `home_harness.dart`'s `pumpHome` is the precedent
/// and its doc gives the whole argument.
Future<void> pumpReading(
  WidgetTester tester, {
  required ReadingCubit cubit,
  Locale locale = const Locale('en'),
  Size size = kGeometrySurface,
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
      // Derived from [locale] and **not** left to the default, for
      // `login_harness.dart`'s recorded reason: the harness wraps its child in an
      // explicit `Directionality` that overrides the one `MaterialApp` installs from
      // the locale, so an `ar` locale with the harness's `ltr` default would render
      // Arabic left-to-right and the failure would read as "the page ignores RTL".
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      // **`SettingsScope`, added in Phase 9 and load-bearing for five suites.** Since
      // the font step became `UserSettings.fontStep`, `/reading` reads it out of the
      // installed `MediaQuery` and writes it through `SettingsScope.of(context)` — so
      // a page pumped without a scope above it either throws out of `build` (no
      // locator registration) or, worse, writes through the locator's singleton while
      // nothing rebuilds. The scope is what makes the `Aa` panel honest here, and
      // `reading_page_test.dart` asserts the write reached a **store**.
      child: settingsScope(tester, ReadingPage(cubit: cubit)),
    ),
  );
  await pumpReadingFrames(tester, frames);
}

/// Advances [tester] by [count] frames.
///
/// Not `pumpAndSettle`: `ErrorView`'s retry and the ambient clocks are animation
/// sources, and the standing rule is that `pumpAndSettle` is forbidden at the app
/// root for exactly this reason.
Future<void> pumpReadingFrames(WidgetTester tester, int count) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The surface the geometry harness measures at.
///
/// **430×932, not §14's 320×568**, and for `home_geometry_test.dart`'s stated
/// reason: this file compares against the prototype's own numbers, and at 320 the
/// Arabic citation wraps and every vertical measurement being compared moves. §14's
/// requirement is `reading_text_scale_test.dart`'s.
const Size kGeometrySurface = Size(430, 932);

/// The live English passage, as the mapper produces it from
/// `kLiveReadingEnJson`: five verses with **no `text_clean` key at all**, and one
/// question that is already answered and **carries the answer**.
///
/// `text_clean` is absent rather than `null` because that is the live English shape
/// (§5, trap 2) and a fixture that spelled `null` would make defect #2's Arabic-only
/// branch the only one exercised.
const List<Verse> liveEnglishPassageVerses = <Verse>[
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
        'Jesus answered, ‹Verily, verily, I say unto thee, Except a man be born of '
        'water and› [of] ‹the Spirit, he cannot enter into the kingdom of God.›',
  ),
];

/// The live English question, with `user_answer` and `is_correct` **present**.
///
/// That is the whole point of the fixture: the reading response ships the answer with
/// the question, so "the answer is not on the screen" has to be asserted against a
/// payload that has one to hide.
const List<Question> liveEnglishPassageQuestions = <Question>[
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

/// [liveEnglishPassageVerses] as one passage.
const ScriptureText liveEnglishPassage = ScriptureText(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  groupId: 3,
  scheduledDate: '2026-10-03',
  language: ReadingLanguage.english,
  reference: 'John 3:1-5',
  translation: 'NKJV (New King James Version)',
  verses: liveEnglishPassageVerses,
  questions: liveEnglishPassageQuestions,
  isFullyCompleted: true,
  pointsEarnedToday: 10,
  currentStreak: 4,
);

/// The live Arabic passage, with **`text_clean` on every verse** and the same
/// question carrying the same answer.
///
/// `reference` keeps its **space after the colon** — `يوحنا 3: 1-5` — because that
/// spacing is the server's and normalising it would be the client editing a citation.
const List<Verse> liveArabicPassageVerses = <Verse>[
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

/// The live Arabic question: Arabic prompt and options, same answer.
const List<Question> liveArabicPassageQuestions = <Question>[
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

/// [liveArabicPassageVerses] as one passage.
const ScriptureText liveArabicPassage = ScriptureText(
  readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  groupId: 3,
  scheduledDate: '2026-10-03',
  language: ReadingLanguage.arabic,
  reference: 'يوحنا 3: 1-5',
  translation: 'Smith & Van Dyck (فانديك)',
  verses: liveArabicPassageVerses,
  questions: liveArabicPassageQuestions,
  isFullyCompleted: true,
  pointsEarnedToday: 10,
  currentStreak: 4,
);

/// The live English passage's **first verse**, shared so a suite can build a
/// `ScriptureText` whose `verses` list is one entry without restating it.
///
/// Added in Phase 8 for the quiz's fixtures: `threeOpen` and its siblings each
/// declare a full `ScriptureText`, and a fixture that copied verse one five times
/// is five places to keep in step. `/quiz` never reads a verse, so **one** is enough
/// — and its brevity is the honest description of what the quiz cares about.
const Verse firstVerse = Verse(
  bookNumber: 43,
  chapter: 3,
  number: 1,
  text:
      'There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:',
);

/// The live English passage's single question, already answered and carrying the
/// answer. See [liveEnglishPassageQuestions], which is the `const` list form.
///
/// Spelled out rather than indexed out of that list because a suite needs a
/// **named** question to assert on, and `liveEnglishPassageQuestions.first` reads
/// as "the first of the live list" while this is "the already-answered question",
/// which is what a quiz fixture is about.
const Question answeredQuestion = Question(
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
);

/// A question that is **open**, which the live payloads of 2026-10-04 are and the
/// 2026-10-03 one is not.
///
/// Its `id` is `question-group-3` — the fabricated id the live endpoint hands out
/// (§5 trap 10) — and that is deliberate rather than a convenient UUID: the client's
/// only job is to echo whatever the server gave it, and `question_repository`'s
/// port doc says so. A fixture using a well-formed UUID would pass the same tests
/// and hide the case this backend actually produces.
const Question openQuestion = Question(
  id: 'question-group-3',
  sortOrder: 1,
  type: 'mcq',
  prompt: 'What was the name of the man who came to Jesus by night?',
  options: <String, String>{
    'A': 'Nicodemus',
    'B': 'Paul',
    'C': 'Peter',
    'D': 'Lazarus',
  },
  pointsValue: 10,
  alreadyAnswered: false,
);

/// The letter of every drop cap on screen, in order.
///
/// ## WHY A WALK AND NOT `find.byType(Text)`
///
/// `PassageDropCap.span` produces a `WidgetSpan` whose child is a `Text`, and a
/// `WidgetSpan` has **no `Element`** — so the cap is in the tree, is the largest
/// thing `/reading` draws, and `find.byType(Text)` cannot reach it. The verse
/// paragraph is the only `RichText` on this screen with children, and the cap is
/// the `WidgetSpan` among them.
List<String> dropCapLetters(WidgetTester tester) => <String>[
  for (final RichText rich in tester.widgetList<RichText>(
    find.byType(RichText),
  ))
    if (rich.text is TextSpan)
      for (final InlineSpan child
          in (rich.text as TextSpan).children ?? const <InlineSpan>[])
        if (child is WidgetSpan && child.child is Text)
          (child.child as Text).data ?? '',
];
