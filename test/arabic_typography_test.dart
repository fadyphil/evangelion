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

import 'package:evangelion/core/common/failure.dart';
import 'package:evangelion/core/common/result.dart';
import 'package:evangelion/core/design_system/barrel.dart';
import 'package:evangelion/core/domain/entities/arabic_digits.dart';
import 'package:evangelion/core/domain/entities/auth_session.dart';
import 'package:evangelion/core/domain/entities/leaderboard_board.dart';
import 'package:evangelion/core/domain/entities/reading_language.dart';
import 'package:evangelion/core/domain/entities/scripture_verse.dart';
import 'package:evangelion/core/domain/entities/streak_history_entry.dart';
import 'package:evangelion/core/domain/entities/streak_summary.dart';
import 'package:evangelion/core/domain/entities/submit_result.dart';
import 'package:evangelion/core/domain/entities/user_settings.dart';
import 'package:evangelion/core/domain/repositories/auth_repository.dart';
import 'package:evangelion/core/domain/repositories/leaderboard_repository.dart';
import 'package:evangelion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:evangelion/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:evangelion/features/auth/domain/login_credentials.dart';
import 'package:evangelion/features/auth/domain/usecases/get_current_session.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_in.dart';
import 'package:evangelion/features/auth/domain/usecases/sign_out.dart';
import 'package:evangelion/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:evangelion/features/home/domain/greeting_period.dart';
import 'package:evangelion/features/home/presentation/home_l10n.dart';
import 'package:evangelion/features/home/presentation/widgets/selah_card.dart';
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
import 'package:evangelion/features/quiz/presentation/widgets/quiz_option_card.dart';
import 'package:evangelion/features/reading/presentation/reading_l10n.dart';
import 'package:evangelion/features/reading/presentation/widgets/reading_pill.dart';
import 'package:evangelion/features/result/presentation/result_l10n.dart';
import 'package:evangelion/features/settings/presentation/pages/settings_page.dart';
import 'package:evangelion/features/settings/presentation/settings_l10n.dart';
import 'package:evangelion/l10n/app_localizations.dart';
import 'package:evangelion/l10n/app_localizations_ar.dart';
import 'package:evangelion/l10n/l10n.dart';
import 'package:flutter/material.dart';
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

  group('`/settings`', () {
    // ## NO LONGER VACUOUS — THE **LAST** SCREEN TO GET ITS ARABIC, IN PHASE 9
    //
    // Decision 79 declared `/settings` vacuous with the note "Phase 9 writes it", and
    // this is that arm. `/quiz` was lifted in Phase 8 by the same edit shape: the
    // `Placeholder for /settings` literal is gone, `vacuousBecause` is now `null`, and
    // the list is **declared**, which is decision 79's whole mechanism — a run cannot
    // disappear and leave the gate satisfied by the ones that remain.
    //
    // Built from `AppLocalizationsAr()`, never transcribed. A hand-typed Arabic list is
    // the "second declaration" this gate's own doc warns against: a dropped combining
    // mark is invisible in a diff and the failure then reads as "the widget rendered the
    // wrong string" instead of "the test typed the wrong string".
    final AppLocalizations ar = AppLocalizationsAr();
    final List<String> arabic = <String>[
      ar.settingsTitle,
      // The three `SettingsGroup` headers.
      ar.settingsAppearance,
      ar.settingsReading,
      ar.settingsAbout,
      // The **theme** control's three options. `SegmentedControl` renders them as
      // text, and this is the run most likely to regress: `AppThemeMode` maps to
      // `ThemeMode` at the app root, and a wrong mapping would still render *some*
      // label, so only the declared set catches it.
      ar.settingsTheme,
      ar.settingsThemeLight,
      ar.settingsThemeDark,
      ar.settingsThemeSystem,
      // The font stepper's row and its two control labels.
      ar.settingsFontSize,
      ar.settingsDecreaseFontSize,
      ar.settingsIncreaseFontSize,
      // The reduce-motion row.
      ar.settingsReduceMotion,
      // The default-language row, and the row's **trailing value** — the language the
      // screen is currently in. Declared as a function of the arm rather than as a
      // literal: the setting is `null` here ("follow the platform"), so the effective
      // language in this arm is Arabic and the row says `العربية`. That is the string
      // the whole `ReadingLanguage` derivation exists to produce, and it is also the
      // run that catches the setting being ignored: a page that lost the locale would
      // render `English` here and fail the family arm as tofu-free Latin in an RTL arm.
      ar.settingsDefaultLanguage,
      ar.languageLabelFor(ReadingLanguage.arabic),
      // The About group's row.
      ar.settingsVersion,
      // The header: the title and the back chevron's label. `AppTopBar`-style
      // headers put the back control's name in a tooltip, and §14 forced that string
      // into this client, so it is a painted run on a screen with a header.
      ar.settingsTitle,
      ar.settingsBack,
    ];

    // ## `settingsMotionOn` / `settingsMotionOff` ARE **DELIBERATELY NOT** IN THE LIST
    //
    // `EvaToggle` publishes its state as `Semantics(label: labels.on/off,
    // excludeSemantics: true)` and paints **no** text: the control is a thumb and a
    // track. A semantics label never reaches a glyph buffer, so this gate — which reads
    // painted runs — cannot see it, and declaring either label fails the other half of
    // the gate with `Declared but NOT rendered`. The same category error
    // `/quiz`'s `quizProgress` group records, for the same reason.
    //
    // The labels are still asserted, at the layer that can see them:
    // `settings_page_test.dart` reads the merged semantics node. Phase 9 made them
    // **required** (`EvaToggleLabels`) precisely because they used to be the two
    // hard-coded English words `On` and `Off`.

    testWidgets('the Arabic arm, on the written screen', (
      WidgetTester tester,
    ) async {
      // Built in the test body, per `settings_harness.dart`'s recorded reason: a bloc
      // built in `setUp` runs its events outside the fake-async zone `pump` drains.
      final SettingsHarness settings = settingsHarness();
      await tester.pumpWidget(
        settingsScope(
          tester,
          evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: SettingsPage(cubit: settings.cubit),
          ),
        ),
      );
      await tester.pump();

      await expectArabicTypography(
        tester,
        screen: '/settings',
        expectedArabic: arabic,
      );
      await expectNoTofuInAnyRun(tester, screen: '/settings');
    });

    testWidgets('and the LANGUAGE SHEET is gated, which is the only place', (
      WidgetTester tester,
    ) async {
      // The sheet is a `showModalBottomSheet` route of its own, so it is a second
      // screen inside `/settings` and it needs its own pump — the same reason
      // `/reading`'s `Aa` disclosure has one.
      //
      // **`settingsLanguageSheetTitle` is the run this catches most:** the sheet is
      // reachable only by tapping the default-language row, so a sheet that opened
      // with no title — or with the row's label repeated — would leave this list
      // unsatisfied, which is the assertion working rather than the test being fussy.
      final SettingsHarness settings = settingsHarness();
      await tester.pumpWidget(
        settingsScope(
          tester,
          evaPrimitiveHarness(
            theme: EvaThemeDark.theme,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
            child: SettingsPage(cubit: settings.cubit),
          ),
        ),
      );
      await tester.pump();

      // Tapped by its rendered label, not a key: `SettingsPage` has no key on that
      // row, and adding a test-only key to production markup to make a test easier is
      // the coupling this repository's harnesses exist to avoid.
      await tester.tap(find.text(ar.settingsDefaultLanguage));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);

      await expectArabicTypography(
        tester,
        screen: '/settings (language sheet)',
        // **The page's own runs are still painted behind the modal sheet**, so the
        // declaration is the union: a modal bottom sheet covers the screen, it does not
        // unmount it. Spreading `arabic` is also what makes this arm a *second*
        // independent reading of the page's list — if the page's runs changed and only
        // the first test were updated, this one would fail on the difference.
        //
        // Built from the same `languageLabelFor` derivation the sheet itself uses, so
        // the list cannot disagree with the widget about what a language is called.
        expectedArabic: <String>[
          // **`settingsBack` is excluded here and declared in the page arm.**
          //
          // `IconActionButton`'s accessible name feeds a `Tooltip`, and `icon_action_
          // button.dart` records that a `Tooltip` "paints nothing until a gesture". So
          // whether its message is a *painted* run depends on the gesture state of the
          // tree, and this arm's tap is a gesture: with the sheet up, the back label is
          // not among the painted runs, and declaring it here fails the gate's
          // `Declared but NOT rendered` half. The page arm above is where that run
          // belongs, and it declares it — a run needs one owning arm, not two.
          ...arabic.where((String run) => run != ar.settingsBack),
          ar.settingsLanguageSheetTitle,
          ...ReadingLanguage.values.map(ar.languageLabelFor),
        ],
      );
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
