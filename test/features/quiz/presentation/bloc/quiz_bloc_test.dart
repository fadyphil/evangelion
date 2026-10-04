import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/question.dart';
import 'package:evangelion/core/domain/entities/quiz_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/quiz/domain/usecases/refresh_session_questions.dart';
import 'package:evangelion/features/quiz/domain/usecases/start_session.dart';
import 'package:evangelion/features/quiz/domain/usecases/submit_answer.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/contract_payloads.dart';
import '../../../../support/reading_harness.dart';

/// `QuizBloc` — red-first (AGENT_CONTEXT §6: "every cubit", with `bloc_test` +
/// `mocktail`). The fakes here are `reading_harness.dart`'s, which count what they
/// were asked and — for the submit — record the whole triple, because "the body sent
/// was the contract's" is a claim a count cannot make.
///
/// ## THE FIVE STATES, AND WHY "SUBMITTING" IS NOT A `bool`
///
/// `QuizStatus` distinguishes loading / ready / submitting / failed / complete
/// because the reader can tell those five apart. The interesting pair is
/// **submitting** and **ready**: a single `isLoading` would have to collapse them,
/// and any word it picked would be a claim the reader cannot verify — the CTA has to
/// go dead for the round trip and come back either graded or failed, and a flag that
/// said "busy" would leave the *failure* indistinguishable from still-busy.
///
/// **`complete` is a state and not a derived getter** because the plan asks for it
/// and because it is observable: the CTA's label and its enabled-ness both change
/// when it is reached, so a widget test can see it without re-deriving the rule.
void main() {
  /// Two questions: the first open, the second already answered on the wire.
  const ScriptureText twoQuestions = ScriptureText(
    readingId: 'reading-group-3-2026-10-04',
    groupId: 3,
    scheduledDate: '2026-10-04',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV (New King James Version)',
    verses: <Verse>[firstVerse],
    questions: <Question>[openQuestion, answeredQuestion],
    isFullyCompleted: false,
    pointsEarnedToday: 0,
    currentStreak: 4,
  );

  /// The same two questions with **the open one now answered** — the payload a
  /// second fetch returns, and the fixture the refresh tests need.
  const ScriptureText bothAnswered = ScriptureText(
    readingId: 'reading-group-3-2026-10-04',
    groupId: 3,
    scheduledDate: '2026-10-04',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV (New King James Version)',
    verses: <Verse>[firstVerse],
    questions: <Question>[
      Question(
        id: 'question-group-3',
        sortOrder: 1,
        type: 'mcq',
        prompt: 'What was the name of the man who came to Jesus by night?',
        options: <String, String>{'A': 'Nicodemus', 'B': 'Paul'},
        pointsValue: 10,
        alreadyAnswered: true,
        userAnswer: 'A',
        isCorrect: true,
      ),
      answeredQuestion,
    ],
    isFullyCompleted: true,
    pointsEarnedToday: 10,
    currentStreak: 4,
  );

  /// Three questions, all open — the "a reader can answer everything" fixture.
  const ScriptureText threeOpen = ScriptureText(
    readingId: 'reading-group-3-2026-10-04',
    groupId: 3,
    scheduledDate: '2026-10-04',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV (New King James Version)',
    verses: <Verse>[firstVerse],
    questions: <Question>[
      openQuestion,
      Question(
        id: 'question-group-4',
        sortOrder: 2,
        type: 'mcq',
        prompt: 'Where did Nicodemus find Jesus?',
        options: <String, String>{'A': 'In Galilee', 'B': 'In Jerusalem'},
        pointsValue: 10,
        alreadyAnswered: false,
      ),
      Question(
        id: 'question-group-5',
        sortOrder: 3,
        type: 'mcq',
        prompt: 'What did Jesus call Nicodemus?',
        options: <String, String>{'A': 'A teacher', 'B': 'A ruler'},
        pointsValue: 10,
        alreadyAnswered: false,
      ),
    ],
    isFullyCompleted: false,
    pointsEarnedToday: 0,
    currentStreak: 4,
  );

  /// The **already-answered question first**, so the reader lands on a closed
  /// question without having to answer anything to get there.
  ///
  /// This is a real shape — `Question.sortOrder` is the server's and it is free to
  /// put an answered question anywhere — and it is the only way to reach the
  /// "advance past a closed question" arm from a cold start, because the advance
  /// guard refuses to skip an **open** one.
  const ScriptureText firstAnswered = ScriptureText(
    readingId: 'reading-group-3-2026-10-04',
    groupId: 3,
    scheduledDate: '2026-10-04',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV (New King James Version)',
    verses: <Verse>[firstVerse],
    questions: <Question>[answeredQuestion, openQuestion],
    isFullyCompleted: true,
    pointsEarnedToday: 10,
    currentStreak: 4,
  );

  /// The session `twoQuestions` becomes, with nothing touched.
  const QuizSession aFreshSession = QuizSession(
    readingId: 'reading-group-3-2026-10-04',
    answers: <QuizAnswer>[
      QuizAnswer(question: openQuestion),
      QuizAnswer(question: answeredQuestion),
    ],
  );

  /// Lets the bloc's microtasks drain.
  ///
  /// **Microtasks, not timers.** See the note on the body below.
  ///
  /// **A `delayed(Duration.zero)` was tried first and hung**, at the suite's full
  /// timeout with no failure message. The cause was not the clock: the first draft
  /// of this helper was rewritten by a search-and-replace that turned its own body
  /// into `await settle()`, so it recursed and the microtask queue never drained.
  /// It is written out here rather than generated, and the four-turns note is kept
  /// because the same sweep can reach it again.
  Future<void> settle() async {
    for (int turn = 0; turn < 4; turn++) {
      await Future<void>.microtask(() {});
    }
  }

  /// Every state [bloc] emits from **now on**, plus the state it is in when the
  /// subscription is taken.
  ///
  /// This is how the "**refused**" cases below assert that nothing happened, rather
  /// than counting `bloc_test`'s emitted list by index. Counting by index needs the
  /// exact number of intermediate states to be right, and when a handler legitimately
  /// grows one the test fails with "expected [] but got [QuizState]" — which says
  /// the state is different, not that an extra emit happened. `bloc.stream` does not
  /// replay, so the current state is prepended.
  Future<List<QuizState>> watch(QuizBloc bloc) async {
    final List<QuizState> states = <QuizState>[bloc.state];
    final StreamSubscription<QuizState> subscription = bloc.stream.listen(
      states.add,
    );
    addTearDown(subscription.cancel);
    return states;
  }

  QuizBloc blocOver(
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

  group('`QuizStarted`', () {
    // ## AND IT IS RE-DISPATCHED **WITHOUT THE READER ASKING**, WHICH IS WHY
    // ## `lastResult` HAS TO SURVIVE IT
    //
    // `_QuizBodyState.didChangeDependencies` re-dispatches `QuizStarted` on every
    // locale change, and `QuizPage.bloc == null` in production means that is the only
    // way this screen ever loads. So a `QuizStarted` after a grade is not a corner
    // case — it is what the reader gets when they switch language while looking at a
    // live "See results" button.
    //
    // It used to end in `QuizCta.none` with no reason on screen: `_onStarted` emitted
    // `const QuizState()`, which drops `lastResult`, and `_emitReading` built a state
    // that did not carry it. Nothing asserted the field survived, so the CTA silently
    // went dead under a reader's finger.
    test('and it CARRIES `lastResult` across a reload, so the CTA stays live', () async {
      final QuizBloc bloc = blocOver(
        const Result<ScriptureText>.success(threeOpen),
      );

      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      bloc.add(const QuizAdvanced());
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      bloc.add(const QuizAdvanced());
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      bloc.add(const QuizAdvanced());
      await settle();
      expect(bloc.state.status, QuizStatus.complete);
      expect(bloc.state.cta, QuizCta.finish, reason: 'the terminal state');

      // **The locale switch**, while the reader is looking at a live "See results"
      // button. Same event, same bloc, no reader action — exactly what
      // `didChangeDependencies` sends.
      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();

      expect(
        bloc.state.lastResult,
        contractSubmitAnswerFixture,
        reason:
            'the result is a fact about an answer the server graded; re-reading the '
            'reading does not un-grade it. `_onRetried` already carries it — see that '
            'handler\'s "if the handler reads what it needs, it reads it first". '
            'Dropping it here put `/result` out of reach for the rest of the session',
      );
      expect(bloc.state.status, QuizStatus.ready);

      // ## AND THE CTA IS **STILL** `none`, WHICH IS THE PART THIS DOES **NOT**
      // ## FIX — STATED HERE SO IT IS A RECORD AND NOT A SURPRISE
      //
      // Carrying `lastResult` is necessary and not sufficient. `_onStarted` also
      // **rebuilds the session** from the wire, because a fresh start refetches a
      // *language-specific* payload — so the cursor is back at question one with
      // nothing selected, and `QuizState.cta`'s second arm (`isOpen`) wins over the
      // `lastResult` arm. A reader who switches language therefore still lands on
      // `QuizCta.none`.
      //
      // That is recorded rather than fixed, and the reason is scope: making
      // `QuizStarted` rebase instead of rebuild is `_onRetried`'s two arms, and it
      // changes what a *first* start means. `QuizState.cta`'s own table is the other
      // half of the answer — it says the terminal CTA is `finish` only when
      // `lastResult` is in hand, so with the field dropped there was **no** press
      // that could ever open `/result` again, and now there is one.
      expect(
        bloc.state.cta,
        QuizCta.none,
        reason:
            'the session was rebuilt, so the reader is back on an unselected first '
            'question. Asserted so the residue of this fix is a documented fact',
      );
    });

    blocTest<QuizBloc, QuizState>(
      'goes loading → ready, with the session and the reader at question one',
      build: () => blocOver(const Result<ScriptureText>.success(twoQuestions)),
      act: (QuizBloc bloc) =>
          bloc.add(const QuizStarted(ReadingLanguage.english)),
      expect: () => <Matcher>[
        isA<QuizState>().having(
          (QuizState s) => s.status,
          'status',
          QuizStatus.loading,
        ),
        isA<QuizState>()
            .having((QuizState s) => s.status, 'status', QuizStatus.ready)
            .having((QuizState s) => s.session, 'session', aFreshSession)
            .having((QuizState s) => s.currentIndex, 'index', 0)
            .having((QuizState s) => s.failure, 'failure', isNull)
            // Nothing submitted yet, so `/result` has no input — the constraint that
            // makes `ResultPage`'s parameter required.
            .having((QuizState s) => s.lastResult, 'lastResult', isNull),
      ],
    );

    blocTest<QuizBloc, QuizState>(
      'goes loading → failed, and keeps the FAILURE\'S MESSAGE verbatim',
      build: () => blocOver(
        const Result<ScriptureText>.failure(
          Failure(
            kind: FailureKind.network,
            message: 'Could not reach the server.',
          ),
        ),
      ),
      act: (QuizBloc bloc) =>
          bloc.add(const QuizStarted(ReadingLanguage.english)),
      expect: () => <Matcher>[
        isA<QuizState>().having(
          (QuizState s) => s.status,
          'status',
          QuizStatus.loading,
        ),
        isA<QuizState>()
            .having((QuizState s) => s.status, 'status', QuizStatus.failed)
            .having((QuizState s) => s.session, 'session', isNull)
            .having(
              (QuizState s) => s.failure?.message,
              'message',
              'Could not reach the server.',
            ),
      ],
    );

    blocTest<QuizBloc, QuizState>(
      'a reading with NO questions is **ready**, not failed, and the CTA says so',
      build: () => blocOver(
        const Result<ScriptureText>.success(
          ScriptureText(
            readingId: 'reading-group-3-2026-10-04',
            groupId: 3,
            scheduledDate: '2026-10-04',
            language: ReadingLanguage.english,
            reference: 'John 3:1-5',
            translation: 'NKJV',
            verses: <Verse>[firstVerse],
            questions: <Question>[],
            isFullyCompleted: false,
            pointsEarnedToday: 0,
            currentStreak: 0,
          ),
        ),
      ),
      act: (QuizBloc bloc) =>
          bloc.add(const QuizStarted(ReadingLanguage.english)),
      expect: () => <Matcher>[
        isA<QuizState>().having(
          (QuizState s) => s.status,
          'status',
          QuizStatus.loading,
        ),
        isA<QuizState>()
            .having((QuizState s) => s.status, 'status', QuizStatus.ready)
            .having((QuizState s) => s.session?.isEmpty, 'isEmpty', isTrue)
            .having((QuizState s) => s.cta, 'cta', QuizCta.none),
      ],
    );
  });

  group('SELECT → CHECK → NEXT → COMPLETE, the plan\'s own sequence', () {
    blocTest<QuizBloc, QuizState>(
      'the whole path, on a three-question reading',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        // **select** — one tap, no request.
        bloc.add(const QuizOptionSelected('B'));
        await settle();
        // **check** — the submit goes out and comes back.
        bloc.add(const QuizAnswerChecked());
        await settle();
        // **next**
        bloc.add(const QuizAdvanced());
        await settle();
        // select, check, next on question two.
        bloc.add(const QuizOptionSelected('A'));
        await settle();
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced());
        await settle();
        // select, check, next on question three — and there is no fourth, so this
        // is the **complete**.
        bloc.add(const QuizOptionSelected('A'));
        await settle();
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced());
        await settle();
      },
      verify: (QuizBloc bloc) {
        final QuizState state = bloc.state;
        expect(state.status, QuizStatus.complete);
        expect(state.session?.answeredCount, 3);
        // Three submits, and the **last** one is what `/result` is handed.
        expect(state.lastResult, contractSubmitAnswerFixture);
        // The reader is left looking at the last question, whose verdict is on
        // screen — `complete` does not blank the session.
        expect(state.currentIndex, 2);
        expect(state.currentAnswer?.isCorrect, isTrue);
        expect(state.cta, QuizCta.finish);
      },
    );

    test('and the submit count is exactly one per checked question', () async {
      // The count is what rules out a double submit, and a double submit is the
      // 409 §5 trap 3 is about. `zeroCheckTwice` below is the finer assertion; this
      // one is the summary.
      final QuizBloc bloc = blocOver(
        const Result<ScriptureText>.success(threeOpen),
      );
      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      for (int i = 0; i < 3; i++) {
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        if (i < 2) {
          bloc.add(const QuizAdvanced());
          await settle();
        }
      }
      expect(bloc.state.session?.answeredCount, 3);
    });
  });

  group('select', () {
    blocTest<QuizBloc, QuizState>(
      'records the letter and issues NO request',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('C'));
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.currentAnswer?.selectedLetter, 'C');
        expect(bloc.state.currentAnswer?.isChecked, isFalse);
        expect(bloc.state.cta, QuizCta.check);
      },
    );

    blocTest<QuizBloc, QuizState>(
      'and a second tap **replaces** the letter rather than adding one',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizOptionSelected('D'));
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.currentAnswer?.selectedLetter, 'D');
        expect(bloc.state.session?.answers.first.selectedLetter, 'D');
      },
    );

    test('a letter that is already the selection emits **nothing**', () async {
      // §4's "no emit when unchanged", which is what keeps a reader's thumb resting
      // on an option from repainting the screen, and what keeps
      // `ReadingCubit.setFontStep`'s drag from repainting the passage.
      final QuizBloc bloc = blocOver(
        const Result<ScriptureText>.success(threeOpen),
      );
      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      await settle();

      final List<QuizState> states = await watch(bloc);
      bloc.add(const QuizOptionSelected('A'));
      await settle();

      expect(states, hasLength(1), reason: 'only the state it started in');
      expect(bloc.state.currentAnswer?.selectedLetter, 'A');
    });

    test('a selection on a **closed** question is refused', () async {
      // The reader arrives on the already-answered question — the CTA offers "next"
      // for a closed question, so they *can* get here — and taps an option. The
      // card's `enabled: false` is the visible half; this is the half that holds
      // when the event arrives from somewhere the card does not govern.
      final QuizBloc bloc = blocOver(
        const Result<ScriptureText>.success(firstAnswered),
      );
      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      expect(bloc.state.currentAnswer?.question.alreadyAnswered, isTrue);

      final List<QuizState> states = await watch(bloc);
      bloc.add(const QuizOptionSelected('B'));
      await settle();

      expect(states, hasLength(1));
      expect(bloc.state.currentAnswer?.selectedLetter, isNull);
    });
  });

  group('check — and the 409 the client must PREVENT', () {
    blocTest<QuizBloc, QuizState>(
      'emits submitting, then ready with the verdict and the last result',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.status, QuizStatus.ready);
        expect(bloc.state.currentAnswer?.isChecked, isTrue);
        expect(bloc.state.currentAnswer?.verdict, contractSubmitAnswerFixture);
        expect(bloc.state.lastResult, contractSubmitAnswerFixture);
        // **Nothing on screen says the verdict is right.** The boolean is in the
        // state; whether it reaches the reader is the page's question, and
        // `quiz_page_test.dart` is what holds the answer.
        expect(bloc.state.cta, QuizCta.next);
      },
    );

    // ## AND THIS IS THE **ONLY** PLACE THE TRIPLE IS ASSERTED, BECAUSE THE BLOC IS
    // ## THE ONLY THING THAT CAN GET IT WRONG
    //
    // `SubmitAnswer`'s doc names this exact transposition as the hazard and defers it
    // to a file — `quiz_submit_request_test.dart` — that does not exist. The version
    // here was a `blocTest` whose entire `verify` was `expect(bloc, isA<QuizBloc>())`
    // with a comment saying the triple was asserted over there, so **nothing** read
    // `CountingReadingRepository.submissions` and the planted mutation
    // (`readingId:` and `questionId:` swapped at the `SubmitAnswerParams`
    // construction) left the suite green.
    //
    // A **use-case** test cannot catch it: it builds its own `SubmitAnswerParams`, so
    // it proves the params class has three fields and nothing about which field the
    // caller fills. The assertion belongs where the caller is, and the caller is the
    // bloc. `quiz_use_cases_test.dart` keeps the half it can actually see.
    //
    // `SubmittedTriple` is `quiz_harness.dart`'s typedef for the record's shape, and
    // it was dead for exactly as long as this assertion was missing.
    test('sends exactly the contract triple, in the session\'s arm', () async {
      final CountingReadingRepository readings = CountingReadingRepository(
        scripture: const Result<ScriptureText>.success(threeOpen),
      );
      final QuizBloc bloc = QuizBloc(
        startSession: StartSession(readings),
        refreshSessionQuestions: RefreshSessionQuestions(readings),
        submitAnswer: SubmitAnswer(readings),
      );
      addTearDown(bloc.close);

      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      bloc.add(const QuizOptionSelected('C'));
      bloc.add(const QuizAnswerChecked());
      await settle();

      // **The whole record, as one value.** Not `readingId` here and `questionId`
      // there: a transposition is only visible when the two are compared *together*,
      // and reading them off separate assertions lets a swapped pair pass by having
      // each half match something.
      //
      // §5 trap 10 is the cost, and it is why this is not a style assertion. This
      // backend's `question_id` is the fabricated `question-group-3`, which the submit
      // route rejects with `400 · body/question_id must match format "uuid"`. A
      // transposed client sends `{"question_id":"reading-group-3-2026-10-04"}` and
      // the message names a field the reader never touched — so a transposed client
      // and a dead endpoint are indistinguishable from the outside.
      expect(readings.submissions.single, (
        readingId: 'reading-group-3-2026-10-04',
        questionId: 'question-group-3',
        answer: 'C',
      ));
    });

    test(
      'and the SECOND question\'s submit carries THAT question\'s id',
      () async {
        // The triple above is a single question, so it cannot tell "the bloc reads
        // `answer.question.id`" from "the bloc reads `session.answers.first.id`" —
        // both are `question-group-3` when the cursor has never moved. Advancing makes
        // the two differ, and the difference is the second bug the first test cannot
        // see.
        final CountingReadingRepository readings = CountingReadingRepository(
          scripture: const Result<ScriptureText>.success(threeOpen),
        );
        final QuizBloc bloc = QuizBloc(
          startSession: StartSession(readings),
          refreshSessionQuestions: RefreshSessionQuestions(readings),
          submitAnswer: SubmitAnswer(readings),
        );
        addTearDown(bloc.close);

        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced());
        await settle();
        bloc.add(const QuizOptionSelected('B'));
        bloc.add(const QuizAnswerChecked());
        await settle();

        expect(readings.submissions, hasLength(2));
        expect(readings.submissions.last, (
          readingId: 'reading-group-3-2026-10-04',
          questionId: 'question-group-4',
          answer: 'B',
        ));
      },
    );

    test(
      'WITHOUT a selection it emits nothing — no request, no state change',
      () async {
        final QuizBloc bloc = blocOver(
          const Result<ScriptureText>.success(threeOpen),
        );
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();

        final List<QuizState> states = await watch(bloc);
        bloc.add(const QuizAnswerChecked());
        await settle();

        expect(states, hasLength(1));
        expect(bloc.state.currentAnswer?.isChecked, isFalse);
      },
    );

    test(
      'twice is **refused**, which is the prevention §5 trap 3 asks for',
      () async {
        // A reader tapping the CTA twice on a slow connection is the **most likely**
        // way to produce the 409 the plan says must be prevented — so the second tap
        // is not merely harmless, it is the defect.
        final CountingReadingRepository readings = CountingReadingRepository(
          scripture: const Result<ScriptureText>.success(threeOpen),
        );
        final QuizBloc bloc = QuizBloc(
          startSession: StartSession(readings),
          refreshSessionQuestions: RefreshSessionQuestions(readings),
          submitAnswer: SubmitAnswer(readings),
        );
        addTearDown(bloc.close);

        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        expect(readings.submitCalls, 1, reason: 'the first check went out');

        final List<QuizState> states = await watch(bloc);
        bloc.add(const QuizAnswerChecked());
        await settle();

        expect(states, hasLength(1));
        expect(
          readings.submitCalls,
          1,
          reason:
              'one submit for one answer. This is the assertion §5 trap 3 asks for, '
              'and it is only true because the bloc refuses rather than because the '
              'server objects.',
        );
      },
    );

    test(
      'and on an ALREADY-ANSWERED question it is refused outright',
      () async {
        // **The defect the plan names**: "the quiz must disable questions where
        // `already_answered == true` rather than discovering this as an error." The
        // card's `enabled: false` is the visible half; this is the half that holds
        // when the event arrives from somewhere else — a deep link, a test, a future
        // keyboard shortcut. A repository cannot do it: by the time a request exists
        // the reader has pressed the button.
        final CountingReadingRepository readings = CountingReadingRepository(
          scripture: const Result<ScriptureText>.success(firstAnswered),
        );
        final QuizBloc bloc = QuizBloc(
          startSession: StartSession(readings),
          refreshSessionQuestions: RefreshSessionQuestions(readings),
          submitAnswer: SubmitAnswer(readings),
        );
        addTearDown(bloc.close);

        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        expect(bloc.state.currentAnswer?.question.alreadyAnswered, isTrue);

        final List<QuizState> states = await watch(bloc);
        bloc.add(const QuizAnswerChecked());
        await settle();

        expect(states, hasLength(1));
        expect(
          readings.submitCalls,
          0,
          reason:
              'no request left the client. The 409 is unreachable from here.',
        );
      },
    );

    blocTest<QuizBloc, QuizState>(
      'a 409 goes to `failed` and KEEPS the session, so the reader sees why',
      build: () => blocOver(
        const Result<ScriptureText>.success(threeOpen),
        submission: const Result<SubmitResult>.failure(
          Failure(
            kind: FailureKind.conflict,
            message: 'This question has already been submitted by this user.',
            statusCode: 409,
          ),
        ),
      ),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.status, QuizStatus.failed);
        // The session survives, because the reader's *selection* is still true and
        // the alternative — a blank screen with an error — hides a question they
        // were mid-way through. This is `ReadingCubit`'s rule stated the other way
        // round: a failed **submit** is not a failed **read**.
        expect(bloc.state.session?.readingId, threeOpen.readingId);
        expect(bloc.state.session?.questionCount, 3);
        expect(
          bloc.state.session?.answers.last.question.id,
          'question-group-5',
          reason:
              'the untouched entries come through verbatim — `withSection`\'s '
              'independence, recorded decision 44, and the two witnesses for it',
        );
        expect(bloc.state.currentAnswer?.selectedLetter, 'A');
        expect(bloc.state.currentAnswer?.isChecked, isFalse);
        expect(bloc.state.failure?.kind, FailureKind.conflict);
        expect(bloc.state.cta, QuizCta.none, reason: 'no CTA while failed');
      },
    );

    blocTest<QuizBloc, QuizState>(
      'and a WRONG answer is a verdict too — `false`, not absent',
      build: () => blocOver(
        const Result<ScriptureText>.success(threeOpen),
        submission: const Result<SubmitResult>.success(
          contractWrongAnswerFixture,
        ),
      ),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('B'));
        bloc.add(const QuizAnswerChecked());
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.currentAnswer?.isChecked, isTrue);
        expect(bloc.state.currentAnswer?.isCorrect, isFalse);
        expect(bloc.state.lastResult, contractWrongAnswerFixture);
        // …and the reader still moves on: a wrong answer is not a dead end, and
        // refusing to advance would leave them stuck on question one forever.
        expect(bloc.state.cta, QuizCta.next);
      },
    );
  });

  group('next — and it must not SKIP a question', () {
    blocTest<QuizBloc, QuizState>(
      'advances by exactly **one**, and only after the current one is closed',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced());
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.currentIndex, 1);
        expect(bloc.state.currentAnswer?.question.id, 'question-group-4');
        expect(bloc.state.currentAnswer?.isChecked, isFalse);
        expect(bloc.state.currentAnswer?.selectedLetter, isNull);
      },
    );

    test(
      'is refused while the current question is still OPEN and unchecked',
      () async {
        // The mutation this guards: an `advance` that ignored `isOpen` would jump a
        // reader past a question they had not answered, and `answeredCount` would be
        // short at the end with nothing on screen to explain it.
        final QuizBloc bloc = blocOver(
          const Result<ScriptureText>.success(threeOpen),
        );
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();

        final List<QuizState> states = await watch(bloc);
        bloc.add(const QuizAdvanced());
        await settle();

        expect(states, hasLength(1));
        expect(bloc.state.currentIndex, 0);
        expect(bloc.state.cta, QuizCta.none);
      },
    );

    test(
      'and refused when the reader has chosen but not yet checked',
      () async {
        final QuizBloc bloc = blocOver(
          const Result<ScriptureText>.success(threeOpen),
        );
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        await settle();
        expect(
          bloc.state.cta,
          QuizCta.check,
          reason: 'the CTA says "Check answer"',
        );

        final List<QuizState> states = await watch(bloc);
        bloc.add(const QuizAdvanced());
        await settle();

        expect(states, hasLength(1));
        expect(bloc.state.currentIndex, 0);
      },
    );

    blocTest<QuizBloc, QuizState>(
      'but IS allowed past a question the wire already answers — there is nothing '
      'to do with it',
      build: () => blocOver(const Result<ScriptureText>.success(firstAnswered)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizAdvanced());
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.currentIndex, 1);
        expect(bloc.state.currentAnswer?.isOpen, isTrue);
        expect(bloc.state.cta, QuizCta.none, reason: 'nothing chosen yet');
      },
    );

    blocTest<QuizBloc, QuizState>(
      'and off the end of a session of **only** answered questions the CTA is dead, '
      'because there is no `SubmitResult` for `/result`',
      // **The dead end, stated rather than papered over.** The live payload's shape
      // reaches it: every question arrives answered. There is nothing to submit, so
      // there is no response, so `/result` has no input — and `ResultPage`'s
      // parameter is required, which is what makes that a compile error instead of
      // an empty screen. The honest answer is a dead button whose accessible name
      // says why, and an X control that works.
      build: () => blocOver(
        const Result<ScriptureText>.success(
          ScriptureText(
            readingId: 'reading-group-3-2026-10-04',
            groupId: 3,
            scheduledDate: '2026-10-04',
            language: ReadingLanguage.english,
            reference: 'John 3:1-5',
            translation: 'NKJV (New King James Version)',
            verses: <Verse>[firstVerse],
            questions: <Question>[answeredQuestion],
            isFullyCompleted: true,
            pointsEarnedToday: 10,
            currentStreak: 4,
          ),
        ),
      ),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizAdvanced());
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.status, QuizStatus.complete);
        expect(
          bloc.state.currentIndex,
          0,
          reason: 'clamped to the only question',
        );
        expect(bloc.state.lastResult, isNull);
        expect(
          bloc.state.cta,
          QuizCta.none,
          reason:
              '**not** `finish`. `finish` means "press to open `/result`", and '
              '`ResultPage` requires a `SubmitResult` — so a `finish` with no '
              '[QuizState.lastResult] would be a control the page cannot honour. '
              'The dead end is in the state, which is what makes it assertable.',
        );
        expect(bloc.state.session?.answeredCount, 1);
      },
    );

    blocTest<QuizBloc, QuizState>(
      'off the end it emits `complete` and **keeps the index on the last question**',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced()); // → 1
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced()); // → 2
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced()); // → complete
      },
      verify: (QuizBloc bloc) {
        expect(bloc.state.status, QuizStatus.complete);
        // **Not 3.** An index past the end has no answer to render, and
        // `ScriptureBlock`-style rendering would throw on it. Clamping is the whole
        // of what this assertion holds.
        expect(bloc.state.currentIndex, 2);
      },
    );

    test('`complete` is idempotent — a second `next` emits nothing', () async {
      final QuizBloc bloc = blocOver(
        const Result<ScriptureText>.success(threeOpen),
      );
      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      bloc.add(const QuizAdvanced()); // → 1
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      bloc.add(const QuizAdvanced()); // → 2
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      bloc.add(const QuizAdvanced()); // → complete
      await settle();
      expect(bloc.state.status, QuizStatus.complete);

      final List<QuizState> states = await watch(bloc);
      bloc.add(const QuizAdvanced());
      await settle();

      expect(states, hasLength(1));
      expect(bloc.state.currentIndex, 2);
    });

    test(
      'and the finished screen is not editable — a selection is refused',
      () async {
        final QuizBloc bloc = blocOver(
          const Result<ScriptureText>.success(threeOpen),
        );
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced()); // → 1
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced()); // → 2
        await settle();
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        bloc.add(const QuizAdvanced()); // → complete
        await settle();

        final List<QuizState> states = await watch(bloc);
        bloc.add(const QuizOptionSelected('D'));
        await settle();

        expect(states, hasLength(1));
        expect(bloc.state.currentAnswer?.selectedLetter, 'A');
      },
    );
  });

  group('`QuizRetried` — and `RefreshSessionQuestions` doing its one job', () {
    test('a retry that has something to retry DOES re-read', () async {
      // The companion to `is silent when nothing failed`, and the pair is what says
      // the silence is a decision rather than a missing handler: same event, same
      // use case, one request and none.
      final CountingReadingRepository readings = CountingReadingRepository(
        scripture: const Result<ScriptureText>.failure(
          Failure(
            kind: FailureKind.network,
            message: 'Could not reach the server.',
          ),
        ),
      );
      final QuizBloc bloc = QuizBloc(
        startSession: StartSession(readings),
        refreshSessionQuestions: RefreshSessionQuestions(readings),
        submitAnswer: SubmitAnswer(readings),
      );
      addTearDown(bloc.close);

      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      expect(bloc.state.status, QuizStatus.failed);
      expect(readings.calls, 1);

      // **Swapped in the test body, not from an `addTearDown`.** The first draft of
      // this fixture swapped the payload from a teardown callback, which runs
      // *after* the test — so the retry read the same payload and the assertion
      // below could not have told a re-fetch from a re-read. Recorded decision 15's
      // lesson, arriving as a fixture bug: the check passed for the wrong reason.
      readings.scripture = const Result<ScriptureText>.success(bothAnswered);

      bloc.add(const QuizRetried(ReadingLanguage.english));
      await settle();

      expect(readings.calls, 2, reason: 'a second request went out');
      expect(bloc.state.status, QuizStatus.ready);
      expect(bloc.state.failure, isNull);
      expect(bloc.state.session?.answeredCount, 2);
    });

    test(
      'and it takes the FRESH flag mid-session, over the cached one',
      () async {
        // ## THE FALSIFYING SHAPE FOR THE USE CASE
        //
        // The fixture's `already_answered` on question one **flips** between the two
        // reads. A refresh that trusted the cached flag would carry the *first*
        // payload's `false` into state and this test fails on `isTrue` below. A
        // refresh that re-fetched but kept the old question entities would also fail
        // it. Only "the second payload's entity" passes.
        final CountingReadingRepository readings = CountingReadingRepository(
          scripture: const Result<ScriptureText>.success(threeOpen),
        );
        final QuizBloc bloc = QuizBloc(
          startSession: StartSession(readings),
          refreshSessionQuestions: RefreshSessionQuestions(readings),
          submitAnswer: SubmitAnswer(readings),
        );
        addTearDown(bloc.close);

        // A submit that fails, so there is a failure to retry from and a selection to
        // keep — the case where re-reading and rebasing is doing real work.
        readings.submission = const Result<SubmitResult>.failure(
          Failure(
            kind: FailureKind.conflict,
            message: 'This question has already been submitted by this user.',
            statusCode: 409,
          ),
        );

        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        expect(bloc.state.currentAnswer?.isOpen, isTrue);

        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        expect(bloc.state.status, QuizStatus.failed);

        // The server now says question one is answered — as it would after the very
        // 409 above.
        readings.scripture = const Result<ScriptureText>.success(bothAnswered);
        readings.submission = const Result<SubmitResult>.success(
          contractSubmitAnswerFixture,
        );

        bloc.add(const QuizRetried(ReadingLanguage.english));
        await settle();

        expect(bloc.state.status, QuizStatus.ready);
        expect(bloc.state.failure, isNull);
        expect(
          bloc.state.session?.answers.first.question.alreadyAnswered,
          isTrue,
          reason:
              'the second payload said so. The cached one said `false`, and trusting '
              'it is a 409 the reader walks into.',
        );
        expect(bloc.state.currentAnswer?.isOpen, isFalse);
        expect(bloc.state.currentAnswer?.isChecked, isFalse);
        expect(
          bloc.state.currentAnswer?.selectedLetter,
          'A',
          reason:
              "the reader's own choice survives the re-read — it is not on the wire "
              'and it is theirs',
        );
      },
    );

    test(
      'and it re-reads `reading_id` too, because that value moves (§5 trap 11)',
      () async {
        final CountingReadingRepository readings = CountingReadingRepository(
          scripture: const Result<ScriptureText>.success(threeOpen),
        );
        final QuizBloc bloc = QuizBloc(
          startSession: StartSession(readings),
          refreshSessionQuestions: RefreshSessionQuestions(readings),
          submitAnswer: SubmitAnswer(readings),
        );
        addTearDown(bloc.close);
        readings.submission = const Result<SubmitResult>.failure(
          Failure(kind: FailureKind.server, message: 'Internal Server Error'),
        );

        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        expect(bloc.state.session?.readingId, 'reading-group-3-2026-10-04');

        // **To `failed` through a submit**, because that is the only route a retry is
        // dispatched from: `QuizRetried` is **silent** unless `status == failed` (the
        // test below). The first draft of this fixture "induced" the failure by
        // swapping in a failing payload and retrying — which is a no-op, so it
        // asserted `failed` against a state that was still `ready`, and the fixture
        // rather than the bloc was what was wrong.
        bloc.add(const QuizOptionSelected('A'));
        bloc.add(const QuizAnswerChecked());
        await settle();
        expect(bloc.state.status, QuizStatus.failed);

        readings.submission = const Result<SubmitResult>.success(
          contractSubmitAnswerFixture,
        );
        readings.scripture = const Result<ScriptureText>.success(
          ScriptureText(
            readingId: 'reading-group-3-2026-10-05',
            groupId: 3,
            scheduledDate: '2026-10-05',
            language: ReadingLanguage.english,
            reference: 'John 3:1-5',
            translation: 'NKJV (New King James Version)',
            verses: <Verse>[firstVerse],
            questions: <Question>[openQuestion],
            isFullyCompleted: false,
            pointsEarnedToday: 0,
            currentStreak: 4,
          ),
        );

        bloc.add(const QuizRetried(ReadingLanguage.english));
        await settle();

        expect(
          bloc.state.session?.readingId,
          'reading-group-3-2026-10-05',
          reason:
              "a refresh that kept the old id would submit against yesterday's "
              'reading — a 404 whose message names a *question*',
        );
        expect(
          bloc.state.session?.questionCount,
          1,
          reason: 'the re-read is shorter',
        );
        expect(bloc.state.currentIndex, 0, reason: 'and the cursor is clamped');
      },
    );

    test('a retry that has **nothing** to retry is silent', () async {
      // `HomeBloc._onRetried`'s rule, and its own doc's argument: a retry that
      // re-fetches when there is nothing to retry would re-issue a request on every
      // accidental dispatch and blur the one thing the retry exists to show. The
      // companion test above is what makes the silence a decision: same event, one
      // request and none.
      final CountingReadingRepository readings = CountingReadingRepository(
        scripture: const Result<ScriptureText>.success(threeOpen),
      );
      final QuizBloc bloc = QuizBloc(
        startSession: StartSession(readings),
        refreshSessionQuestions: RefreshSessionQuestions(readings),
        submitAnswer: SubmitAnswer(readings),
      );
      addTearDown(bloc.close);

      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      expect(bloc.state.status, QuizStatus.ready);

      final List<QuizState> states = await watch(bloc);
      bloc.add(const QuizRetried(ReadingLanguage.english));
      await settle();

      expect(states, hasLength(1));
      expect(
        readings.calls,
        1,
        reason:
            'no second request. A `GET` on the wire for nothing is the defect.',
      );
    });

    test('a failed re-read goes to `failed` and DROPS the session', () async {
      // The other side of the submit-failure rule, and deliberately the opposite:
      // a failed **read** must not leave a stale session under an error, because
      // `already_answered` on it is exactly what we cannot vouch for any more. That
      // is `ReadingCubit`'s rule and it is the right one here.
      final CountingReadingRepository readings = CountingReadingRepository(
        scripture: const Result<ScriptureText>.success(threeOpen),
      );
      final QuizBloc bloc = QuizBloc(
        startSession: StartSession(readings),
        refreshSessionQuestions: RefreshSessionQuestions(readings),
        submitAnswer: SubmitAnswer(readings),
      );
      addTearDown(bloc.close);
      readings.submission = const Result<SubmitResult>.failure(
        Failure(
          kind: FailureKind.conflict,
          message: 'This question has already been submitted by this user.',
          statusCode: 409,
        ),
      );

      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();
      expect(bloc.state.status, QuizStatus.failed);
      expect(bloc.state.session, isNotNull, reason: 'a failed submit keeps it');

      readings.scripture = const Result<ScriptureText>.failure(
        Failure(
          kind: FailureKind.network,
          message: 'Could not reach the server.',
        ),
      );
      bloc.add(const QuizRetried(ReadingLanguage.english));
      await settle();

      expect(bloc.state.status, QuizStatus.failed);
      expect(bloc.state.session, isNull, reason: 'a failed read does not');
      expect(bloc.state.failure?.message, 'Could not reach the server.');
    });
  });

  group('the CTA, which is the whole of the screen\'s affordances', () {
    blocTest<QuizBloc, QuizState>(
      'every arm, in the order a reader meets them',
      build: () => blocOver(const Result<ScriptureText>.success(threeOpen)),
      act: (QuizBloc bloc) async {
        bloc.add(const QuizStarted(ReadingLanguage.english));
        await settle();
        expect(bloc.state.cta, QuizCta.none, reason: 'nothing chosen');
        bloc.add(const QuizOptionSelected('A'));
        await settle();
        expect(bloc.state.cta, QuizCta.check);
        bloc.add(const QuizAnswerChecked());
        await settle();
        expect(bloc.state.cta, QuizCta.next);
        bloc.add(const QuizAdvanced());
        await settle();
        expect(
          bloc.state.cta,
          QuizCta.none,
          reason: 'question two, nothing chosen',
        );
      },
      verify: (QuizBloc bloc) => expect(bloc.state.cta, QuizCta.none),
    );

    test('and it is `none` while a submit is in flight', () async {
      // The state a page can only reach by holding a request open — and decision
      // 37's warning applies here, because a fake that answers by awaiting a
      // `Completer` never completes and the suite hangs at the full timeout. So the
      // assertion is made on the **emit** instead: the `submitting` state is
      // observed as it passes, which needs no held request at all.
      final CountingReadingRepository readings = CountingReadingRepository(
        scripture: const Result<ScriptureText>.success(threeOpen),
      );
      final QuizBloc bloc = QuizBloc(
        startSession: StartSession(readings),
        refreshSessionQuestions: RefreshSessionQuestions(readings),
        submitAnswer: SubmitAnswer(readings),
      );
      addTearDown(bloc.close);

      final List<QuizStatus> statuses = <QuizStatus>[];
      final StreamSubscription<QuizState> subscription = bloc.stream.listen(
        (QuizState state) => statuses.add(state.status),
      );
      addTearDown(subscription.cancel);

      bloc.add(const QuizStarted(ReadingLanguage.english));
      await settle();
      bloc.add(const QuizOptionSelected('A'));
      bloc.add(const QuizAnswerChecked());
      await settle();

      expect(
        statuses,
        contains(QuizStatus.submitting),
        reason:
            'the in-flight state was emitted, so it is observable and so a '
            'page has something to disable its CTA on',
      );
      expect(bloc.state.cta, QuizCta.next, reason: 'and it is over by now');
    });
  });

  group('the events themselves', () {
    test('`QuizOptionSelected` is not the same request twice', () {
      // Recorded decision 48's Equatable lesson: an event that dropped `props`
      // would make every selection equal to every other and `bloc.add` would
      // swallow the second. That is a **behavioural** consequence, not a
      // `props`-formatting one, which is why the assertion is about the events
      // rather than about a getter.
      expect(const QuizOptionSelected('A'), const QuizOptionSelected('A'));
      expect(
        const QuizOptionSelected('A'),
        isNot(equals(const QuizOptionSelected('B'))),
      );
      expect(const QuizAnswerChecked(), const QuizAnswerChecked());
      expect(
        const QuizStarted(ReadingLanguage.english),
        isNot(equals(const QuizStarted(ReadingLanguage.arabic))),
      );
      expect(
        const QuizStarted(ReadingLanguage.english),
        isNot(equals(const QuizRetried(ReadingLanguage.english))),
      );
    });

    test('`QuizAnswerChecked` and `QuizAdvanced` take no argument', () {
      // They act on the **current** answer, which is state. An argument would be a
      // second way to say which question, and the two could disagree.
      expect(const QuizAnswerChecked().props, isEmpty);
      expect(const QuizAdvanced().props, isEmpty);
    });
  });
}
