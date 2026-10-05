import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/auth/presentation/pages/login_page.dart';
import 'package:evangelion/features/home/presentation/pages/home_page.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/features/reading/presentation/pages/reading_page.dart';
import 'package:evangelion/features/reading/presentation/widgets/scripture_block.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_system_harness.dart';
import 'support/home_harness.dart';
import 'support/login_harness.dart';
import 'support/quiz_harness.dart';
import 'support/reading_harness.dart';
import 'support/settings_harness.dart';

/// `08-build-phases.md` Phase 10's **verify** line: *"the app renders correctly at
/// 320×568, 390×844, and 430×932."*
///
/// ## WHAT WAS ACTUALLY MISSING, MEASURED BEFORE ANYTHING WAS BUILT
///
/// The plan's four scope bullets were three-quarters done (measured and reported
/// separately). The **verify** line was not: a `grep` for those three sizes across
/// `test/` found exactly **one** viewport mention in the whole suite —
/// `Size(430, 2400)` in `reading_geometry_test.dart` — and none of the three sizes
/// appeared as a *render* test of any screen. The six screens were pinned to one
/// viewport each, and the three viewport numbers all **already existed** as house
/// constants (`kNarrowSurface` 320×568, `kAmbientSurface` 390×844,
/// `kGeometrySurface` 430×932). The gap was never a missing constant; it was three
/// separate answers to three separate questions and no matrix.
///
/// | screen | pumped at, before Phase 10 |
/// | --- | --- |
/// | `/login` | 320×568 only |
/// | `/` | 320×568 only |
/// | `/reading` | 430×932 only (plus 320×568 at 1.22×, in the §14 text-scale suite) |
/// | `/quiz` | 430×932 only (plus 320×568 at 1.22×) |
/// | `/result` | 430×932 only (plus 320×568 at 1.22×) |
/// | **`/settings`** | **430×932 only** — the shipped default surface |
///
/// So `/result` had never been rendered at the width §14 names, and `/settings` —
/// the screen with a three-column theme track, a stepper and a switch — had never
/// been rendered at 320 at all, at any text scale. That is the absence this file
/// closes.
///
/// ## HOW EACH OF THESE DETECTS AN OVERFLOW, WHICH IS THE WHOLE PROBLEM WITH THEM
///
/// **`testWidgets` does not fail on overflow.** `RenderFlex.performLayout` records
/// the overflow and `paint` calls `paintOverflowIndicator`, which reports through
/// `FlutterError.reportError` — inside an `assert`, so only in a debug build, which
/// is what `flutter test` is. So the diagnostic becomes a **pending exception** on the
/// `WidgetTester`, and an assertion that renders three sizes and checks nothing is a
/// green test about nothing. This repository has four recorded cases of that shape.
///
/// Two independent things hold it here, and both are needed:
///
/// 1. **`expectNoOverflow(tester, …)`** — from `design_system_harness.dart`, which
///    drains **every** pending exception (one `takeException()` can hide the second
///    overflow on a page that has two) and asserts the screen's own landmark rendered
///    first, so "no overflow" over an empty tree cannot pass.
/// 2. **The negative control below**, which plants a widget that is deliberately too
///    wide at 320 and asserts the same instrument reports it. Without it, "no
///    overflow" is indistinguishable from a detector that cannot see one — which is
///    the failure mode AGENT_CONTEXT §7 calls "a gate that cannot fail is worse than
///    no gate", applied to an assertion.
///
/// ## WHY ONE `testWidgets` PER (SCREEN, STATE, SIZE) RATHER THAN A LOOP
///
/// `DebugOverflowIndicatorMixin._reportOverflow` reports **once** per render object
/// and sets `_overflowReportNeeded = false`, restored only by `reassemble`. Re-pumping
/// the *same* tree at a second size would paint the second overflow — so the banner
/// would be visible — and **not** report it. A loop that mounted all three sizes in
/// one test would therefore be blind to every overflow after the first, and green.
/// One test per size gives each a fresh render object and a fresh reporter.
///
/// The states are swept rather than only the happy one for the reason
/// `home_accessibility_test.dart` records: loading, ready, failed and Arabic lay out
/// differently, and the states with the most text are the ones that wrap. A viewport
/// test that only mounts the ready state is a viewport test about half the screen.
///
/// ## AND THE TEXT SCALE IS **NOT** SWEPT HERE
///
/// §14's "1.22× at 320px" is five screens' own `*_text_scale_test.dart`, and
/// `/settings` has none — which is a real gap and is closed by
/// `settings_text_scale_test.dart`. This file is deliberately at scale 1.0, because
/// "renders correctly at these three sizes" and "renders correctly at these three
/// sizes *with the reader's font preference at maximum*" are two different claims and
/// the second already has five homes.
/// Mounts one screen state and lets it settle.
///
/// **A named alias rather than the function type spelled inline in [Mount].** A
/// record typedef containing `Future<void> Function(WidgetTester)` does not parse,
/// and the parse error lands twenty lines below the typedef that caused it — which is
/// the kind of thing that costs an afternoon. Both typedefs are at file scope for the
/// same reason: a local typedef reads as if it were scoped, and it is not the
/// question anyone is asking.
typedef Pump = Future<void> Function(WidgetTester tester);

/// One screen state to mount.
///
/// [state] is what a failure reads as, so it is written the way a person would say
/// it. [pump] mounts and settles. [landmark] is the widget whose presence makes "no
/// overflow" non-vacuous — the screen's own, never `find.byType(Scaffold)`.
typedef Mount = ({String state, Pump pump, Finder landmark});

void main() {
  /// The three surfaces, in the plan's own order.
  ///
  /// Read off the house constants rather than written out, so this file cannot claim a
  /// viewport the rest of the suite does not use — and so a change to any of them is
  /// visible here as a change to the matrix.
  const List<(String, Size)> surfaces = <(String, Size)>[
    ('320x568', kNarrowSurface),
    ('390x844', kAmbientSurface),
    ('430x932', kGeometrySurface),
  ];

  void matrix(String screen, List<Mount> mounts) {
    for (final Mount mount in mounts) {
      for (final (String size, Size surface) in surfaces) {
        testWidgets('$screen — ${mount.state} — $size', (
          WidgetTester tester,
        ) async {
          // Written **inside** the body, before the mount reads it — see
          // [_currentSurface]'s doc for why that is the only safe place.
          _currentSurface = surface;
          await mount.pump(tester);
          expectNoOverflow(
            tester,
            somethingRendered: () => mount.landmark.evaluate().isNotEmpty,
            surface: '$screen / ${mount.state} / $size',
          );
        });
      }
    }
  }

  group('the six shipped screens, at all three viewports', () {
    // ---------------------------------------------------------------------------
    matrix('/login', <Mount>[
      (
        state: 'signed out, empty fields',
        pump: (WidgetTester tester) =>
            pumpLogin(tester, bloc: _authBloc(), size: _currentSurface),
        landmark: find.byType(LoginPage),
      ),
      (
        state: 'an errored field, whose message is a sentence',
        pump: (WidgetTester tester) async {
          final AuthBloc bloc = _authBloc();
          bloc.add(const AuthSubmitted());
          await pumpLogin(tester, bloc: bloc, size: _currentSurface);
        },
        landmark: find.byType(LoginPage),
      ),
    ]);

    // ---------------------------------------------------------------------------
    matrix('/', <Mount>[
      (
        state: 'ready',
        pump: (WidgetTester tester) =>
            pumpHome(tester, bloc: harness().bloc, size: _currentSurface),
        landmark: find.byType(HomePage),
      ),
      (
        state: 'a failed reading, so the panel is an ErrorView',
        pump: (WidgetTester tester) => pumpHome(
          tester,
          bloc: harness(
            reading: const Result<ScriptureText>.failure(homeReadingFailure),
          ).bloc,
          size: _currentSurface,
        ),
        landmark: find.byType(HomePage),
      ),
      (
        state: 'a failed streak',
        pump: (WidgetTester tester) => pumpHome(
          tester,
          bloc: harness(
            streak: const Result<StreakSummary>.failure(streakFailure),
          ).bloc,
          size: _currentSurface,
        ),
        landmark: find.byType(HomePage),
      ),
    ]);

    // ---------------------------------------------------------------------------
    matrix('/reading', <Mount>[
      (
        state: 'ready, English',
        pump: (WidgetTester tester) => pumpReading(
          tester,
          cubit: readingHarness().cubit,
          size: _currentSurface,
        ),
        landmark: find.byType(ScriptureBlock),
      ),
      (
        state: 'ready, Arabic — taller script and a longer caption',
        pump: (WidgetTester tester) => pumpReading(
          tester,
          cubit: readingHarness(
            scripture: const Result<ScriptureText>.success(liveArabicPassage),
          ).cubit,
          locale: const Locale('ar'),
          size: _currentSurface,
        ),
        landmark: find.byType(ScriptureBlock),
      ),
      (
        state: 'the failed state, whose message is a sentence',
        pump: (WidgetTester tester) => pumpReading(
          tester,
          cubit: readingHarness(
            scripture: const Result<ScriptureText>.failure(readingFailure),
          ).cubit,
          size: _currentSurface,
        ),
        landmark: find.byType(ReadingPage),
      ),
      (
        state: 'the `Aa` panel OPEN — a row of controls over the CTA',
        pump: (WidgetTester tester) async {
          await pumpReading(
            tester,
            cubit: readingHarness().cubit,
            size: _currentSurface,
          );
          await tester.tap(find.byIcon(Icons.format_size));
          await pumpReadingFrames(tester, 4);
        },
        landmark: find.byType(FontSizeStepper),
      ),
    ]);

    // ---------------------------------------------------------------------------
    matrix('/quiz', <Mount>[
      (
        state: 'a question with nothing chosen on it',
        pump: (WidgetTester tester) => pumpQuiz(
          tester,
          bloc: quizBloc(
            const Result<ScriptureText>.success(liveEnglishQuizPassage),
          ),
          size: _currentSurface,
        ),
        landmark: find.byType(QuizOptionCard),
      ),
      (
        state: 'a graded question, with the verdict glyph beside each card',
        pump: (WidgetTester tester) async {
          await pumpQuiz(
            tester,
            bloc: quizBloc(
              const Result<ScriptureText>.success(liveEnglishQuizPassage),
              submission: defaultSubmission,
            ),
            size: _currentSurface,
          );
          await tester.tap(find.text(liveEnglishQuestion.options['A']!));
          await pumpQuizFrames(tester, 2);
          await tester.tap(find.text(AppLocalizationsEn().quizCheckAnswer));
          await pumpQuizFrames(tester, 6);
        },
        landmark: find.byType(QuizOptionCard),
      ),
      (
        state: 'the failed load, so the screen is an ErrorView',
        pump: (WidgetTester tester) => pumpQuiz(
          tester,
          bloc: quizBloc(
            const Result<ScriptureText>.failure(
              Failure(kind: FailureKind.network, message: 'offline'),
            ),
          ),
          size: _currentSurface,
        ),
        landmark: find.byType(QuizPage),
      ),
    ]);

    // ---------------------------------------------------------------------------
    matrix('/result', <Mount>[
      (
        state: 'the finished reading',
        pump: (WidgetTester tester) =>
            pumpResult(tester, result: _aResult, size: _currentSurface),
        landmark: find.byType(ResultPage),
      ),
      (
        state: 'the ARABIC arm, with Arabic-Indic numerals in every number',
        pump: (WidgetTester tester) => pumpResult(
          tester,
          result: _aResult,
          locale: const Locale('ar'),
          size: _currentSurface,
        ),
        landmark: find.byType(ResultPage),
      ),
    ]);

    // ---------------------------------------------------------------------------
    matrix('/settings', <Mount>[
      (
        state: 'ready',
        pump: (WidgetTester tester) =>
            pumpSettings(tester, size: _currentSurface),
        landmark: find.byType(SettingsPage),
      ),
      (
        state: 'the failure notice, whose sentence wraps',
        pump: (WidgetTester tester) => pumpSettings(
          tester,
          cubit: _unreachableStore(),
          size: _currentSurface,
        ),
        landmark: find.byType(SettingsPage),
      ),
      (
        state: 'the Arabic arm, whose language sheet is a tap away',
        pump: (WidgetTester tester) => pumpSettings(
          tester,
          locale: const Locale('ar'),
          size: _currentSurface,
        ),
        landmark: find.byType(SettingsPage),
      ),
    ]);
  });

  // ---------------------------------------------------------------------------
  group('the overflow detector itself — the negative control', () {
    // ## THIS IS THE MANDATORY MUTATION, AND IT IS **PERMANENT**
    //
    // Everything above is `expectNoOverflow(tester, …)`. An assertion that renders
    // three sizes and checks nothing is the vacuous test this repository has four
    // recorded cases of, and so is an assertion that checks for something the
    // framework never reports. This group plants a widget that is **provably** too
    // wide for 320 and asserts that the same instrument sees it.
    //
    // Measured, before this group existed, by editing a production widget: a
    // `Text` inside a `Row` without an `Expanded` overflowed by **94 pixels on the
    // right** on `/settings`' new notice, and the only reason it was found is that
    // `flutter test` printed `A RenderFlex overflowed by 94 pixels on the right.`
    // during an unrelated probe. Nothing was asserting about it.
    testWidgets('a deliberately too-wide row is reported at 320', (
      WidgetTester tester,
    ) async {
      // **Through `pumpPrimitive`, and the first version of this test did not size
      // the view at all.** It pumped `evaPrimitiveHarness` directly, which sets no
      // `physicalSize`, so the row laid out against the framework's **800×600** test
      // surface, 480 fit comfortably, and this test failed with
      // `Expected: non-empty / Actual: []` — a false negative that had exactly one
      // cause. `pumpPrimitive` is `design_system_harness.dart`'s own answer and it
      // pins the viewport to [kNarrowSurface].
      await pumpPrimitive(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 12; i++) const SizedBox(width: 40, height: 20),
          ],
        ),
      );

      // **Asserted as a list, so the failure is a list of the errors found.** The
      // assertion the matrix uses is `expect(overflows, isEmpty)`; this is its
      // mirror, and it fails when the detector works. If a future Flutter stopped
      // reporting overflow through `FlutterError.reportError`, this test goes red
      // and the twenty-odd assertions above are known to be blind rather than
      // quietly so.
      final List<Object> found = drainOverflowErrors(tester);
      expect(
        found,
        isNotEmpty,
        reason:
            'THE DETECTOR IS BROKEN. Twelve 40px boxes in a 320px `Row` overflow by '
            '160px, and the framework reports it through `FlutterError.reportError` '
            '— which `testWidgets` records as a pending exception. An empty list here '
            'means every "renders correctly" assertion in this file is green about '
            'nothing.',
      );
      expect(
        found.first.toString(),
        contains('overflowed'),
        reason:
            'and the diagnostic is the overflow one, so an unrelated pending '
            'exception cannot stand in for it',
      );
    });

    testWidgets('and the same row at 430 does NOT overflow', (
      WidgetTester tester,
    ) async {
      // The **other half** of the negative control, and the half that stops it being
      // satisfied by "any error at all". Eight 40px boxes fit in 390; nine do not.
      // If the detector reported everything, this would fail; if it reported
      // nothing, the previous test would. Between them the instrument is pinned from
      // both sides.
      await pumpPrimitive(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 8; i++) const SizedBox(width: 40, height: 20),
          ],
        ),
      );

      expect(
        drainOverflowErrors(tester),
        isEmpty,
        reason:
            '8 x 40 = 320 fits inside 390 with 70 to spare, so nothing may be '
            'reported. A non-empty list here means the detector fires on clean '
            'layouts, which would make every assertion in the matrix above pass for '
            'the wrong reason.',
      );
    });

    testWidgets('and a landmark that is absent is caught before the overflow', (
      WidgetTester tester,
    ) async {
      // The anti-vacuity half, negative-controlled. `expectNoOverflow` checks
      // `somethingRendered()` **first**, so a caller whose landmark is missing gets
      // that failure rather than a green "no overflow" over an empty tree — which is
      // the other half of vacuous, and the one a render test hits by accident when a
      // screen's landmark is renamed.
      await pumpPrimitive(tester, const SizedBox.shrink());

      expect(
        () => expectNoOverflow(
          tester,
          somethingRendered: () => find.byType(LoginPage).evaluate().isNotEmpty,
          surface: '320x568 / nothing / 320x568',
        ),
        throwsA(isA<TestFailure>()),
        reason:
            'an empty tree cannot overflow, so the landmark check is the only thing '
            'standing between this helper and a green tick about nothing',
      );
    });
  });
}

/// The surface the running mount is being asked about.
///
/// **A mutable module-level variable, deliberately.** Every mount closure in the
/// matrix table needs to reach the size its `testWidgets` was registered with, and
/// the alternative — threading a `size` parameter through 19 closures by hand — is
/// the copy-and-paste that makes a table of 19 rows wrong in one place. It is safe
/// because `testWidgets` bodies never overlap: `flutter_test` runs them one at a
/// time, so the value is written immediately before the body that reads it.
///
/// The cost is stated rather than hidden: a test that read this value **after** an
/// `await` on a *different* surface would get the wrong number. Every mount here
/// passes it straight into its pump, which is the whole of its use.
Size _currentSurface = kNarrowSurface;

/// A real `AuthBloc` over the in-memory fake store.
///
/// `login_accessibility_test.dart` keeps a private `buildTestBloc` for the same
/// thing. It is not moved here: this file needs it once and that file needs it nine
/// times, and a shared builder in `login_harness.dart` would be a third place to
/// change when `AuthBloc`'s constructor does.
AuthBloc _authBloc() {
  final FakeAuthRepository repository = FakeAuthRepository(
    AuthLocalDataSource(),
  );
  return AuthBloc(
    signIn: SignIn(repository),
    getCurrentSession: GetCurrentSession(repository),
    signOut: SignOut(repository),
  );
}

/// The response `/result` is pumped with.
///
/// The numbers are recognisable so nothing on screen is blank, which is the
/// anti-vacuity condition for the two stat tiles — a `StatTile` with an empty value
/// renders nothing and the page would lay out shorter than a reader's ever does.
const SubmitResult _aResult = SubmitResult(
  questionId: 'question-group-3',
  isCorrect: true,
  pointsEarned: 10,
  currentTotalPoints: 120,
  currentStreak: 12,
  longestStreak: 30,
  readingCompleted: true,
);

/// A cubit over a store that cannot be reached, for `/settings`' failure notice.
///
/// The notice is the one `/settings` state whose **sentence wraps**, which is why it
/// is in this matrix and not only in its own suite: an inline notice in a `Row` is
/// exactly the shape that overflowed by 94 pixels while it was being written.
SettingsCubit _unreachableStore() {
  const Failure failure = Failure(
    kind: FailureKind.storage,
    message:
        'the preferences could not be reached: '
        'MissingPluginException(No implementation found)',
  );
  final SettingsCubit cubit = SettingsCubit(
    getSettings: const GetSettings(FailingSettingsRepository(failure)),
    updateSettings: const UpdateSettings(FailingSettingsRepository(failure)),
  );
  addTearDown(cubit.close);
  return cubit;
}
