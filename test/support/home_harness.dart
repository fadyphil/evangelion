import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
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

/// [ReadingRepository] that answers [answer] and counts its calls.
final class CountingReadingRepository implements ReadingRepository {
  /// Starts out answering [answer].
  CountingReadingRepository({required this.answer});

  /// What the next call answers.
  Result<TodayReading> answer;

  /// How many times [today] has been called.
  int calls = 0;

  /// The languages [today] has been asked for, in order.
  final List<ReadingLanguage> asked = <ReadingLanguage>[];

  @override
  Future<Result<TodayReading>> today({
    required ReadingLanguage language,
  }) async {
    calls++;
    asked.add(language);
    return answer;
  }
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
const Failure readingFailure = Failure(
  kind: FailureKind.serialization,
  message:
      "Could not read today's reading: `verses` is absent, and a non-empty "
      'list was expected.',
);

/// The streak endpoint's own failure, for the mirror-image fixture.
const Failure streakFailure = Failure(
  kind: FailureKind.network,
  message: 'Could not reach the server.',
);

/// Builds a [HomeBloc] over counting fakes, and registers the teardown.
HomeHarness harness({
  Result<TodayReading>? reading,
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
    answer: reading ?? const Result<TodayReading>.success(liveEnglishReading),
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
