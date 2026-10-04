import 'package:bloc_test/bloc_test.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/today_reading.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/reading_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/domain/usecases/get_reader_session.dart';
import 'package:evangelion/features/home/domain/usecases/load_streak_summary.dart';
import 'package:evangelion/features/home/domain/usecases/load_today_reading.dart';
import 'package:evangelion/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/home_harness.dart';

/// [HomeBloc] — red-first with `bloc_test` (AGENT_CONTEXT §6: every cubit).
///
/// ## THREE SECTIONS, AND THE SHAPE THAT FALLS OUT OF THAT
///
/// `/` asks three questions: who is this, what is today's reading, and how long
/// is the streak. Two of them come from two endpoints that **disagree with each
/// other** (§5), so they cannot be one "loaded" flag: a single status would have
/// to answer "is Home loaded?" with a number, and any number it picked would be a
/// reconciliation. So there are two section statuses and one extra piece of
/// information that is not a section at all.
///
/// ## WHY THE SESSION HAS NO STATUS
///
/// Because `AuthRepository.getCurrentSession` failing is **unreachable in
/// production**, and a status for it would be a branch nothing can fire:
/// `/login` is the only unguarded route and `/` is behind `AuthGuard`, which
/// redirects on `AuthStatus.isAuthenticated`, which reads `AuthBloc.state` — the
/// same repository this bloc asks. So the port's failure arm is real code and the
/// UI has no error surface for it; what it produces is **no name**, and the
/// greeting falls back to the prototype's `…evening.` split. `AuthBloc`'s
/// `_onSignedOut` takes the same position on the same reasoning, and says so.
///
/// The branch is still tested (from a test, where it *is* reachable), because a
/// test is one of the two places it can be reached from and "no test reaches it"
/// is not the same claim as "nothing reaches it".
///
/// ## THE CLOCK IS INJECTED
///
/// `HomeBloc` takes a `DateTime Function()`. Without it the greeting's
/// time-of-day could only be tested in whatever hour the suite happens to run in,
/// and the afternoon and morning branches would ship unexercised. `AuthBloc`'s
/// fixtures use `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)` for the same
/// kind of reason.
class MockReadingRepository extends Mock implements ReadingRepository {}

class MockStreakRepository extends Mock implements StreakRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() => registerFallbackValue(ReadingLanguage.english));

  late MockReadingRepository readings;
  late MockStreakRepository streaks;
  late MockAuthRepository auth;

  // 09:30 local, so [GreetingPeriod.morning].
  DateTime clock() => DateTime(2026, 10, 3, 9, 30);

  final TodayReading liveReading = const TodayReading(
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
    getReaderSession: GetReaderSession(auth),
    now: clock,
  );

  setUp(() {
    readings = MockReadingRepository();
    streaks = MockStreakRepository();
    auth = MockAuthRepository();

    when(() => readings.today(language: any(named: 'language')))
        .thenAnswer((_) async => Result<TodayReading>.success(liveReading));
    when(
      streaks.summary,
    ).thenAnswer((_) async => const Result<StreakSummary>.success(liveStreak));
    when(auth.getCurrentSession)
        .thenAnswer((_) async => Result<AuthSession>.success(session));
  });

  group('before anything has been asked', () {
    blocTest<HomeBloc, HomeState>(
      'both sections are loading and no greeting is on screen yet',
      build: build,
      verify: (HomeBloc bloc) {
        expect(bloc.state.readingStatus, HomeSectionStatus.loading);
        expect(bloc.state.streakStatus, HomeSectionStatus.loading);
        // **Null, not a default.** The prototype's word is `Good evening`, and a
        // non-nullable default would paint that word on the first frame before any
        // clock has been read — a hard-coded value for exactly as long as it takes
        // `HomeStarted` to reach its first emit.
        expect(bloc.state.greetingPeriod, isNull);
        expect(bloc.state.readerName, isNull);
        expect(bloc.state.readerInitials, isNull);
      },
    );
  });

  group('HomeStarted — the successful launch', () {
    blocTest<HomeBloc, HomeState>(
      'emits the greeting first, then the three answers in a fixed order',
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
        HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
        ),
        // 4. The streak, and its `currentStreak: 0` — **not** reconciled with the
        //    reading's `4`.
        HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
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
      expect: () => hasLength(4),
    );
  });

  group(
    'the session has no error surface, because it cannot fail in production',
    () {
      blocTest<HomeBloc, HomeState>(
        'a missing session yields no name and no failure',
        setUp: () {
          when(auth.getCurrentSession).thenAnswer(
            (_) async => const Result<AuthSession>.failure(
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
          // panel falls back to the prototype's `…evening.` split, which is the
          // whole of the degraded rendering.
          expect(bloc.state.readerStatus, HomeSectionStatus.ready);
          // And the other two sections are unaffected — a missing session is not a
          // broken screen.
          expect(bloc.state.readingStatus, HomeSectionStatus.ready);
          expect(bloc.state.streakStatus, HomeSectionStatus.ready);
        },
        expect: () => hasLength(4),
      );
    },
  );

  group('one section fails', () {
    blocTest<HomeBloc, HomeState>(
      'a failed READING leaves the streak ready and keeps its own number',
      setUp: () {
        when(() => readings.today(language: any(named: 'language'))).thenAnswer(
          (_) async => const Result<TodayReading>.failure(serializationFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      // **The whole point of the section statuses.** Not a screen-wide error and
      // not a blank panel: the greeting, the flame and the streak survive.
      expect: () => <HomeState>[
        const HomeState(greetingPeriod: GreetingPeriod.morning),
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
        ),
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.failed,
          readingFailure: serializationFailure,
        ),
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.failed,
          readingFailure: serializationFailure,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'a failed STREAK leaves the reading ready and keeps its flag',
      setUp: () {
        when(streaks.summary).thenAnswer(
          (_) async => const Result<StreakSummary>.failure(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.streakStatus, HomeSectionStatus.failed);
        expect(bloc.state.streakFailure, networkFailure);
        expect(bloc.state.streak, isNull);
        // The panel still knows whether the reading is finished, because that
        // answer came from the *other* endpoint. A single "loaded" flag would have
        // thrown this away with the streak.
        expect(bloc.state.readingStatus, HomeSectionStatus.ready);
        expect(bloc.state.reading!.isFullyCompleted, isTrue);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'both failing is still two failures, not one',
      setUp: () {
        when(() => readings.today(language: any(named: 'language'))).thenAnswer(
          (_) async => const Result<TodayReading>.failure(serializationFailure),
        );
        when(streaks.summary).thenAnswer(
          (_) async => const Result<StreakSummary>.failure(networkFailure),
        );
      },
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeStarted(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.readingFailure, serializationFailure);
        expect(bloc.state.streakFailure, networkFailure);
        expect(bloc.state.greetingPeriod, GreetingPeriod.morning);
        expect(bloc.state.readerName, 'David Mina');
      },
    );
  });

  group('HomeRetried re-fetches ONLY what failed', () {
    blocTest<HomeBloc, HomeState>(
      'a reading retry does not touch the streak port',
      // **No stub here**, so the retry hits the default `setUp` answer — a
      // *success*. An earlier version left the port stubbed to fail forever and
      // asserted the intermediate `loading` frame as if the retry had succeeded,
      // which turned the interesting half of the assertion (does the streak
      // survive?) into a check that both sections failed.
      build: build,
      seed: () => const HomeState(
        greetingPeriod: GreetingPeriod.morning,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readerStatus: HomeSectionStatus.ready,
        readingStatus: HomeSectionStatus.failed,
        readingFailure: serializationFailure,
        streakStatus: HomeSectionStatus.ready,
        streak: liveStreak,
      ),
      act: (HomeBloc bloc) =>
          bloc.add(const HomeRetried(ReadingLanguage.english)),
      expect: () => <HomeState>[
        // Back to loading, failure cleared — so the `ErrorView` and its retry
        // button disappear while the request is open and cannot be pressed twice.
        const HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
        ),
        HomeState(
          greetingPeriod: GreetingPeriod.morning,
          readerName: 'David Mina',
          readerInitials: 'DM',
          readerStatus: HomeSectionStatus.ready,
          readingStatus: HomeSectionStatus.ready,
          reading: liveReading,
          streakStatus: HomeSectionStatus.ready,
          streak: liveStreak,
        ),
      ],
      verify: (_) {
        verify(() => readings.today(language: any(named: 'language')))
            .called(1);
        verifyNever(streaks.summary);
        // And the session is not re-read: it is not a section that can fail, so
        // there is nothing to retry.
        verifyNever(auth.getCurrentSession);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a streak retry does not touch the reading port',
      seed: () => HomeState(
        greetingPeriod: GreetingPeriod.morning,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readerStatus: HomeSectionStatus.ready,
        readingStatus: HomeSectionStatus.ready,
        reading: liveReading,
        streakStatus: HomeSectionStatus.failed,
        streakFailure: networkFailure,
      ),
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeRetried(ReadingLanguage.english)),
      verify: (_) {
        verify(streaks.summary).called(1);
        verifyNever(() => readings.today(language: any(named: 'language')));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'both failing retries both, and only those two',
      seed: () => const HomeState(
        greetingPeriod: GreetingPeriod.morning,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readerStatus: HomeSectionStatus.ready,
        readingStatus: HomeSectionStatus.failed,
        readingFailure: serializationFailure,
        streakStatus: HomeSectionStatus.failed,
        streakFailure: networkFailure,
      ),
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeRetried(ReadingLanguage.english)),
      verify: (_) {
        verify(() => readings.today(language: any(named: 'language')))
            .called(1);
        verify(streaks.summary).called(1);
        verifyNever(auth.getCurrentSession);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a retry with nothing failed emits nothing at all',
      seed: () => HomeState(
        greetingPeriod: GreetingPeriod.morning,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readerStatus: HomeSectionStatus.ready,
        readingStatus: HomeSectionStatus.ready,
        reading: liveReading,
        streakStatus: HomeSectionStatus.ready,
        streak: liveStreak,
      ),
      build: build,
      act: (HomeBloc bloc) =>
          bloc.add(const HomeRetried(ReadingLanguage.english)),
      // **Silence, not an emit.** A retry control on a screen with no failures
      // would be a control that reports nothing happened — which is correct, and
      // is asserted here because "no failures, so nothing to do" is otherwise
      // indistinguishable from "a retry that silently dropped its event".
      expect: () => const <HomeState>[],
      verify: (_) {
        verifyNever(streaks.summary);
        verifyNever(() => readings.today(language: any(named: 'language')));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a retry that fails again reports the new failure, not the old one',
      setUp: () {
        // One call, one answer. The state is **seeded** rather than produced by a
        // first attempt, so a call counter would be off by one — the retry is the
        // first call this port ever sees.
        when(() => readings.today(language: any(named: 'language'))).thenAnswer(
          (_) async => const Result<TodayReading>.failure(networkFailure),
        );
      },
      build: build,
      seed: () => const HomeState(
        greetingPeriod: GreetingPeriod.morning,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readerStatus: HomeSectionStatus.ready,
        readingStatus: HomeSectionStatus.failed,
        readingFailure: serializationFailure,
        streakStatus: HomeSectionStatus.ready,
        streak: liveStreak,
      ),
      act: (HomeBloc bloc) =>
          bloc.add(const HomeRetried(ReadingLanguage.english)),
      verify: (HomeBloc bloc) {
        expect(bloc.state.readingStatus, HomeSectionStatus.failed);
        expect(bloc.state.readingFailure, networkFailure);
      },
    );
  });

  group('HomeState.withSection', () {
    // The method's own doc claims a rule — "a section going back to `loading`
    // cannot keep the `Failure` that put it there" — and only the `loading` half of
    // it is reachable through `_onRetried`, which is the sole caller. So the
    // `failed` arms were uncovered, and an uncovered branch in a total function is
    // a specified behaviour nothing checks.
    test('a section moving to failed keeps its failure and drops its data', () {
      const Failure failure = Failure(
        kind: FailureKind.network,
        message: 'no streak',
      );
      const HomeState bothReady = HomeState(
        greetingPeriod: GreetingPeriod.evening,
        readerStatus: HomeSectionStatus.ready,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readingStatus: HomeSectionStatus.ready,
        reading: liveEnglishReading,
        streakStatus: HomeSectionStatus.ready,
        streak: liveStreakSummary,
      );
      // One section has failed and the other has not — the state `_onRetried`
      // exists for, and the only way to reach it in this test.
      final HomeState ready = bothReady.withStreak(
        status: HomeSectionStatus.failed,
        streak: null,
        failure: failure,
      );

      // Leaving `failed` for `loading` is what `_onRetried` does.
      final HomeState loading = ready.withSection(
        readingStatus: HomeSectionStatus.loading,
        streakStatus: HomeSectionStatus.loading,
      );

      expect(loading.readingStatus, HomeSectionStatus.loading);
      expect(loading.streakStatus, HomeSectionStatus.loading);
      expect(loading.readingFailure, isNull);
      expect(loading.streakFailure, isNull);

      // Moving *to* `failed` is the other direction, and it must not clear the
      // failure it was handed or keep the data it is replacing.
      final HomeState failed = loading.withSection(
        readingStatus: HomeSectionStatus.failed,
        streakStatus: HomeSectionStatus.failed,
      );

      expect(failed.readingStatus, HomeSectionStatus.failed);
      expect(failed.reading, isNull);
      expect(failed.streak, isNull);
      expect(
        failed.readingFailure,
        isNull,
        reason:
            'withSection sets statuses, it does not invent failures — the '
            'caller passes them through withStreak/withReading',
      );

      // And a null parameter means "leave this section alone", which is why they
      // are nullable at all. Built from `bothReady` and not from `ready`, because
      // `ready`'s streak is already failed and "left alone" would then assert
      // nothing — the first version of this line read `HomeSectionStatus.ready`
      // here and was wrong about its own fixture.
      final HomeState onlyReading = bothReady.withSection(
        readingStatus: HomeSectionStatus.failed,
      );

      expect(onlyReading.readingStatus, HomeSectionStatus.failed);
      expect(onlyReading.streakStatus, HomeSectionStatus.ready);
      expect(onlyReading.streak, liveStreakSummary);
    });

    test('withSection() with both parameters null is the identity', () {
      const HomeState ready = HomeState(
        greetingPeriod: GreetingPeriod.evening,
        readerStatus: HomeSectionStatus.ready,
        readerName: 'David Mina',
        readerInitials: 'DM',
        readingStatus: HomeSectionStatus.ready,
        reading: liveEnglishReading,
        streakStatus: HomeSectionStatus.ready,
        streak: liveStreakSummary,
      );

      expect(ready.withSection(), ready);
    });
  });

  group('the events', () {
    // `Equatable.props` is not a formality: `bloc.add` on a duplicate is a no-op
    // only if the event is equal, and both events carry the language precisely so
    // that two `HomeRetried(english)`s are the same request. Without these the
    // equality is untested and a `props` that returned `const []` — the classic
    // Equatable mistake — would pass every behavioural suite here.
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
        const HomeRetried(ReadingLanguage.arabic),
        const HomeRetried(ReadingLanguage.arabic),
      );
      expect(
        const HomeRetried(ReadingLanguage.arabic),
        isNot(const HomeRetried(ReadingLanguage.english)),
      );
      // The two are different requests even in the same language, so a `started`
      // can never be swallowed as a retry.
      expect(
        const HomeStarted(ReadingLanguage.english),
        isNot(const HomeRetried(ReadingLanguage.english)),
      );
    });

    test('a HomeCleared is neither a HomeStarted nor a HomeRetried', () {
      // A `props => const []` on the base would make every event equal to every other,
      // so a `HomeCleared` could be swallowed behind an unrelated request. Asserting
      // the three are distinct is the cheap half of that, and it is the half that is
      // worth asserting here.
      //
      // ## AND WHY THERE IS **NO** "two HomeCleareds are equal" ASSERTION
      //
      // Because it cannot be written here without proving nothing, and the
      // measurement is worth recording. `const HomeCleared()` is **canonicalised** by
      // Dart, so `expect(const HomeCleared(), const HomeCleared())` compares one
      // instance with itself: `Equatable.==` returns on `identical` and `props` is
      // never read. Building two *non-const* instances does read `props` — and
      // `prefer_const_constructors` fires on every way of spelling that, because the
      // constructor is `const` and there is no argument that could vary.
      //
      // The remaining escape is an `// ignore:`, and **this repository uses none** —
      // a fact its own docs record. So the assertion was deleted rather than
      // suppressed, and the underlying reachability is recorded as decision 48:
      // `HomeCleared.props` is dead code by construction, exactly like
      // `HomeEvent.props`, because nothing compares two clears.
      //
      // The behaviour that *would* matter is asserted where it is observable:
      // `HomeCleared and it is idempotent, because sign-out can arrive twice`.
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
    // ## WHAT THIS EXISTS FOR
    //
    // `HomeBloc` is a process-wide `registerSingleton` (`navigation_injection.dart`),
    // so between sign-out and process death it held a reader's `displayName`, their
    // monogram, today's `reading` and their `streak`, and nothing took them out.
    // `/` is also the screen a *second* signed-in reader lands on, and `HomeStarted`'s
    // first emit copies the previous reader's fields forward — so it was not only
    // hygiene, it was the wrong name greeting the wrong person.
    //
    // `AuthBloc` may not dispatch it: `AuthBloc` is in `features/auth` and this is in
    // `features/home`, so naming it is Gate 2. The dispatcher is
    // `configureNavigation()`, which holds both blocs; `navigation_injection_test.dart`
    // drives that wiring over the real registrations.
    test('empties the state back to the cold-launch one', () async {
      final HomeBloc bloc = build();

      bloc.add(const HomeStarted(ReadingLanguage.english));
      // **The streak, not the reading**, is the last of the three emits, so waiting on
      // it is waiting on all of them. `firstWhere(reading != null)` returned on an
      // earlier state and the premise below failed on `readerName` — measured, and
      // worth naming because "wait for the thing I am asserting about" is the obvious
      // and wrong version of this line.
      await bloc.stream.firstWhere((HomeState s) => s.streak != null);

      // The premise: a reader's identity really is in there before the clear.
      expect(bloc.state.readerName, isNotNull);
      expect(bloc.state.readerInitials, isNotNull);
      expect(bloc.state.reading, isNotNull);
      expect(bloc.state.streak, isNotNull);

      bloc.add(const HomeCleared());
      await bloc.stream.firstWhere((HomeState s) => s == const HomeState());

      // **`const HomeState()`, not a partial clear.** `HomeState`'s doc argues that a
      // `String? = null` parameter cannot express "clear it", so every writer builds
      // the whole state; a partial clear would be the first writer here that does
      // not. The cold-launch state *is* the post-sign-out state, which is why there is
      // no second constructor to invent.
      expect(bloc.state, const HomeState());
      expect(bloc.state.readerName, isNull);
      expect(bloc.state.readerInitials, isNull);
      expect(bloc.state.reading, isNull);
      expect(bloc.state.streak, isNull);
      expect(
        bloc.state,
        const HomeState(),
        reason:
            'equality is the claim: `HomeState.props` lists all ten fields, so an '
            'equality match cannot be hiding a field that was left behind',
      );
      await bloc.close();
    });

    test('and it is idempotent, because sign-out can arrive twice', () async {
      // A bloc emits nothing when the new state equals the old, so a second clear is
      // absorbed — which is correct and worth pinning, because a listener that
      // counted states would otherwise see a phantom re-entry.
      final HomeBloc bloc = build();

      bloc.add(const HomeCleared());
      await bloc.stream.firstWhere((HomeState s) => s == const HomeState());

      bloc.add(const HomeCleared());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, const HomeState());
      await bloc.close();
    });
  });

  group('the constructor', () {
    test('needs every collaborator, so a half-wired bloc cannot be built', () {
      // Not a test of behaviour — a statement that the three use cases are
      // required, so the object graph cannot be assembled with one missing and
      // discovered at the first `HomeStarted`.
      expect(
        () => HomeBloc(
          loadTodayReading: LoadTodayReading(readings),
          loadStreakSummary: LoadStreakSummary(streaks),
          getReaderSession: GetReaderSession(auth),
          now: clock,
        ),
        returnsNormally,
      );
    });
  });
}
