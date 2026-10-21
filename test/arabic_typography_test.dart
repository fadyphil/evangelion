/// **Defect #2 on all eight screens, from one harness.**
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
/// ## EIGHT SCREENS, NO EXEMPTIONS
///
/// AGENT_CONTEXT §2's route table names **eight** routes, and this file has a group
/// for every one of them: `/login`, `/`, `/reading`, `/quiz`, `/result`, `/settings`,
/// `/communion` and — since Task 5.6 — `/journey`.
///
/// **The three former stubs are built now, and this header used to say they were
/// not.** It said that `/quiz`, `/result` and `/settings` render
/// `Placeholder for /quiz` and nothing else, and that each of them declared an
/// **empty** Arabic list with a `vacuousBecause` — which was decision 79's honest
/// report at the time (Phase 8 lifted `/quiz` and `/result`, Phase 9 lifted
/// `/settings`) and stopped being true long before the eighth screen landed.
/// Every one of the eight groups now declares a **non-empty** list, and
/// `expectArabicTypography` *refuses* a `vacuousBecause` on a screen that has
/// Arabic runs — so a group that went back to declaring nothing would be red
/// rather than quiet.
///
/// Their capability is not asserted in the abstract; it is proved by the per-screen
/// mutation in the review, which plants a wrong-family Arabic run on each of them.
///
/// ## THE THREE ARMS EVERY SCREEN GETS
///
/// 1. the **declared set** of Arabic runs, compared for equality in both directions;
/// 2. every one of them in Amiri — the token *and* the literal string;
/// 3. **every character on screen** carried by the family that renders it — the
///    arm that catches a run the app's own strings do not cover: a
///    `Failure.message`, the framework's own Arabic label, a `·` or a `×`.
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

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:evangelion/app/router/app_router.dart';
import 'package:evangelion/core/common/app_config.dart';
import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/sky_entry.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/user_role.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/core/domain/repositories/sky_repository.dart';
import 'package:evangelion/core/domain/repositories/streak_repository.dart';
import 'package:evangelion/core/navigation/auth_status.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/dock/presentation/widgets/lumen_dock.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
import 'package:evangelion/features/journey/data/datasources/medal_local_data_source.dart';
import 'package:evangelion/features/journey/data/repositories/medal_repository_impl.dart';
import 'package:evangelion/features/journey/domain/journey_rings.dart';
import 'package:evangelion/features/journey/domain/medal.dart';
import 'package:evangelion/features/journey/domain/usecases/get_journey_reader_session.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_sky_count.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_history.dart';
import 'package:evangelion/features/journey/domain/usecases/load_journey_streak_summary.dart';
import 'package:evangelion/features/journey/presentation/bloc/journey_cubit.dart';
import 'package:evangelion/features/journey/presentation/journey_l10n.dart';
import 'package:evangelion/features/journey/presentation/pages/journey_page.dart';
import 'package:evangelion/features/journey/presentation/widgets/journey_account_rows.dart';
import 'package:evangelion/features/leaderboard/data/datasources/cheer_local_data_source.dart';
import 'package:evangelion/features/leaderboard/data/repositories/local_cheer_repository.dart';
import 'package:evangelion/features/leaderboard/domain/leaderboard_ranking.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/get_board_reader_session.dart';
import 'package:evangelion/features/leaderboard/domain/usecases/load_leaderboard.dart';
import 'package:evangelion/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:evangelion/features/leaderboard/presentation/pages/communion_page.dart';
import 'package:evangelion/features/leaderboard/presentation/widgets/communion_countdown_line.dart';
import 'package:evangelion/features/quiz/presentation/bloc/quiz_bloc.dart';
import 'package:evangelion/features/quiz/presentation/quiz_l10n.dart';
import 'package:evangelion/features/quiz/presentation/result_l10n.dart';
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/settings/domain/usecases/get_settings.dart';
import 'package:evangelion/features/settings/domain/usecases/update_settings.dart';
import 'package:evangelion/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/features/settings/presentation/workshop_logic.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/app_localizations_en.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'support/arabic_typography_gate.dart';
import 'support/contract_payloads.dart';
import 'support/design_system_harness.dart';
import 'support/font_coverage.dart';
import 'support/home_harness.dart' hide CountingReadingRepository;
import 'support/login_harness.dart';
import 'support/quiz_harness.dart';
import 'support/reading_harness.dart';
import 'support/settings_harness.dart';

void main() {
  group('`/` — the home screen', () {
    /// The Arabic runs the redesigned `/` renders, measured off the rendered tree.
    ///
    /// ## BUILT FROM THE TABLES, THE FIXTURES AND THE WIDGETS — **NOT** TYPED OUT
    ///
    /// The old suite's lesson stands, and Phase 5.2 added a third source: the two
    /// cards' eyebrows are `Text.rich` compositions, and the gate reads a rich
    /// text as **one run per span** (`renderedRuns`' doc says why a lossy join
    /// would hide a wrong-family span). So each eyebrow contributes TWO entries —
    /// the label-with-separator and the reference — and both come from the same
    /// derivation the widget runs: the label from `AppLocalizationsAr()`, the
    /// reference from the fixture.
    ///
    /// The one composed value the old list carried (`greetingLead`) is gone with
    /// the sentence greeting: the redesign's greeting is `peaceWith(name)`, whose
    /// name is the session's **first token** (`home_l10n.dart`'s `firstNameOf`) —
    /// `سلام، David` on the Arabic arm with this fixture's `David Mina`, which is
    /// a mixed-script run and is in the list *because* it is what the reader
    /// actually sees.
    final AppLocalizations ar = AppLocalizationsAr();

    /// The runs every arm carries, whatever the reading resolved to.
    ///
    /// [reading] is `false` for the failed arm, whose reading section is an
    /// `ErrorView` — and the parameter, rather than a set-difference at the call
    /// site, is what the *fixture collision* forces: the day's card's Arabic
    /// reference and the last light's are the same string (`يوحنا 3: 1-5`), so
    /// removing "the reference" by value would remove the last light's too. The
    /// runs are filtered by **section**, never by value.
    List<String> sharedRuns({required bool reading}) => <String>[
      // The caption, the greeting and the chip: `home_l10n.dart`'s `greetingWord`
      // switch, `peaceWith`'s first-token join, and the unit beside the numeral.
      // The chip's numeral itself is NOT listed here and that is deliberate: `٠`
      // is in the gate's Arabic range, and it is asserted on its own below with
      // the family that carries it — see the tofu correction in `streak_chip.dart`.
      ar.greetingWord(GreetingPeriod.morning),
      ar.peaceWith(firstNameOf('David Mina')),
      // **The numeral is its own run, and it is Arabic script.** `٠` (U+0660) is
      // inside the gate's Arabic range, so the family gate already polices it —
      // this entry is what makes the *set* honest, and the row below asserts the
      // family that carries it. The first version of this list omitted it and the
      // gate answered with a rendered run nothing declared, which is the gate
      // working.
      ar.digits(0),
      ar.homeDays,
      // The day's card: the eyebrow's label span (` · ` included, exactly as the
      // widget writes it) and the reference span, then the verse. **Absent from
      // the failed arm**, whose reading section is an `ErrorView` and renders
      // none of them.
      if (reading) '${ar.homeVerseOfTheDay} · ',
      if (reading) liveArabicScripture.reference,
      if (reading) liveArabicScripture.verses.first.textClean!,
      // The last-light card, in its READY arm: the same eyebrow shape, the hint,
      // and the reference the server composed — read through the widget's own
      // `referenceFor` so the Arabic arm's spacing (`٢٣: ١-٦`) is the served one.
      '${ar.homeLastLight} · ',
      liveStreakHistoryEntry.referenceAr,
      ar.homeResumeHint,
      // The selah card and the library row, with their composed counts in this
      // arm's numerals (`digits`, which is `:988`'s `N`).
      ar.homeSelah,
      ar.selahSeconds(SelahCard.defaultSeconds),
      ar.homeTheLibrary,
      ar.scrollsOpen(scrolls: 6, open: 4),
    ];

    /// The two book cards a 320-wide surface builds first (`psalms`, `john`).
    ///
    /// **The caption is ONE run, and the first version of this list had it as
    /// two.** The carousel composes `category · count` into a single `Text`
    /// (`library_carousel.dart`'s caption), so the gate reads one run per card,
    /// and splitting it in the expectation fails with four entries the rendered
    /// tree never held — measured on this suite's first run.
    List<String> builtBookRuns() => <String>[
      'المزامير', '${ar.homeCategoryPoetry} · ${ar.verseCount(6)}', // psalms
      'يوحنا', '${ar.homeCategoryGospel} · ${ar.verseCount(5)}', // john
    ];

    testWidgets('the Arabic arm, with the live Arabic payload', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Right<Failure, ScriptureText>(liveArabicScripture),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/',
        expectedArabic: <String>[
          ...sharedRuns(reading: true),
          ...builtBookRuns(),
        ],
      );
      await expectNoTofuInAnyRun(tester, screen: '/');
    });

    testWidgets('and the chip\'s numeral is in Amiri, not the scripture face', (
      WidgetTester tester,
    ) async {
      // The run the list above deliberately omits, asserted on its own: `٠` is
      // inside the gate's Arabic range, so the family gate would already refuse
      // EB Garamond for it — this row exists to name the defect that was here,
      // because the first version of the chip rendered `digits(count)` in
      // `scriptureFamily` and the *browser* the prototype runs in falls back
      // per character while this client does not.
      final HomeHarness h = harness(
        reading: const Right<Failure, ScriptureText>(liveArabicScripture),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      expect(
        familyOfText(tester, ar.digits(0)),
        EvaTypography.arabicFamily,
        reason:
            'Arabic-Indic digits are Arabic script, and EB Garamond has '
            'zero Arabic glyphs — the prototype only escapes this because a '
            'browser falls back per character',
      );
    });

    testWidgets('and the same screen in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness();
      await pumpHome(tester, bloc: h.bloc);
      await _expectNoArabic(tester, '/');
    });

    testWidgets('the EMPTY last light replaces its two runs with one sentence', (
      WidgetTester tester,
    ) async {
      // `redesign.html:1192-1197`: `lastRef` becomes `—` (identical across the
      // arms, so NOT an Arabic run), the body becomes `noLight`, the hint is
      // gone with the tap, and the eyebrow\'s reference span disappears — so
      // this arm has one run fewer than the ready one and the body\'s sentence
      // is the longest string on the screen.
      final HomeHarness h = harness(
        reading: const Right<Failure, ScriptureText>(liveArabicScripture),
        history: const Right<Failure, List<StreakHistoryEntry>>(
          <StreakHistoryEntry>[],
        ),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/',
        expectedArabic: <String>[
          ...sharedRuns(reading: true)
              .where((String run) => run != ar.homeResumeHint),
          ...builtBookRuns(),
          ar.homeNoLight,
        ],
      );
    });

    testWidgets('the FAILED reading is gated on its own list, and its '
        '`Failure.message` renders in the ambient arm', (
      WidgetTester tester,
    ) async {
      final HomeHarness h = harness(
        reading: const Left<Failure, ScriptureText>(homeReadingFailure),
        streak: const Right<Failure, StreakSummary>(liveStreakSummary),
      );
      await pumpHome(tester, bloc: h.bloc, locale: const Locale('ar'));

      // The reading section has no payload, so the verse, the reference span and
      // the two built book cards are NOT declared here — a gate that declared
      // the ready screen\'s list on the failed one would fail for the wrong
      // reason and send the next reader looking for a layout bug. The greeting
      // block, the chip, the last-light card, the selah card and the library
      // row all render independently of the reading, which is the
      // four-independent-sections property.
      await expectArabicTypography(
        tester,
        screen: '/',
        expectedArabic: <String>[
          ...sharedRuns(reading: false),
          ...builtBookRuns(),
          // The retry label — the one run the reading's failure adds, in the
          // arm's family like every other app string. **The failure's own
          // message is deliberately NOT declared**: this fixture's message is
          // pure Latin (`verses` is absent…), so it is not an Arabic run, and
          // the family assertion below is about the *rendering rule* the
          // message is subject to, not about this fixture's characters.
          ar.homeRetry,
        ],
      );
      expect(
        familyOfText(tester, homeReadingFailure.message),
        EvaTypography.arabicFamily,
        reason:
            'the message is the SERVER\'s string, and the ambient arm decides '
            'the family it renders in — the same rule `retryLabelFamily` '
            'records for the retry label',
      );
    });
  });

  group('`/login`', () {
    /// The Arabic runs the redesigned login **paints** on an empty form.
    ///
    /// Phase 5.1 rebuilt the screen against `eva/redesign.html:503-511`, and the
    /// rebuild changed both the set and the mechanism. The old screen painted ten
    /// runs (labels, links, the divider, two social rows); the redesign paints
    /// **three**: the two bare fields' placeholders and the CTA — the only
    /// strings the prototype itself translates (`data-i18n="enter"` at `:508`,
    /// `emErr`/`pwErr` at `:976`). The wordmark, the tagline, the footer and the
    /// ghost labels are widget literals in both directions — the redesign renders
    /// them untranslated, and `app_localizations_test.dart`'s Latin-exception
    /// table says why that is a decision and not an omission.
    ///
    /// **The labels are deliberately NOT in this list, and that is the gate's own
    /// trap again:** `EvaTextField.showLabel` is `false` on this screen (the
    /// redesign's field is bare, `:506-507`), so `authEmailLabel`/
    /// `authPasswordLabel` live only in `Semantics(label:)` — never painted — and
    /// declaring them here fails the other half with `Declared but NOT rendered`.
    /// They are asserted by `login_accessibility_test.dart`, which reads the
    /// semantics tree, because that is the layer they exist on.
    ///
    /// Built from the string table, for the reason `/`'s list gives.
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      ar.authEmailHint,
      ar.authPasswordHint,
      ar.authEnterTheWord,
      // **The role picker's three option labels**, and they are painted runs:
      // `SegmentedControl` draws each option's label. The **track's** own name
      // (`authRoleLabel`) is deliberately **not** in this list — it lives in
      // `Semantics(label:)` and is never painted, and declaring a run that is
      // not rendered fails the other half of this gate with
      // "Declared but NOT rendered". The same trap the field labels record
      // below.
      ar.authRoleKid,
      ar.authRoleServant,
      ar.authRoleAdmin,
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

    testWidgets('the field validator\'s error is localized now, and the gap '
        'this gate used to pin is closed', (WidgetTester tester) async {
      await pumpLogin(tester, bloc: _authBloc(), locale: const Locale('ar'));
      await tester.enterText(find.byType(TextField).at(1), 'abc');
      await tester.pump();

      // **The family is the deliverable and it is asserted.** The error line is
      // `EvaTextField`'s helper row; `arabicAware` resolves it for the arm, so
      // the localized sentence renders in Amiri, not in a DM-Sans tofu box.
      expect(
        familyOfText(tester, ar.authPasswordTooShort),
        EvaTypography.arabicFamily,
        reason:
            'the field\'s error line must take the ambient arm\'s face, '
            'because the sentence is Arabic on this arm',
      );

      // **The recorded gap is CLOSED, and this is its closure note.** Phase 9
      // pinned `kShortPasswordMessage == "That password's too short"` and
      // `kRequiredMessage == 'This field is required'` as English literals the
      // Arabic arm would show, with the instruction: "this assertion goes red
      // the day someone fixes it — which is the point." Phase 5.1 is that day:
      // the redesign states one message per field (`redesign.html:1305-1306`),
      // the domain constants carry that wording as the log-canonical copy, and
      // the page renders the localized sentence **by presence**
      // (`state.passwordError != null`) — never by matching the domain's text.
      // The English literals are gone with the prototype that framed them.
      expect(
        kShortPasswordMessage,
        'password too short',
        reason:
            'the domain\'s log-canonical copy is the redesign\'s own wording '
            '(`redesign.html:976`); the reader\'s sentence lives in the ARB, '
            'not here',
      );
      // `kRequiredMessage` is **deleted**, not reworded: the redesign's
      // single-message-per-field model has no separate "required" complaint
      // (`redesign.html:1305-1306`). Its death is visible in
      // `login_credentials.dart` itself — the constant is gone, not deprecated —
      // so there is nothing here to assert without resurrecting it.

      // And the error state's painted set: the email placeholder is joined by
      // the redesign's own Arabic error sentence. The password's placeholder is
      // deliberately NOT declared — the reader has typed into that field, and a
      // placeholder only paints while the field is empty; its slot now holds
      // the typed value (masked) and the sentence below it.
      await expectArabicTypography(
        tester,
        screen: '/login',
        expectedArabic: <String>[
          ar.authEmailHint,
          ar.authEnterTheWord,
          ar.authPasswordTooShort,
          // **The role picker's three options** — they are painted whatever the
          // form's state is, so they belong in this list too. The track's own
          // name is not painted and is not here; see the list above.
          ar.authRoleKid,
          ar.authRoleServant,
          ar.authRoleAdmin,
        ],
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
      // Sites 1 and 4 — the **crumb**, which Task 5.3 rewrote as one composed line
      // (`ReadingStringsPhrases.crumbMeta`, `eva/redesign.html:1346`): the book
      // number, the verse count with its unit, and the lit-star count with its
      // unit. `liveArabicPassage.translation` — the metadata row's own `translation`
      // field, which the deleted `ReadingHeader` rendered — is **no longer on the
      // screen at all**; the field survives because other screens read it.
      ar.crumbMeta(
        category: '${liveArabicPassage.verses.first.bookNumber}',
        verses: liveArabicPassage.verses.length,
        litStars: 0,
      ),
      // The citation, which is the crumb's title and a run of its own.
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
      // Site 5 — the CTA's caption, **composed** and with this arm's numerals.
      // `readingBeginReflection` ("Begin reflection") and `readingCaptionFor` (an
      // ICU plural) were both retired in Task 5.3: the redesign's CTA has one line
      // and the prototype composes it as
      // `` `${tr('quiz')} · ${N(qEff)} ${tr('questions')}` `` (`eva/redesign.html:1347`),
      // so `ReadingStringsPhrases.quizCaption` is what renders and the count it is
      // given is the passage's own `questionCount`.
      ar.quizCaption(liveArabicPassage.questionCount),
      // The pill's `.pbtn` labels and the two dial options — the controls that
      // replaced the three tooltips.
      //
      // **The Arabic dial option is `ع`, one character and Arabic script**, so it
      // is a run in its own right; `SegmentedControl` gives it Amiri through
      // `arabicAware`, which is why this row can demand the Arabic family of a
      // single letter.
      ReadingPill.languageLabelArabic,
      // `ReadingPill.decreaseLabel` is `A−` — a Latin `A` and U+2212 — so it is
      // **not** an Arabic run and must not be declared here: declaring it makes the
      // gate report a declared run the tree never held, which is the error the
      // exact-set assertion exists to catch.
      //
      // The `listen` **label**, which is Arabic script and therefore an Arabic run in
      // its own right. Its *accessible name* is the longer composed string below —
      // a name and a label are two different strings on two different nodes, and the
      // gate reads the rendered one.
      ar.readingListen,
      // The five verse **numerals**, each with the single space `:1362` puts after
      // it (`<i>${…}</i> ${t}`), because the numeral is its own `TextSpan` and the
      // gate reads one run per span. Derived from the fixture's own count.
      for (int i = 0; i < liveArabicPassage.verses.length; i++)
        '${ar.digits(liveArabicPassage.verses[i].number)} ',
      // ## AND THREE NAMES THIS LIST CARRIED THAT ARE **NOT RENDERED RUNS**
      //
      // `readingBack` (the chevron), `readingBookmark` (the old tooltip) and
      // `listeningUnavailable(suffix)` are **accessible names**, not painted text:
      // the chevron is the character `‹`, the bookmark is a painted star, and the
      // pill's `listen` label is the bare word. The tofu gate reads what is on the
      // tree, so declaring a name here reported it as a run nothing drew — which is
      // the exact failure the gate exists to catch, and where it caught mine.
      //
      // **The names are asserted where they belong**: `reading_accessibility_test.dart`
      // owns every node's accessible name on this screen, and a name that is not
      // rendered is precisely the kind that is easiest to lose in a redesign.
      //
      // ## AND TWO STRINGS THIS LIST USED TO CARRY, WHICH THE REDESIGN UNRENDERED
      //
      // `readingTextSize` (the old `Aa` control's name) and `readingBookmark` (the
      // old tooltip) are **still in the ARB** — `/settings` and other screens read
      // them — but the redesigned reader paints its bookmark as a star
      // (`FourPointedStar`) and steps its type size with two `.pbtn`s, so neither
      // string is a rendered run any more. Declaring them would have been the exact
      // failure this gate was built to catch: a suite that declares a string to make
      // a test pass, for a string nothing draws.
    ];

    testWidgets('the Arabic arm, with the live Arabic passage', (
      WidgetTester tester,
    ) async {
      final ReadingHarness h = readingHarness(
        scripture: const Right<Failure, ScriptureText>(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/reading',
        expectedArabic: arabic,
      );
      await expectNoTofuInAnyRun(tester, screen: '/reading');
    });

    testWidgets('the pill\'s four labels are gated, and one of them is Arabic', (
      WidgetTester tester,
    ) async {
      // **The `Aa` disclosure this row replaced is gone with the redesign.** The old
      // screen had a panel opened by an `Icons.format_size` control, and this row
      // gated the two strings behind that tap. `eva/redesign.html:550-551` writes
      // the stepper as two `.pbtn`s — `A−` and `A+` — **always visible**, with no
      // panel and no `format_size` icon anywhere in `:540-560`.
      //
      // So there is nothing behind a tap any more, and this row is the claim that
      // replaced it: the three Latin labels and the one Arabic word are all on
      // screen at once, and the Arabic one is the only one that is Arabic script.
      final ReadingHarness h = readingHarness(
        scripture: const Right<Failure, ScriptureText>(liveArabicPassage),
      );
      await pumpReading(tester, cubit: h.cubit, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/reading',
        expectedArabic: <String>[
          ...arabic,
          // `ReadingPill`'s own labels, declared here as well as in the list above
          // because this row is about **them**: the gate is exact-set, so a label
          // added to the screen without a row here fails — which is the property
          // that let the tofu below be measured in the first place.
        ],
      );
    });
    testWidgets(
      'and in English renders Arabic in exactly ONE place — the dial',
      (WidgetTester tester) async {
        // ## WHY THIS ROW IS NO LONGER "NO ARABIC AT ALL", AND WHAT IT BECAME
        //
        // The other screens still assert exactly that, and for them it holds. This
        // one stopped being true on its first run of the redesigned reader, and the
        // reason is the redesign: `eva/redesign.html:554` writes the language control
        // as **two options on both arms** —
        // `<button class="on" data-l="en">EN</button><button data-l="ar">ع</button>` —
        // so an English reader is shown the Arabic option of the control that would
        // take them to the Arabic arm. `ع` is one character and it is Arabic script,
        // so it is an Arabic run on an English screen, by design.
        //
        // The old reader had no such control on the arm's face (its language switch
        // lived in a panel), so "renders no Arabic at all" was true here and the row
        // was free. It is not free now, and **the row is worth keeping**: it is what
        // stops a *second* Arabic string from appearing on the English arm, which is
        // the defect a redesign is most likely to introduce — a string left in the
        // wrong arm's table, or a widget keyed on the wrong locale.
        final ReadingHarness h = readingHarness();
        await pumpReading(tester, cubit: h.cubit);

        final List<RenderedRun> arabic = await arabicRuns(tester);
        expect(
          arabic.map((RenderedRun r) => r.label).toSet(),
          <String>{ReadingPill.languageLabelArabic},
          reason:
              'the English arm must render exactly one Arabic run — the dial\'s own '
              'Arabic option — and no more. A second one is a string that leaked '
              'across the arms, and this is where it is cheapest to find.',
        );

        // And it is in the Arabic face, which is the part that was tofu before
        // `SegmentedControl` grew `labelFamilyOf`: `eva/redesign.html:186` keys that
        // face on the *option*, so the English arm's `ع` needs it too.
        expect(arabic.single.family, EvaTypography.arabicFamily);
      },
    );
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
      // The appbar crumb — the payload's own reference, composed with the arm's
      // `quizRefraction` (`redesign.html:565`, filled at `:1348`). It replaced the
      // old `questionProgress` run when the redesign removed the count sentence.
      ar.quizCrumb(liveArabicQuizPassage.reference),
      // The score's numeral — `redesign.html:566`'s `✦ N`, with the star painted
      // and the digits the arm's own.
      ar.digits(0),
      // The question text — the **payload** arm again, and the one this list was
      // missing when the gate first fired on this screen. The failure named it
      // exactly: `Declared but NOT rendered: {تحقق من الإجابة}`, `Rendered: … ما اسم
      // الفريسي الذي جاء إلى يسوع ليلاً؟`. An option list is not a question.
      liveArabicQuestion.prompt,
      // The four option texts: the **payload** arm, so `QuizOptionCard`'s required
      // `ReadingLanguage` is the only thing that can put them in Amiri.
      ...liveArabicQuestion.options.values,
    ];
    // **`ar.quizProgress` IS DELIBERATELY NOT IN THE LIST, and that is a fact about the
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
    // other's coverage. `ar.quizExit` is the same category: the redesign's bare `‹`
    // carries a `Semantics` name and paints no string.

    testWidgets('the Arabic arm, with the live Arabic question', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveArabicQuizPassage),
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
      );
    });

    testWidgets('and the GRADED card is gated too', (
      WidgetTester tester,
    ) async {
      // The verdict is the one run that exists only **after** a check, and under
      // the redesign it lives on the card rather than in a banner
      // (`redesign.html:350-359`). Its own gate needs its own pump — the same
      // reason `/reading`'s `Aa` disclosure has one.
      // **`quizBlocWith`, not a hand-built bloc**: decision 20's rule is that the bloc
      // is built in the test body, and this suite already imports
      // `home_harness.dart`, whose `CountingReadingRepository` collides with
      // `reading_harness.dart`'s by name. The harness takes the collision away, which
      // is decision 47's argument one layer up: one rule, one place.
      final ({QuizBloc bloc, CountingReadingRepository readings}) fixture =
          quizBlocWith(
            const Right<Failure, ScriptureText>(liveArabicQuizPassage),
          );
      await pumpQuiz(tester, bloc: fixture.bloc, locale: const Locale('ar'));

      // **Read off the fixture, not typed here.** A hand-typed copy of a corpus
      // string is the "second declaration" this gate's own doc warns against: if the
      // fixture's option text is ever corrected, the tap silently misses and the
      // card is never graded, which fails as *"the verdict is absent"* and reads as
      // the gate working. `liveArabicQuestion` is the one transcription.
      await tester.tap(find.text(liveArabicQuestion.options['A']!));
      await pumpQuizFrames(tester, 2);
      await tester.tap(find.text(ar.quizCheckAnswer));
      await pumpQuizFrames(tester, 4);

      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is QuizOptionCard &&
              widget.state == QuizOptionState.correct,
        ),
        findsOneWidget,
      );
      await expectArabicTypography(
        tester,
        screen: '/quiz',
        // Same reasoning as the arm above, and for two more runs: the CTA's new
        // label and the score's new numeral. `correctSuffix` is *not* here — like
        // `ProgressBeads`' label it is a semantics-only string, and
        // `quiz_page_test.dart`'s spoiler group is what reads it.
        //
        // **The ready arm's `ar.digits(0)` is removed, not left in.** The score moved
        // to the submit response's `pointsEarned`, so the graded screen paints `١٠`
        // where it painted `٠`; keeping both would fail the gate's
        // `Declared but NOT rendered` half, which is the half that caught this.
        expectedArabic: <String>[
          ...arabic.where((String run) => run != ar.digits(0)),
          ar.digits(contractSubmitAnswerFixture.pointsEarned),
          ar.quizSeeResults,
        ],
      );
    });

    testWidgets('and the EMPTY state is gated too', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS ARM EXISTS, AND IT IS A **GAP** THAT WAS OPEN
      //
      // `/quiz` renders the **shared** `EmptyState` when the session has no
      // questions, and the empty state's two strings are Arabic. Before Task
      // 5.5, `EmptyState` painted its title in `headlineMedium` (the display
      // serif, EBGaramond) and its message in `bodyMedium` (the UI sans,
      // Inter) with **no `arabicAware`** — and **neither family carries a single
      // Arabic glyph**, so the whole empty screen was a row of tofu boxes, one
      // per character.
      //
      // **This group had no arm for it**, which is how a shared widget's defect
      // stayed invisible on the screen that had it first: the gate was
      // installed on `/quiz` and did not look at the empty state. The defect was
      // found on `/communion`, whose group does have an empty-state arm.
      //
      // So the arm is here to close the gap, not because the fix needs it — the
      // fix landed in `empty_state.dart` and this arm is what keeps it.
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(arabicQuizPassageWithoutQuestions),
      );
      await pumpQuiz(tester, bloc: bloc, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/quiz (empty)',
        // The empty state is the **only** thing on this screen, so the declared
        // set is the two strings and nothing else — which is what the
        // exact-set assertion is for.
        expectedArabic: <String>[
          ar.quizNoQuestionsTitle,
          ar.quizNoQuestionsMessage,
        ],
      );
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      final QuizBloc bloc = quizBloc(
        const Right<Failure, ScriptureText>(liveEnglishQuizPassage),
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

  group('`/settings` — the Workshop', () {
    // ------------------------------------------------------------------------
    // THE SCREEN, AND WHY THIS GROUP IS A **REWRITE** RATHER THAN AN EDIT
    // ------------------------------------------------------------------------
    //
    // `/settings` was the **last** screen to get its Arabic, in Phase 9, and it
    // was the **smallest**: three groups, five controls, and a declared list of
    // **sixteen** runs. Task 5.7 replaced the screen with the Workshop —
    // `eva/redesign.html:638-700`, **seven groups and thirty-three rows** — and
    // the list below is a rewrite of the Phase-9 one: every dead key removed,
    // every new key added, and the one run the redesign adds that the old
    // screen never had — the restore toast — given an arm of its own.
    //
    // ## WHAT DIED, AND WHY NONE OF IT IS A RUN ANY MORE
    //
    // | the Phase-9 key | what replaced it |
    // | --- | --- |
    // | `settingsAppearance`, `settingsReading` | the two headers the redesign does not have. `:645`, `:649`, `:651`, `:666`, `:682`, `:690` and `:696` are the **seven** it does, and `SettingsGroup`'s own doc says "seven of them" — which is now true of this screen. |
    // | `settingsTheme`, `settingsThemeLight`, `settingsThemeDark`, `settingsThemeSystem` | the three-segment theme picker is **gone**: `:650` holds **one** control, the Daylight toggle. |
    // | `settingsFontSize` | `settingsTypeSize` — the prototype's "Type size" (`:693`), not Phase 9's "Font size". |
    // | `settingsDefaultLanguage`, `settingsLanguageSheetTitle` | the language **sheet** is gone: `:646-648` is a two-segment track. |
    // | `settingsMotionOn`, `settingsMotionOff` | **dead, and gone from the ARB with them**: the screen names every switch by its **row title** in both arms, so the position words are read by nothing. |
    //
    // **And `settingsVersion` is not a run either.** It is the app bar's version
    // chip's **accessible name** (`_VersionChip`'s `Semantics(label:)`), and an
    // accessible name never reaches a glyph buffer — the same category error
    // `/quiz`'s `quizProgress` records. The chip **paints**
    // `AppConfig.appVersion`, and that is one of the eleven Latin runs below.
    //
    // ## THE LIST IS BUILT FROM THE ARB, NEVER TRANSCRIBED
    //
    // For `/`'s reason: a hand-typed Arabic list in a test is a second copy of
    // the corpus, and a dropped combining mark is invisible in a diff and reads
    // as "the widget rendered the wrong string" instead of "the test typed the
    // wrong string".
    final AppLocalizations ar = AppLocalizationsAr();

    /// The Arabic runs the Workshop paints on its ready arm.
    ///
    /// ## AND THE ORDER IS THE **PROTOTYPE'S DOM ORDER**
    ///
    /// `:645`, `:649`, `:651`, `:666`, `:682`, `:690`, `:696` — the seven
    /// headers in that order, and the rows under each of them in the order the
    /// prototype writes them. The gate compares **sets**, so the order here is
    /// documentation rather than a constraint; it is here so that a reader
    /// checking one run against the prototype finds it in one place.
    final List<String> arabic = <String>[
      // --- the app bar (`:639-643`) ------------------------------------------
      // The title, and the back control's **tooltip**. A `Tooltip` paints
      // nothing until a gesture, and the gate's probe holds every one of them
      // open — so the name is a painted run, exactly as `/communion`'s back
      // tooltip is.
      ar.settingsTitle,
      ar.settingsBack,
      // --- 1. the language group (`:645-648`) -------------------------------
      ar.settingsWsLang,
      // The segment's two options, in the client's own-script names
      // (`settings_l10n.dart`'s rule: "a language names itself in its own
      // script"). **Both** are Arabic on this arm.
      //
      // **And they are read through the same `languageLabelFor` derivation the
      // control itself uses**, so the list cannot disagree with the widget about
      // what a language is called — `/communion`'s group gives that argument.
      ar.languageLabelFor(ReadingLanguage.english),
      ar.languageLabelFor(ReadingLanguage.arabic),
      // --- 2. the theme group (`:649-650`) ----------------------------------
      ar.settingsThemeGroup,
      ar.settingsDaylight,
      // --- 3. the light workshop (`:651-665`) -------------------------------
      ar.settingsWsLight,
      ar.settingsShaderEngine,
      ar.settingsCurtainShape,
      // The four Curtain-shape options — `:655`'s own four `data-i18n` keys.
      ar.settingsCurtainTop,
      ar.settingsCurtainBottom,
      ar.settingsCurtainSides,
      ar.settingsCurtainShafts,
      ar.settingsReach,
      ar.settingsBrightness,
      ar.settingsTouchGlow,
      ar.settingsHue,
      ar.settingsMultichromeMelt,
      ar.settingsRayCombing,
      ar.settingsWhiteCores,
      ar.settingsDotVeil,
      // --- 4. the witness sky (`:666-681`) -----------------------------------
      ar.settingsSkyGroup,
      ar.settingsStars,
      ar.settingsConstellations,
      ar.settingsStarCount,
      ar.settingsStarBrightness,
      ar.settingsStarShape,
      ar.settingsStarField,
      ar.settingsTwinkle,
      // --- 5. focus & ritual (`:682-689`) -----------------------------------
      ar.settingsRitualGroup,
      ar.settingsFocusDelay,
      ar.settingsSelahLength,
      ar.settingsBreathGuide,
      ar.settingsVespersAutoDim,
      ar.settingsReduceMotion,
      ar.settingsCalmMotion,
      ar.settingsHaptics,
      // --- 6. communion (`:690-695`) -----------------------------------------
      ar.settingsCommunionGroup,
      ar.settingsVeilWitnesses,
      ar.settingsShowPodium,
      ar.settingsTypeSize,
      // The preview line (`:694`) — the prototype's own Arabic literal, and a
      // run for the same reason the seven segment labels are: the prototype
      // writes it in a script, not in its own `I18N` table.
      kPreviewTextArabic,
      ar.settingsRestoreDefaults,
      // --- 7. about (`:696-698`) ---------------------------------------------
      ar.settingsAbout,
      ar.settingsShaders,
      ar.settingsTokens,
      // --- the type-size stepper's two tooltips (`:693`) ---------------------
      //
      // The two steppers are `IconActionButton`s, so their names are
      // **tooltips** — and a tooltip the gate's probe holds open is a painted
      // run. The track's own label (`settingsFontScale`) is **not** here: it is
      // the `_Track`'s `Semantics(label:)`, and a semantics label never reaches
      // a glyph buffer.
      ar.settingsDecreaseFontSize,
      ar.settingsIncreaseFontSize,
    ];

    testWidgets('the Arabic arm, on the Workshop', (WidgetTester tester) async {
      await pumpSettings(
        tester,
        locale: const Locale('ar'),
        size: _settingsWholeScreenSurface,
      );
      _expectTheWholeScreenIsOnTheSurface(
        tester,
        restoreRowTitle: ar.settingsRestoreDefaults,
      );

      await expectArabicTypography(
        tester,
        screen: '/settings',
        expectedArabic: arabic,
      );
      await _expectSettingsTofuFree(tester, screen: '/settings');

      // ## AND THE GROUP HEADER IS **SINGLE-SCRIPT**, WHICH IS THE DIVERGENCE
      // ## FROM THE PROTOTYPE'S OWN BILINGUAL LABEL
      //
      // `eva/redesign.html:949` writes the language group's header as
      // `language · اللغة` on the English arm and `اللغة · language` on the
      // Arabic one — each arm names the thing in the reader's script and then
      // in the *other* one. **That cannot be one ARB value**:
      // `app_localizations_test.dart`'s English-arm gate is **absolute** ("the
      // English arm holds no Arabic script at all", no exemption list), and a
      // bilingual value breaks it in both directions at once.
      //
      // So each arm keeps the prototype's **first** half, and the pairing is a
      // **recorded divergence**. **This assertion is the divergence's other
      // half** — it says the Arabic arm's value really is the single-script
      // one, and not a bilingual string that happens to have been trimmed:
      // the value carries **no ASCII at all**, so neither the Latin half nor
      // the `·` that joined them is in it.
      expect(
        ar.settingsWsLang.runes.where((int rune) => rune < 0x80),
        isEmpty,
        reason:
            'the Arabic arm\'s value for the language group\'s header is the '
            'prototype\'s first half only. A bilingual value would carry Latin '
            'script here — and it would carry Arabic script in the English '
            'arm, which `app_localizations_test.dart` forbids outright.',
      );
    });

    testWidgets('and the eleven literals the screen paints are on this arm', (
      WidgetTester tester,
    ) async {
      // ## WHY THESE ELEVEN ARE ASSERTED **HERE** AND NOT IN `expectedArabic`
      //
      // **`expectedArabic` is a set of ARABIC runs**, and the gate's predicate
      // is a range over the four Arabic blocks — so a Latin run cannot go in
      // it. Declaring 'DOT' there would fail the gate's other half with
      // "Declared but NOT rendered", which is the exact failure the gate exists
      // to catch.
      //
      // **And that is the whole reason this row exists.** The seven segment
      // labels are the prototype's own **untranslated English** — `:673` and
      // `:678` carry no `data-i18n` — and a reader of the Arabic arm sees
      // "DOT", "STAR", "CROSS", "GEM", "CROWN", "HIGH" and "FULL" in a row.
      // That is a **recorded decision** (the orchestrator's: an ARB key whose
      // two arms are identical would have to join `app_localizations_test
      // .dart`'s `mustBeIdentical` set, and that set is the gate that catches
      // an untranslated string), and a decision that is not asserted anywhere is
      // a decision nobody made on purpose. **This is where they are painted,
      // so this is where they are asserted.**
      await pumpSettings(
        tester,
        locale: const Locale('ar'),
        size: _settingsWholeScreenSurface,
      );
      _expectTheWholeScreenIsOnTheSurface(
        tester,
        restoreRowTitle: ar.settingsRestoreDefaults,
      );

      // ## THE FAMILIES ARE READ OFF THE **RENDERED** TREE, NOT THE WIDGETS
      //
      // `familyOfText` answers "what family was *passed* to this `Text`", and
      // the seven segment labels carry theirs on an `AnimatedDefaultTextStyle`
      // with a `Text` that has **no** style of its own — so `familyOfText`
      // answers `''` for them. That is the truth about the *widget* and not
      // about the *rendering*, and this row is about the rendering. The gate's
      // own instrument reads the resolved family, and one read serves all
      // eleven.
      final Map<String, String> families = <String, String>{
        for (final RenderedRun run in await renderedRuns(tester))
          run.label: run.family,
      };

      // --- the seven untranslated segment labels (`:673`, `:678`) -----------
      //
      // **They are painted in their OWN CASE on the Arabic arm**, because
      // `eva/redesign.html:190` says so: `[dir=rtl] .segp button{…text-
      // transform:none}` — and the prototype's `:136` says the same for the
      // `.mono` class these labels are.
      //
      // **AND THAT IS A FIX, not a divergence.** The widget used to upper-case
      // every label on both arms, so the Arabic arm read `DOT` where the
      // prototype writes `dot` — and the gate recorded it as a divergence
      // rather than "fixing" it, because the fix belonged to the widget. The
      // widget now skips the transform under RTL, and the two rules that
      // changed together — the transform AND the tracking — are the ones
      // `:190` states.
      for (final String label in <String>[
        ...kStarShapeLabels,
        ...kStarFieldLabels,
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason:
              '`$label` is one of the seven untranslated segment labels, and the '
              'Arabic arm paints it as the prototype wrote it — in its own case '
              '(`:190` drops the transform under RTL) and untranslated, which is '
              'the recorded decision.',
        );
        expect(
          families[label],
          EvaTypography.arabicFamily,
          reason:
              '`$label` is a Latin word on the Arabic arm, and it renders in '
              'the ambient arm\'s face — `arabicAware` resolves the whole '
              'segmented control under RTL, which is the prototype\'s `:190` '
              'rule. The family is what the control resolved it to.',
        );
      }

      // --- the app bar's version chip (`:642`) -------------------------------
      expect(
        find.text(AppConfig.appVersion),
        findsOneWidget,
        reason:
            'the chip carries the app\'s real version, not the design system\'s '
            '`v1.2` — a reader looking at a version chip wants the version of '
            'the app they are holding.',
      );
      expect(
        families[AppConfig.appVersion],
        EvaTypography.arabicFamily,
        reason:
            'the chip is a `.mono` run (`:642`, `:30`), and under RTL it is in '
            'the ambient arm\'s face.',
      );

      // --- the About group's two values (`:697-698`) ------------------------
      for (final String value in <String>[kShadersVersion, kTokensVersion]) {
        expect(
          find.text(value),
          findsOneWidget,
          reason:
              '`$value` is the prototype\'s own literal for the design system\'s '
              'version, and the row says so rather than claiming it is this '
              'client\'s.',
        );
        expect(
          families[value],
          EvaTypography.arabicFamily,
          reason:
              'the `.ar` style (`:421`) is a mono run, and under RTL it is in the '
              'ambient arm\'s face.',
        );
      }

      // --- the restore row's arrow (`:695`) ---------------------------------
      expect(
        find.text(kRestoreGlyph),
        findsOneWidget,
        reason: 'the restore row carries the prototype\'s own `↺` (`:695`).',
      );
      expect(
        families[kRestoreGlyph],
        EvaTypography.arabicFamily,
        reason:
            'the arrow is painted in the ambient arm\'s face, and the **glyph** '
            'is drawn by the fallback — which is the next assertion.',
      );
      expect(
        tester.widget<Text>(find.text(kRestoreGlyph)).style?.fontFamilyFallback,
        contains(EvaTypography.uiFamily),
        reason:
            'U+21BA is in **no** bundled mono or scripture face — measured, it is '
            'in `Inter` and `IBMPlexSansArabic` alone — so the row declares '
            '`fontFamilyFallback: [Inter]` and the engine draws the arrow out of '
            'it. A row that lost the fallback would render a tofu box, and this '
            'is the assertion that says so.',
      );
      expect(
        familyCovers(EvaTypography.uiFamily, <int>[0x21BA]),
        isTrue,
        reason:
            'the fallback family has to carry the arrow, or the fallback is a '
            'fiction.',
      );
      expect(
        familyCovers(EvaTypography.arabicFamily, <int>[0x21BA]),
        isFalse,
        reason:
            'and the primary family has **not** to carry it — otherwise the '
            'fallback would be decoration and this row would be measuring '
            'nothing.',
      );

      // **And the arrow is mirrored under RTL**, which is `:138` —
      // `[dir=rtl] .srow .ar{transform:scaleX(-1)}` — and the only glyph **on
      // this screen** that has to be mirrored by hand, because U+21BA has no
      // `Bidi_Mirrored` property and no text engine mirrors it by itself.
      final Iterable<Transform> mirrors = tester.widgetList<Transform>(
        find.ancestor(
          of: find.text(kRestoreGlyph),
          matching: find.byType(Transform),
        ),
      );
      expect(
        mirrors.any((Transform mirror) => mirror.transform.entry(0, 0) < 0),
        isTrue,
        reason:
            'the arrow is the prototype\'s `.srow .ar` span (`:695`), and `:138` '
            'mirrors it under RTL. A scale of +1 would draw it pointing the '
            'wrong way.',
      );
    });

    testWidgets('and the FAILURE notice is two more runs', (
      WidgetTester tester,
    ) async {
      // ## WHY THIS ARM EXISTS, AND IT IS THE FILE'S OWN ARGUMENT
      //
      // `/quiz` has an "EMPTY state is gated too" arm, `/communion` has a
      // "FAILED board is the retry label and nothing else" arm, and `/journey`
      // has a "FAILED screen is the app bar and the retry label" arm. **The
      // failure state is a state the viewport matrix itself sweeps** — the
      // `/settings` arm mounts it at all three sizes — and it is the state
      // whose **sentence wraps**, so it is the one most likely to tofu.
      //
      // **And the notice's two strings are the app's own**, so on the Arabic
      // arm they are Arabic and they are runs:
      //
      // * the sentence, painted by the notice's own `Text` and resolved by
      //   `arabicAware` — so in Amiri, not in the Latin UI face;
      // * the retry label, and `EvaButton.labelFamily` is **required** (decision
      //   66), so the button names its own family — `arabicAwareFamily` puts it
      //   in Amiri on this arm.
      //
      // **And the failure's own `message` is deliberately NOT declared.** The
      // notice renders `settingsPreferencesUnavailable` and **not**
      // `state.failure!.message` — the server's string is deliberately kept off
      // the screen — so there is no run to declare. (The one this fixture
      // carries is English anyway.)
      final SettingsCubit failing = SettingsCubit(
        getSettings: const GetSettings(
          FailingSettingsRepository(
            Failure(
              kind: FailureKind.storage,
              message: 'the preferences could not be reached',
            ),
          ),
        ),
        updateSettings: const UpdateSettings(
          FailingSettingsRepository(
            Failure(
              kind: FailureKind.storage,
              message: 'the preferences could not be reached',
            ),
          ),
        ),
      );
      addTearDown(failing.close);

      await pumpSettings(
        tester,
        cubit: failing,
        locale: const Locale('ar'),
        size: _settingsWholeScreenSurface,
      );
      _expectTheWholeScreenIsOnTheSurface(
        tester,
        restoreRowTitle: ar.settingsRestoreDefaults,
      );

      expect(
        find.text(ar.settingsPreferencesUnavailable),
        findsOneWidget,
        reason:
            'the notice is on the screen — a failure that showed no sentence '
            'would leave the reader with twenty-nine controls and no word '
            'about what went wrong.',
      );

      await expectArabicTypography(
        tester,
        screen: '/settings (failure notice)',
        // The page's own runs are still painted under the notice, so the
        // declaration is the union.
        expectedArabic: <String>[
          ...arabic,
          ar.settingsPreferencesUnavailable,
          ar.settingsRetry,
        ],
      );
      await _expectSettingsTofuFree(
        tester,
        screen: '/settings (failure notice)',
      );
    });

    testWidgets('and the RESTORE TOAST is a run of its own', (
      WidgetTester tester,
    ) async {
      // ## THE ONE RUN THE TOAST ADDS
      //
      // `settingsRestored` is the prototype's own `:975` pair — "↺ nocturne
      // defaults restored" / "↺ استُعيدت الافتراضيات" — and the toast is
      // raised **only when the write is confirmed** (`_SettingsBody._restore`),
      // so the arm has to press the row rather than assert the string.
      //
      // **And the arrow is inside the message**, which is why this arm's tofu
      // check is the local one: the message's family is the ambient arm's, and
      // U+21BA is not in it. The toast declares the same
      // `fontFamilyFallback: [Inter]` the row does, and the assertion below is
      // that it does.
      await pumpSettings(
        tester,
        locale: const Locale('ar'),
        size: _settingsWholeScreenSurface,
      );
      _expectTheWholeScreenIsOnTheSurface(
        tester,
        restoreRowTitle: ar.settingsRestoreDefaults,
      );

      // The restore row is the **last** row of the sixth group, and the surface
      // holds the whole screen — so the tap below reaches it.
      await tester.tap(find.text(ar.settingsRestoreDefaults));
      for (int frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        find.text(ar.settingsRestored),
        findsOneWidget,
        reason:
            'the toast is up — a restore that raised no confirmation would leave '
            'a reader with twenty-three changed values and no word about them.',
      );
      expect(
        tester
            .widget<Text>(find.text(ar.settingsRestored))
            .style
            ?.fontFamilyFallback,
        contains(EvaTypography.uiFamily),
        reason:
            'the toast\'s own message carries the arrow, and the arrow is in no '
            'bundled mono or scripture face — the toast declares the same '
            '`fontFamilyFallback: [Inter]` the restore row does.',
      );

      await expectArabicTypography(
        tester,
        screen: '/settings (restore toast)',
        // The page's own runs are still painted behind the toast, so the
        // declaration is the union.
        expectedArabic: <String>[...arabic, ar.settingsRestored],
      );
      await _expectSettingsTofuFree(
        tester,
        screen: '/settings (restore toast)',
      );
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      // The control, for `/`'s reason: with no Arabic on screen the Arabic
      // assertions above are vacuously true, so this row is what catches a
      // screen that stopped honouring the locale.
      //
      // **And it is a real control here**, because the language segment's two
      // options are the app's own-script names — "English" and "Arabic" on
      // this arm — so the English screen shows an option called "Arabic" and
      // **not one Arabic character**. (The Arabic option is Amiri on this arm,
      // because `SegmentedControl.labelFamilyOf` is keyed on the **option**
      // and not on the direction — `:186`'s rule — but the *text* is Latin.)
      await pumpSettings(tester, size: _settingsWholeScreenSurface);
      _expectTheWholeScreenIsOnTheSurface(
        tester,
        restoreRowTitle: AppLocalizationsEn().settingsRestoreDefaults,
      );

      await _expectNoArabic(tester, '/settings');
      await _expectSettingsTofuFree(tester, screen: '/settings (en)');
    });
  });

  group('`/communion` — the cohort\'s board', () {
    /// ## THE SEVENTH SCREEN, AND THE ONE GATE
    ///
    /// `/communion` is the redesigned cohort board (ADR-0022, Task 5.5), and it
    /// is a **screen**: an app bar, two segmented controls, a podium, a list, a
    /// you-card, a countdown, an empty state and a failure state. A screen the
    /// typography gate does not cover is a screen whose Arabic arm nobody has
    /// looked at — and this repository's own history is a screen whose Arabic
    /// arm was **entirely tofu** behind a green suite (recorded decision 73).
    ///
    /// So this group is the seventh application of the **one** gate: the
    /// instrument is `test/support/arabic_typography_gate.dart`, and this file
    /// is where it is applied. A gate with seven copies is seven gates, and
    /// they drift.
    ///
    /// ## THE THREE ARMS, AND THE ENGLISH CONTROL
    ///
    /// 1. the **declared set** of Arabic runs, compared for equality in both
    ///    directions;
    /// 2. every one of them in Amiri — the token *and* the literal string;
    /// 3. **every character on screen** carried by the family that renders it.
    ///
    /// Plus the English control, for `/`'s reason: with no Arabic on screen
    /// the Arabic gate is vacuous by construction, so a screen that silently
    /// stopped honouring the locale would pass every Arabic assertion.
    ///
    /// ## AND THE ONE THING ABOUT THIS SCREEN THAT IS NOT OBVIOUS
    ///
    /// **A row's name is a run only when it carries Arabic.** `full_name`
    /// arrives from the wire as one Latin string for both locales — the
    /// backend has no Arabic name field — so a witness's un-veiled name is
    /// **pure Latin** and is *not* an Arabic run, and declaring it would trip
    /// the exact-set assertion with "a declared run the tree never held".
    ///
    /// The reader's own row carries the " · أنت" suffix, so **it** is a run
    /// (Latin and Arabic in one span). A veiled witness's name is "شاهد ٣",
    /// so **that** is a run too. Three cases, three answers, and the fixture
    /// below puts all three on one screen.
    ///
    /// ## AND THE TWO KINDS OF STRING THAT ARE **NOT** PAINTED
    ///
    /// The row's `Semantics` label (`ar.leaderboardRowSemantics`, through
    /// `leaderboard_l10n.dart`'s `leaderboardRowAnnouncement`) is an
    /// **accessible name**, never painted — the category error `/quiz`'s
    /// `quizProgress` records.
    ///
    /// **And it was asserted by NOBODY, on either arm.** The English one is
    /// read by `communion_page_test.dart`'s semantics group; the **Arabic** one
    /// — the arm this group exists for — had no assertion anywhere, and the
    /// Arabic arm of that string **dropped the score entirely** (its `few` /
    /// `many` / `other` arms never interpolated `{digits}`, so a screen-reader
    /// user was told a witness had "points" and not how many). The ARB is fixed
    /// and `app_localizations_test.dart` now pins the Arabic rendering; the
    /// *announcement* itself is asserted by the l10n wrapper's own suite.
    ///
    /// **The two tooltips are the opposite case, and this is the trap.** A
    /// `Tooltip` paints nothing until a gesture, and `renderedRuns` holds each
    /// one open past `kLongPressTimeout` and reads the tree then — so the veil
    /// button's name ("حجب الشهود") and the back control's own Arabic label
    /// ("رجوع", which is `MaterialLocalizations`' Arabic `backButtonTooltip`)
    /// **are** painted runs, and the declared set has to name both.
    ///
    /// And naming them is how the gate found the defect this group is here
    /// for: `CommunionAppBar`'s `_IconHit` built its `Tooltip` with no
    /// `textStyle`, so the framework resolved the family to the theme's
    /// `bodyMedium` — the **Latin** UI face — and the gate reported
    ///
    ///     `رجوع` renders Arabic in `Inter`, which carries no Arabic glyph at all
    ///
    /// one box per character, for both tooltips. The fix is the one
    /// `IconActionButton` already had: the family is resolved with
    /// `arabicAwareFamily(direction, …)` and handed to the `Tooltip` as its
    /// `textStyle`, and the two tooltips are Amiri on the Arabic arm.
    final AppLocalizations ar = AppLocalizationsAr();

    testWidgets('the Arabic arm, on the ready board', (
      WidgetTester tester,
    ) async {
      await _pumpCommunion(tester, _communionBoard, locale: const Locale('ar'));
      final String back = await arabicBackTooltip();

      await expectArabicTypography(
        tester,
        screen: '/communion',
        expectedArabic: _communionRuns(
          ar,
          metric: LeaderboardMetric.light,
          veiled: false,
          ranked: true,
          backTooltip: back,
        ),
      );
      // The third arm, and the only one that is language-agnostic: every
      // character on the screen is carried by the family that renders it.
      await expectNoTofuInAnyRun(tester, screen: '/communion');
    });

    testWidgets('and the VEIL replaces every name but the reader\'s', (
      WidgetTester tester,
    ) async {
      // The veil is a **rendering choice over rows that already arrived**
      // (`UserSettings.veilWitnesses`), so the board is the same board — and
      // the difference in the declared set is exactly the three witness names
      // and the witness the gap line names.
      //
      // **The reader is never veiled** (`LeaderboardRowTile`'s own doc: the
      // prototype checks the reader *before* the veil), so the reader's name
      // is the same "Latin · أنت" run it is on the un-veiled arm.
      await _pumpCommunion(
        tester,
        _communionBoard,
        locale: const Locale('ar'),
        veiled: true,
      );
      final String back = await arabicBackTooltip();

      await expectArabicTypography(
        tester,
        screen: '/communion (veiled)',
        expectedArabic: _communionRuns(
          ar,
          metric: LeaderboardMetric.light,
          veiled: true,
          ranked: true,
          backTooltip: back,
        ),
      );
      await expectNoTofuInAnyRun(tester, screen: '/communion (veiled)');
    });

    testWidgets('and the STREAKS metric swaps the two numbers and drops the '
        'pass hint', (WidgetTester tester) async {
      // The second metric is a **second answer to the board's question**, not a
      // relabelling: the podium and the rows print the streak where they
      // printed the score, and the sub-line prints the score where it printed
      // the streak (`leaderboard_row_tile.dart`'s switch, which pairs each
      // number with the *other* metric's name).
      //
      // **And the pass hint is gone**, because the ÷15 is the **light**
      // economy (`eva/redesign.html:755`) and a streak gap is not a number of
      // verses (D14). The gap line is therefore a shorter string here, and the
      // declared set is shorter with it.
      await _pumpCommunion(
        tester,
        _communionBoard,
        locale: const Locale('ar'),
        metric: LeaderboardMetric.streaks,
      );
      final String back = await arabicBackTooltip();

      await expectArabicTypography(
        tester,
        screen: '/communion (streaks)',
        expectedArabic: _communionRuns(
          ar,
          metric: LeaderboardMetric.streaks,
          veiled: false,
          ranked: true,
          backTooltip: back,
        ),
      );
      await expectNoTofuInAnyRun(tester, screen: '/communion (streaks)');
    });

    testWidgets('and the reader the board does not rank is named, not '
        'numbered', (WidgetTester tester) async {
      // The cold state: `my_standing` answers `{"rank": null, "score": 0}` for
      // a child who has not scored (`LeaderboardStanding`'s own doc). The
      // card then falls back to the session's name, says **"not ranked yet"**
      // instead of a place, and prints **no value at all** — a fabricated
      // number is the one thing D9 forbids.
      //
      // **And no row is the reader's**, so no row's name carries the " · أنت"
      // suffix: every name on this arm is the pure Latin the wire sent.
      await _pumpCommunion(
        tester,
        _communionUnrankedBoard,
        locale: const Locale('ar'),
      );
      final String back = await arabicBackTooltip();

      await expectArabicTypography(
        tester,
        screen: '/communion (unranked)',
        expectedArabic: _communionRuns(
          ar,
          metric: LeaderboardMetric.light,
          veiled: false,
          ranked: false,
          backTooltip: back,
        ),
      );
      await expectNoTofuInAnyRun(tester, screen: '/communion (unranked)');
    });

    testWidgets('and the CHEER toast is a run of its own', (
      WidgetTester tester,
    ) async {
      // The toast is the success confirmation, and it is **one** run: the
      // widget paints the message in a single `Text` beside a painted star.
      //
      // **Tapped on a witness's row, and the name it carries is the one the
      // screen is allowed to show** — the veil applies to the toast's name
      // too, so a voice-over user cannot hear what the screen is forbidden
      // to show.
      await _pumpCommunion(tester, _communionBoard, locale: const Locale('ar'));
      final String back = await arabicBackTooltip();

      // The list's last row is the witness's, and it is the only row that is
      // not the reader's.
      await tester.tap(find.text(_communionWitness.fullName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      await expectArabicTypography(
        tester,
        screen: '/communion (cheer toast)',
        expectedArabic: <String>[
          ..._communionRuns(
            ar,
            metric: LeaderboardMetric.light,
            veiled: false,
            ranked: true,
            backTooltip: back,
          ),
          // The toast's own sentence.
          ar.leaderboardCheerSent(_communionWitness.fullName),
        ],
      );
      await expectNoTofuInAnyRun(tester, screen: '/communion (cheer toast)');
    });

    testWidgets(
      'and the WEEKLY countdown is pinned, which the page cannot do',
      (WidgetTester tester) async {
        // ## WHY THIS ARM PUMPS THE WIDGET AND NOT THE PAGE
        //
        // The page's countdown is a function of the **wall clock**:
        // `CommunionCountdownLine` calls `DateTime.now()` when the page builds
        // it, so its Arabic string is "يُصفّر بعد نحو ٤ي ١٣س" today and a
        // different string tomorrow. A declared **set** cannot hold a value
        // that changes, and a test that recomputed it from its own clock would
        // be red once an hour, for a reason that has nothing to do with the
        // screen.
        //
        // The widget owns the seam that fixes it: `CommunionCountdownLine`'s
        // `now` parameter exists "for deterministic testing" and the page does
        // not pass it. So the **string** is pinned here, on the widget that
        // renders it, with a fixed instant.
        //
        // **And the string is the one that matters.** The English
        // `leaderboardResetsIn` says "resets in ≈ 3d 4h" with a U+2248, and
        // **Amiri carries no U+2248** — so the Arabic string says "نحو"
        // ("about") instead, and that is the whole reason this run is in Amiri
        // at all. A run that needed the glyph would be tofu.
        await tester.pumpWidget(
          evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: CommunionCountdownLine(
              window: LeaderboardWindow.weekly,
              now: DateTime(2026, 1, 7, 10, 30),
            ),
          ),
        );
        await tester.pump();

        await expectArabicTypography(
          tester,
          screen: '/communion (weekly countdown)',
          expectedArabic: <String>[
            // Wednesday the seventh of January, ten-thirty in the morning: four
            // days and thirteen hours to the next Monday, in this arm's own
            // numerals, with the arm's own unit letters.
            ar.leaderboardResetsIn(ar.digits(4), ar.digits(13), 'ي', 'س'),
          ],
        );
        await expectNoTofuInAnyRun(
          tester,
          screen: '/communion (weekly countdown)',
        );
      },
    );

    testWidgets('and the FAILED board is the retry label and nothing else', (
      WidgetTester tester,
    ) async {
      // ## AND THE ONE RUN THE FAILURE STATE ADDS
      //
      // The retry control's label, "حاول مرة أخرى" — which the page hands to
      // `ErrorView` **by hand**, with its own locale comparison:
      //
      //     retryFamily: Localizations.localeOf(context).languageCode == 'ar'
      //         ? EvaTypography.arabicFamily
      //         : EvaTypography.uiFamily,
      //
      // A page that dropped the Arabic half of that switch would render the
      // one label on the screen where something has already gone wrong in a
      // face with no Arabic glyphs, and **no other group's gate would see
      // it**: the `/` group's failed arm renders the same *string* through
      // the same `ErrorView`, but the **family** is this page's own argument.
      //
      // **And the countdown is gone**, because the countdown is gated on the
      // **response's** board (`communion_page.dart`: the line renders only
      // `if (state.board case final LeaderboardBoard board)`), and a failed
      // request has no board. That is a run that is **not** on this arm, and
      // declaring it would be the other half of the exact-set assertion.
      //
      // The failure's own **message** is deliberately not declared: this
      // fixture's message is the server's English text, so it is not an
      // Arabic run. The family that renders it is `ErrorView`'s own
      // `arabicAware`, and the tofu arm below is what checks the glyphs.
      await _pumpCommunionFailed(tester, locale: const Locale('ar'));
      final String back = await arabicBackTooltip();

      await expectArabicTypography(
        tester,
        screen: '/communion (failed)',
        expectedArabic: <String>[
          // The chrome: the app bar's title, the two tooltips, and the two
          // segmented controls' five options.
          ar.leaderboardTitle,
          back,
          ar.leaderboardVeil,
          ar.leaderboardWindowWeekly,
          ar.leaderboardWindowMonthly,
          ar.leaderboardWindowAllTime,
          ar.leaderboardMetricLight,
          ar.leaderboardMetricStreaks,
          // The retry control's label, and the only Arabic run this state
          // adds.
          ar.readingRetry,
        ],
      );
      await expectNoTofuInAnyRun(tester, screen: '/communion (failed)');
    });

    testWidgets('and the EMPTY board is two more runs', (
      WidgetTester tester,
    ) async {
      // ## AND THIS ARM WAS **RED** UNTIL THE SHARED `EmptyState` WAS FIXED
      //
      // The empty cohort is a real state — the server answers with zero rows
      // and the page draws the empty state (`communion_page.dart`'s
      // `board.rows.isEmpty` branch) — and the empty state's two strings are
      // Arabic, so they are runs.
      //
      // **They used to render in faces that carry no Arabic glyph at all.**
      // The shared design-system `EmptyState` painted its title with
      // `Theme.of(context).textTheme.headlineMedium` (the display serif) and
      // its message with `bodyMedium` (the UI sans), and **neither went
      // through `arabicAware`** — so on the Arabic arm the gate reported
      //
      //     `لا توجد نتائج بعد` renders Arabic in `EBGaramond`, which carries no
      //     Arabic glyph at all
      //
      // one tofu box per character, for the whole empty screen. The fix is
      // the one `StatTile` got in Phase 8: `arabicAware` on both runs.
      //
      // **The arm is here to keep it fixed.** A gate that quietly stops
      // covering a broken state is "a gate that cannot fail" wearing a
      // nicer hat, and this is the arm that says so.
      await _pumpCommunion(
        tester,
        _communionEmptyBoard,
        locale: const Locale('ar'),
      );
      final String back = await arabicBackTooltip();

      await expectArabicTypography(
        tester,
        screen: '/communion (empty)',
        expectedArabic: <String>[
          // The chrome every arm carries.
          ar.leaderboardTitle,
          back,
          ar.leaderboardVeil,
          ar.leaderboardWindowWeekly,
          ar.leaderboardWindowMonthly,
          ar.leaderboardWindowAllTime,
          ar.leaderboardMetricLight,
          ar.leaderboardMetricStreaks,
          ar.leaderboardNoReset,
          // The empty state's own two strings.
          ar.leaderboardEmptyTitle,
          ar.leaderboardEmptyBody,
        ],
      );
      await expectNoTofuInAnyRun(tester, screen: '/communion (empty)');
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      // The control, for `/`'s reason: with no Arabic on screen the Arabic
      // assertions above are vacuously true, so this row is what catches a
      // screen that stopped honouring the locale.
      await _pumpCommunion(tester, _communionBoard);
      await _expectNoArabic(tester, '/communion');

      // **The third arm on the English side too**, and the gate's own doc says
      // why: that arm is "language-agnostic on purpose". The English strings
      // carry the two characters this screen's Arabic strings had to avoid —
      // the `·` of "no reset · the sky remembers" and the `≈` of "pass with ≈4
      // verses" — and both are rendered in the **mono** face, which is a
      // Latin face. So this row is where the English numerals and the `≈`
      // are checked for the glyph they need.
      await expectNoTofuInAnyRun(tester, screen: '/communion (en)');
    });
  });

  group('`/journey` — the reader\'s journey', () {
    /// ## THE EIGHTH SCREEN, AND THE ONLY RIGHT-TO-LEFT ONE IN THIS FILE
    ///
    /// `/journey` is the redesigned profile (ADR-0022, Task 5.6): an app bar, an
    /// orb, the reader's name, the transcribed role line, the hero streak, three
    /// rings, the sky line, a medals strip and four account rows.
    ///
    /// It is also the screen whose Arabic arm carries **Arabic-Indic digits in
    /// nine separate places** — the hero, the three rings, the sky line's two
    /// counts, the medals' own count, and the two ARB rows that **bake a digit
    /// into their text**: `journeyScribe`'s "كاتبة · المستوى ٧" and
    /// `journeyMedalStreakSeven`'s "٧ أيام". The prototype bakes them into its
    /// own i18n table the same way (`:933` and `:937`), and the prototype's row
    /// at `:933` is read by the client as a **run with a digit in it** — not as a
    /// number composed at the call site.
    ///
    /// **U+0660–U+0669 is inside the block this gate's predicate is a range
    /// over**, so every one of those nine is an Arabic run to the gate and to a
    /// reader — and every one of them has to be in a face that carries the
    /// glyph. `JetBrainsMono` carries none of them, which is why every mono run
    /// on this screen goes through `arabicAware`.
    ///
    /// ## AND THE FIVE THINGS THIS GROUP PROVES THAT THE OTHER SEVEN DO NOT
    ///
    /// 1. **The percent sign.** The rings' values on the Arabic arm end in `٪`
    ///    (U+066A) and not in `%` (U+0025) — the prototype's own `N()` (`:981`)
    ///    maps one to the other, and this client's `journeyPercent` does the
    ///    same. **U+0025 is in all five bundled families and U+066A is in
    ///    Amiri**, so a ring that said `%` on the Arabic arm would not tofu — it
    ///    would be *wrong*, and no glyph check would catch it. That is why the
    ///    group asserts the sign and not merely the presence of a sign.
    /// 2. **The fleuron's pin.** `❧` (U+2767) is in **EB Garamond alone** and
    ///    it is **not Arabic content**, so the Arabic arm has to keep it on the
    ///    scripture face. An `arabicAware` swap would put it in Amiri, which
    ///    does not carry it — and the no-tofu arm is what catches that.
    /// 3. **The four marks that cannot be typed at all.** `✦` (U+2726),
    ///    `✠` (U+2720), `☩` (U+2629) and `⚙` (U+2699) are in **no** bundled
    ///    family, so three of them are painted (`FourPointedStar`) and the
    ///    fourth is the framework's (`Icons.settings`). The group asserts that
    ///    **no run on the screen carries any of the four**.
    /// 4. **The direction.** The rows' `›` mirrors under RTL and the app bar's
    ///    `.iconbtn` pill does **not** — Task 5.5's lesson, and both halves of
    ///    it.
    /// 5. **The order.** The three rings and the four medals keep the
    ///    prototype's order, and the row reverses under RTL exactly as the
    ///    prototype's flexbox does.
    ///
    /// ## AND THE ONE STRING ON THIS SCREEN THAT IS **NOT** AN ARABIC RUN
    ///
    /// The reader's own name. The prototype's is a literal — `Mariam Hanna` at
    /// `:587`, written again by JavaScript at `:992` as `مريم حنا` on the Arabic
    /// arm — and **this client's is the session's**, which the backend sends as
    /// one Latin string for both locales. So the name under the orb is pure
    /// Latin, and declaring it would trip the exact-set assertion with "a
    /// declared run the tree never held". The monogram in the orb is the
    /// session's `initials` for the same reason.
    ///
    /// **And the reason it is not an Arabic run is not "it is Latin".** It is a
    /// run in **Amiri** under RTL — `arabicAware` swapped it — and Amiri carries
    /// the Latin too, so the no-tofu arm covers it even though the Arabic arm
    /// does not.
    final AppLocalizations ar = AppLocalizationsAr();

    testWidgets('the Arabic arm, on the ready screen', (
      WidgetTester tester,
    ) async {
      await _pumpJourney(tester, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/journey',
        expectedArabic: _journeyReadyRuns(ar),
      );
      // The third arm, and the only one that is language-agnostic: every
      // character on the screen is carried by the family that renders it.
      await expectNoTofuInAnyRun(tester, screen: '/journey');
    });

    testWidgets('and the FAILED screen is the app bar and the retry label', (
      WidgetTester tester,
    ) async {
      // ## THE ONE RUN THE FAILURE STATE ADDS
      //
      // The retry control's label, "أعد المحاولة" — which the page hands to
      // `ErrorView` **by hand**, with its own arm switch:
      //
      //     retryFamily: context.l10n.isArabicArm
      //         ? EvaTypography.arabicFamily
      //         : EvaTypography.uiFamily,
      //
      // A page that dropped the Arabic half of that switch would render the
      // one label on the screen where something has already gone wrong in a
      // face with no Arabic glyphs, and **no other group's gate would see
      // it**: the `/communion` group's failed arm renders the **board's** copy
      // of the same label through the same `ErrorView`, and the two are two
      // separate ARB keys now — so the *family*, which is this page's own
      // argument, is the only thing either arm can check.
      //
      // **And the failure's own message is deliberately not declared.** It is
      // the server's English text, so it is not an Arabic run; the family that
      // renders it is `ErrorView`'s own `arabicAware`, and the tofu arm below
      // is what checks the glyphs.
      await _pumpJourney(tester, locale: const Locale('ar'), failed: true);

      await expectArabicTypography(
        tester,
        screen: '/journey (failed)',
        expectedArabic: <String>[
          // The chrome: the app bar's title and its two tooltips.
          //
          // **And no back control's label** — the journey is a tab and has no
          // back control. See `_journeyReadyRuns`.
          ar.journeyTitle,
          ar.journeyRowBoard,
          ar.journeyRowSettings,
          // The retry control's label, and the only Arabic run this state adds.
          ar.journeyRetry,
        ],
      );
      await expectNoTofuInAnyRun(tester, screen: '/journey (failed)');
    });

    testWidgets('and in English renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      // The control, for `/`'s reason: with no Arabic on screen the Arabic
      // assertions above are vacuously true, so this row is what catches a
      // screen that stopped honouring the locale.
      await _pumpJourney(tester);
      await _expectNoArabic(tester, '/journey');

      // **The third arm on the English side too**, and this screen is where it
      // has the most to check: the English arm's runs carry the `·` of the role
      // line and the sky line, the `×` of the "streak ×7" medal, the `/` of
      // the medals' own count and the `%` of the two rings — and all of them
      // are rendered in the **mono** face, which is a Latin face.
      await expectNoTofuInAnyRun(tester, screen: '/journey (en)');
    });

    group('the typeface rule, and why the mono face cannot be left alone', () {
      test('and the mono face carries neither an Arabic glyph nor a digit', () {
        // **The reason the whole rule exists, stated as arithmetic.**
        //
        // `JetBrainsMono` is one of the five bundled families and it is the
        // face this screen's `.mono` runs are written in — the role line, the
        // hero's sub-line, the sky line, the rings' values and labels, the
        // medals' labels and count, and the two section labels. It carries
        // **no** Arabic glyph and **no** Arabic-Indic digit, so a run that
        // stayed in it on the Arabic arm would be a row of tofu boxes.
        expect(
          familyCovers(EvaTypography.monoFamily, <int>[0x0628, 0x0644]),
          isFalse,
          reason:
              'JetBrains Mono carries no Arabic glyph at all, so every Arabic run '
              'this screen paints has to have been swapped out of it',
        );
        expect(
          familyCovers(EvaTypography.monoFamily, <int>[0x0667]),
          isFalse,
          reason:
              'and no Arabic-Indic digit either — which is what makes the '
              'digit-bearing runs (the hero, the three rings, the sky line\'s two '
              'counts and the medals\' count) the sharpest case',
        );
      });

      testWidgets('and every mono run on this screen is on a face that has them', (
        WidgetTester tester,
      ) async {
        await _pumpJourney(tester, locale: const Locale('ar'));

        final List<RenderedRun> runs = await arabicRuns(tester);
        final Map<String, String> families = <String, String>{
          for (final RenderedRun run in runs) run.label: run.family,
        };

        // **The mono runs, named.** Every one of them is written in the
        // `.mono` face in the prototype — `:30`'s rule, and `:135`, `:136`,
        // `:409` and `:418`'s four RTL overrides — so every one of them is a
        // run that would be tofu if `arabicAware` had not been applied to it.
        for (final String label in _journeyMonoRuns(ar)) {
          expect(
            families[label],
            EvaTypography.arabicFamily,
            reason:
                '`$label` is one of the screen\'s mono runs, and the mono face '
                'carries neither the Arabic letters nor the Arabic-Indic digits '
                'it needs. The family is what `arabicAware` resolved it to.',
          );
        }

        // **And the nine digit-bearing runs, which is where the mono face would
        // have failed hardest.** Two of them are not mono at all — the hero's
        // number is the display face, and the medals' count is — and both are
        // still digit-bearing, so both are still in the same boat.
        for (final String label in _journeyDigitRuns(ar)) {
          expect(
            families[label],
            EvaTypography.arabicFamily,
            reason:
                '`$label` carries an Arabic-Indic digit, and no bundled Latin '
                'face carries one. The family is what `arabicAware` resolved it '
                'to.',
          );
        }

        // **And the whole Arabic arm is in one face** — the gate's own
        // third-arm rule, restated here for the runs this screen owns.
        expect(
          <String>{for (final RenderedRun run in runs) run.family},
          <String>{EvaTypography.arabicFamily},
        );
      });
    });

    group('the glyphs, and the four that cannot be typed at all', () {
      test('the four missing marks are in no bundled family', () {
        // **Measured, not assumed** — `journey_glyph_test.dart` reads the same
        // `cmap`s, and this row is the typography gate's own copy of the
        // measurement, because the gate is what enforces it.
        for (final int codepoint in <int>[0x2726, 0x2720, 0x2629, 0x2699]) {
          for (final String family in kBundledFontFamilies) {
            expect(
              codepointsForFamily(family).contains(codepoint),
              isFalse,
              reason:
                  'U+${codepoint.toRadixString(16).toUpperCase()} is in $family — '
                  'so the painted substitutes this screen ships are not the only '
                  'way it could have been drawn, and the decision needs '
                  're-reading',
            );
          }
        }
      });

      test('the fleuron is in EB Garamond alone', () {
        for (final String family in kBundledFontFamilies) {
          expect(
            codepointsForFamily(family).contains(0x2767),
            family == 'EBGaramond',
            reason:
                'U+2767 is in $family — the fleuron is drawn as text in the '
                'scripture family, and that only holds while EB Garamond is the '
                'one family that carries it',
          );
        }
      });

      test('and the percent sign the Arabic arm uses is in Amiri', () {
        // **U+0025 is in all five families and U+066A is in Amiri** — so the
        // *wrong* sign on the Arabic arm would not tofu. It would be a
        // translation defect, and the next row is what catches it.
        expect(
          familyCovers(EvaTypography.arabicFamily, <int>[0x066A]),
          isTrue,
          reason:
              'U+066A is missing from Amiri, so the Arabic arm\'s percentage '
              'would be a tofu box',
        );
        for (final String family in kBundledFontFamilies) {
          expect(
            codepointsForFamily(family).contains(0x0025),
            isTrue,
            reason:
                'U+0025 is missing from $family — and that is exactly why the '
                'Arabic arm cannot carry the Latin sign: it would render, and '
                'nobody would notice',
          );
        }
      });

      testWidgets('and none of the four is typed anywhere on the screen', (
        WidgetTester tester,
      ) async {
        await _pumpJourney(tester, locale: const Locale('ar'));

        // **Every painted run, read off the tree.** A mark that is in no family
        // and is *typed* is a tofu box, and the run is the only place a typed
        // character shows up.
        final List<RenderedRun> runs = await renderedRuns(tester);
        for (final RenderedRun run in runs) {
          for (final int codepoint in <int>[0x2726, 0x2720, 0x2629, 0x2699]) {
            expect(
              run.label.runes,
              isNot(contains(codepoint)),
              reason:
                  '`${run.label}` carries U+${codepoint.toRadixString(16).toUpperCase()}, '
                  'which is in no bundled family — it would be a tofu box on '
                  '/journey',
            );
          }
        }

        // **And the two substitutions are the ones the prototype's own roles
        // ask for.** The star is painted, the crosses unify on it, and the gear
        // is the framework's icon.
        expect(find.byType(FourPointedStar), findsNWidgets(3));
        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events), findsOneWidget);
        expect(find.text('❧'), findsOneWidget);
      });

      testWidgets('and the fleuron is pinned to the scripture face on the '
          'Arabic arm too', (WidgetTester tester) async {
        // ## THE PIN, AND WHY IT IS NOT `arabicAware`
        //
        // `❧` is in EB Garamond **alone**. Under RTL the house's rule swaps
        // every Arabic run into Amiri — and Amiri does not carry U+2767, so an
        // `arabicAware` fleuron is a tofu box in the middle of an Arabic
        // screen. The tile therefore **pins** the family, and this row is what
        // holds the pin.
        await _pumpJourney(tester, locale: const Locale('ar'));

        final Text fleuron = tester.widget<Text>(find.text('❧'));
        expect(
          fleuron.style?.fontFamily,
          EvaTypography.scriptureFamily,
          reason:
              'the fleuron is not Arabic content, so it stays on the scripture '
              'face on both arms — the pin is what keeps the Arabic arm from '
              'tofu-ing it',
        );
      });

      testWidgets('and the Arabic arm writes `٪` where the Latin arm writes `%`', (
        WidgetTester tester,
      ) async {
        // ## THE PROTOTYPE'S OWN TRANSFORM
        //
        // `:981` is `const N=s=>lang==='ar'?String(s).replace(/\d/g,…).replace(/%/g,'٪'):String(s)`
        // — the digits first and the sign second — and `:987` writes every
        // `.rv[data-v]` through it, so the prototype's rings read `٨٣٪` and
        // `٩٢٪` on the Arabic arm.
        //
        // **And the screen's own values are the ones the gate reads.** The two
        // ratios go through `journeyPercent`, and the count ring carries **no**
        // sign at all — the prototype's `:593` writes `data-v="86"` where its
        // neighbours write `83%` and `92%`, and this client resolved that
        // deliberately: a percent sign is a unit, and a count of answered
        // questions does not have one.
        await _pumpJourney(tester, locale: const Locale('ar'));

        final List<RenderedRun> runs = await arabicRuns(tester);
        final List<String> values = <String>[
          for (final RenderedRun run in runs)
            if (run.label.endsWith('٪') || run.label.endsWith('%')) run.label,
        ];

        expect(
          values,
          hasLength(2),
          reason:
              'the two ratio rings carry a sign and the count ring carries none — '
              'the values on screen were $values',
        );
        for (final String value in values) {
          expect(
            value,
            endsWith('٪'),
            reason:
                'the Arabic arm writes U+066A and not U+0025. Both are in the '
                'bundled fonts, so the Latin sign would render and nobody would '
                'notice: `$value` is the defect this row exists to catch',
          );
          expect(value, isNot(contains('%')));
        }
        // And the sign is the Arabic one, not a lookalike.
        expect(values.first.codeUnitAt(values.first.length - 1), 0x066A);
      });
    });

    group('the direction, and the two rules the prototype states', () {
      testWidgets('the rows\' chevron mirrors under RTL', (
        WidgetTester tester,
      ) async {
        // ## `:138` — `[dir=rtl] .srow .ar{display:inline-block;transform:scaleX(-1)}`
        //
        // The trailing `›` on every account row is U+203A, which is a
        // **`Bidi_Mirrored`** character, so the text engine paints the mirrored
        // form in a right-to-left paragraph. The row does **not** transform it
        // on top of that — the widget's own doc says so, and the reason is
        // that a `scaleX(-1)` over an already-mirrored glyph flips it *back*.
        //
        // **The pixels, and not the paragraph's direction.** The paragraph being
        // RTL is the *mechanism*; whether the glyph came out pointing the other
        // way is the *claim*, and the claim is what a reader sees.
        //
        // **And the comparison is between the row's own chevron on the two
        // arms** — the same widget, the same face, the same size — so what is
        // left is the one thing the direction changed.
        final List<String> ltr = await _chevronMask(tester, TextDirection.ltr);
        final List<String> rtl = await _chevronMask(tester, TextDirection.rtl);

        expect(
          ltr.length,
          rtl.length,
          reason:
              'the two arms drew the chevron at the same height, so the '
              'comparison below is between two shapes and not two windows',
        );
        expect(
          _pixelDifferences(rtl, ltr.map(_reverseRow).toList()),
          lessThanOrEqualTo(1),
          reason:
              'the RTL chevron is the LTR chevron mirrored — the same shape, '
              'pointing the other way. The one pixel of slack is the '
              'antialiasing of the point, which lands on a different side of '
              'the pixel grid on the two arms.',
        );
        expect(
          rtl,
          isNot(ltr),
          reason: 'and it is therefore not the same glyph as the LTR chevron',
        );
      });

      testWidgets('and the app bar\'s two pills do not mirror', (
        WidgetTester tester,
      ) async {
        // ## THE OTHER HALF OF TASK 5.5'S LESSON
        //
        // `:139` is `[dir=rtl] .chev{transform:scaleX(-1)}` — the prototype
        // mirrors the **bare glyph** control. And **no `[dir=rtl]` rule mentions
        // `.iconbtn` at all**, so the **pill** — the 30px glass circle the
        // trophy and the gear sit in — is **not** mirrored.
        //
        // **Measured in the tree, not in the prototype.** Flutter's `Icon`
        // wraps a `matchTextDirection: true` icon in a `Transform` that scales
        // x by −1 under RTL, and leaves every other icon alone. So the two
        // halves are two different answers to the same question, and this row
        // asks both.
        //
        // **AND THE BARE-GLYPH HALF IS GONE WITH THE CHEVRON.** The journey is
        // a **tab** now (Phase 6), and a tab has no way back — the prototype's
        // journey carries a 68px spacer where the chevron would be
        // (`eva/redesign.html:578`), and so does the client. There is no
        // `.chev` on this screen to mirror, and a test that asserted one would
        // be asserting a control that does not exist.
        await _pumpJourney(tester, locale: const Locale('ar'));

        expect(
          find.byIcon(Icons.arrow_back_ios_new),
          findsNothing,
          reason:
              'the journey is a tab, so it has no back control at all — the '
              'prototype\'s own journey carries a spacer, not a chevron',
        );
        expect(
          _isFlipped(tester, find.byIcon(Icons.emoji_events)),
          isFalse,
          reason:
              'the trophy is the prototype\'s `.iconbtn` (`:151`), and no '
              '`[dir=rtl]` rule mentions `.iconbtn` — a pill does not mirror',
        );
        expect(
          _isFlipped(tester, find.byIcon(Icons.settings)),
          isFalse,
          reason: 'and neither does the gear beside it',
        );
      });

      testWidgets('and the rings and the medals keep the prototype\'s order', (
        WidgetTester tester,
      ) async {
        // ## WHAT IS ACTUALLY TRUE, MEASURED
        //
        // The brief's question was "does an RTL screen still show the first
        // ring on the left?", and the answer is **no** — on either arm the
        // order is the prototype's, and the *visual* order reverses under RTL
        // on both.
        //
        // **The prototype.** `:401` is `.rings{display:flex;justify-content:
        // center;gap:26px}` — a flex row — and `:1400` sets the root's
        // `dir="rtl"` on the Arabic arm. A flex row's main axis follows
        // `direction`, so the prototype's first ring is at the **right** under
        // RTL, and `:410`'s `.medals` is the same shape.
        //
        // **The client.** `JourneyRingsRow` builds a `Row`, and Flutter's
        // `RenderFlex` flips the main axis under `TextDirection.rtl` — the
        // first child is laid out at the **right**. The medals strip is a
        // horizontal `ListView`, whose axis direction follows the ambient
        // direction the same way.
        //
        // So the two agree, and the order the reader reads is verses, quizzes,
        // accuracy either way — right to left on the Arabic arm.
        //
        // **And the two arms are two pumps in two tests, not one test with two
        // pumps.** The page's body is a `const` widget, so a second
        // `pumpWidget` over the same tree **reuses** its `State` — and that
        // state's `_loaded` flag is already set, so the new cubit is never asked
        // to load and the screen stays on its spinner. One pump per arm is the
        // shape that works.
        final JourneyRings rings = deriveJourneyRings(_journeyHistory);
        final AppLocalizations en = AppLocalizationsEn();

        await _pumpJourney(tester);

        // LTR: the prototype's order, left to right.
        expect(
          _leftOf(
            tester,
            journeyPercent(en, rings.completion),
            en.digits(rings.answered),
          ),
          isTrue,
          reason: 'the verses ring is left of the quizzes ring under LTR',
        );
        expect(
          _leftOf(
            tester,
            en.digits(rings.answered),
            journeyPercent(en, rings.accuracy),
          ),
          isTrue,
          reason: 'and the quizzes ring is left of the accuracy ring',
        );

        // And the medals strip, which is the same shape.
        expect(
          _leftOf(
            tester,
            monoCapsText(Medal.firstLight.label(en), TextDirection.ltr),
            monoCapsText(Medal.psalmist.label(en), TextDirection.ltr),
          ),
          isTrue,
          reason: 'the first medal is leftmost under LTR',
        );
      });

      testWidgets('and they reverse under RTL, exactly as the prototype does', (
        WidgetTester tester,
      ) async {
        final JourneyRings rings = deriveJourneyRings(_journeyHistory);

        await _pumpJourney(tester, locale: const Locale('ar'));

        // RTL: the same order, read right to left.
        expect(
          _leftOf(
            tester,
            journeyPercent(ar, rings.accuracy),
            ar.digits(rings.answered),
          ),
          isTrue,
          reason:
              'under RTL the accuracy ring is the leftmost one, because the row '
              'reverses exactly as the prototype\'s flex row does',
        );
        expect(
          _leftOf(
            tester,
            ar.digits(rings.answered),
            journeyPercent(ar, rings.completion),
          ),
          isTrue,
          reason: 'and the verses ring is the rightmost one',
        );

        // And the medals strip, which is the same shape.
        expect(
          _leftOf(
            tester,
            Medal.streakSeven.label(ar),
            Medal.firstLight.label(ar),
          ),
          isTrue,
          reason:
              'under RTL the third medal is left of the first, which is the '
              'strip reversing the way `.medals` does (`:410`, `display:flex`)',
        );
      });
    });
  });

  group('`/dock` — the five-slot dock', () {
    // ## THE NINTH SURFACE, AND THE FIRST ONE THAT IS **NOT** A SCREEN
    //
    // The dock is the redesign's navigation (`eva/redesign.html:702-708`) and
    // Phase 6 of the Lumen redesign built it. It is **not** a screen — it is
    // chrome, drawn by the shell over whichever tab is showing — and that is
    // exactly why it needs a row here: **the gate's rule is about what a
    // reader sees, and the dock is on screen for every reader of every tab.**
    //
    // ## AND ITS FIVE LABELS ARE THE PROTOTYPE'S OWN i18n ROWS
    //
    // `:931-932` — `dockHome`, `dockRead`, `dockToday`, `dockJourney` and
    // `dockBoard` — so the Arabic arm is the prototype's Arabic, and the gate
    // is what says the client renders it in a face that carries it.
    //
    // **The declared set is compared in BOTH directions** (decision 79), so a
    // run that silently vanishes is red rather than vacuously true — and a new
    // run is red by name.
    final AppLocalizations ar = AppLocalizationsAr();

    testWidgets('the Arabic arm draws the five slot labels', (
      WidgetTester tester,
    ) async {
      await _pumpDock(tester, locale: const Locale('ar'));

      await expectArabicTypography(
        tester,
        screen: '/dock',
        expectedArabic: <String>[
          ar.dockHome,
          ar.dockRead,
          ar.dockToday,
          ar.dockBoard,
          ar.dockJourney,
        ],
      );
      // The third arm, and the only one that is language-agnostic.
      await expectNoTofuInAnyRun(tester, screen: '/dock');
    });

    testWidgets('and in English it renders no Arabic at all', (
      WidgetTester tester,
    ) async {
      // The control, for the same reason every other screen has one: with no
      // Arabic on screen the Arabic assertions are vacuously true, so this row
      // catches a dock that stopped honouring the locale.
      await _pumpDock(tester);
      await _expectNoArabic(tester, '/dock');
      await expectNoTofuInAnyRun(tester, screen: '/dock (en)');
    });
  });

  group('the ARM ITSELF, and what the two hard-coded states of the rule do', () {
    // The three properties the whole mechanism rests on, tested as a plain function
    // with no widget tree — so they are a unit test rather than a widget test, and a
    // reader can check them in three lines.
    test('and which bundled families can render Arabic is now a decision', () {
      // THIS WAS A SINGLETON AND IS NOT ANY MORE. It read "Amiri is the only
      // bundled family that can render Arabic", which was true when the redesign
      // had not landed and `eva/redesign.html` names TWO Arabic faces:
      //
      //   --ar     Amiri                  arabic SCRIPTURE
      //   --ui-ar  IBM Plex Sans Arabic   arabic chrome
      //
      // Both are bundled, so "the only family" has no referent. What replaced it
      // is the pair that matters, asserted in both directions because a resolver
      // that returned either one for both would leave two roles rendering
      // identically and no notice taken.
      expect(
        familyCovers(EvaTypography.arabicFamily, <int>[0x0628, 0x0644]),
        isTrue,
        reason: 'Amiri must render Arabic — it is the scripture face',
      );
      expect(
        familyCovers(EvaTypography.uiArabicFamily, <int>[0x0628, 0x0644]),
        isTrue,
        reason:
            'IBM Plex Sans Arabic must render Arabic — it is the chrome face, '
            'and every Arabic label in the app now routes through it',
      );
      expect(
        EvaTypography.uiArabicFamily,
        isNot(EvaTypography.arabicFamily),
        reason: 'the split is the whole point; sharing one family undoes it',
      );
      // The Latin faces still must not render Arabic. This is what makes the
      // assertion above a discrimination rather than a tautology — if every family
      // "covered" Arabic, checking that two of them do would mean nothing.
      for (final String family in <String>[
        EvaTypography.uiFamily,
        EvaTypography.monoFamily,
        EvaTypography.displayFamily,
        EvaTypography.scriptureFamily,
      ]) {
        expect(
          familyCovers(family, <int>[0x0628, 0x0644]),
          isFalse,
          reason:
              '$family is a Latin face. If it now reports Arabic coverage the '
              'whole gate has stopped discriminating.',
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

/// The board `/communion` is gated on: five children, and the reader **fourth**.
///
/// ## WHY THE READER IS FOURTH
///
/// The list is `sorted.skip(3)` — the prototype's own slice, recorded in
/// `communion_page.dart` — so the first three children are the **podium**'s
/// and only the fourth and fifth are rows in the list.
///
/// Putting the reader fourth means one pump shows **both** of the names this
/// screen can paint, side by side:
///
/// * the reader's own row, whose name carries the " · أنت" suffix and is
///   therefore an **Arabic run**; and
/// * the fifth child's row, whose name is the pure Latin the wire sent and is
///   therefore **not** an Arabic run.
///
/// The podium's three names are Latin for the same reason, and the veil arm
/// below turns all four into "شاهد ٣".
///
/// The scores and the streaks are ordered the same way on purpose, so the
/// `streaks` metric does not reorder the board and the two arms differ only
/// in the numbers they print.
const LeaderboardBoard _communionBoard = LeaderboardBoard(
  window: LeaderboardWindow.allTime,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      userId: 'u1',
      fullName: 'Peter George',
      currentStreak: 12,
      rank: 1,
      score: 1280,
      initials: 'PG',
    ),
    LeaderboardRow(
      userId: 'u2',
      fullName: 'Ana Silva',
      currentStreak: 8,
      rank: 2,
      score: 940,
      initials: 'AS',
    ),
    LeaderboardRow(
      userId: 'u3',
      fullName: 'Mariam Anton',
      currentStreak: 5,
      rank: 3,
      score: 610,
      initials: 'MA',
    ),
    LeaderboardRow(
      userId: 'u4',
      fullName: 'David Mina',
      currentStreak: 2,
      rank: 4,
      score: 560,
      initials: 'DM',
    ),
    LeaderboardRow(
      userId: 'u5',
      fullName: 'Noor Haddad',
      currentStreak: 1,
      rank: 5,
      score: 300,
      initials: 'NH',
    ),
  ],
  standing: _communionStanding,
  cohortSize: 5,
);

/// The same board with the reader **unranked** — the cold state.
///
/// `my_standing` answers `{"rank": null, "score": 0}` for a child who has not
/// scored (`LeaderboardStanding`'s own doc), and the card then falls back to
/// the session's name and says "not ranked yet" instead of a place.
const LeaderboardBoard _communionEmptyBoard = LeaderboardBoard(
  window: LeaderboardWindow.allTime,
  groupId: 3,
  rows: <LeaderboardRow>[],
  standing: null,
  cohortSize: 0,
);

const LeaderboardBoard _communionUnrankedBoard = LeaderboardBoard(
  window: LeaderboardWindow.allTime,
  groupId: 3,
  rows: <LeaderboardRow>[
    LeaderboardRow(
      userId: 'u1',
      fullName: 'Peter George',
      currentStreak: 12,
      rank: 1,
      score: 1280,
      initials: 'PG',
    ),
    LeaderboardRow(
      userId: 'u2',
      fullName: 'Ana Silva',
      currentStreak: 8,
      rank: 2,
      score: 940,
      initials: 'AS',
    ),
    LeaderboardRow(
      userId: 'u3',
      fullName: 'Mariam Anton',
      currentStreak: 5,
      rank: 3,
      score: 610,
      initials: 'MA',
    ),
    LeaderboardRow(
      userId: 'u4',
      fullName: 'David Mina',
      currentStreak: 2,
      rank: 4,
      score: 560,
      initials: 'DM',
    ),
    LeaderboardRow(
      userId: 'u5',
      fullName: 'Noor Haddad',
      currentStreak: 1,
      rank: 5,
      score: 300,
      initials: 'NH',
    ),
  ],
  standing: LeaderboardStanding(rank: null, score: 0),
  cohortSize: 5,
);

/// The child **below** the reader, and the one the list's last row shows.
final LeaderboardRow _communionWitness = _communionBoard.rows[4];

/// The signed-in reader's name, from the session.
///
/// The you-card's **fallback**: a reader the payload does not rank is named by
/// the session's `displayName` rather than by a row.
const String _communionSessionName = 'David Mina';

/// The runs `/communion` paints, for one board.
///
/// [metric] is the metric the board is ordered by, [veiled] whether the
/// witness veil is on, [ranked] whether the payload ranks the reader at all,
/// and [backTooltip] the framework's own Arabic label for the back control.
///
/// ## THE SCREEN'S OWN ARITHMETIC, NOT A COPY OF IT
///
/// The positions come from `leaderboardPositionOf` and the gap from
/// `leaderboardGapFor` — the same domain functions the widgets call — so a
/// change to the ranking shows up here as a **mismatch** rather than as two
/// lists that agree by accident. And the strings come from
/// `AppLocalizationsAr()`, for `/`'s reason: a hand-typed Arabic list in a
/// test is a second copy of the corpus.
List<String> _communionRuns(
  AppLocalizations ar, {
  required LeaderboardMetric metric,
  required bool veiled,
  required bool ranked,
  required String backTooltip,
}) {
  final List<LeaderboardRow> ordered = leaderboardOrder(
    _communionBoard.rows,
    metric,
  );
  final List<String> declared = <String>[
    // The app bar's title.
    ar.leaderboardTitle,
    // The back control's tooltip — the framework's own Arabic label.
    backTooltip,
    // The veil button's tooltip.
    ar.leaderboardVeil,
    // The scope control's three options.
    ar.leaderboardWindowWeekly,
    ar.leaderboardWindowMonthly,
    ar.leaderboardWindowAllTime,
    // The metric control's two options.
    ar.leaderboardMetricLight,
    ar.leaderboardMetricStreaks,
    // The countdown, on the all-time window.
    ar.leaderboardNoReset,
    // The podium's three values — the metric's number for each column.
    for (final LeaderboardRow row in ordered.take(3))
      ar.digits(leaderboardValueOf(row, metric)),
    // ...and the three places its columns print.
    for (int place = 1; place <= 3; place++) ar.digits(place),
  ];

  for (int index = 0; index < ordered.length; index++) {
    final LeaderboardRow row = ordered[index];
    // The **display** position, which is the index in this metric's order and
    // not the server's `rank` — they differ under the `streaks` metric, and
    // the screen prints the display one.
    final int position = leaderboardPositionOf(ordered, row);
    final bool isReader = ranked && row.rank == _communionStanding.rank;

    // The name — and **only two of the four names on this screen are Arabic
    // runs**: the reader's (Latin plus the Arabic " · أنت") and a veiled
    // witness's ("شاهد ٣"). A witness's un-veiled name is the pure Latin
    // the wire sent, so it is **not** a run and declaring it would trip the
    // exact-set assertion with "a declared run the tree never held".
    final String? name = _communionName(
      ar,
      row,
      position,
      isReader: isReader,
      veiled: veiled,
    );
    if (name != null) declared.add(name);

    // The list's own three numbers. The podium's are already declared above.
    if (index >= 3) {
      declared.addAll(<String>[
        ar.digits(position),
        _communionSubline(ar, row, metric),
        ar.digits(leaderboardValueOf(row, metric)),
      ]);
    }
  }

  if (!ranked) {
    // The reader the payload does not rank: the session's name, "not ranked
    // yet", and **no value at all** — a fabricated number is the one thing D9
    // forbids.
    declared.add('$_communionSessionName · ${ar.leaderboardYou}');
    declared.add(ar.leaderboardUnranked);
    return declared;
  }

  // The you-card: the reader's own row.
  final LeaderboardRow reader = leaderboardReaderRow(
    _communionBoard.rows,
    standingRank: _communionStanding.rank,
  )!;
  final int position = leaderboardPositionOf(ordered, reader);
  declared.add('${reader.fullName} · ${ar.leaderboardYou}');
  declared.add(ar.digits(position));
  declared.add(ar.digits(leaderboardValueOf(reader, metric)));

  final LeaderboardGap? gap = leaderboardGapFor(
    ordered: ordered,
    readerPosition: position,
    metric: metric,
  );
  if (gap != null) {
    // The witness above the reader, veiled or not.
    final String above = veiled
        ? ar.leaderboardWitness(ar.digits(gap.abovePosition))
        : gap.aboveName;
    final String base = ar.leaderboardGapLine(above, ar.digits(gap.gap));
    // **One run, not two**: the card composes the base sentence and the pass
    // hint into a single `Text`. And the pass hint is the **light** metric's
    // ÷15 economy, so it is absent under `streaks` (D14) and the string is
    // shorter there.
    declared.add(
      gap.verses == null
          ? base
          : '$base · ${ar.leaderboardPassHint(ar.digits(gap.verses!))}',
    );
  }

  return declared;
}

/// The name a row carries, or `null` when the name is **not** an Arabic run.
///
/// `full_name` arrives from the wire as one Latin string for both locales —
/// the backend has no Arabic name field — so a witness's un-veiled name is
/// pure Latin and is not a run at all.
String? _communionName(
  AppLocalizations ar,
  LeaderboardRow row,
  int position, {
  required bool isReader,
  required bool veiled,
}) {
  if (veiled && !isReader) return ar.leaderboardWitness(ar.digits(position));
  if (isReader) return '${row.fullName} · ${ar.leaderboardYou}';
  return null;
}

/// The sub-line a row carries under [metric].
///
/// The row shows the **other** metric's number beside that metric's own name
/// (`leaderboard_row_tile.dart`'s switch), so the `light` board's sub-line is
/// the streak count and the `streaks` board's is the score.
String _communionSubline(
  AppLocalizations ar,
  LeaderboardRow row,
  LeaderboardMetric metric,
) => switch (metric) {
  LeaderboardMetric.light =>
    '${ar.digits(row.currentStreak)} ${ar.leaderboardMetricStreaks}',
  LeaderboardMetric.streaks =>
    '${ar.digits(row.score)} ${ar.leaderboardMetricLight}',
};

/// The framework's Arabic label for the back control.
///
/// `MaterialLocalizations.of(context).backButtonTooltip` is the string
/// `CommunionAppBar`'s chevron carries, and on the Arabic arm it is **Arabic**
/// — so it is an Arabic run, and the declared set has to name it.
///
/// Read from the framework's own table and never typed, for `/`'s reason: a
/// hand-typed Arabic string in a test is a second copy of the corpus, and
/// this one belongs to the framework rather than to the app.
Future<String> arabicBackTooltip() async =>
    (await GlobalMaterialLocalizations.delegate.load(const Locale('ar')))
        .backButtonTooltip;

/// The reader's standing in [_communionBoard].
const LeaderboardStanding _communionStanding = LeaderboardStanding(
  rank: 4,
  score: 560,
);

/// The session the board's reader falls back to.
final class _CommunionAuthRepo implements AuthRepository {
  const _CommunionAuthRepo();

  @override
  Future<Result<AuthSession>> getCurrentSession() async =>
      Result<AuthSession>.of(
        AuthSession(
          userId: 'u4',
          displayName: _communionSessionName,
          email: 'david@example.com',
          initials: 'DM',
          createdAt: DateTime.utc(2026),
        ),
      );

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async => getCurrentSession();

  @override
  Future<Result<void>> signOut() async => Result<void>.of(null);
}

/// A board the port refuses to answer.
///
/// The failure's **message** is the server's own English text, on the reason
/// `ErrorView`'s doc gives: the message is whatever the server sent, and the
/// client renders it in the ambient arm's family.
final class _CommunionFailingRepo implements LeaderboardRepository {
  const _CommunionFailingRepo();

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async => const Left<Failure, LeaderboardBoard>(
    Failure(
      kind: FailureKind.validation,
      message: 'Could not read the leaderboard: x-group-id is not a number',
    ),
  );
}

/// A board the port answers with, whatever the request.
final class _CommunionRepo implements LeaderboardRepository {
  const _CommunionRepo(this.answer);

  final LeaderboardBoard answer;

  @override
  Future<Result<LeaderboardBoard>> board({
    required LeaderboardWindow window,
    required int limit,
  }) async => Result<LeaderboardBoard>.of(answer);
}

/// Pumps `/communion` over [board] and settles it.
///
/// ## WHY THE SCOPE IS NOT OPTIONAL
///
/// The page reads the veil and the podium toggle through `SettingsScope.of`,
/// which falls back to the locator's `SettingsHandle` when no scope is above
/// the context — and that fallback is **not watched**, so a page pumped bare
/// would never repaint when the settings arrive. `settingsScope` is the one
/// place that spelling lives.
///
/// ## AND WHY THE FRAMES ARE COUNTED
///
/// Not `pumpAndSettle`: the ambient clocks under `NeuralScaffold` never
/// settle, so settling is a timeout rather than a green tick. The frames are
/// here for the two futures the screen waits on — the settings load and the
/// board request — and the veil arm depends on the first one having landed
/// before the last frame.
/// Pumps `/communion` over a **failed** request.
Future<void> _pumpCommunionFailed(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  settingsHarness(initial: const UserSettings());
  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: const LoadLeaderboard(_CommunionFailingRepo()),
    getReaderSession: const GetBoardReaderSession(_CommunionAuthRepo()),
    cheerRepository: LocalCheerRepository(CheerLocalDataSource()),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: locale,
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: settingsScope(tester, CommunionPage(cubit: cubit)),
    ),
  );
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpCommunion(
  WidgetTester tester,
  LeaderboardBoard board, {
  Locale locale = const Locale('en'),
  bool veiled = false,
  LeaderboardMetric metric = LeaderboardMetric.light,
}) async {
  settingsHarness(initial: UserSettings(veilWitnesses: veiled));
  final LeaderboardCubit cubit = LeaderboardCubit(
    loadLeaderboard: LoadLeaderboard(_CommunionRepo(board)),
    getReaderSession: const GetBoardReaderSession(_CommunionAuthRepo()),
    cheerRepository: LocalCheerRepository(CheerLocalDataSource()),
  );
  addTearDown(cubit.close);
  // The metric is a **presentation-only** choice over the board already in
  // hand (`LeaderboardCubit.selectMetric`'s doc), and the page's own load
  // preserves it — so it is set before the pump.
  cubit.selectMetric(metric);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: locale,
      // Derived from [locale] and **not** left to the default, for
      // `login_harness.dart`'s recorded reason: the harness wraps its child in
      // an explicit `Directionality` that overrides the one Material installs
      // from the locale, so an `ar` locale rendered LTR reads as "the page
      // ignores RTL".
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: settingsScope(tester, CommunionPage(cubit: cubit)),
    ),
  );
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// ## WHY THE STUB PUMPER IS GONE
///
/// This file used to carry a `_pumpStub` helper for the three screens that were still
/// `Placeholder for …` stubs. Phase 8 lifted `/quiz` and Phase 9 lifted `/settings`, so
/// the helper had no caller left — and an unused private function in a gate file is
/// worse than a missing one: it is a second, silently-drifting way to mount a screen
/// for this gate, and `dart analyze --fatal-infos` (Gate 1) is what stopped it sitting
/// there. Each screen now builds the tree it actually needs: a bloc over a real payload
/// for `/quiz`, a real store over `shared_preferences` for `/settings`.

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

/// The surface the `/settings` gate is pumped on.
///
/// ## WHY IT IS **TALLER THAN A PHONE**
///
/// The gate reads the **painted** tree, and a `Tooltip` paints its message
/// only while it is held open — and the gate's probe holds each tooltip open
/// with a **long press on the tooltip's own target**. A target that is
/// **off-screen** cannot be long-pressed, so its tooltip never paints and its
/// name is not a run at all.
///
/// The Workshop's type-size stepper is in the **sixth** of its seven groups, so
/// at a phone's height it is below the fold and its two names — "Decrease font
/// size" and "Increase font size" — would silently drop out of the declared
/// set. **The gate would then be measuring a window rather than a screen**,
/// which `/journey`'s group refuses to do for exactly this reason ("A declared
/// set that changed with the viewport would be a gate measuring the window
/// rather than the screen").
///
/// **So the surface holds the whole screen.** The page's content is about
/// **2960** tall in the ready state and about **3134** in the failure state —
/// the notice above the groups adds its own height — and this surface is
/// **3200**, so the scroll view has nothing to scroll in **either** state and
/// every tooltip on the page is reachable.
///
/// **And the arm asserts the extent is zero** (see
/// [_expectTheWholeScreenIsOnTheSurface]), so a screen that grew past this
/// surface fails with "the surface is too short now" rather than with a
/// puzzling "the list is stale".
const Size _settingsWholeScreenSurface = Size(390, 3200);

/// The Workshop's own scroll view has nothing to scroll on
/// [_settingsWholeScreenSurface].
///
/// ## WHY THIS IS ASSERTED RATHER THAN ASSUMED
///
/// The surface is a number in a test, and the screen's content is another
/// number that moves every time a row is added. When the content outgrows the
/// surface the page scrolls again, the type-size stepper falls below the fold,
/// and its two tooltips stop painting — which would make the declared set
/// **wrong** rather than the screen broken, and the failure would read as "the
/// list is stale".
///
/// This assertion turns that into the truth it is: the surface is too short
/// for the screen it is meant to hold.
void _expectTheWholeScreenIsOnTheSurface(
  WidgetTester tester, {
  required String restoreRowTitle,
}) {
  final Finder restoreRow = find.text(restoreRowTitle);
  expect(
    restoreRow,
    findsOneWidget,
    reason:
        'the restore row is on the screen — it is the last row of the sixth '
        'group, and the scroll view below is measured through it.',
  );
  final ScrollableState page = tester.state<ScrollableState>(
    find.ancestor(of: restoreRow, matching: find.byType(Scrollable)).first,
  );
  expect(
    page.position.maxScrollExtent,
    0,
    reason:
        'the `/settings` gate is pumped on a surface tall enough to hold the '
        'whole screen, so that every tooltip on it is reachable. The page has '
        'grown past that surface: raise `_settingsWholeScreenSurface`, or the '
        'type-size stepper falls below the fold and its two names stop being '
        'runs.',
  );
}

/// Every painted run on `/settings` is carried by a bundled face — **the run's
/// own, or the fallback the screen declares for the arrow**.
///
/// ## WHY THIS IS NOT `expectNoTofuInAnyRun`
///
/// The shared instrument reads a run's **primary** family and asks that family
/// for the glyph. One run on this screen is painted by a **fallback**: the `↺`
/// (U+21BA) is in **no** bundled mono or scripture face — measured, it is in
/// `Inter` and `IBMPlexSansArabic` alone — and both the restore row
/// (`workshop_rows.dart`'s `_arValueStyle`) and the restore toast
/// (`workshop_restore_toast.dart`) declare `fontFamilyFallback: [Inter]`, so
/// the engine draws the **arrow** out of `Inter` and the letters out of the
/// face the run names.
///
/// The shared instrument would report that arrow as **tofu**, which it is not,
/// and the arrow is the one glyph on this screen the instrument cannot see. So
/// the check below is the shared one **plus the fallback**.
///
/// ## AND THE UNION IS **NARROW** ON PURPOSE
///
/// Only the runs that carry the arrow get `Inter` added to their coverage.
/// Every other run is checked against its own family alone, exactly as the
/// shared instrument checks it — so a run that stopped being carried by its own
/// face is still a finding.
///
/// **And the fallback's presence is asserted, not assumed.** The row that owns
/// the arrow declares it (`workshop_rows.dart`), and the `/settings` group's own
/// row reads the declaration off the rendered `Text` — so a row that lost its
/// `fontFamilyFallback` fails there and fails here, and the two are the same
/// claim read from two sides.
Future<void> _expectSettingsTofuFree(
  WidgetTester tester, {
  required String screen,
}) async {
  for (final RenderedRun run in await renderedRuns(tester)) {
    // **The framework's own family is allowed**, exactly as the shared
    // instrument allows it: an `Icon` builds a `RichText` in the framework's
    // `MaterialIcons` font, the icons carry no text, and the coverage check
    // cannot ask about a family `pubspec.yaml` does not declare.
    if (kFrameworkFamilies.contains(run.family)) continue;
    expect(
      kBundledFontFamilies.contains(run.family),
      isTrue,
      reason:
          '`${run.label}` renders in `${run.family}`, which `pubspec.yaml` does '
          'not declare. A name outside the declared families resolves to the '
          'engine\'s default font with no error at all — and the engine\'s '
          'default font is not one this project ships.',
    );
    if (!kBundledFontFamilies.contains(run.family)) continue;
    final Set<int> available = <int>{
      ...codepointsForFamily(run.family),
      if (run.label.contains(kRestoreGlyph))
        ...codepointsForFamily(EvaTypography.uiFamily),
    };
    final List<int> missing = <int>{
      for (final int unit in run.label.codeUnits)
        if (!isIgnorableCodeUnit(unit) && !available.contains(unit)) unit,
    }.toList()..sort();
    expect(
      missing,
      isEmpty,
      reason:
          '`${run.label}` is rendered in `${run.family}`, which has no glyph for '
          '${missing.map((int u) => 'U+${u.toRadixString(16).toUpperCase()}').join(", ")} — '
          'these would be tofu boxes on $screen.',
    );
  }
}

// ---------------------------------------------------------------------------
// `/journey`'s own fixtures and helpers.
//
// The `/communion` group's helpers are above; these are the same shape, for
// the eighth screen.
// ---------------------------------------------------------------------------

/// The four scheduled days `/journey`'s three rings are derived from.
///
/// **Four days, three of them completed, over two books** — chosen so the
/// three derived numbers are all different and none of them is a copy of the
/// prototype's `.83` / `.86` / `.92` decoration:
///
/// | the derived number | the arithmetic | the value on the Arabic arm |
/// | --- | --- | --- |
/// | the completion ratio | 3 completed of 4 days | `٧٥٪` |
/// | the answered count | 10 + 10 + 0 + 6 | `٢٦` |
/// | the accuracy ratio | 20 correct of 26 answered | `٧٧٪` |
/// | the constellations | the distinct completed books — 43 and 19 | `٢` |
///
/// **The book names are the payload's own**, in both arms, and neither reaches
/// the screen: the journey draws no book name at all. They are here because the
/// entity carries them.
const List<StreakHistoryEntry> _journeyHistory = <StreakHistoryEntry>[
  StreakHistoryEntry(
    readingId: 'r1',
    scheduledDate: '2026-01-04',
    bookNumber: 43,
    bookNameEn: 'John',
    bookNameAr: 'يوحنا',
    referenceEn: 'John 3:1-5',
    referenceAr: 'يوحنا ٣: ١-٥',
    totalQuestions: 10,
    answeredQuestions: 10,
    correctAnswers: 8,
    pointsEarned: 8,
    isCompleted: true,
  ),
  StreakHistoryEntry(
    readingId: 'r2',
    scheduledDate: '2026-01-03',
    bookNumber: 43,
    bookNameEn: 'John',
    bookNameAr: 'يوحنا',
    referenceEn: 'John 3:6-10',
    referenceAr: 'يوحنا ٣: ٦-١٠',
    totalQuestions: 10,
    answeredQuestions: 10,
    correctAnswers: 8,
    pointsEarned: 8,
    isCompleted: true,
  ),
  StreakHistoryEntry(
    readingId: 'r3',
    scheduledDate: '2026-01-02',
    bookNumber: 19,
    bookNameEn: 'Psalms',
    bookNameAr: 'المزامير',
    referenceEn: 'Psalms 23:1-6',
    referenceAr: 'المزمور ٢٣: ١-٦',
    totalQuestions: 8,
    answeredQuestions: 0,
    correctAnswers: 0,
    pointsEarned: 0,
    isCompleted: false,
  ),
  StreakHistoryEntry(
    readingId: 'r4',
    scheduledDate: '2026-01-01',
    bookNumber: 19,
    bookNameEn: 'Psalms',
    bookNameAr: 'المزامير',
    referenceEn: 'Psalms 23:7-12',
    referenceAr: 'المزمور ٢٣: ٧-١٢',
    totalQuestions: 6,
    answeredQuestions: 6,
    correctAnswers: 4,
    pointsEarned: 4,
    isCompleted: true,
  ),
];

/// The streak the hero number shows.
///
/// `eva/redesign.html:589`'s is the literal `12`, written by JavaScript at
/// `:989`; this one is the endpoint's own `current_streak`.
const StreakSummary _journeySummary = StreakSummary(
  currentStreak: 12,
  longestStreak: 6,
  lastCompletedDate: '2026-01-04',
  todayStatus: StreakTodayStatus.completed,
  todayCompleted: true,
  todayScheduled: true,
  nextMilestone: 3,
  daysToMilestone: 3,
);

/// How many stars the sky line counts.
///
/// The sky is a **real** port read (`SkyRepository.count()`), and the number
/// here is the fixture's, not the prototype's `0` at `:596`.
const int _journeyStarsLit = 7;

/// The medals the shelf holds, in the prototype's draw order (`:599-602`).
const List<Medal> _journeyEarnedMedals = Medal.values;

/// How many medals there are in all — the prototype's "4 / 12" (`:597`).
const int _journeyTotalMedals = 12;

/// The failure the failed arm reports.
///
/// **The server's own wording**, which is English — so it is not an Arabic run
/// and the declared set does not name it. The family that renders it is
/// `ErrorView`'s own `arabicAware`.
const Failure _journeyFailure = Failure(
  kind: FailureKind.network,
  message: 'Could not read the streak: the request timed out',
);

/// The Arabic runs `/journey` paints on its **ready** arm.
///
/// ## BUILT FROM THE SCREEN'S OWN ARITHMETIC, NOT A COPY OF IT
///
/// The three ring values come from `deriveJourneyRings` and
/// `countCompletedBooks` — the same domain functions the page calls — and the
/// percentages come from `journeyPercent`, the page's own transform. So a
/// change to the derivation shows up here as a **mismatch** rather than as two
/// lists that agree by accident.
///
/// ## AND THE TWENTY-ONE `journey*` KEYS ARE NINETEEN RUNS HERE
///
/// Nineteen of the twenty-one are painted **on the ready arm**, and two of
/// them (`journeyRowBoard` and `journeyRowSettings`) are painted **twice** —
/// once as the app bar's tooltip and once as the account row's title — so the
/// ready screen draws **twenty-nine** Arabic runs over **twenty-seven**
/// distinct labels: the nineteen keys, the framework's own Arabic label for
/// the back control, and the seven runs the screen **composes out of
/// numerals**.
///
/// The two that are not on the ready arm:
///
/// * `journeyUnavailableSuffix` is **not painted at all** — it is the reason
///   a dead row carries in its **accessible name**
///   (`journey_account_rows.dart`'s `Semantics(label: …)`), and an accessible
///   name never reaches a glyph buffer. Declaring it would be the exact
///   failure the gate exists to catch — the same category error `/quiz`'s
///   `quizProgress` records — and the reason it is asserted is
///   `journey_page_test.dart`'s accessibility group, which reads the
///   semantics tree.
/// * `journeyRetry` is painted on the **failed** arm only, and the failed
///   arm's declared set names it.
List<String> _journeyReadyRuns(AppLocalizations ar) {
  final JourneyRings rings = deriveJourneyRings(_journeyHistory);
  final int constellations = countCompletedBooks(_journeyHistory);

  return <String>[
    // The app bar: the title and the two buttons' tooltips.
    //
    // **And NO back control's label**, because there is no back control: the
    // journey is a **tab** now (Phase 6), and a tab has no way back. The
    // prototype's journey has a 68px spacer where the chevron would be
    // (`eva/redesign.html:578`), and the client has the spacer too. The
    // framework's own Arabic `backButtonTooltip` ("رجوع") therefore **is not
    // painted on this screen at all** — and a declared set that still named it
    // would be a list of runs a reader never sees.
    ar.journeyTitle,
    ar.journeyRowBoard,
    ar.journeyRowSettings,
    // The identity block: the role line — with its **baked-in** `٧` — the
    // hero's number and the hero's sub-line.
    ar.journeyScribe,
    ar.digits(_journeySummary.currentStreak),
    ar.journeyStreakSub,
    // The three rings, in the prototype's order: a value and a label each.
    journeyPercent(ar, rings.completion),
    ar.journeyRingVerses,
    ar.digits(rings.answered),
    ar.journeyRingQuizzes,
    journeyPercent(ar, rings.accuracy),
    ar.journeyRingAccuracy,
    // The sky line: three words and two counts, in five spans — the `·`
    // separators are the widget's own and carry no Arabic.
    ar.journeySky,
    ar.digits(_journeyStarsLit),
    ar.journeyStarsLit,
    ar.digits(constellations),
    ar.journeyConstellations,
    // The medals: the section label, the count and the four names.
    ar.journeyMedals,
    '${ar.digits(_journeyEarnedMedals.length)} / ${ar.digits(_journeyTotalMedals)}',
    for (final Medal medal in _journeyEarnedMedals) medal.label(ar),
    // The account block: the section label, the two live rows' titles (already
    // declared above as the app bar's tooltips) and the two dead rows'.
    ar.journeyAccount,
    ar.journeyRowShare,
    ar.journeyRowPlans,
  ];
}

/// The screen's **mono** runs, named.
///
/// Every one of them is written in the `.mono` face in the prototype — `:30`'s
/// rule, and `:135`, `:136`, `:409` and `:418`'s four RTL overrides — so every
/// one of them is a run that would be tofu if `arabicAware` had not been
/// applied to it.
List<String> _journeyMonoRuns(AppLocalizations ar) {
  final JourneyRings rings = deriveJourneyRings(_journeyHistory);

  return <String>[
    // The role line and the hero's sub-line.
    ar.journeyScribe,
    ar.journeyStreakSub,
    // The sky line: three words.
    ar.journeySky,
    ar.journeyStarsLit,
    ar.journeyConstellations,
    // The three rings: a value and a label each.
    journeyPercent(ar, rings.completion),
    ar.journeyRingVerses,
    ar.digits(rings.answered),
    ar.journeyRingQuizzes,
    journeyPercent(ar, rings.accuracy),
    ar.journeyRingAccuracy,
    // The medals: four names and the count.
    '${ar.digits(_journeyEarnedMedals.length)} / ${ar.digits(_journeyTotalMedals)}',
    for (final Medal medal in _journeyEarnedMedals) medal.label(ar),
    // The two section labels.
    ar.journeyMedals,
    ar.journeyAccount,
  ];
}

/// The screen's **digit-bearing** runs, named.
///
/// **Nine of them**, and they are the sharpest case in this group: every one
/// carries an Arabic-Indic digit, and `JetBrainsMono` — the face the screen's
/// mono runs are written in — carries none.
List<String> _journeyDigitRuns(AppLocalizations ar) {
  final JourneyRings rings = deriveJourneyRings(_journeyHistory);

  return <String>[
    // The hero's number — the one digit run that is **not** mono: the hero is
    // `displayLarge` on the scripture face (`:399-400`).
    ar.digits(_journeySummary.currentStreak),
    // The two ratio rings and the count ring.
    journeyPercent(ar, rings.completion),
    ar.digits(rings.answered),
    journeyPercent(ar, rings.accuracy),
    // The sky line's two counts.
    ar.digits(_journeyStarsLit),
    ar.digits(countCompletedBooks(_journeyHistory)),
    // The medals' own count.
    '${ar.digits(_journeyEarnedMedals.length)} / ${ar.digits(_journeyTotalMedals)}',
    // And the two ARB rows that **bake** a digit into their text — the
    // prototype's own i18n table does the same (`:933` and `:937`).
    ar.journeyScribe,
    ar.journeyMedalStreakSeven,
  ];
}

/// Pumps `/journey` and settles it.
///
/// **The frames are counted, not settled.** The ambient clocks under
/// `NeuralScaffold` never settle, so `pumpAndSettle` is a timeout rather than
/// a green tick. The frames are here for the five futures the screen waits on
/// and for the rings' own entrance.
///
/// ## AND THE SURFACE IS **WIDE**, AND THAT IS A MEASUREMENT
///
/// `:410` is `.medals{display:flex;gap:12px;overflow-x:auto}`, and the four
/// medals are 4 × 104 + 3 × 12 = **452** wide — so on a 390px phone the strip
/// **scrolls**, and the fourth medal is not in the tree at all. The gate
/// declares the **screen's** runs rather than the viewport's, so the surface
/// here is wide enough for all four: 452 + the strip's own 18px of padding on
/// each side, plus the page's 14px gutter on each side, is 516.
///
/// A declared set that changed with the viewport would be a gate measuring the
/// window rather than the screen.
Future<void> _pumpJourney(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool failed = false,
}) async {
  tester.view.physicalSize = const Size(800, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final JourneyCubit cubit = JourneyCubit(
    getReaderSession: const GetJourneyReaderSession(_JourneyAuthRepo()),
    loadStreakSummary: LoadJourneyStreakSummary(
      _JourneyStreakRepo(fails: failed),
    ),
    loadStreakHistory: LoadJourneyStreakHistory(
      _JourneyStreakRepo(fails: failed),
    ),
    loadSkyCount: const LoadJourneySkyCount(_JourneySkyRepo()),
    // **The shipped stub, not a fixture.** The medals are ADR-0022's fiction
    // behind a port, and the fiction lives in the data source — so the gate
    // reads the same four names the app ships.
    medalRepository: MedalRepositoryImpl(MedalLocalDataSource()),
  );
  addTearDown(cubit.close);

  final _JourneyRouter router = _JourneyRouter();
  addTearDown(router.dispose);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: locale,
      // Derived from [locale] and **not** left to the default, for
      // `login_harness.dart`'s recorded reason: the harness wraps its child in
      // an explicit `Directionality` that overrides the one Material installs
      // from the locale, so an `ar` locale rendered LTR reads as "the page
      // ignores RTL".
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      // The router, and why the screen needs one — see [_JourneyRouter].
      child: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: JourneyPage(cubit: cubit),
      ),
    ),
  );
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Mounts the **dock**, for the `/dock` group.
///
/// The dock is **chrome, not a screen** — the shell draws it over whichever
/// tab is showing — so this mounts the widget itself. The gate is about what
/// a reader sees, and the reader sees exactly this widget on every tab.
Future<void> _pumpDock(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(800, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      locale: locale,
      // Derived from [locale] and **not** left to the default, for the same
      // reason `_pumpJourney` says it: the harness wraps its child in an
      // explicit `Directionality` that overrides the one Material installs.
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: Builder(
        builder: (BuildContext context) => LumenDock(
          items: <LumenDockItem>[
            LumenDockItem(
              label: context.l10n.dockHome,
              glyph: const Icon(Icons.home_outlined, size: 20),
            ),
            LumenDockItem(
              label: context.l10n.dockRead,
              glyph: const Icon(Icons.auto_stories_outlined, size: 20),
            ),
            LumenDockItem(
              label: context.l10n.dockToday,
              glyph: const LumenOrb(),
            ),
            LumenDockItem(
              label: context.l10n.dockBoard,
              glyph: const Icon(Icons.emoji_events_outlined, size: 20),
            ),
            LumenDockItem(
              label: context.l10n.dockJourney,
              glyph: const Icon(Icons.person_outline, size: 20),
            ),
          ],
          activeIndex: 0,
          onSelect: (int _) {},
        ),
      ),
    ),
  );
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A router whose navigation goes nowhere.
///
/// ## WHY THE GATE NEEDS ONE, AND IT IS NOT COSMETIC///
/// The shared instrument's tooltip probe long-presses every `Tooltip` on the
/// screen and then **releases the gesture**. `/journey`'s app bar puts its
/// **rows'** strings on its **tooltips** — `journeyRowBoard` and
/// `journeyRowSettings`, one string in two places on purpose, so a tooltip
/// and its row cannot drift — and the probe's "is this message painted?" check
/// is therefore satisfied by the **account row's title** rather than by the
/// tooltip. The gesture is released before the long press can win the arena,
/// and the **button's own tap fires**.
///
/// On `/communion` the same probe releases the same way, but its tooltips carry
/// strings nothing else paints, so the long press wins and no tap happens.
/// Here the tap is real, and without a router above the page it throws
/// `AutoRouter operation requested with a context that does not include an
/// AutoRouter` — the **harness** talking, not the screen.
///
/// So the screen is given a router whose navigation is a no-op, and the tap has
/// nothing to do. The gate still reads the **painted** tree, and the declared
/// set is still the screen's.
///
/// ## AND IT IS THE APP'S OWN ROUTER, SUBCLASSED
///
/// `StackRouter` cannot be implemented outside `auto_route`'s own library — it
/// has a private member — so the only concrete `StackRouter` this test can
/// reach is the app's [AppRouter]. Subclassing it and answering "nothing
/// happened" to the two calls the app bar makes is the smallest way to give
/// the screen a router without mounting the whole app.
final class _JourneyRouter extends AppRouter {
  _JourneyRouter() : super(const _JourneyAuthStatus(), _JourneyAuthChanges());

  @override
  Future<T?> pushPath<T extends Object?>(
    String path, {
    bool includePrefixMatches = false,
    OnNavigationFailure? onFailure,
  }) async => null;

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async => false;
}

/// The session the router's guard reads.
///
/// **Signed in**, because the app bar's buttons are the ones the probe taps
/// and the screen is behind the auth guard.
final class _JourneyAuthStatus implements AuthStatus {
  const _JourneyAuthStatus();

  @override
  bool get isAuthenticated => true;
}

/// The router's re-evaluation signal.
///
/// **A notifier nobody notifies.** The app's own is a `ChangeNotifier` fed by
/// the auth bloc, and this gate has no session to change.
final class _JourneyAuthChanges extends ReevaluateListenable {}

/// The session `/journey` names the reader by.
///
/// **Latin, and that is the point.** The backend has no Arabic name field —
/// the same fact `/communion`'s group records — so the reader's own name and
/// monogram are pure Latin and are **not** Arabic runs.
final class _JourneyAuthRepo implements AuthRepository {
  const _JourneyAuthRepo();

  @override
  Future<Result<AuthSession>> getCurrentSession() async =>
      Result<AuthSession>.of(
        AuthSession(
          userId: 'u4',
          displayName: 'David Mina',
          email: 'david@example.com',
          initials: 'DM',
          createdAt: DateTime.utc(2026),
        ),
      );

  @override
  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) => getCurrentSession();

  @override
  Future<Result<void>> signOut() async => Result<void>.of(null);
}

/// The streak the screen's hero and its rings are derived from.
final class _JourneyStreakRepo implements StreakRepository {
  const _JourneyStreakRepo({required this.fails});

  /// Whether the read fails, which is what puts the screen in its failed arm.
  final bool fails;

  @override
  Future<Result<StreakSummary>> summary() async => fails
      ? const Left<Failure, StreakSummary>(_journeyFailure)
      : Result<StreakSummary>.of(_journeySummary);

  @override
  Future<Result<List<StreakHistoryEntry>>> history() async => fails
      ? const Left<Failure, List<StreakHistoryEntry>>(_journeyFailure)
      : Result<List<StreakHistoryEntry>>.of(_journeyHistory);
}

/// The lit stars the sky line counts.
final class _JourneySkyRepo implements SkyRepository {
  const _JourneySkyRepo();

  @override
  Future<Result<SkyEntry>> record(SkyEntry entry) async =>
      Result<SkyEntry>.of(entry);

  @override
  Future<Result<List<SkyEntry>>> entries() async =>
      Result<List<SkyEntry>>.of(const <SkyEntry>[]);

  @override
  Future<Result<int>> count() async => Result<int>.of(_journeyStarsLit);

  @override
  Future<Result<void>> clear() async => Result<void>.of(null);
}

/// Whether the icon under [finder] is flipped horizontally.
///
/// **The sign of the x-scale, and not the presence of a `Transform`.** The
/// design system's own transforms are translations — `SettingsTile`'s hover
/// slide is `Matrix4.translationValues(4, 0, 0)` — so "there is a `Transform`
/// near it" is true of almost everything and answers nothing.
///
/// Flutter's `Icon` wraps its `RichText` in a `Transform` that scales x by
/// −1 under RTL **when the icon declares `matchTextDirection`**, and the
/// x-scale's sign is what says "mirrored".
///
/// **And the `Transform` is *inside* the icon, not above it** — `Icon.build`
/// returns the `Transform` as the icon's own child — so the walk is a
/// *descendant* search and not an ancestor one.
bool _isFlipped(WidgetTester tester, Finder finder) {
  final Finder flips = find.descendant(
    of: finder,
    matching: find.byType(Transform),
  );
  for (final Element element in flips.evaluate()) {
    final Transform flip = element.widget as Transform;
    if (flip.transform.entry(0, 0) < 0) return true;
  }
  return false;
}

/// Whether the run [left] is painted to the left of the run [right].
bool _leftOf(WidgetTester tester, String left, String right) =>
    tester.getRect(find.text(left)).left <
    tester.getRect(find.text(right)).left;

/// The painted ink of the account rows' trailing chevron, as a binary mask.
///
/// **One row of `'0'`/`'1'` per pixel row, cropped to the ink.** The crop
/// removes the one difference between the two arms that is not the mirroring —
/// under RTL the paragraph puts the glyph at the other end of its own box — so
/// what is left is the glyph's *shape*, and the shape is what "mirrored" is
/// about.
Future<List<String>> _chevronMask(
  WidgetTester tester,
  TextDirection direction, {
  int threshold = _chevronInkThreshold,
}) async {
  _pinSurface(tester);
  await tester.pumpWidget(
    evaPrimitiveHarness(
      theme: EvaThemeDark.theme,
      // **The English arm on both pumps.** The row's *title* is not what this
      // probe is about, and holding it still keeps the two captures
      // comparable. The harness's own default locale is `en`, so saying it
      // again would be the redundant argument the linter refuses.
      textDirection: direction,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      child: const RepaintBoundary(
        key: _journeyChevronKey,
        child: JourneyAccountRows(
          onOpenBoard: _noopJourney,
          onOpenSettings: _noopJourney,
        ),
      ),
    ),
  );
  await tester.pump();

  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_journeyChevronKey));
  final (Uint8List, int)? captured = await tester.runAsync<(Uint8List, int)>(
    () async {
      final ui.Image image = boundary.toImageSync();
      final ByteData? data = await image.toByteData();
      final int width = image.width;
      image.dispose();
      if (data == null) throw StateError('the chevron produced no pixels');
      return (data.buffer.asUint8List(), width);
    },
  );
  if (captured == null) throw StateError('runAsync returned no pixels');
  final (Uint8List bytes, int stride) = captured;

  final Rect chevron = tester.getRect(find.text('›').first);
  final Rect box = tester.getRect(find.byKey(_journeyChevronKey));
  final int left = (chevron.left - box.left).round();
  final int top = (chevron.top - box.top).round();
  final int width = chevron.width.round();
  final int height = chevron.height.round();

  final List<String> mask = <String>[];
  for (int y = 0; y < height; y++) {
    final StringBuffer row = StringBuffer();
    for (int x = 0; x < width; x++) {
      final int offset = (((top + y) * stride) + (left + x)) * 4;
      row.write(bytes[offset + 3] > threshold ? '1' : '0');
    }
    mask.add(row.toString());
  }
  return _cropToInk(mask);
}

/// Pins the surface the pixel probes are captured on.
///
/// **Logical pixels and physical ones have to be the same scale.** The crop is
/// measured in logical pixels and the capture is in physical ones, and the
/// default test surface is 800×600 at **3×** — so an unpinned probe reads a
/// third-scale corner of the glyph it meant to read.
void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The alpha above which a pixel counts as inked.
///
/// **64 of 255 — a quarter of full coverage.** Measured over the eight
/// thresholds, and this is the one at which the two arms' chevrons are the
/// **same shape**: at 0 and 40 the antialiasing of the point lands on a
/// different pixel of the grid on the two arms, and at 16 and 200 the two arms
/// do not even agree on how wide the glyph is. At 64 the shape is three pixels
/// across and five tall, and the RTL one is the LTR one reversed — **with no
/// slack at all**.
///
/// The slack the assertion allows is one pixel in the whole mask, which is the
/// one place a different rasteriser could put the point's antialiasing.
const int _chevronInkThreshold = 64;

/// The mask cropped to its own ink.
///
/// **And the ink's own box, so the two arms' masks are the glyph** rather than
/// a window onto it. A mask with no ink comes back unchanged, so a chevron
/// that was not painted fails the comparison rather than passing it.
List<String> _cropToInk(List<String> mask) {
  int top = mask.length;
  int bottom = -1;
  int left = 1 << 30;
  int right = -1;
  for (int y = 0; y < mask.length; y++) {
    final String row = mask[y];
    for (int x = 0; x < row.length; x++) {
      if (row[x] != '1') continue;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  if (bottom < 0) return mask;
  return <String>[
    for (int y = top; y <= bottom; y++) mask[y].substring(left, right + 1),
  ];
}

/// A row of a mask, reversed.
String _reverseRow(String row) => row.split('').reversed.join();

/// How many pixels two masks of the same shape differ in.
///
/// **And the shorter of the two is padded with blanks**, so a mask that lost a
/// column counts the loss rather than hiding it.
int _pixelDifferences(List<String> a, List<String> b) {
  final int rows = a.length < b.length ? a.length : b.length;
  int differing = 0;
  for (int y = 0; y < rows; y++) {
    final String left = a[y];
    final String right = b[y];
    final int width = left.length < right.length ? left.length : right.length;
    for (int x = 0; x < width; x++) {
      if (left[x] != right[x]) differing++;
    }
    differing += (left.length - width) + (right.length - width);
  }
  differing += (a.length - rows) + (b.length - rows);
  return differing;
}

/// A control that does nothing, for the rows the probe renders.
void _noopJourney() {}

/// The key for the chevron's capture.
const Key _journeyChevronKey = ValueKey<String>('journey-chevron-boundary');
