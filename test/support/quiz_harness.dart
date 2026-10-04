import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/domain/usecases/refresh_session_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_payloads.dart';
import 'design_system_harness.dart';
import 'reading_harness.dart';

export 'reading_harness.dart' show kGeometrySurface;

/// The shared fixture for every `/quiz` and `/result` widget test.
///
/// ## WHY THE BLOC IS BUILT **IN THE TEST BODY**
///
/// Recorded decision 20, measured: a bloc built in `setUp` runs its events on a
/// microtask queue outside the fake-async zone `tester.pump()` drains, so
/// `bloc.state` is correct and `find.text(…)` returns **zero** widgets. Decision 37
/// adds the other half — a fake that answers by awaiting a `Completer` never
/// completes and the suite hangs at the full timeout — so [quizBloc] answers
/// **synchronously** with a `Result`.
///
/// ## AND THE QUESTION IDS ARE THE **FABRICATED** ONES
///
/// §5 trap 10, verified live against `HEAD = 4a1c834`: the id `GET /readings/today/
/// {lang}` hands out for group 3 is `question-group-3`, which the submit route then
/// rejects with `400 … must match format "uuid"`. Every fixture here uses it, because
/// a fixture built from well-formed UUIDs would pass every test in this phase and
/// hide the case this backend actually produces.
const Question liveArabicQuestion = Question(
  id: 'question-group-3',
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
  alreadyAnswered: false,
);

/// The English twin of [liveArabicQuestion].
const Question liveEnglishQuestion = Question(
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

/// One open question in Arabic, in the shape the live Arabic payload serves.
///
/// **`already_answered: false`** — the 2026-10-04 capture is an open question, while
/// the 2026-10-03 one was already answered. Both shapes matter and both are
/// reachable: `reading_harness.dart`'s `answeredQuestion` is the second, and
/// `quiz_page_test.dart`'s spoiler group uses it as the payload that **has** an
/// answer to hide.
const ScriptureText liveArabicQuizPassage = ScriptureText(
  readingId: 'reading-group-3-2026-10-04',
  groupId: 3,
  scheduledDate: '2026-10-04',
  language: ReadingLanguage.arabic,
  reference: 'يوحنا 3: 1-5',
  translation: 'Smith & Van Dyck (فانديك)',
  verses: <Verse>[firstVerse],
  questions: <Question>[liveArabicQuestion],
  isFullyCompleted: false,
  pointsEarnedToday: 0,
  currentStreak: 4,
);

/// The English twin of [liveArabicQuizPassage].
const ScriptureText liveEnglishQuizPassage = ScriptureText(
  readingId: 'reading-group-3-2026-10-04',
  groupId: 3,
  scheduledDate: '2026-10-04',
  language: ReadingLanguage.english,
  reference: 'John 3:1-5',
  translation: 'NKJV (New King James Version)',
  verses: <Verse>[firstVerse],
  questions: <Question>[liveEnglishQuestion],
  isFullyCompleted: false,
  pointsEarnedToday: 0,
  currentStreak: 4,
);

/// An **open** question that nevertheless carries the server's answer key.
///
/// ## WHY THIS FIXTURE EXISTS AT ALL, AND WHY IT IS NOT THE SAME AS
/// [liveEnglishQuestion]
///
/// `liveEnglishQuestion` is the 2026-10-04 capture: `already_answered: false` and no
/// `userAnswer`, no `is_correct` — there is nothing on it to leak. A spoiler test
/// run against it passes on **any** screen, including one that renders `is_correct`
/// the moment the frame paints, because the field is `null`.
///
/// So this is the sharpest instrument the domain allows: `already_answered: false`,
/// which makes the question **submittable**, and `user_answer: 'A'` with
/// `is_correct: true`, which is the payload shape §5 trap 3 describes. A screen that
/// reads either field before the reader commits shows something here and nothing in
/// the capture-based fixture — so the capture-based test would be the one lying.
Question verdictCarryingQuestion = liveEnglishQuestion.copyWith(
  userAnswer: 'A',
  isCorrect: true,
);

/// [liveEnglishQuizPassage] with [questions] in place of its own.
///
/// **A function, not a fourth `const` transcription.** `ScriptureText` carries ten
/// fields, eight of which are irrelevant to every quiz suite, and three of those
/// eight are date-stamped. Copying the whole block per fixture is how a fixture and
/// its passage drift apart silently — and the drift is invisible because nothing
/// compares them. This way the passage has exactly one transcription and the
/// questions are the only thing a suite varies.
ScriptureText englishPassageWith(List<Question> questions) => ScriptureText(
  readingId: liveEnglishQuizPassage.readingId,
  groupId: liveEnglishQuizPassage.groupId,
  scheduledDate: liveEnglishQuizPassage.scheduledDate,
  language: liveEnglishQuizPassage.language,
  reference: liveEnglishQuizPassage.reference,
  translation: liveEnglishQuizPassage.translation,
  verses: liveEnglishQuizPassage.verses,
  questions: questions,
  isFullyCompleted: liveEnglishQuizPassage.isFullyCompleted,
  pointsEarnedToday: liveEnglishQuizPassage.pointsEarnedToday,
  currentStreak: liveEnglishQuizPassage.currentStreak,
);

/// The Arabic twin of [englishPassageWith].
ScriptureText arabicPassageWith(List<Question> questions) => ScriptureText(
  readingId: liveArabicQuizPassage.readingId,
  groupId: liveArabicQuizPassage.groupId,
  scheduledDate: liveArabicQuizPassage.scheduledDate,
  language: liveArabicQuizPassage.language,
  reference: liveArabicQuizPassage.reference,
  translation: liveArabicQuizPassage.translation,
  verses: liveArabicQuizPassage.verses,
  questions: questions,
  isFullyCompleted: liveArabicQuizPassage.isFullyCompleted,
  pointsEarnedToday: liveArabicQuizPassage.pointsEarnedToday,
  currentStreak: liveArabicQuizPassage.currentStreak,
);

/// A passage whose **first** question is already answered and whose second is open.
///
/// ## WHY THIS NEEDS TWO QUESTIONS TO EXIST
///
/// [aClosedFixture] — one closed question, nothing submitted — is **already** the
/// dead end. `QuizCta`'s table has no row between "closed, on the last, not yet
/// finished" and "closed, on the last, and nothing was submitted": with one question
/// and no result the state is `none` from the first frame, and there is no press that
/// gets there. So the row above it — `closed, more to advance to → next` — is
/// unreachable from a one-question payload, and a suite that wanted it would have to
/// invent a second question.
///
/// This is that second question, taken from the live capture rather than authored:
/// `answeredQuestion` is `sortOrder: 1` and `liveEnglishQuestion` is the open one, so
/// the pair reads as one reading in the order the server would send it.
ScriptureText get mixedQuizPassage =>
    englishPassageWith(<Question>[answeredQuestion, liveEnglishQuestion]);

/// A [QuizBloc] over a counting fake answering [reading].
///
/// The teardown is registered **here** rather than at each call site, for decision
/// 20's reason: every suite that builds a bloc outside a `testWidgets` body has to
/// remember, and the one that forgets leaks a stream.
QuizBloc quizBloc(
  Result<ScriptureText> reading, {
  Result<SubmitResult>? submission,
}) {
  final CountingReadingRepository readings = CountingReadingRepository(
    scripture: reading,
  );
  if (submission != null) readings.submission = submission;
  final QuizBloc bloc = QuizBloc(
    startSession: StartSession(readings),
    refreshSessionQuestions: RefreshSessionQuestions(readings),
    submitAnswer: SubmitAnswer(readings),
  );
  addTearDown(bloc.close);
  return bloc;
}

/// The fake behind [quizBloc], for the suites that need to read what it was asked.
///
/// A second parameter rather than a second constructor, because "the bloc and the
/// repository" is one fixture with two handles and two constructors would let a
/// suite pair a bloc with a repository it did not mean.
({QuizBloc bloc, CountingReadingRepository readings}) quizBlocWith(
  Result<ScriptureText> reading, {
  Result<SubmitResult>? submission,
}) {
  final CountingReadingRepository readings = CountingReadingRepository(
    scripture: reading,
  );
  if (submission != null) readings.submission = submission;
  final QuizBloc bloc = QuizBloc(
    startSession: StartSession(readings),
    refreshSessionQuestions: RefreshSessionQuestions(readings),
    submitAnswer: SubmitAnswer(readings),
  );
  addTearDown(bloc.close);
  return (bloc: bloc, readings: readings);
}

/// The default submit response a [QuizBloc] answers with.
///
/// [contractSubmitAnswerFixture] rather than a success of this file's own: it is the
/// transcription of the one contract the backend declares, and a second fixture for
/// it would be a second thing to keep in step.
Result<SubmitResult> get defaultSubmission =>
    const Result<SubmitResult>.success(contractSubmitAnswerFixture);

/// Mounts [QuizPage] over [bloc] and lets the load land.
///
/// [frames] is a parameter for `reading_harness.dart`'s reason: the *loading* state is
/// reached and left inside one frame while the *ready* state has to be reached and
/// then re-read.
Future<void> pumpQuiz(
  WidgetTester tester, {
  required QuizBloc bloc,
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
      // ## THE REDUCED-MOTION SWITCH, AND WHAT IT WAS MEASURED TO REACH
      //
      // **Measured, not assumed**, on the pinned toolchain — and the measurement is
      // the reason this parameter is kept rather than deleted:
      //
      // | probe | result |
      // | --- | --- |
      // | `MediaQuery.maybeDisableAnimationsOf` at the `QuizPage` element | `true` |
      // | … at the `NeuralBackground` element | `true` |
      // | … at the `GoldFlecks` element (on a graded-correct card) | `true` |
      // | `NeuralTiers.resolve` at that position — the value `NeuralBackground.build` computes | `NeuralTier.low`, where the same probe with the flag off resolves `NeuralTier.mid` |
      // | the `animate` field on the painter `GoldFlecks` builds | `false`, where the flag off gives `true` — i.e. the flecks freeze at clock `0` instead of reading it |
      //
      // So the flag reaches the `MediaQuery` **and two widgets observe it**, which is
      /// the distinction that matters: a passthrough nothing reads would be a knob in
      /// name only. `pumpReading` and `pumpResult` carry the same switch for the
      /// same reason — §14's reduced-motion requirement is a standing gate on **every**
      /// screen, and this is the only way to ask it of `/quiz`.
      //
      // **`rg 'disableAnimations: true' test/` finds a live caller for `pumpHome`
      // (`home_accessibility_test.dart`) and, since this was measured, one for
      // `pumpResult` (`result_page_test.dart`). None turns it for `/quiz` yet.** That
      // is recorded rather than guessed at: `/quiz`'s reduced-motion behaviour is not
      // asserted anywhere yet, and this is the instrument that will assert it.
      //
      // **Not deleted**, which is a disagreement with the suggestion to remove it. The
      // shape §7's "a knob nothing turns" is about is a knob whose *own* doc claims a
      // caller or a behaviour that does not exist — `ResultStrings.noResultSuffix`
      // claimed a control that does not exist, and `expectThePortIsTheSeam` was a
      // tautology. Both were deleted. This one claims nothing it has not measured.
      disableAnimations: disableAnimations,
      locale: locale,
      // Derived from [locale] and **not** left to the default, for
      // `login_harness.dart`'s recorded reason: the harness wraps its child in an
      // explicit `Directionality` that overrides the one `MaterialApp` installs, so
      // an `ar` locale with the harness's `ltr` default would render Arabic
      // left-to-right and the failure would read as "the page ignores RTL".
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: QuizPage(bloc: bloc),
    ),
  );
  await pumpQuizFrames(tester, frames);
}

/// Advances [tester] by [count] frames.
///
/// Not `pumpAndSettle`: `GoldFlecks` reads the ambient float clock and
/// `NeuralScaffold` paints orbs on it, so both are animation sources and the
/// standing rule is that `pumpAndSettle` is forbidden at the app root for exactly
/// this reason.
Future<void> pumpQuizFrames(WidgetTester tester, int count) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Mounts [ResultPage] over [result].
///
/// [frames] exists for the same reason as [pumpQuiz]'s: `ResultPage` paints a burst
/// whose glow and five flecks read the same ambient clock.
///
/// **[disableAnimations] was added here rather than defended as an inconsistency.**
/// `pumpResult` was the one member of the `pump*` family without the switch, and this
/// file's `pumpQuiz` doc used to claim "`pumpReading` and `pumpResult`'s siblings
/// carry it" — true of `pumpReading`, false of `pumpResult`, and unverified for
/// either. Measured on the pinned toolchain: mounting this page under
/// `evaPrimitiveHarness(disableAnimations: true)` puts `true` at both the `ResultPage`
/// and `NeuralBackground` elements, and `NeuralTiers.resolve` — the exact call
/// `NeuralBackground.build` makes, with this position's real `MediaQuery` and size —
/// then returns `NeuralTier.low` where the default call returns `NeuralTier.mid`. So
/// the wiring works and only the switch was missing, and a uniformity argument that
/// is only true for two of the three members is not worth making.
///
/// `result_page_test.dart` is now the live caller, which is the point: §14's
/// reduced-motion requirement is a standing gate, and `/result` cannot be asked about
/// it at all without this parameter.
Future<void> pumpResult(
  WidgetTester tester, {
  required SubmitResult result,
  Locale locale = const Locale('en'),
  Size size = kGeometrySurface,
  double textScale = 1.0,
  bool disableAnimations = false,
  int frames = 4,
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
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: ResultPage(result: result),
    ),
  );
  await pumpQuizFrames(tester, frames);
}
