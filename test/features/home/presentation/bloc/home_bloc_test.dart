import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/library_book.dart';
import 'package:evangelion/features/home/domain/library_catalogue_repository.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_last_light.dart';
import 'package:evangelion/features/home/domain/usecases/load_library_catalogue.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/home_harness.dart';

/// [HomeBloc] — red-first with `bloc_test` (AGENT_CONTEXT §6: every cubit).
///
/// ## FIVE SECTIONS, AND THE SHAPE THAT FALLS OUT OF THAT
///
/// `/` asks five questions: who is this, what is today's reading, how long is the
/// streak, where was the light last, and what does the library hold. Three of them
/// come from **four endpoints that fail independently**, and two of those four
/// disagree with each other about the same reader (§5), so they cannot be one
/// "loaded" flag: a single status would have to answer "is Home loaded?" with a
/// number, and any number it picked would be a reconciliation. So there are four
/// section statuses and one extra piece of information that is not a section at
/// all.
///
/// ## WHY THE STREAK IS **TWO** SECTIONS
///
/// Because `GET /streak/summary` and `GET /streak` are two requests
/// (`streak.routes.ts:1-9`, `:163-172`) and the redesign gave each its own surface:
/// the chip (`:516`) reads the summary's `current_streak` and the last-light card
/// (`:524`) reads `history[0]`. One status for both would make a chip that has a
/// number report `loading` because the card's thirty rows failed — a lie about a
/// request that succeeded.
///
/// ## WHY THE SESSION HAS NO ERROR SURFACE
///
/// Because `AuthRepository.getCurrentSession` failing is **unreachable in
/// production**, and a status for it would be a branch nothing can fire:
/// `/login` is the only unguarded route and `/` is behind `AuthGuard`, which
/// redirects on `AuthStatus.isAuthenticated`, which reads `AuthBloc.state` — the
/// same repository this bloc asks. So the port's failure arm is real code and the
/// UI has no error surface for it; what it produces is **no name**, and the
/// greeting says `peace` alone. `AuthBloc`'s `_onSignedOut` takes the same position
/// on the same reasoning, and says so.
///
/// The branch is still tested (from a test, where it *is* reachable), because a
/// test is one of the two places it can be reached from and "no test reaches it" is
/// not the same claim as "nothing reaches it".
///
/// ## AND WHY THE LIBRARY'S FAILED STATE IS ALSO UNREACHABLE, AND ALSO TESTED
///
/// `LibraryCatalogueRepositoryImpl` returns a literal list, so
/// `catalogueStatus: failed` cannot happen in production — decision 26's shape
/// exactly, and the same answer: the branch is real code the port promises, so it is
/// written and reached from a fake. Two unreachable-but-tested arms in one file is
/// a pattern, and saying so here is cheaper than a reader discovering it twice.
///
/// ## THE CLOCK IS INJECTED
///
/// `HomeBloc` takes a `DateTime Function()`. Without it the greeting's
/// time-of-day could only be tested in whatever hour the suite happens to run in,
/// and the afternoon and vigil branches would ship unexercised. `AuthBloc`'s
/// fixtures use `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)` for the same
/// kind of reason.
class MockReadingRepository extends Mock implements ReadingRepository {}

class MockStreakRepository extends Mock implements StreakRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLibraryCatalogueRepository extends Mock
    implements LibraryCatalogueRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(ReadingLanguage.english);
  });
  late MockReadingRepository readings;
  late MockStreakRepository streaks;
  late MockAuthRepository auth;
  late MockLibraryCatalogueRepository catalogue;

  // 09:30 local, so [GreetingPeriod.morning].
  DateTime clock() => DateTime(2026, 10, 3, 9, 30);

  const TodayReading liveReading = TodayReading(
    readingId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    groupId: 3,
    scheduledDate: '2026-10-03',
    language: ReadingLanguage.english,
    reference: 'John 3:1-5',
    translation: 'NKJV (New King James Version)',
    verseCount: 5,
    firstVerseText: 'There was a man of the Pharisees',
    questionCount: 1,
    answeredQuestionCount: 1,
    isFullyCompleted: true,
    pointsEarnedToday: 10,
    currentStreak: 4,
  );

  // **Deliberately contradictory with `liveReading`**: streak `0` where the
  // reading says `4`. See `streak_summary.dart`.
  const StreakSummary liveStreak = StreakSummary(
    currentStreak: 0,
    longestStreak: 6,
    lastCompletedDate: '2026-09-29',
    todayStatus: StreakTodayStatus.pending,
    todayCompleted: false,
    todayScheduled: true,
    nextMilestone: 3,
    daysToMilestone: 3,
  );

  /// The most recent scheduled day, and the **only** row: one is enough to reach
  /// `history[0]` and one more would only add a second card's worth of text.
  const List<StreakHistoryEntry> liveHistory = <StreakHistoryEntry>[
    liveStreakHistoryEntry,
  ];

  /// The shipped catalogue, read from the data source that holds it.
  final List<LibraryBook> liveCatalogueBooks = liveCatalogue;

  final AuthSession session = AuthSession(
    userId: '11111111-1111-1111-1111-111111111111',
    email: 'david.mina@evangelion.app',
    displayName: 'David Mina',
    initials: 'DM',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  const Failure networkFailure = Failure(
    kind: FailureKind.network,
    message: 'Could not reach the server.',
  );
  const Failure serializationFailure = Failure(
    kind: FailureKind.serialization,
    message: "Could not read today's reading: `verses` is absent",
  );

  /// The bloc production builds: real use cases over mocked ports.
  HomeBloc build() => HomeBloc(
    loadTodayReading: LoadTodayReading(readings),
    loadStreakSummary: LoadStreakSummary(streaks),
    loadLastLight: LoadLastLight(streaks),
    loadLibraryCatalogue: LoadLibraryCatalogue(catalogue),
    getReaderSession: GetReaderSession(auth),
    now: clock,
  );

  setUp(() {
    readings = MockReadingRepository();
    streaks = MockStreakRepository();
    auth = MockAuthRepository();
    catalogue = MockLibraryCatalogueRepository();

    when(() => readings.today(language: any(named: 'language')))
        .thenAnswer((_) async => Result<TodayReading>.of(liveReading));
    when(
      streaks.summary,
    ).thenAnswer((_) async => const Right<Failure, StreakSummary>(liveStreak));
    when(streaks.history).thenAnswer(
      (_) async => const Right<Failure, List<StreakHistoryEntry>>(liveHistory),
    );
    when(auth.getCurrentSession)
        .thenAnswer((_) async => Result<AuthSession>.of(session));
    when(
      catalogue.books,
    ).thenAnswer((_) async => Result<List<LibraryBook>>.of(liveCatalogueBooks));
  });

  group('before anything has been asked', () {
    blocTest<HomeBloc, HomeState>(
      'every section is loading and no greeting is on screen yet',
      build: build,
      verify: (HomeBloc bloc) {
        expect(bloc.state.readingStatus, HomeSectionStatus.loading);
        expect(bloc.state.streakStatus, HomeSectionStatus.loading);
        expect(bloc.state.lastLightStatus, HomeSectionStatus.loading);
        expect(bloc.state.catalogueStatus, HomeSectionStatus.loading);
        // **Null, not a default.** The redesign's word is `night vigil` on the
        // clock's other side, and a non-nullable default would paint a greeting
        // before any clock has been read — a hard-coded value for exactly as long
        // as it takes `HomeStarted` to reach its first emit.
        expect(bloc.state.greetingPeriod, isNull);
        expect(bloc.state.readerName, isNull);
        expect(bloc.state.readerInitials, isNull);
      },
    );
  });

  group('HomeStarted — the successful launch', () {
    blocTest<HomeBloc, HomeState>(
      'emits the greeting first, then the five answers in a fixed order',
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      expect: () => <HomeState>[
        // 1. The greeting, before any network. Reading it from the clock here
        //    rather than in the widget is what lets `greeting_period_test.dart`
        //    reach all 24 hours.
        const HomeState(greetingPeriod: GreetingPeriod.morning),
        // 2. The reader, from the session — no error surface, see the file doc.
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
        ),
        // 3. The reading, and its `is_fully_completed` — the *reading* endpoint's
        //    answer, not the streak endpoint's `today_completed`.
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
        ),
        // 4. The streak chip's summary, and its `currentStreak: 0` — **not**
        //    reconciled with the reading's `4`.
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
        ),
        // 5. The last-light card's pointer, from `history[0]` of the **other**
        //    endpoint. The reference is the server's and is carried verbatim.
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
          lastLightStatus: HomeSectionStatus.ready,
          lastLight: liveStreakHistoryEntry,
        ),
        // 6. The carousel's books, **last**. `_onStarted` starts all five requests
        //    before its first `await` and then awaits them in a fixed order, so the
        //    emission order is a property of that method rather than of which future
        //    happens to resolve first. A sixth frame appearing here is the carousel
        //    being requested; a sixth frame NOT appearing would mean it silently
        //    stopped being.
        HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
          lastLightStatus: HomeSectionStatus.ready,
          lastLight: liveStreakHistoryEntry,
          catalogueStatus: HomeSectionStatus.ready,
          catalogue: liveCatalogueBooks,
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'holds both contradictory numbers without reconciling them',
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        // The measured inconsistency (`HEAD = 4a1c834`), restated as an assertion
        // on the bloc: the reading says the streak is 4 and completed, the summary
        // says 0 and pending. Both survive into the state untouched. The
        // *surfaces* are asserted in `home_page_test.dart`; this is where the
        // numbers are shown to have survived the bloc.
        expect(bloc.state.reading!.currentStreak, 4);
        expect(bloc.state.reading!.isFullyCompleted, isTrue);
        expect(bloc.state.streak!.currentStreak, 0);
        expect(bloc.state.streak!.todayStatus, StreakTodayStatus.pending);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'takes the card\'s pointer from `history[0]` and not from the newest row',
      setUp: () {
        // **Two rows, the second one later.** `streak.service.ts:88-96` sorts
        // `scheduled_date DESC`, so index 0 is the most recent scheduled day — and
        // a use case that picked by date, or took `last`, would answer a different
        // question. This is the assertion that pins "index 0" as the rule.
        when(streaks.history).thenAnswer(
          (_) async => const Right<Failure, List<StreakHistoryEntry>>(
            <StreakHistoryEntry>[
              StreakHistoryEntry(
                readingId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
                scheduledDate: '2026-10-03',
                bookNumber: 19,
                bookNameEn: 'Psalms',
                bookNameAr: 'المزامير',
                referenceEn: 'Psalms 23:1-6',
                referenceAr: 'المزمور 23: 1-6',
                totalQuestions: 2,
                answeredQuestions: 2,
                correctAnswers: 2,
                pointsEarned: 20,
                isCompleted: true,
              ),
              liveStreakHistoryEntry,
            ],
          ),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.lastLight!.referenceEn, 'Psalms 23:1-6');
        expect(bloc.state.lastLight!.bookNumber, 19);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'an EMPTY history is `ready` with no pointer, not a failure',
      setUp: () {
        when(streaks.history).thenAnswer(
          (_) async => const Right<Failure, List<StreakHistoryEntry>>(
            <StreakHistoryEntry>[],
          ),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        // **The prototype's own empty state** (`redesign.html:1192-1197`): the
        // cohort has no scheduled reading on file, the card says so in words and
        // drops its tap. A `failed` here would put a retry on screen for a request
        // that succeeded.
        expect(bloc.state.lastLightStatus, HomeSectionStatus.ready);
        expect(bloc.state.lastLight, isNull);
        expect(bloc.state.lastLightFailure, isNull);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'asks the reading port for the language the event carries',
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.arabic)),
      verify: (_) {
        verify(() => readings.today(language: ReadingLanguage.arabic))
            .called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'and the greeting is read from the injected clock, once',
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (_) {},
      // `HomeStarted` is dispatched once; a second read of the clock would be a
      // second chance for the greeting to change under the reader.
      expect: () => hasLength(6),
    );
  });

  group(
    'the session has no error surface, because it cannot fail in production',
    () {
      blocTest<HomeBloc, HomeState>(
        'a missing session yields no name and no failure',
        setUp: () {
          when(auth.getCurrentSession).thenAnswer(
            (_) async => const Left<Failure, AuthSession>(
              Failure(
                kind: FailureKind.unauthorized,
                message: 'Not signed in.',
              ),
            ),
          );
        },
        build: build,
        act: (HomeBloc bloc) =>
            bloc.add(const HomeStarted(ReadingLanguage.english)),
        verify: (HomeBloc bloc) {
          expect(bloc.state.readerName, isNull);
          expect(bloc.state.readerInitials, isNull);
          // `ready`, not `failed`: there is nothing to retry and nothing to say. The
          // greeting says `peace` alone, which is the whole of the degraded
          // rendering.
          expect(bloc.state.readerStatus, HomeSectionStatus.ready);
          // And the other four sections are unaffected — a missing session is not a
          // broken screen.
          expect(bloc.state.readingStatus, HomeSectionStatus.ready);
          expect(bloc.state.streakStatus, HomeSectionStatus.ready);
          expect(bloc.state.lastLightStatus, HomeSectionStatus.ready);
          expect(bloc.state.catalogueStatus, HomeSectionStatus.ready);
        },
        expect: () => hasLength(6),
      );
    },
  );

  group('one section fails', () {
    blocTest<HomeBloc, HomeState>(
      'a failed READING leaves the chip, the card and the carousel alone',
      setUp: () {
        when(() => readings.today(language: any(named: 'language'))).thenAnswer(
          (_) async => const Left<Failure, TodayReading>(serializationFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.readingStatus, HomeSectionStatus.failed);
        expect(bloc.state.reading, isNull);
        expect(bloc.state.readingFailure, serializationFailure);
        expect(bloc.state.streak!.currentStreak, 0);
        expect(bloc.state.lastLightStatus, HomeSectionStatus.ready);
        expect(bloc.state.catalogueStatus, HomeSectionStatus.ready);
        expect(bloc.state.catalogue!.length, liveCatalogueBooks.length);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a failed STREAK leaves the card, which is a different endpoint',
      setUp: () {
        when(streaks.summary).thenAnswer(
          (_) async => const Left<Failure, StreakSummary>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.streakStatus, HomeSectionStatus.failed);
        expect(bloc.state.streak, isNull);
        expect(bloc.state.streakFailure, networkFailure);
        // **The whole point of the second section**: `GET /streak` answered, so the
        // last-light card draws. A shared status would have blanked it.
        expect(bloc.state.lastLightStatus, HomeSectionStatus.ready);
        expect(bloc.state.lastLight, liveStreakHistoryEntry);
        expect(bloc.state.lastLightFailure, isNull);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a failed LAST LIGHT leaves the chip\'s number on screen',
      setUp: () {
        when(streaks.history).thenAnswer(
          (_) async =>
              const Left<Failure, List<StreakHistoryEntry>>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.lastLightStatus, HomeSectionStatus.failed);
        expect(bloc.state.lastLight, isNull);
        expect(bloc.state.lastLightFailure, networkFailure);
        // Phase 6's requirement, on the arm the redesign created: "a failed fetch
        // renders an error with a working retry **while the streak chip still
        // renders**".
        expect(bloc.state.streakStatus, HomeSectionStatus.ready);
        expect(bloc.state.streak!.currentStreak, 0);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a failed CATALOGUE empties the strip and keeps every other section',
      setUp: () {
        // **Unreachable in production** — the shipped adapter is a literal list —
        // and reachable here because the port promises a `Result`. The test is the
        // proof that the arm is written rather than inferred.
        when(catalogue.books).thenAnswer(
          (_) async => const Left<Failure, List<LibraryBook>>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.catalogueStatus, HomeSectionStatus.failed);
        expect(bloc.state.catalogue, isNull);
        expect(bloc.state.catalogueFailure, networkFailure);
        expect(bloc.state.readingStatus, HomeSectionStatus.ready);
        expect(bloc.state.streakStatus, HomeSectionStatus.ready);
        expect(bloc.state.lastLightStatus, HomeSectionStatus.ready);
      },
    );
  });

  group('HomeRetried re-fetches ONLY what failed', () {
    blocTest<HomeBloc, HomeState>(
      'a failed reading retries the reading and touches nothing else',
      setUp: () {
        when(() => readings.today(language: any(named: 'language'))).thenAnswer(
          (_) async => const Left<Failure, TodayReading>(serializationFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) async {
        bloc.add(const HomeStarted(ReadingLanguage.english));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const HomeRetried(ReadingLanguage.english));
      },
      verify: (_) {
        verify(() => readings.today(language: any(named: 'language')))
            .called(2);
        verify(streaks.summary).called(1);
        verify(streaks.history).called(1);
        verify(catalogue.books).called(1);
      },
      // Six frames for the launch, then **two** for the retry: the `withSection`
      // emit that moves the reading back to `loading`, and the answer. The other
      // sections are not re-emitted, which is the assertion with teeth — a retry
      // that re-issued everything would still end here and be wrong by three frames.
      expect: () => hasLength(8),
    );

    blocTest<HomeBloc, HomeState>(
      'a failed streak retries only the summary, and the card\'s rows are not re-read',
      setUp: () {
        when(streaks.summary).thenAnswer(
          (_) async => const Left<Failure, StreakSummary>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) async {
        bloc.add(const HomeStarted(ReadingLanguage.english));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const HomeRetried(ReadingLanguage.english));
      },
      verify: (_) {
        verify(streaks.summary).called(2);
        // **Thirty rows and a subquery each** (`streak.service.ts:98-112`) — the
        // cost the port's doc gives for keeping the two endpoints apart.
        verify(streaks.history).called(1);
        verify(() => readings.today(language: any(named: 'language')))
            .called(1);
        verify(catalogue.books).called(1);
      },
      expect: () => hasLength(8),
    );

    blocTest<HomeBloc, HomeState>(
      'a failed last light retries only `GET /streak`',
      setUp: () {
        when(streaks.history).thenAnswer(
          (_) async =>
              const Left<Failure, List<StreakHistoryEntry>>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) async {
        bloc.add(const HomeStarted(ReadingLanguage.english));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const HomeRetried(ReadingLanguage.english));
      },
      verify: (_) {
        verify(streaks.history).called(2);
        verify(streaks.summary).called(1);
        verify(() => readings.today(language: any(named: 'language')))
            .called(1);
        verify(catalogue.books).called(1);
      },
      expect: () => hasLength(8),
    );

    blocTest<HomeBloc, HomeState>(
      'a failed catalogue retries the catalogue and nothing else',
      setUp: () {
        when(catalogue.books).thenAnswer(
          (_) async => const Left<Failure, List<LibraryBook>>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) async {
        bloc.add(const HomeStarted(ReadingLanguage.english));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const HomeRetried(ReadingLanguage.english));
      },
      verify: (_) {
        verify(catalogue.books).called(2);
        verify(streaks.summary).called(1);
        verify(streaks.history).called(1);
        verify(() => readings.today(language: any(named: 'language')))
            .called(1);
      },
      expect: () => hasLength(8),
    );

    blocTest<HomeBloc, HomeState>(
      'a retry with nothing to retry emits NOTHING',
      build: build,
      act: (HomeBloc bloc) async {
        bloc.add(const HomeStarted(ReadingLanguage.english));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const HomeRetried(ReadingLanguage.english));
      },
      verify: (_) {
        // The silence is the assertion, and the four ports are the proof that it
        // was silence rather than a re-fetch nobody counted.
        verify(streaks.summary).called(1);
        verify(streaks.history).called(1);
        verify(catalogue.books).called(1);
        verify(() => readings.today(language: any(named: 'language')))
            .called(1);
      },
      expect: () => hasLength(6),
    );

    blocTest<HomeBloc, HomeState>(
      'and four failed sections retry in ONE intermediate frame, not four',
      setUp: () {
        when(() => readings.today(language: any(named: 'language'))).thenAnswer(
          (_) async => const Left<Failure, TodayReading>(serializationFailure),
        );
        when(streaks.summary).thenAnswer(
          (_) async => const Left<Failure, StreakSummary>(networkFailure),
        );
        when(streaks.history).thenAnswer(
          (_) async =>
              const Left<Failure, List<StreakHistoryEntry>>(networkFailure),
        );
        when(catalogue.books).thenAnswer(
          (_) async => const Left<Failure, List<LibraryBook>>(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) async {
        bloc.add(const HomeStarted(ReadingLanguage.english));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const HomeRetried(ReadingLanguage.english));
      },
      // Six for the launch, then **five** for the retry: one `withSection` emit
      // carrying all four sections back to `loading`, and four answers. Six would
      // mean the emit had been split per section, which is the flicker the single
      // emit exists to prevent.
      expect: () => hasLength(11),
    );
  });

  group('HomeState.withSection', () {
    const HomeState loaded = HomeState(
      readingStatus: HomeSectionStatus.failed,
      readingFailure: _serialization,
      streakStatus: HomeSectionStatus.ready,
      streak: liveStreak,
      lastLightStatus: HomeSectionStatus.ready,
      lastLight: liveStreakHistoryEntry,
      catalogueStatus: HomeSectionStatus.ready,
      catalogue: <LibraryBook>[],
      readerName: 'David Mina',
    );

    test('a section moving to failed keeps its failure and drops its data', () {
      final HomeState next = loaded.withSection(
        readingStatus: HomeSectionStatus.failed,
      );
      expect(next.readingFailure, _serialization);
      expect(next.reading, isNull);
    });

    test('a section moving back to loading drops the failure that put it there', () {
      // An `ErrorView` cannot offer a retry for a request that is open, so the
      // failure leaves with the status.
      final HomeState next = loaded.withSection(
        readingStatus: HomeSectionStatus.loading,
      );
      expect(next.readingFailure, isNull);
      expect(next.reading, isNull);
      expect(next.readingStatus, HomeSectionStatus.loading);
    });

    test('a section left alone keeps its data AND its failure', () {
      final HomeState next = loaded.withSection(
        streakStatus: HomeSectionStatus.loading,
      );
      expect(next.readingStatus, HomeSectionStatus.failed);
      expect(next.readingFailure, _serialization);
      // And the one that moved: its data went with it.
      expect(next.streakStatus, HomeSectionStatus.loading);
      expect(next.streak, isNull);
    });

    test('THE CATALOGUE SURVIVES A RETRY OF ANOTHER SECTION', () {
      // **This is the defect the fourth section used to carry.** The board card had
      // its own writer precisely because `withSection` re-derived only the reading
      // and streak — and the writer it *did* have was not called by a retry, so a
      // retry of the reading rebuilt a state with **no** `leaderboard` and left the
      // card spinning for ever behind a request that had succeeded. The suite said
      // "re-fetches only what failed" and passed; the screen had a spinner.
      //
      // With the card gone and the carousel in its place the same rule is now
      // structural: `withSection` derives every section it is asked about and
      // carries the rest, so there is no writer a retry can forget.
      final HomeState next = loaded.withSection(
        readingStatus: HomeSectionStatus.loading,
      );
      expect(next.catalogueStatus, HomeSectionStatus.ready);
      expect(next.lastLightStatus, HomeSectionStatus.ready);
      expect(next.lastLight, liveStreakHistoryEntry);
      expect(next.readerName, 'David Mina');
      expect(next.greetingPeriod, isNull);
    });

    test('withSection() with every parameter null is the identity', () {
      expect(loaded.withSection(), loaded);
    });
  });

  group('the events', () {
    test('HomeStarted and HomeRetried compare by language', () {
      expect(
        const HomeStarted(ReadingLanguage.english),
        const HomeStarted(ReadingLanguage.english),
      );
      expect(
        const HomeStarted(ReadingLanguage.english),
        isNot(const HomeStarted(ReadingLanguage.arabic)),
      );
      expect(
        const HomeRetried(ReadingLanguage.english),
        const HomeRetried(ReadingLanguage.english),
      );
    });

    test('a HomeCleared is neither a HomeStarted nor a HomeRetried', () {
      expect(
        const HomeCleared(),
        isNot(const HomeStarted(ReadingLanguage.english)),
      );
      expect(
        const HomeCleared(),
        isNot(const HomeRetried(ReadingLanguage.english)),
      );
    });
  });

  group('HomeCleared', () {
    test('empties the state back to the cold-launch one', () async {
      final HomeBloc bloc = build();

      bloc.add(const HomeStarted(ReadingLanguage.english));
      // **The catalogue, not the reading**, is the last of the five emits, so
      // waiting on it is waiting on all of them. `firstWhere(reading != null)`
      // returns on an earlier state and the premise below fails on `catalogue` —
      // measured, and worth naming because "wait for the thing I am asserting
      // about" is the obvious and wrong version of this line.
      await bloc.stream.firstWhere((HomeState s) => s.catalogue != null);

      // The premise: a reader's identity really is in there before the clear.
      expect(bloc.state.readerName, isNotNull);
      expect(bloc.state.readerInitials, isNotNull);
      expect(bloc.state.reading, isNotNull);
      expect(bloc.state.streak, isNotNull);
      expect(bloc.state.lastLight, isNotNull);
      expect(bloc.state.catalogue, isNotNull);

      bloc.add(const HomeCleared());
      await bloc.stream.firstWhere((HomeState s) => s == const HomeState());

      // **`const HomeState()`, not a partial clear.** `HomeState`'s doc argues that
      // a `String? = null` parameter cannot express "clear it", so every writer
      // builds the whole state; a partial clear would be the first writer here that
      // does not. The cold-launch state *is* the post-sign-out state, which is why
      // there is no second constructor to invent.
      expect(bloc.state, const HomeState());
      expect(bloc.state.readerName, isNull);
      expect(bloc.state.readerInitials, isNull);
      expect(bloc.state.reading, isNull);
      expect(bloc.state.streak, isNull);
      expect(bloc.state.lastLight, isNull);
      expect(bloc.state.catalogue, isNull);
      expect(
        bloc.state,
        const HomeState(),
        reason:
            'equality is the claim, and the generated `==` covers all fourteen '
            'fields, so an equality match cannot be hiding a field that was left '
            'behind',
      );
      await bloc.close();
    });

    test('and it is idempotent, because sign-out can arrive twice', () async {
      // **One clear is enough and the second emits nothing.** `const HomeState() ==
      // const HomeState()` is true and `emit` drops an equal state, so the second
      // clear produces no frame — which is what keeps `configureNavigation`'s two
      // calls (the dispatcher's and the guard's) from costing a rebuild.
      final HomeBloc bloc = build();
      addTearDown(bloc.close);
      bloc.add(const HomeStarted(ReadingLanguage.english));
      await bloc.stream.firstWhere((HomeState s) => s.catalogue != null);

      final List<HomeState> afterFirst = <HomeState>[];
      final StreamSubscription<HomeState> first = bloc.stream.listen(
        afterFirst.add,
      );
      bloc.add(const HomeCleared());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const HomeCleared());
      await Future<void>.delayed(Duration.zero);
      await first.cancel();

      expect(afterFirst, hasLength(1));
      expect(bloc.state, const HomeState());
    });
  });

  group('the constructor', () {
    test('needs every collaborator, so a half-wired bloc cannot be built', () {
      // Six required named parameters, and the failure is a **compile** error
      // rather than a null that arrives in a request. There is no test body to
      // write for this: the assertion is that this file compiles with six and
      // would not with five, which is the same claim `HomeState`'s doc makes about
      // `@Freezed(copyWith: false)`.
      expect(
        HomeBloc.new,
        isNotNull,
        reason: 'the constructor is only reachable with all six arguments',
      );
    });
  });
}

/// The failure [HomeState.withSection]'s group carries, declared once because a
/// `const Failure` is a value and this suite's whole subject is which fields move.
const Failure _serialization = Failure(
  kind: FailureKind.serialization,
  message: "Could not read today's reading: `verses` is absent",
);
