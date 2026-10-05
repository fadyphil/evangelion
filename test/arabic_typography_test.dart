/// **Defect #2 on all six screens, from one harness.**
///
/// ## WHAT THIS FILE IS
///
/// `reading_glyph_test.dart` built the right instrument and applied it to one screen.
/// Recorded decision 73 measured the other two built screens and found their Arabic
/// arms **mostly tofu** with a green suite, because `home_page_test.dart` asserted
/// the family on the **preview only**. So this file is the instrument's promotion:
/// `test/support/arabic_typography_gate.dart` does the work, and this file runs it
/// over **every** screen, which is the whole deliverable.
///
/// ## SIX SCREENS, NO EXEMPTIONS
///
/// AGENT_CONTEXT §2's route table names six routes. **Three of them are stubs** —
/// `/quiz`, `/result` and `/settings` render `Placeholder for /quiz` and nothing
/// else — and the brief named only two. All three are here, and each declares an
/// **empty** Arabic list with a `vacuousBecause`, which is the difference between a
/// gate that is installed and honest and one that is silently doing nothing
/// (§7: "A gate whose target directory does not exist yet reports **vacuous** and says
/// so — report that honestly rather than calling it a pass").
///
/// Their capability is not asserted in the abstract; it is proved by the per-screen
/// mutation in the review, which plants a wrong-family Arabic run on each of them.
///
/// ## THE THREE ARMS EVERY SCREEN GETS
///
/// 1. the **declared set** of Arabic runs, compared for equality in both directions;
/// 2. every one of them in Amiri — the token *and* the literal string;
/// 3. **every character on screen** carried by the family that renders it, which is
///    the only one of the three that does real work on the three stub screens.
///
/// Plus an English control per screen: with no Arabic on screen, the Arabic gate is
/// vacuous *by construction*, so a screen that silently stopped honouring the locale
/// would pass the Arabic assertions. The control is what catches that — it asserts
/// that the Arabic arm was **reached**.
///
/// ## AND THE FIX IT GUARDS IS ONE FUNCTION
///
/// `EvaTypography.arabicAware` in `core/design_system/tokens/eva_typography.dart`.
/// Two hard-coded states of it are proved by mutation in the review: forced to
/// `return style`, and forced to never swap.
library;

import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/feedback_banner.dart';
import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/features/result/presentation/result_l10n.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/arabic_typography_gate.dart';
import 'support/design_system_harness.dart';
import 'support/font_coverage.dart';
import 'support/home_harness.dart' hide CountingReadingRepository;
import 'support/login_harness.dart';
import 'support/quiz_harness.dart';
import 'support/reading_harness.dart';

void main() {
  group('`/` — the home screen', () {
    /// The seven Arabic runs `/` renders, measured off the rendered tree.
    ///
    /// **Five of the seven were wrong before this phase.** `CormorantGaramond` for
    /// the greeting's lead-in, `DMSans` for the streak subtitle, `SpaceMono` for the
    /// panel status line, `DMSans` for the reference and `DMSans` for `ابدأ التأمل`.
    /// Two were already right and are listed so a regression names them: the preview
    /// (Phase 6's defect C1) and the `Continue` button (Phase 7's decision 66).
    ///
    /// ## BUILT FROM THE TABLES AND THE FIXTURES, **NOT** TYPED OUT
    ///
    /// The first version of this list was Arabic literals, and every one of them is a
    /// second copy of a string that already lives in `AppLocalizations` or in the live
    /// payload. Four went wrong on the first run — a missing combining mark is
    /// invisible in a diff and the failure then reads as "the widget rendered the
    /// wrong string" rather than "the test typed the wrong string". So the UI strings
    /// come from `AppLocalizationsAr()` and the payload strings from the fixture, and
    /// nothing here is transcribed.
    ///
    /// The one composed value, the greeting's lead-in, is `greetingLead`'s own
    /// output for the period the fixture's clock resolves to — which is exactly the
    /// derivation the panel uses, and is asserted to be a *distinct* string from the
    /// rest so a change to it cannot silently collapse two runs into one.
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      ar.greetingLead(GreetingPeriod.morning, hasName: true),
      ar.homeStreakResting,
      // **`continueReading`, not `readingComplete`** — and the reason is the
      // fixture, not a slip: `liveArabicScripture.isFullyCompleted` is **false**,
      // because `home_harness.dart`'s doc says the Arabic arm must be unfinished so
      // both branches of the eyebrow are reachable. The completed branch is gated by
      // its own test below rather than being assumed here.
      ar.homeContinueReading,
      liveArabicScripture.verses.first.textClean!,
      liveArabicScripture.reference,
      ar.homeContinueLabel,
      ar.homeStartReflection,
    ];

    testWidgets('the Arabic arm, with the live Arabic payload', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result<ScriptureText>.success(liveArabicScripture),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      await expectArabicTypography(tester, screen: '/', expectedArabic: arabic);
      await expectNoTofuInAnyRun(tester, screen: '/');
    });

    testWidgets('and the same screen in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);
      await _expectNoArabic(tester, '/');
    });

    testWidgets('the COMPLETED branch of the same status line', (
      WidgetTester tester,
    ) async {
      // `liveArabicScripture` is unfinished so the other branch is reachable, which
      // means a gate that declared only `continueReading` would never see
      // `readingComplete` — the run most likely to be dropped in a refactor, and the
      // one the review named.
      final HomeHarness h = harness(
        reading: Result<ScriptureText>.success(
          liveArabicScripture.copyWith(isFullyCompleted: true),
        ),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/',
        expectedArabic: <String>[
          for (final String run in arabic)
            if (run != ar.homeContinueReading) run,
          ar.homeReadingComplete,
        ],
      );
    });

    testWidgets('the FAILED state is gated on its own list, and its '
        '`Failure.message` renders in the ambient arm', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Result<ScriptureText>.failure(homeReadingFailure),
        streak: const Result<StreakSummary>.success(liveStreakSummary),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      // **Three runs, not seven.** The panel has no reading, so the preview, the
      // reference and both controls are genuinely absent — and a gate that declared
      // the content screen's list here would fail for the wrong reason and send the
      // next reader looking for a layout bug.
      await expectArabicTypography(
        tester,
        screen: '/',
        expectedArabic: <String>[
          ar.greetingLead(GreetingPeriod.morning, hasName: true),
          ar.homeStreakResting,
          // The retry label — an Arabic run this phase's own first draft of the list
          // forgot, which the gate caught. That is the gate working.
          ar.homeRetry,
        ],
      );
      expect(
        familyOfText(tester, homeReadingFailure.message),
        EvaTypography.arabicFamily,
        reason:
            '`ErrorView` renders a `Failure.message` in `titleMedium` — DM Sans — '
            'and DM Sans carries no Arabic at all, so a backend that localised its '
            'errors would render tofu on the one screen where something has already '
            'gone wrong. Amiri carries ASCII as well, so the English case is '
            'unaffected.',
      );
    });
  });

  group('`/login`', () {
    /// The ten Arabic runs `/login` renders.
    ///
    /// **Nine of the ten were wrong before this phase**, and four of them are not in
    /// recorded decision 73's list: `كلمة المرور` (the password field's label),
    /// `جديد هنا؟`, `أنشئ حسابًا` and the divider's `أو`. Only `تسجيل الدخول` was
    /// right, from decision 66's required `labelFamily`.
    ///
    /// Built from the string table, for the reason `/`'s list gives.
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      ar.authTagline,
      // `EvaTextField` renders its label as `label.toUpperCase()`, and Arabic has no
      // case — so the rendered run is the field value itself. Asserting the table's
      // value is correct *because* the transform is a no-op here, and the widget's doc
      // says so rather than leaving it to be re-derived.
      ar.authEmailLabel,
      ar.authPasswordLabel,
      ar.authSignIn,
      ar.authForgotPassword,
      ar.authNewHere,
      ar.authCreateAccount,
      ar.authDivider,
      ar.authContinueWithGoogle,
      ar.authContinueWithApple,
    ];

    testWidgets('the Arabic arm, on the empty form', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: _authBloc(), locale: const Locale('ar'));
      await expectArabicTypography(
        tester,
        screen: '/login',
        expectedArabic: arabic,
      );
      await expectNoTofuInAnyRun(tester, screen: '/login');
    });

    testWidgets('the field validator\'s error is gated, and its **wording** is a '
        'recorded English gap', (WidgetTester tester) async {
      await pumpLogin(tester, bloc: _authBloc(), locale: const Locale('ar'));
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.pump();

      // **The family is the deliverable and it is asserted.** `EvaTextField`'s error
      // text is `bodySmall` — DM Sans — and `arabicAware` now resolves it for the
      // arm, so a localised validator message will render. That is the half this
      // phase owns.
      expect(
        familyOfText(tester, kShortPasswordMessage),
        EvaTypography.arabicFamily,
        reason:
            'the field\'s error helper text must take the ambient arm\'s face, '
            'because the moment this message is Arabic it has to render.',
      );

      // **And the wording is a recorded gap, pinned so it cannot be forgotten.**
      // `kShortPasswordMessage` and `kRequiredMessage` are English literals in
      // `features/auth/domain/login_credentials.dart` — a **pure-Dart domain file**,
      // which by Gate 1 has no `Locale` and therefore cannot pick an arm. The fix is
      // a validation-*code* enum on `LoginValidation` plus a message in
      // `AppLocalizations`, which changes `AuthState`'s public shape and is a domain
      // decision this typography gate does not own.
      //
      // **What Phase 9 inherits, stated:** two English sentences on the Arabic arm of
      // `/login`, at `bodySmall`, in the right family. The family is done; the
      // language is not, and this assertion goes red the day someone fixes it —
      // which is the point.
      expect(
        kShortPasswordMessage,
        "That password's too short",
        reason:
            'this pins the recorded gap, not the wording. If you have localised the '
            'validator, update this note in `login_credentials.dart` and delete the '
            'expectation — do not leave a test that documents a defect nobody is '
            'tracking.',
      );
      expect(kRequiredMessage, 'This field is required');

      await expectArabicTypography(
        tester,
        screen: '/login',
        expectedArabic: arabic,
        vacuousBecause: null,
      );
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      await pumpLogin(tester, bloc: _authBloc());
      await _expectNoArabic(tester, '/login');
    });
  });

  group('`/reading`', () {
    /// The twelve Arabic runs `/reading` renders, all of which were already Amiri.
    ///
    /// Phase 7's own table, kept as a **declared set** rather than as a per-site
    /// `expect`, so that a run cannot disappear and leave the gate satisfied by the
    /// eleven that remain. Six of these are the verse paragraphs — whole-verse runs,
    /// which the per-site table covers by pointing at the marker inside them.
    ///
    /// Built from the fixture and `AppLocalizationsAr()`, for `/`'s reason: a
    /// hand-typed Arabic list in a test is a second copy of the corpus.
    /// Built from the fixture and the string table, for `/`'s reason: a hand-typed
    /// Arabic list in a test is a second copy of the corpus.
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      // Site 1 — the metadata row: the payload's own `translation`, which is
      // **per-language** (`ReadingHeader`'s doc has the measurement) and half of it
      // is Arabic.
      liveArabicPassage.translation,
      // Site 4 — the citation.
      liveArabicPassage.reference,
      // The five verse paragraphs — whole-verse runs, which the per-site table covers
      // by pointing at the marker inside them.
      //
      // **`Verse.text`, not `displayText`.** Recorded decision 51 makes
      // `textClean ?? text` the rule for the arm's single resolution — and
      // `scripture_verse.dart` then overrides it for the sanctuary, whose own field
      // doc reads "THE SANCTURARY RENDERS **THIS**, NOT `displayText`": the reading
      // screen shows scripture whole and diacritised, and `displayText` is a
      // *preview* projection. The first draft of this list used `displayText` and
      // the gate named all five as unrendered, which is the third time in this
      // repository that a test's own wrong derivation has read as a widget defect.
      for (final Verse verse in liveArabicPassage.verses) verse.text,
      // Site 5 — the CTA label.
      ar.readingBeginReflection,
      // Site 2 — the caption, with Arabic-Indic digits.
      ar.readingCaption(1),
      // Sites 7, 8 and 9 — the three control tooltips, which have **no prototype
      // line**: `ReadingEnScreen.tsx:14-16` and `ReadingArScreen.tsx:21-29` are bare
      // `<button>`s with an inline `<svg>` and no label, so §14 forced these three
      // strings into this client. They are the 30 tofu boxes decision 71 records.
      ar.readingBack,
      ar.readingTextSize,
      '${ar.readingBookmark} — ${ar.readingUnavailableSuffix}',
    ];

    testWidgets('the Arabic arm, with the live Arabic passage', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/reading',
        expectedArabic: arabic,
      );
      await expectNoTofuInAnyRun(tester, screen: '/reading');
    });

    testWidgets('the `Aa` disclosure is gated — it is two more Arabic runs behind '
        'a tap', (WidgetTester tester) async {
      final ReadingHarness h = readingHarness(
        scripture: const Result<ScriptureText>.success(liveArabicPassage),
      );
      // **A taller viewport than `kGeometrySurface`, and it is load-bearing.**
      // `ScriptureBlock` is a `ListView.builder`, so a verse below the fold is not
      // merely off-screen — it is **never built**, and a run that is never built is a
      // run this gate cannot see. Opening the panel costs about 60px and pushed
      // verse five off the end, so the exact-set assertion below failed on a run that
      // was not missing from the widget but missing from the *fixture of what gets
      // rendered*.
      //
      // The alternative — declaring whatever happens to be on screen at 932 — makes
      // this test a function of the viewport, and a viewport is a number a later
      // phase will change for its own reasons. So the viewport grows instead.
      await pumpReading(
        tester,
        cubit: h.cubit,
        locale: const Locale('ar'),
        size: const Size(430, 1200),
      );
      await tester.tap(find.byIcon(Icons.format_size));
      await pumpReadingFrames(tester, 4);

      await expectArabicTypography(
        tester,
        screen: '/reading',
        expectedArabic: <String>[
          ...arabic,
          // `AppLocalizations.ar`'s own two new strings. They were
          // `'Decrease font size'` / `'Increase font size'` hard-coded in
          // `FontSizeStepper`, so before this phase this arm rendered two English
          // sentences in a panel on a bilingual screen.
          AppLocalizationsAr().readingDecreaseFontSize,
          AppLocalizationsAr().readingIncreaseFontSize,
        ],
      );
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness();
      await pumpReading(tester, cubit: h.cubit);
      await _expectNoArabic(tester, '/reading');
    });
  });

  // The three stubs. Each declares an EMPTY Arabic list and says why — which is the
  // honest report §7 asks for, and which is also a live claim: a stub that grows its
  // first Arabic run is red here, naming the string, until somebody has checked the
  // family it renders in.
  group('`/quiz`', () {
    // ## NO LONGER VACUOUS, AND THE LIST IS BUILT FROM THE FIXTURE
    //
    // Recorded decision 79 declared this screen **vacuous** — a stub whose whole body
    // was `Placeholder for /quiz` — and passed a `vacuousBecause` saying Phase 8
    // would write it. Phase 8 did, so `vacuousBecause` is now `null` and the list is
    // **declared**, which is decision 79's actual mechanism: a run cannot disappear
    // and leave the gate satisfied by the ones that remain.
    //
    // Built from the Arabic fixture and `AppLocalizationsAr()`, for decision 79's reason:
    // a hand-typed Arabic list in a test is a second copy of the corpus.
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      // The progress label — `questionProgress` with Arabic-Indic digits.
      ar.questionProgress(1, 1),
      // The question text — the **payload** arm again, and the one this list was
      // missing when the gate first fired on this screen. The failure named it
      // exactly: `Declared but NOT rendered: {تحقق من الإجابة}`, `Rendered: … ما اسم
      // الفريسي الذي جاء إلى يسوع ليلاً؟`. An option list is not a question.
      liveArabicQuestion.prompt,
      // The four option texts: the **payload** arm, so `QuizOptionCard`'s required
      // `ReadingLanguage` is the only thing that can put them in Amiri.
      ...liveArabicQuestion.options.values,
      // The close control's tooltip — a bare `<button>` around an `<svg>` cross in
      // the prototype (`QuizScreen.tsx:46-50`), so §14 forced the string into this
      // client, exactly as it forced `AppLocalizations.readingBack` on Phase 7.
      ar.quizExit,
    ];
    // **`ar.quizProgress` is DELIBERATELY NOT IN THE LIST, and that is a fact about the
    // gate rather than an omission.**
    //
    // `QuizHeader` passes `strings.quizProgress` to `ProgressBeads.semanticLabel`, and
    // `ProgressBeads` puts it in a `Semantics(label: …, excludeSemantics: true)`
    // node — it is **never rendered as text**. This gate reads *painted* runs, so a
    // semantics-only string cannot appear in the rendered set, and declaring it
    // fails the gate's other half: `Declared but NOT rendered: {السؤال}`. That is
    // the assertion working — it caught a category error I had made, where I
    // listed every Arabic string on the screen without asking whether any of them
    // reaches a glyph buffer.
    //
    // The label is still asserted, by the gate that covers the right layer:
    // `quiz_page_test.dart`'s semantics group reads `ProgressBeads`' merged node and
    // names it. Two instruments, two layers, and this one declines to claim the
    // other's coverage.

    testWidgets('the Arabic arm, with the live Arabic question', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(
        const Result<ScriptureText>.success(liveArabicQuizPassage),
      );
      await pumpQuiz(tester, bloc: bloc, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/quiz',
        // **The CTA label is added per test, not hoisted into the base list.** The
        // button relabels itself — `checkAnswer` before a choice, `nextQuestion`
        // after a check — so one of the two labels is always absent, and hoisting
        // it would leave whichever test did not render it failing the gate's
        // `Declared but NOT rendered` half. The failure said exactly that:
        // `Actual: Set:['تحقق من الإجابة']` while the rendered tree said
        // `السؤال التالي`.
        expectedArabic: <String>[...arabic, ar.quizCheckAnswer],
        vacuousBecause: null,
      );
    });

    testWidgets('and the FEEDBACK banner is gated too', (
      WidgetTester tester,
    ) async {
      // The banner is the one run on this screen that only exists **after** a check,
      // so its own gate needs its own pump — the same reason `/reading`'s `Aa`
      // disclosure has one.
      // **`quizBlocWith`, not a hand-built bloc**: decision 20's rule is that the bloc
      // is built in the test body, and this suite already imports
      // `home_harness.dart`, whose `CountingReadingRepository` collides with
      // `reading_harness.dart`'s by name. The harness takes the collision away, which
      // is decision 47's argument one layer up: one rule, one place.
      final ({QuizBloc bloc, CountingReadingRepository readings}) fixture =
          quizBlocWith(
            const Result<ScriptureText>.success(liveArabicQuizPassage),
          );
      await pumpQuiz(tester, bloc: fixture.bloc, locale: const Locale('ar'));

      // **Read off the fixture, not typed here.** A hand-typed copy of a corpus
      // string is the "second declaration" this gate's own doc warns against: if the
      // fixture's option text is ever corrected, the tap silently misses and the
      // banner never appears, which fails as *"the banner is absent"* and reads as
      // the gate working. `liveArabicQuestion` is the one transcription.
      await tester.tap(find.text(liveArabicQuestion.options['A']!));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(ar.quizCheckAnswer));
      await pumpQuizFrames(tester, 4);

      expect(find.byType(FeedbackBanner), findsOneWidget);
      await expectArabicTypography(
        tester,
        screen: '/quiz',
        // Same reasoning as the arm above, and for one more run: the **verdict
        // sentence** the banner shows once an answer is checked, and the CTA's new
        // label. `correctSuffix` is *not* here — like `ProgressBeads`' label it is a
        // semantics-only string, and `quiz_page_test.dart`'s spoiler group is what
        // reads it.
        expectedArabic: <String>[
          ...arabic,
          ar.quizVerdictCorrect,
          ar.quizNextQuestion,
        ],
        vacuousBecause: null,
      );
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(
        const Result<ScriptureText>.success(liveEnglishQuizPassage),
      );
      await pumpQuiz(tester, bloc: bloc);
      await _expectNoArabic(tester, '/quiz');
    });
  });

  group('`/result`', () {
    // ## ALSO NO LONGER VACUOUS, AND IT HAS NO BLOB TO START FROM
    //
    // `/reading` and `/quiz` have a captured Arabic payload. `/result` has **no
    // fixture at all** — the plan's own cut gives it no repository, so there is
    // nothing to capture — which makes this list the purest form of decision 79's
    // rule: every run here is either the app's own chrome or an integer the client
    // rendered, and all of it comes from `AppLocalizationsAr()`.
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      // The headline sentence.
      ar.resultCompleteMessage,
      // The streak pill, with **Arabic-Indic digits** — `AppLocalizations.streakLabelFor`
      // runs `_countIn`, so `4` is `٤`. This is the one run on the screen whose
      // *numerals* are Arabic, and it is why `arabic_digits.dart` moved to
      // `core/domain/` in Phase 8: three features needed it.
      ar.streakLabelFor(current: 4, longest: 6),
      // The two stat tiles' **labels**, which `StatTile` renders in mono caps — the
      // Latin-on-the-AR-arm family is `StatTile`'s own recorded Phase-10 debt and is
      // not this phase's, so only the *strings* are declared here.
      ar.resultThisAnswer,
      ar.resultBestRun,
      // The score's caption, and both buttons.
      //
      // ## AND THE CAPTION IS A **PLURAL** NOW, TAKING THE SCORE
      //
      // It used to be the bare noun `نقطة`, which is SINGULAR and so was wrong for
      // every score from 3 up — `٥ نقطة` instead of `٥ نقاط`. `resultTotalCaption` is
      // an ICU plural now and the score above it is `٤٠`, which is Arabic's `many`
      // class, so this arm still renders `نقطة`. The **wrong** arm below renders
      // `نقاط`, and that difference is the fix being visible in this file.
      ar.resultTotalCaption(40),
      ar.resultReflectAgain,
      ar.resultBackHome,
      // **The three bare numerals**, which is what the gate found missing and is
      // the reason `arabic_digits.dart` had to move to `core/domain/` in Phase 8.
      //
      // A run of *only* digits is still a run of Arabic characters: U+0660–U+0669
      // sits inside the U+0600–U+06FF block this gate's predicate is a range over,
      // so `٤٠` is Arabic to it and to a reader. The three numbers the screen shows
      // are `٤٠` (the total, which also appears inside `completeMessage` — hence two
      // separate runs of it on screen), `١٠` (this answer's points) and `٦` (the
      // longest run), and `arabicIndicDigits` is the one function that produces all
      // three.
      arabicIndicDigits(40),
      arabicIndicDigits(10),
      arabicIndicDigits(6),
    ];

    testWidgets('the Arabic arm, with the live-shaped submit response', (
      WidgetTester tester,
    ) async {
      await pumpResult(
        tester,
        locale: const Locale('ar'),
        result: const SubmitResult(
          questionId: 'question-group-3',
          isCorrect: true,
          pointsEarned: 10,
          currentTotalPoints: 40,
          currentStreak: 4,
          longestStreak: 6,
          readingCompleted: true,
        ),
      );

      await expectArabicTypography(
        tester,
        screen: '/result',
        expectedArabic: arabic,
        vacuousBecause: null,
      );
    });

    // ## AND THE **WRONG** ARM, WHICH IS THE STATE THAT BREAKS THE LIST ABOVE
    //
    // The list is one screen's runs, and one screen has **four** states. The gate
    // above declares the correct-and-complete one, so the three others are rendered by
    // no test in this family — and the wrong arm is the interesting one, because it is
    // the only state where **every number is zero**:
    //
    // ```text
    // is_correct: false, points_earned: 0, current_streak: 0, longest_streak: 0
    // → ٠   twice  (the streak pill's count and the longest run's)
    // → اليوم ٠  (the pill's own label for a zero streak)
    // → ليس هذه المرة…  (incorrectMessage, which never appears in the list above)
    // ```
    //
    // `ArabicIndicDigits(0)` is `U+0660`, inside the U+0600–U+06FF block this gate's
    // predicate is a range over, so a bare `٠` is a run of Arabic to it and to a
    // reader — which is the whole argument the three non-zero numerals above make.
    // Declaring the wrong arm is what turns that argument from "the predicate accepts
    // digits" into "the screen's zero state is gated".
    //
    // **`partialMessage` is still undeclared**, and that is recorded rather than
    // papered over: it needs a *correct* answer with `reading_completed: false`, which
    // is a fifth `SubmitResult` and a third pump, for a sentence that differs from
    // `completeMessage` only in its second clause. The family gate covers the numeral
    // rule and the two divergent headline sentences; the per-string script check that
    // would cover the fifth state is `test/l10n/app_localizations_test.dart`'s, over the ARB itself.
    //
    // **And the list below is NOT `arabic` plus two entries.** `expectArabicTypography`
    // asserts in **both** directions — nothing declared may go unrendered, and nothing
    // rendered may go undeclared — so carrying the correct arm's `completeMessage`,
    // `اليوم ٤` and `٤٠`/`١٠`/`٦` into a screen that shows none of them fails the first
    // half. Measured, the wrong arm renders exactly:
    ///
    /// ```text
    /// ٠ | نقاط | ليس هذه المرة. كل سؤال يُحتسب. | اليوم ٠ | ٠ | هذه الإجابة | ٠ | أطول سلسلة
    /// ```
    ///
    /// plus the two button captions. So `٠` appears **three** times on screen and the
    /// two stat labels are unchanged, while the score, the pill and the headline are
    /// all different strings from the correct arm's.
    ///
    /// **The caption in that line was `نقطة` and is now `نقاط`,** because
    /// `resultTotalCaption` became a plural and `0` is Arabic's `zero` class. This is
    /// the one place in the file where ARB changed what a reader sees rather than
    /// only how it is spelled, and it changed it in the direction the grammar points.
    testWidgets('the WRONG arm, where every number is `٠`', (
      WidgetTester tester,
    ) async {
      const SubmitResult wrong = SubmitResult(
        questionId: 'question-group-3',
        isCorrect: false,
        pointsEarned: 0,
        currentTotalPoints: 0,
        currentStreak: 0,
        longestStreak: 0,
        readingCompleted: false,
      );
      await pumpResult(tester, locale: const Locale('ar'), result: wrong);

      await expectArabicTypography(
        tester,
        screen: '/result (wrong)',
        expectedArabic: <String>[
          // The headline sentence the correct arm never shows.
          ar.resultIncorrectMessage,
          // The score — a bare `٠`, from `currentTotalPoints: 0`.
          arabicIndicDigits(0),
          // The score's caption — **NOT unchanged by the state any more.** The score
          // is `٠`, which is Arabic's `zero` class, so this arm renders `نقاط` where
          // the correct arm's `٤٠` rendered `نقطة`. The doc block above records the
          // measured line and has been corrected with it.
          ar.resultTotalCaption(0),
          // The pill: **the label and a zero count**, so the string differs from the
          // correct arm's `اليوم ٤` in its numeral and nowhere else.
          ar.streakLabelFor(current: 0, longest: 0),
          // The two stat tiles — label unchanged, value `٠` in both.
          ar.resultThisAnswer,
          ar.resultBestRun,
          // Both buttons, unchanged by the state.
          ar.resultReflectAgain,
          ar.resultBackHome,
        ],
        vacuousBecause: null,
      );
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      await pumpResult(
        tester,
        result: const SubmitResult(
          questionId: 'question-group-3',
          isCorrect: true,
          pointsEarned: 10,
          currentTotalPoints: 40,
          currentStreak: 4,
          longestStreak: 6,
          readingCompleted: true,
        ),
      );
      await _expectNoArabic(tester, '/result');
    });
  });

  group('`/settings`', () {
    // **The one screen still vacuous**, and decision 79's rule is that saying so is
    // what makes it a pass rather than a silence. Phase 9 writes it.
    testWidgets('the gate is installed and reports itself VACUOUS', (
      WidgetTester tester,
    ) async {
      await _pumpStub(tester, const SettingsPage());
      await expectArabicTypography(
        tester,
        screen: '/settings',
        expectedArabic: const <String>[],
        vacuousBecause:
            '/settings is a stub: its whole body is the literal '
            '`Placeholder for /settings` and the route name, both Latin. Phase 9 '
            'writes this screen, and this gate is what will hold its Arabic runs to '
            'Amiri from their first commit.',
      );
      await expectNoTofuInAnyRun(tester, screen: '/settings');
      expect(
        familyOfText(tester, 'Placeholder for /settings'),
        isNot(EvaTypography.arabicFamily),
        reason:
            'this screen is Latin-only today. If this ever becomes false, the screen '
            'has been given Arabic and `vacuousBecause` is stale — which is the '
            'failure this assertion exists to make loud.',
      );
    });
  });

  group('the ARM ITSELF, and what the two hard-coded states of the rule do', () {
    // The three properties the whole mechanism rests on, tested as a plain function
    // with no widget tree — so they are a unit test rather than a widget test, and a
    // reader can check them in three lines.
    test('Amiri is the only bundled family that can render Arabic', () {
      for (final String family in kBundledFontFamilies) {
        expect(
          familyCovers(family, <int>[0x0628, 0x0644]),
          family == EvaTypography.arabicFamily,
          reason:
              '$family\'s Arabic coverage decides whether the Arabic arm is tofu. '
              'Measured from the bundled `cmap`s.',
        );
      }
    });

    test(
      'and it carries ASCII too, which is what makes a `Failure.message` safe',
      () {
        expect(
          familyCovers(EvaTypography.arabicFamily, <int>[
            0x20,
            0x30,
            0x39,
            0x41,
            0x5A,
            0x61,
            0x7A,
            0x2014,
            0x3A,
            0x2F,
          ]),
          isTrue,
          reason:
              '`ErrorView` and `streak_flame_row` both render a `Failure.message`, '
              'which is the **server\'s** text verbatim — English today, and '
              'whatever the server writes tomorrow. Swapping to Amiri under RTL is '
              'only safe if Amiri renders the Latin too.',
        );
      },
    );

    test(
      '`arabicAware` is exactly identity under LTR and a family swap under RTL',
      () {
        const TextStyle base = TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEAE8F5),
          letterSpacing: 0.4,
        );
        final TextStyle ltr = arabicAware(base, TextDirection.ltr);
        expect(
          ltr.fontFamily,
          isNull,
          reason: 'the Latin arm keeps its inherited family',
        );
        expect(ltr.fontSize, base.fontSize);
        expect(ltr.fontWeight, base.fontWeight);
        expect(ltr.color, base.color);
        expect(ltr.letterSpacing, base.letterSpacing);

        final TextStyle rtl = arabicAware(base, TextDirection.rtl);
        expect(rtl.fontFamily, EvaTypography.arabicFamily);
        // **Nothing else moves.** A family swap that also changed a size or an ink
        // would be a layout change wearing a typography fix's clothes, and §14 is the
        // gate that would have caught it only after the golden moved.
        expect(rtl.fontSize, base.fontSize);
        expect(rtl.fontWeight, base.fontWeight);
        expect(rtl.color, base.color);
        expect(rtl.letterSpacing, base.letterSpacing);
      },
    );

    test(
      '`arabicAwareFamily` agrees with it, and never returns an empty name',
      () {
        expect(
          arabicAwareFamily(TextDirection.rtl, EvaTypography.uiFamily),
          EvaTypography.arabicFamily,
        );
        expect(
          arabicAwareFamily(TextDirection.ltr, EvaTypography.uiFamily),
          EvaTypography.uiFamily,
        );
        expect(
          arabicAwareFamily(TextDirection.rtl, EvaTypography.monoFamily),
          EvaTypography.arabicFamily,
          reason:
              'the Latin face is the *starting point*, not the answer — a caller that '
              'passed Space Mono must still get Amiri on the Arabic arm.',
        );
      },
    );

    test('the Arabic predicate is a BLOCK range, and `رجوع` proves it', () {
      // The four codepoints the first version sampled. `رجوع` is none of them, which
      // is why thirty tofu boxes shipped behind a green gate.
      //
      // ## READ OFF THE ARB, NOT TYPED HERE — and this file used to type it
      //
      // It was `رجوع` four times over, a hand-typed copy of `readingBack`'s Arabic
      // value. `reading_strings_test.dart`'s own doc made the argument against that
      // — *"a hand-typed copy of a corpus string is a second declaration; if the
      // fixture's text is ever corrected, the assertion silently stops testing
      // anything"* — and the string was about to be transcribed into an ARB. So the
      // probe reads the one declaration. The test is unchanged in strength: it is
      // still this predicate's own proof, and it is now proof about a string the app
      // actually ships.
      final String back = AppLocalizationsAr().readingBack;
      expect(
        back,
        'رجوع',
        reason:
            'the ARB is the declaration now — if the translator changes this, this '
            'probe is measuring a different string and the codepoints below may not '
            'be absent from it any more, which is the point of the assertions',
      );
      expect(containsArabic(back), isTrue);
      expect(back.runes, isNot(contains(0x0628)));
      expect(back.runes, isNot(contains(0x0644)));
      expect(back.runes, isNot(contains(0x064E)));
      expect(back.runes, isNot(contains(0x0665)));
      // All four blocks, not just the one the app's own strings happen to use.
      expect(isArabicRune(0x0600), isTrue);
      expect(isArabicRune(0x0750), isTrue);
      expect(isArabicRune(0xFB50), isTrue);
      expect(isArabicRune(0xFE70), isTrue);
      expect(isArabicRune(0x06FF), isTrue);
      expect(isArabicRune(0x077F), isTrue);
      expect(isArabicRune(0xFDFF), isTrue);
      expect(isArabicRune(0xFEFF), isTrue);
      // The boundaries either side, which is where a sloppy `<=` becomes `<`.
      expect(isArabicRune(0x05FF), isFalse);
      expect(isArabicRune(0x0700), isFalse);
      expect(isArabicRune(0x074F), isFalse);
      expect(isArabicRune(0x0780), isFalse);
      expect(isArabicRune(0xFB4F), isFalse);
      expect(isArabicRune(0xFE00), isFalse);
      expect(isArabicRune(0xFE70 - 1), isFalse);
      // And it is not a "looks Arabic" test: Latin and digits are not.
      expect(containsArabic('John 3:1-5'), isFalse);
      expect(containsArabic('Continue'), isFalse);
      expect(containsArabic('٤'), isTrue, reason: 'Arabic-Indic digit four');
      expect(containsArabic('٤'), isTrue);
    });
  });
}

AuthBloc _authBloc() {
  final FakeAuthRepository repo = FakeAuthRepository(AuthLocalDataSource());
  final AuthBloc bloc = AuthBloc(
    signIn: SignIn(repo),
    getCurrentSession: GetCurrentSession(repo),
    signOut: SignOut(repo),
  );
  addTearDown(bloc.close);
  return bloc;
}

Future<void> _pumpStub(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: const Locale('ar'),
      // Derived from the locale, for `login_harness.dart`'s recorded reason.
      textDirection: TextDirection.rtl,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: page,
    ),
  );
  await tester.pump();
}

/// No rendered run on [screen] contains an Arabic character.
///
/// **This is the control, and it is not redundant.** With no Arabic on screen, the
/// Arabic gate above is vacuously true — so a screen that silently stopped honouring
/// the locale (a harness that forgot `ar`, a `Directionality` the page ignored, a
/// `MaterialApp` that resolved `ar` back to `en`) would pass the Arabic assertions
/// and this is what would catch it.
Future<void> _expectNoArabic(WidgetTester tester, String screen) async {
  final List<RenderedRun> arabic = await arabicRuns(tester);
  expect(
    arabic,
    isEmpty,
    reason:
        '$screen was pumped at `en` and rendered Arabic: '
        '${arabic.map((RenderedRun r) => "`${r.label}`").join(", ")}. Either the '
        'strings are not localised for this arm or the locale did not reach the '
        'page.',
  );
}
