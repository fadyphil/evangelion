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
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/auth_strings.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_strings.dart';
import 'package:evangelion/features/quiz/presentation/pages/quiz_page.dart';
import 'package:evangelion/features/reading/domain/arabic_digits.dart';
import 'package:evangelion/features/reading/presentation/reading_strings.dart';
import 'package:evangelion/features/result/presentation/pages/result_page.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/arabic_typography_gate.dart';
import 'support/design_system_harness.dart';
import 'support/font_coverage.dart';
import 'support/home_harness.dart';
import 'support/login_harness.dart';
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
    /// second copy of a string that already lives in `HomeStrings` or in the live
    /// payload. Four went wrong on the first run — a missing combining mark is
    /// invisible in a diff and the failure then reads as "the widget rendered the
    /// wrong string" rather than "the test typed the wrong string". So the UI strings
    /// come from `HomeStrings.ar()` and the payload strings from the fixture, and
    /// nothing here is transcribed.
    ///
    /// The one composed value, the greeting's lead-in, is `greetingLead`'s own
    /// output for the period the fixture's clock resolves to — which is exactly the
    /// derivation the panel uses, and is asserted to be a *distinct* string from the
    /// rest so a change to it cannot silently collapse two runs into one.
    const HomeStrings ar = HomeStrings.ar();
    final List<String> arabic = <String>[
      ar.greetingLead(GreetingPeriod.morning, hasName: true),
      ar.streakResting,
      // **`continueReading`, not `readingComplete`** — and the reason is the
      // fixture, not a slip: `liveArabicScripture.isFullyCompleted` is **false**,
      // because `home_harness.dart`'s doc says the Arabic arm must be unfinished so
      // both branches of the eyebrow are reachable. The completed branch is gated by
      // its own test below rather than being assumed here.
      ar.continueReading,
      liveArabicScripture.verses.first.textClean!,
      liveArabicScripture.reference,
      ar.continueLabel,
      ar.startReflection,
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
            if (run != ar.continueReading) run,
          ar.readingComplete,
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
          ar.streakResting,
          // The retry label — an Arabic run this phase's own first draft of the list
          // forgot, which the gate caught. That is the gate working.
          ar.retry,
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
    const LoginStrings ar = LoginStrings.ar();
    final List<String> arabic = <String>[
      ar.tagline,
      // `EvaTextField` renders its label as `label.toUpperCase()`, and Arabic has no
      // case — so the rendered run is the field value itself. Asserting the table's
      // value is correct *because* the transform is a no-op here, and the widget's doc
      // says so rather than leaving it to be re-derived.
      ar.emailLabel,
      ar.passwordLabel,
      ar.signIn,
      ar.forgotPassword,
      ar.newHere,
      ar.createAccount,
      ar.divider,
      ar.continueWithGoogle,
      ar.continueWithApple,
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
      // `LoginStrings`, which changes `AuthState`'s public shape and is a domain
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
    /// Built from the fixture and `ReadingStrings.ar()`, for `/`'s reason: a
    /// hand-typed Arabic list in a test is a second copy of the corpus.
    /// Built from the fixture and the string table, for `/`'s reason: a hand-typed
    /// Arabic list in a test is a second copy of the corpus.
    const ReadingStrings ar = ReadingStrings.ar();
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
      ar.beginReflection,
      // Site 2 — the caption, with Arabic-Indic digits.
      '${arabicIndicDigits(1)} ${ar.questionSingular}',
      // Sites 7, 8 and 9 — the three control tooltips, which have **no prototype
      // line**: `ReadingEnScreen.tsx:14-16` and `ReadingArScreen.tsx:21-29` are bare
      // `<button>`s with an inline `<svg>` and no label, so §14 forced these three
      // strings into this client. They are the 30 tofu boxes decision 71 records.
      ar.back,
      ar.textSize,
      '${ar.bookmark} — ${ar.unavailableSuffix}',
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
          // `ReadingStrings.ar`'s own two new strings. They were
          // `'Decrease font size'` / `'Increase font size'` hard-coded in
          // `FontSizeStepper`, so before this phase this arm rendered two English
          // sentences in a panel on a bilingual screen.
          const ReadingStrings.ar().decreaseFontSize,
          const ReadingStrings.ar().increaseFontSize,
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
  for (final (String route, Widget page, String visible)
      in <(String, Widget, String)>[
        ('/quiz', const QuizPage(), 'Placeholder for /quiz'),
        ('/result', const ResultPage(), 'Placeholder for /result'),
        ('/settings', const SettingsPage(), 'Placeholder for /settings'),
      ]) {
    group('`$route`', () {
      testWidgets('the gate is installed and reports itself VACUOUS', (
        WidgetTester tester,
      ) async {
        await _pumpStub(tester, page);
        await expectArabicTypography(
          tester,
          screen: route,
          expectedArabic: const <String>[],
          vacuousBecause:
              '$route is a stub: its whole body is the literal `$visible` and the '
              'route name, both Latin. Phase 8 ($route) and Phase 9 write this '
              'screen, and this gate is what will hold their Arabic runs to Amiri '
              'from their first commit.',
        );
        // Not vacuous after all, in the one direction that can be checked: the two
        // Latin runs are real, and the cmap assertion covers them.
        await expectNoTofuInAnyRun(tester, screen: route);
        expect(
          familyOfText(tester, visible),
          isNot(EvaTypography.arabicFamily),
          reason:
              'this screen is Latin-only today. If this ever becomes false, the '
              'screen has been given Arabic and `vacuousBecause` is stale — which '
              'is the failure this assertion exists to make loud.',
        );
      });
    });
  }

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
      expect(containsArabic('رجوع'), isTrue);
      expect('رجوع'.runes, isNot(contains(0x0628)));
      expect('رجوع'.runes, isNot(contains(0x0644)));
      expect('رجوع'.runes, isNot(contains(0x064E)));
      expect('رجوع'.runes, isNot(contains(0x0665)));
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
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
